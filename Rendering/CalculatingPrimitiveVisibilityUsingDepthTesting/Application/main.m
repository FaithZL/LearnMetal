/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main app entry point.
*/

#if defined(TARGET_IOS)
#import <UIKit/UIKit.h>
#import <TargetConditionals.h>
#import <Availability.h>
#import "AAPLAppDelegate.h"
#else
#import <Cocoa/Cocoa.h>
#endif

#if defined(TARGET_IOS)

//https://developer.apple.com/documentation/metal/calculating_primitive_visibility_using_depth_testing

// 跟OpenGL的深度测试有点区别，OpenGL是基于状态机的思想，在绘制之前，先设置好深度测试的状态
// metal的深度测试跟绘制一样，都是以指令的形式发送到GPU

int main(int argc, char * argv[]) {

#if TARGET_OS_SIMULATOR && (!defined(__IPHONE_13_0))
#error Metal is not supported in this version of Simulator.
#endif

    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AAPLAppDelegate class]));
    }
}

#elif defined(TARGET_MACOS)

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}

#endif
