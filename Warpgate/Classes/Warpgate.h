//
//  Warpgate.h
//  Warpgate
//
//  Created by 吕浩轩 on 2021/1/20.
//

#import <Foundation/Foundation.h>
#import "WarpgateProtocol.h"

#define WGRegister(service_protocol) [Warpgate registerService:@protocol(service_protocol) withModule:self.class];
#define WGModule(service_protocol) ((id<service_protocol>)[Warpgate moduleByService:@protocol(service_protocol)])
#define WGStr(fmt, ...) [NSString stringWithFormat:fmt, ##__VA_ARGS__]

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WarpgateExceptionCode)
{
    WGExceptionDefaultCode = -20001,
    WGExceptionUrlHandlerNotFound = -20002,
    WGExceptionModuleNotFoundException = -20003,
    WGExceptionAPINotFoundException = -20004,
    WGExceptionFailedToRegisterModule = -20005,
    WGExceptionFailedToSetupModule = -20006,
    WGExceptionFailedToFindModuleByService = -20007,

};
// WarpgateException exception name
extern NSExceptionName _Nonnull WarpgateExceptionName;
// Warpgate Exception userInfo keys
extern NSString *const _Nonnull kWarpgateExceptionCode;
extern NSString *const _Nonnull kWarpgateExceptionURLStr;
extern NSString *const _Nonnull kWarpgateExceptionURLParams;
extern NSString *const _Nonnull kWarpgateExceptionServiceProtocolStr;
extern NSString *const _Nonnull kWarpgateExceptionModuleClassStr;
extern NSString *const _Nonnull kWarpgateExceptionAPIStr;
extern NSString *const _Nonnull kWarpgateExceptionAPIArguments;

@interface NSException (Warpgate)
- (WarpgateExceptionCode)wg_exceptionCode;
@end

/**
 The handler for exceptions, like url not found, api not support, ...

 @param exception exceptions when handling route URLs or module APIs
 @return The substitute return object
 */
typedef _Nullable id (^WarpgateExceptionHandler)(NSException * _Nonnull exception);

@interface Warpgate : NSObject

/**
 Method to set exception handler

 @param handler the handler block
 */
+ (void)setExceptionHandler:(WarpgateExceptionHandler _Nullable )handler;

+ (WarpgateExceptionHandler _Nullable )getExceptionHandler;

/**
 Method to register the module srevice with module class.
 Each Module do the registeration before app launch event, like in the +load method.

 @param serviceProtocol the protocol for the module's service
 @param moduleClass The class of the module
 */
+ (void)registerService:(Protocol*_Nonnull)serviceProtocol
             withModule:(Class<WarpgateModuleProtocol> _Nonnull)moduleClass;

/**
 Method to unregister service

 @param serviceProtocol the protocol for the module's service
 */
+ (void)unregisterService:(Protocol*_Nonnull)serviceProtocol;

/**
 Method to setup all registered modules.
 It's recommended to invoke this method in AppDelegate's willFinishLaunchingWithOptions method.
 */
+ (void)setupAllModules;

/**
 Get module instance by service protocol.
 It's recomended to use macro WGModule for convenient

 @param serviceProtocol the service protocol used to register the module
 @return module instance
 */
+ (id<WarpgateModuleProtocol> _Nullable)moduleByService:(Protocol*_Nonnull)serviceProtocol;

//+ (NSArray<Protocol*>*_Nonnull)allRegisteredServices;
//

/**
 Method to get all registered module classes, sorted by module priority.

 @return module class array, not module instances
 */
+ (NSArray<Class<WarpgateModuleProtocol>>*_Nonnull)allRegisteredModules;

/**
 Method to enumarate all modules for methods in UIApplicationDelegate.
 
 @param selector app delegate selector
 @param arguments argument array
 @return the return value of the method implementation in those modules
 */
+ (BOOL)checkAllModulesWithSelector:(nonnull SEL)selector
                          arguments:(nullable NSArray*)arguments;

@end

NS_ASSUME_NONNULL_END
