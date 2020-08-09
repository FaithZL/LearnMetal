/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Application entry point for all platforms
*/

#if defined(TARGET_IOS) || defined(TARGET_TVOS)
#import <UIKit/UIKit.h>
#import <TargetConditionals.h>
#import "AAPLAppDelegate.h"
#else
#import <Cocoa/Cocoa.h>
#endif

#if defined(TARGET_IOS) || defined(TARGET_TVOS)

// https://developer.apple.com/documentation/metal/processing_a_texture_in_a_compute_function
// 这节感觉没神马特别的，就是多了个灰度后处理
int main(int argc, char * argv[]) {

    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AAPLAppDelegate class]));
    }
}

#elif defined(TARGET_MACOS)

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}

#endif
