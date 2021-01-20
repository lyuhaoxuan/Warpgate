//
//  WarpgateProtocol.h
//  Warpgate
//
//  Created by 吕浩轩 on 2021/1/20.
//

#ifndef WarpgateProtocol_h
#define WarpgateProtocol_h

#import <TargetConditionals.h>

#if TARGET_OS_OSX

#import <Cocoa/Cocoa.h>

@protocol WarpgateModuleProtocol <NSApplicationDelegate, NSObject>

#else

#import <UIKit/UIKit.h>

@protocol WarpgateModuleProtocol <UIApplicationDelegate, NSObject>

#endif

#define WarpgateModuleDefaultPriority 100

@required
/**
 Each module should be a singleton class

 @return module instance
 */
+ (instancetype)sharedInstance;

/**
 module setup method, will be invoked by module manager when app is launched or module is loaded.
 It's invoked in main thread synchronourly.
 It's strong recommended to run its content in background thread asynchronously to save launch time.
 */
- (void)setup;

@optional

/**
 The priority of the module to be setup. 0 is the lowest priority;
 If not provided, the default priority is WarpgateModuleDefaultPriority;

 @return the priority
 */
+ (NSUInteger)priority;


/**
 Whether to setup the module synchronously in main thread.
 If it's not implemeted, default value is NO, module will be sutup asyhchronously in backgorud thread.

 @return whether synchronously
 */
+ (BOOL)setupModuleSynchronously;

@end

//@protocol WarpgateServcieProtocol <NSObject>
//
//@end

#endif /* WarpgateModuleProtocol_h */
