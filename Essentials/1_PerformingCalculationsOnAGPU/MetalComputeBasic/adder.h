//
//  adder.h
//  MetalComputeBasic
//
//  Created by Zero on 2020/8/3.
//  Copyright © 2020 Apple. All rights reserved.
//

#ifndef adder_h
#define adder_h

#import <Metal/Metal.h>

class Adder {
    
public:
    Adder * initWithDevice(id<MTLDevice> device);
    
    void prepareData();
    
    void sendComputeCommand();
    
    id<MTLDevice> _mDevice;

    id<MTLComputePipelineState> _mAddFunctionPSO;

    // The command queue used to pass commands to the device.
    id<MTLCommandQueue> _mCommandQueue;

    // Buffers to hold data.
    id<MTLBuffer> _mBufferA;
    id<MTLBuffer> _mBufferB;
    id<MTLBuffer> _mBufferResult;
};

#endif /* adder_h */
