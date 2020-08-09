/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of renderer class which performs Metal setup and per frame rendering
*/

@import simd;
@import MetalKit;

#import "AAPLRenderer.h"
#import "AAPLImage.h"

// Header shared between C code here, which executes Metal API commands, and .metal files, which
//   uses these types as inputs to the shaders
#import "AAPLShaderTypes.h"

// Main class performing the rendering
@implementation AAPLRenderer
{
    // The device (aka GPU) being used to process images.
    id<MTLDevice> _device;

    id<MTLComputePipelineState> _computePipelineState;
    id<MTLRenderPipelineState> _renderPipelineState;

    id<MTLCommandQueue> _commandQueue;

    // Texture object which serves as the source for image processing
    id<MTLTexture> _inputTexture;

    // Texture object which serves as the output for image processing
    id<MTLTexture> _outputTexture;

    // The current size of the viewport, used in the render pipeline.
    vector_uint2 _viewportSize;

    // Compute kernel dispatch parameters
    MTLSize _threadgroupSize;
    MTLSize _threadgroupCount;
}

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView
{
    self = [super init];
    if(self)
    {
        NSError *error = NULL;

        _device = mtkView.device;

        mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;

        // Load all the shader files with a .metal file extension in the project.
        id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];

        // Load the image processing function from the library and create a pipeline from it.
        id<MTLFunction> kernelFunction = [defaultLibrary newFunctionWithName:@"grayscaleKernel"];
        _computePipelineState = [_device newComputePipelineStateWithFunction:kernelFunction
                                                                       error:&error];

        // Compute pipeline State creation could fail if kernelFunction failed to load from the
        // library.  If the Metal API validation is enabled, you automatically get more
        // information about what went wrong.  (Metal API validation is enabled by default
        // when you run a debug build from Xcode.)
        NSAssert(_computePipelineState, @"Failed to create compute pipeline state: %@", error);

        // Load the vertex and fragment functions, and use them to configure a render pipeline.
        id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
        id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"samplingShader"];

        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label = @"Simple Render Pipeline";
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;

        _renderPipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                 error:&error];

        NSAssert(_renderPipelineState, @"Failed to create render pipeline state: %@", error);

        NSURL *imageFileLocation = [[NSBundle mainBundle] URLForResource:@"Image"
                                                           withExtension:@"tga"];

        AAPLImage * image = [[AAPLImage alloc] initWithTGAFileAtLocation:imageFileLocation];

        if(!image)
        {
            return nil;
        }

        MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];
        textureDescriptor.textureType = MTLTextureType2D;
        // Indicate that each pixel has a Blue, Green, Red, and Alpha channel,
        //   each in an 8 bit unnormalized value (0 maps 0.0 while 255 maps to 1.0)
        textureDescriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
        textureDescriptor.width = image.width;
        textureDescriptor.height = image.height;
        
        // The image kernel only needs to read the incoming image data.
        
        textureDescriptor.usage = MTLTextureUsageShaderRead;
        _inputTexture = [_device newTextureWithDescriptor:textureDescriptor];

        // The output texture needs to be written by the image kernel, and sampled
        // by the rendering code.
        
        textureDescriptor.usage = MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead ;
        _outputTexture = [_device newTextureWithDescriptor:textureDescriptor];

        MTLRegion region = {{ 0, 0, 0 }, {textureDescriptor.width, textureDescriptor.height, 1}};

        // size of each texel * the width of the textures
        NSUInteger bytesPerRow = 4 * textureDescriptor.width;

        // Copy the bytes from our data object into the texture
        [_inputTexture replaceRegion:region
                    mipmapLevel:0
                      withBytes:image.data.bytes
                    bytesPerRow:bytesPerRow];

        NSAssert(_inputTexture && !error, @"Failed to create inpute texture: %@", error);

        // Set the compute kernel's threadgroup size to 16x16
        _threadgroupSize = MTLSizeMake(16, 16, 1);

        // Calculate the number of rows and columns of threadgroups given the width of the input image
        // Ensure that you cover the entire image (or more) so you process every pixel
        _threadgroupCount.width  = (_inputTexture.width  + _threadgroupSize.width -  1) / _threadgroupSize.width;
        _threadgroupCount.height = (_inputTexture.height + _threadgroupSize.height - 1) / _threadgroupSize.height;

        // The image data is 2D, so set depth to 1
        _threadgroupCount.depth = 1;

        // Create the command queue
        _commandQueue = [_device newCommandQueue];
    }

    return self;
}

/// Called whenever view changes orientation or is resized
- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
{
    // Save the size of the drawable to pass to the render pipeline.
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
}

/// Called whenever the view needs to render a frame
- (void)drawInMTKView:(nonnull MTKView *)view
{
    static const AAPLVertex quadVertices[] =
    {
        // Pixel positions, Texture coordinates
        { {  250,  -250 },  { 1.f, 1.f } },
        { { -250,  -250 },  { 0.f, 1.f } },
        { { -250,   250 },  { 0.f, 0.f } },

        { {  250,  -250 },  { 1.f, 1.f } },
        { { -250,   250 },  { 0.f, 0.f } },
        { {  250,   250 },  { 1.f, 0.f } },
    };

    // Create a new command buffer for each frame.
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";

    // Process the input image.
    id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];

    // 先进行灰化处理
    [computeEncoder setComputePipelineState:_computePipelineState];

    [computeEncoder setTexture:_inputTexture
                       atIndex:AAPLTextureIndexInput];

    [computeEncoder setTexture:_outputTexture
                       atIndex:AAPLTextureIndexOutput];
    
    [computeEncoder dispatchThreadgroups:_threadgroupCount
                   threadsPerThreadgroup:_threadgroupSize];

    [computeEncoder endEncoding];

    // Use the output image to draw to the view's drawable texture.
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;

    if(renderPassDescriptor != nil)
    {
        // Create the encoder for the render pass.
        id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";

        // Set the region of the drawable to draw into.
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, _viewportSize.x, _viewportSize.y, -1.0, 1.0 }];

        [renderEncoder setRenderPipelineState:_renderPipelineState];

        //  Encode the vertex data.
        [renderEncoder setVertexBytes:quadVertices
                               length:sizeof(quadVertices)
                              atIndex:AAPLVertexInputIndexVertices];

        // Encode the viewport data.
        [renderEncoder setVertexBytes:&_viewportSize
                               length:sizeof(_viewportSize)
                              atIndex:AAPLVertexInputIndexViewportSize];

        // Encode the output texture from the previous stage.
        // 设置纹理，直接将计算好的内容传入
        [renderEncoder setFragmentTexture:_outputTexture
                                  atIndex:AAPLTextureIndexOutput];

        // Draw the quad.
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                          vertexStart:0
                          vertexCount:6];
        
        // 这个不能漏掉，这个表示所有命令已经生成完毕
        [renderEncoder endEncoding];

        // Schedule a present once the framebuffer is complete using the current drawable
        [commandBuffer presentDrawable:view.currentDrawable];
    }

    [commandBuffer commit];
}

@end
