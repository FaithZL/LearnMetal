# Processing a Texture in a Compute Function

Perform data-parallel computations on texture data.

## Overview

In the [Creating and Sampling Textures](https://developer.apple.com/documentation/metal/creating_and_sampling_textures) sample, you learned how to apply textures to a primitive in the rendering pipeline. In this sample, you'll learn how to work with textures in a compute function.

Graphics and compute workloads are not mutually exclusive; Metal provides a unified framework and language that enables seamless integration of graphics and compute workloads. This sample demonstrates this integration by using a compute pipeline to process a color texture into a grayscale image, and then using a graphics pipeline to render that grayscale image to a quad.


## Write a Kernel Function

This sample loads image data into a texture and then uses a kernel function to convert the texture's pixels from color to grayscale. The kernel function processes the pixels independently and concurrently.

The kernel function in this sample is called `grayscaleKernel` and its signature is shown below:

``` metal
kernel void
grayscaleKernel(texture2d<half, access::read>  inTexture  [[texture(AAPLTextureIndexInput)]],
                texture2d<half, access::write> outTexture [[texture(AAPLTextureIndexOutput)]],
                uint2                          gid         [[thread_position_in_grid]])
```

The function takes the following resource parameters:

* `inTexture`: A read-only, 2D texture that contains the input color pixels.
* `outTexture`: A write-only, 2D texture that stores the output grayscale pixels.

Textures that specify a `read` access qualifier can be read from using the `read()` function. Textures that specify a `write` access qualifier can be written to using the `write()` function.

Because this sample processes a 2D texture, the threads are arranged in a 2D grid where each thread corresponds to a unique texel. The kernel function's `gid` parameter uses the ` [[thread_position_in_grid]]` attribute qualifier to receive coordinates for each thread.

A grayscale pixel has the same value for each of its RGB components. This value can be calculated by applying certain weights to each component. This sample uses the Rec. 709 luma coefficients for the color-to-grayscale conversion. First, the function reads a pixel from the texture, using the thread's coordinates to identify which pixel each thread receives. After performing the conversion, it uses the same coordinates to write out the value to the output texture.

``` metal
half4 inColor  = inTexture.read(gid);
half  gray     = dot(inColor.rgb, kRec709Luma);
outTexture.write(half4(gray, gray, gray, 1.0), gid);
```

## Execute a Compute Pass

To process the image, the sample creates a `MTLComputeCommandEncoder` object. 
``` objective-c
id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
```

To dispatch the compute command, the sample needs to know how many times to execute the kernel function, and it calculates this at initialization time. This count corresponds to the grid size, which you define in terms of threads and threadgroups. In this sample, each thread corresponds to a unique texel, and the grid size must be at least the size of the 2D image. For simplicity, this sample uses a 16 x 16 threadgroup size, which is small enough to be used by any GPU. In practice, however, selecting an efficient threadgroup size depends on both the size of the data and the capabilities of a specific device.

``` objective-c
// Set the compute kernel's threadgroup size to 16x16
_threadgroupSize = MTLSizeMake(16, 16, 1);

// Calculate the number of rows and columns of threadgroups given the width of the input image
// Ensure that you cover the entire image (or more) so you process every pixel
_threadgroupCount.width  = (_inputTexture.width  + _threadgroupSize.width -  1) / _threadgroupSize.width;
_threadgroupCount.height = (_inputTexture.height + _threadgroupSize.height - 1) / _threadgroupSize.height;
```

The sample encodes a reference to the compute pipeline and the input and output textures, and then encodes the compute command.
``` objective-c

[computeEncoder setComputePipelineState:_computePipelineState];

[computeEncoder setTexture:_inputTexture
                   atIndex:AAPLTextureIndexInput];

[computeEncoder setTexture:_outputTexture
                   atIndex:AAPLTextureIndexOutput];

[computeEncoder dispatchThreadgroups:_threadgroupCount
               threadsPerThreadgroup:_threadgroupSize];

[computeEncoder endEncoding];
```

After finishing the compute pass, the sample encodes a render pass in the same command buffer, using the rendering commands first introduced in the [Creating and Sampling Textures](https://developer.apple.com/documentation/metal/creating_and_sampling_textures) sample. The output texture from the kernel is passed as the input to the drawing command. Metal automatically tracks dependencies between the compute pass and the render pass. When you send the command buffer to be executed, because Metal sees that the output texture is written by the compute pass and read by the render pass, it makes sure the GPU finishes the compute pass before starting the render pass. If this dependency weren't there, Metal might be able to execute both at the same time.
