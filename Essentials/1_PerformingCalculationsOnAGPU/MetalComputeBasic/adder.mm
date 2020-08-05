//
//  adder.m
//  MetalComputeBasic
//
//  Created by Zero on 2020/8/3.
//  Copyright © 2020 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "adder.h"

Adder * Adder::initWithDevice(id<MTLDevice> device) {
    _mDevice = device;
    
    return this;
}
