//
//  Warpgate.m
//  Warpgate
//
//  Created by 吕浩轩 on 2021/1/20.
//

#import "Warpgate.h"
#import <objc/message.h>
#import <objc/runtime.h>

#define WGLog(msg) NSLog(@"[Warpgate] %@", (msg))
#define WGInstance [Warpgate sharedInstance]

NSExceptionName WarpgateExceptionName = @"WarpgateExceptionName";
NSString * const kWarpgateExceptionCode = @"WarpgateExceptionCode";
NSString * const kWarpgateExceptionURLStr = @"kWarpgateExceptionURLStr";
NSString * const kWarpgateExceptionURLParams = @"kWarpgateExceptionURLParams";
NSString * const kWarpgateExceptionServiceProtocolStr = @"kWarpgateExceptionServiceProtocolStr";
NSString * const kWarpgateExceptionModuleClassStr = @"kWarpgateExceptionModuleClassStr";
NSString * const kWarpgateExceptionAPIStr = @"kWarpgateExceptionAPIStr";
NSString * const kWarpgateExceptionAPIArguments = @"kWarpgateExceptionAPIArguments";

@implementation NSException (Warpgate)
- (WarpgateExceptionCode)wg_exceptionCode {
    return [self.userInfo[kWarpgateExceptionCode] integerValue];
}
@end

@interface NSObject (Warpgate)
- (void)wg_doesNotRecognizeSelector:(SEL)aSelector;
@end

@interface Warpgate() {
    
}
@property (nonatomic, copy) WarpgateExceptionHandler _Nullable exceptionHandler;
@property (nonatomic, strong) NSMutableDictionary *moduleDict; // <moduleName, moduleClass>
@property (nonatomic, strong) NSMutableDictionary *moduleInvokeDict;
+ (instancetype _Nonnull )sharedInstance;
@end

@implementation Warpgate

+ (instancetype _Nonnull )sharedInstance
{
    static Warpgate *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        instance.moduleDict = [NSMutableDictionary dictionary];
        instance.moduleInvokeDict = [NSMutableDictionary dictionary];
    });
    return instance;
}

+ (void)setExceptionHandler:(WarpgateExceptionHandler _Nullable )handler {
    WGInstance.exceptionHandler = handler;
}

+ (WarpgateExceptionHandler _Nullable )getExceptionHandler {
    return WGInstance.exceptionHandler;
}

+ (void)registerService:(Protocol*_Nonnull)serviceProtocol
             withModule:(Class<WarpgateModuleProtocol> _Nonnull)moduleClass {
    NSString *protocolStr = NSStringFromProtocol(serviceProtocol);
    NSString *moduleStr = NSStringFromClass(moduleClass);
    Class class = moduleClass; // to avoid warning
    NSString *exReason = nil;
    if (protocolStr.length == 0) {
        exReason =  WGStr(@"Needs a valid protocol for module %@", moduleStr);
    } else if (moduleStr.length == 0) {
        exReason =  WGStr(@"Needs a valid module for protocol %@", protocolStr);
    } else if (![class conformsToProtocol:serviceProtocol]) {
        exReason =  WGStr(@"Module %@ should confirm to protocol %@", moduleStr, protocolStr);
    } else {
        [self hackUnrecognizedSelecotorExceptionForModule:moduleClass];
        [WGInstance.moduleDict setObject:moduleClass forKey:protocolStr];
    }
    if (exReason.length > 0)  {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        [userInfo setValue:@(WGExceptionFailedToRegisterModule) forKey:kWarpgateExceptionCode];
        [userInfo setValue:protocolStr forKey:kWarpgateExceptionServiceProtocolStr];
        NSException *exception = [[NSException alloc] initWithName:WarpgateExceptionName
                                                            reason:exReason
                                                          userInfo:userInfo];
        WarpgateExceptionHandler handler = [self getExceptionHandler];
        if (handler) {
            handler(exception);
        }
        WGLog(exReason);
    }
}

+ (void)unregisterService:(Protocol*_Nonnull)serviceProtocol {
    NSString *str = NSStringFromProtocol(serviceProtocol);
    if (str.length > 0) {
        [WGInstance.moduleDict removeObjectForKey:str];
    } else {
        WGLog(@"Failed to unregister service, protocol is empty");
    }
}

+ (NSArray<Class<WarpgateModuleProtocol>>*_Nonnull)allRegisteredModules {
    NSArray *modules = WGInstance.moduleDict.allValues;
    NSArray *sortedModules = [modules sortedArrayUsingComparator:^NSComparisonResult(Class class1, Class class2) {
        NSUInteger priority1 = WarpgateModuleDefaultPriority;
        NSUInteger priority2 = WarpgateModuleDefaultPriority;
        if ([class1 respondsToSelector:@selector(priority)]) {
            priority1 = [class1 priority];
        }
        if ([class2 respondsToSelector:@selector(priority)]) {
            priority2 = [class2 priority];
        }
        if(priority1 == priority2) {
            return NSOrderedSame;
        } else if(priority1 < priority2) {
            return NSOrderedDescending;
        } else {
            return NSOrderedAscending;
        }
    }];
    return sortedModules;
}

+ (void)setupAllModules {
    NSArray *modules = [self allRegisteredModules];
    for (Class<WarpgateModuleProtocol> moduleClass in modules) {
        @try {
            BOOL setupSync = NO;
            if ([moduleClass respondsToSelector:@selector(setupModuleSynchronously)]) {
                setupSync = [moduleClass setupModuleSynchronously];
            }
            if (setupSync) {
                [[moduleClass sharedInstance] setup];
            } else {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [[moduleClass sharedInstance] setup];
                });
            }
        } @catch (NSException *exception) {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:exception.userInfo];
            [userInfo setValue:@(WGExceptionFailedToSetupModule) forKey:kWarpgateExceptionCode];
            [userInfo setValue:NSStringFromClass(moduleClass) forKey:kWarpgateExceptionModuleClassStr];
            NSException *ex = [[NSException alloc] initWithName:exception.name
                                                         reason:exception.reason
                                                       userInfo:userInfo];
            WarpgateExceptionHandler handler = [self getExceptionHandler];
            if (handler) {
                 handler(ex);
            }
            WGLog(exception.reason);
        }
    }
}

+ (id<WarpgateModuleProtocol> _Nullable)moduleByService:(Protocol*_Nonnull)serviceProtocol {
    NSString *protocolStr = NSStringFromProtocol(serviceProtocol);
    NSString *exReason = nil;
    NSException *exception = nil;
    if (protocolStr.length == 0) {
        exReason = WGStr(@"Invalid service protocol");
    } else {
        Class class = WGInstance.moduleDict[protocolStr];
        NSString *classStr = NSStringFromClass(class);
        if (!class) {
            exReason = WGStr(@"Failed to find module by protocol %@", protocolStr);
        } else if (![class conformsToProtocol:@protocol(WarpgateModuleProtocol)]) {
            exReason = WGStr(@"Found %@ by protocol %@, but the module doesn't confirm to protocol WarpgateModuleProtocol",
                            classStr, protocolStr);
        } else {
            @try {
                id instance = [class sharedInstance];
                return instance;
            } @catch (NSException *ex) {
                exception = ex;
            }
        }
    }
    if (exReason.length > 0) {
        NSExceptionName name = WarpgateExceptionName;
        NSMutableDictionary *userInfo = nil;
        if (exception != nil) {
            userInfo = [NSMutableDictionary dictionaryWithDictionary:exception.userInfo];
            name = exception.name;
        } else {
            userInfo = [NSMutableDictionary dictionary];
        }
        [userInfo setValue:@(WGExceptionFailedToFindModuleByService) forKey:kWarpgateExceptionCode];
        [userInfo setValue:NSStringFromProtocol(serviceProtocol) forKey:kWarpgateExceptionServiceProtocolStr];
        NSException *ex = [[NSException alloc] initWithName:name
                                                            reason:exReason
                                                          userInfo:userInfo];
        WarpgateExceptionHandler handler = [self getExceptionHandler];
        if (handler) {
            handler(ex);
        }
        WGLog(exReason);
        return nil;
    }
    
}

+ (BOOL)checkAllModulesWithSelector:(SEL)selector arguments:(NSArray*)arguments {
    BOOL result = NO;
    NSArray *modules = [self allRegisteredModules];
    for (Class<WarpgateModuleProtocol> class in modules) {
        id<WarpgateModuleProtocol> moduleItem = [class sharedInstance];
        if ([moduleItem respondsToSelector:selector]) {
            
            __block BOOL shouldInvoke = YES;
            if (![WGInstance.moduleInvokeDict objectForKey:NSStringFromClass([moduleItem class])]) {
                // 如果 modules 里面有 moduleItem 的子类，不 invoke target
                [modules enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if ([NSStringFromClass([obj superclass]) isEqualToString:NSStringFromClass([moduleItem class])]) {
                        shouldInvoke = NO;
                        *stop = YES;
                    }
                }];
            }
            
            if (shouldInvoke) {
                if (![WGInstance.moduleInvokeDict objectForKey:NSStringFromClass([moduleItem class])]) { //cache it
                    [WGInstance.moduleInvokeDict setObject:moduleItem forKey:NSStringFromClass([moduleItem class])];
                }
                
                BOOL ret = NO;
                [self invokeTarget:moduleItem action:selector arguments:arguments returnValue:&ret];
                if (!result) {
                    result = ret;
                }
            }
        }
    }
    return result;
}


+ (BOOL)invokeTarget:(id)target
              action:(_Nonnull SEL)selector
           arguments:(NSArray* _Nullable )arguments
         returnValue:(void* _Nullable)result; {
    if (target && [target respondsToSelector:selector]) {
        NSMethodSignature *sig = [target methodSignatureForSelector:selector];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
        [invocation setTarget:target];
        [invocation setSelector:selector];
        for (NSUInteger i = 0; i<[arguments count]; i++) {
            NSUInteger argIndex = i+2;
            id argument = arguments[i];
            if ([argument isKindOfClass:NSNumber.class]) {
                //convert number object to basic num type if needs
                BOOL shouldContinue = NO;
                NSNumber *num = (NSNumber*)argument;
                const char *type = [sig getArgumentTypeAtIndex:argIndex];
                if (strcmp(type, @encode(BOOL)) == 0) {
                    BOOL rawNum = [num boolValue];
                    [invocation setArgument:&rawNum atIndex:argIndex];
                    shouldContinue = YES;
                } else if (strcmp(type, @encode(int)) == 0
                           || strcmp(type, @encode(short)) == 0
                           || strcmp(type, @encode(long)) == 0) {
                    NSInteger rawNum = [num integerValue];
                    [invocation setArgument:&rawNum atIndex:argIndex];
                    shouldContinue = YES;
                } else if(strcmp(type, @encode(long long)) == 0) {
                    long long rawNum = [num longLongValue];
                    [invocation setArgument:&rawNum atIndex:argIndex];
                    shouldContinue = YES;
                } else if (strcmp(type, @encode(unsigned int)) == 0
                           || strcmp(type, @encode(unsigned short)) == 0
                           || strcmp(type, @encode(unsigned long)) == 0) {
                    NSUInteger rawNum = [num unsignedIntegerValue];
                    [invocation setArgument:&rawNum atIndex:argIndex];
                    shouldContinue = YES;
                } else if(strcmp(type, @encode(unsigned long long)) == 0) {
                    unsigned long long rawNum = [num unsignedLongLongValue];
                    [invocation setArgument:&rawNum atIndex:argIndex];
                    shouldContinue = YES;
                } else if (strcmp(type, @encode(float)) == 0) {
                    float rawNum = [num floatValue];
                    [invocation setArgument:&rawNum atIndex:argIndex];
                    shouldContinue = YES;
                } else if (strcmp(type, @encode(double)) == 0) { // double
                    double rawNum = [num doubleValue];
                    [invocation setArgument:&rawNum atIndex:argIndex];
                    shouldContinue = YES;
                }
                if (shouldContinue) {
                    continue;
                }
            }
            if ([argument isKindOfClass:[NSNull class]]) {
                argument = nil;
            }
            [invocation setArgument:&argument atIndex:argIndex];
        }
        [invocation invoke];
        NSString *methodReturnType = [NSString stringWithUTF8String:sig.methodReturnType];
        if (result && ![methodReturnType isEqualToString:@"v"]) { //if return type is not void
            if([methodReturnType isEqualToString:@"@"]) { //if it's kind of NSObject
                CFTypeRef cfResult = nil;
                [invocation getReturnValue:&cfResult]; //this operation won't retain the result
                if (cfResult) {
                    CFRetain(cfResult); //we need to retain it manually
                    *(void**)result = (__bridge_retained void *)((__bridge_transfer id)cfResult);
                }
            } else {
                [invocation getReturnValue:result];
            }
        }
        return YES;
    }
    return NO;
}

+ (void)hackUnrecognizedSelecotorExceptionForModule:(Class)class {
    SEL originSEL = @selector(doesNotRecognizeSelector:);
    SEL newSEL = @selector(wg_doesNotRecognizeSelector:);
    [self swizzleOrginSEL:originSEL withNewSEL:newSEL inClass:class];
}

+ (void)swizzleOrginSEL:(SEL)originSEL withNewSEL:(SEL)newSEL inClass:(Class)class {
    Method origMethod = class_getInstanceMethod(class, originSEL);
    Method overrideMethod = class_getInstanceMethod(class, newSEL);
    if (class_addMethod(class, originSEL, method_getImplementation(overrideMethod),
                        method_getTypeEncoding(overrideMethod))) {
        class_replaceMethod(class, newSEL, method_getImplementation(origMethod),
                            method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, overrideMethod);
    }
}

@end

@implementation NSObject (Warpgate)

- (void)wg_doesNotRecognizeSelector:(SEL)aSelector {
    @try {
        [self wg_doesNotRecognizeSelector:aSelector];
    } @catch (NSException *ex) {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        [userInfo setValue:@(WGExceptionAPINotFoundException) forKey:kWarpgateExceptionCode];
        NSException *exception = [[NSException alloc] initWithName:ex.name
                                                            reason:ex.reason
                                                          userInfo:userInfo];
        if (WGInstance.exceptionHandler) {
            WGInstance.exceptionHandler(exception);
        } else {
#ifdef DEBUG
            @throw exception;
#endif
        }
    } @finally {
    }
}

@end
