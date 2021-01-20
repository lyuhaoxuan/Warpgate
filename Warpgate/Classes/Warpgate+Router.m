//
//  Warpgate+Router.m
//  Warpgate
//
//  Created by 吕浩轩 on 2021/1/20.
//

#import "Warpgate+Router.h"

#define WGLog(msg) NSLog(@"[Warpgate] %@", (msg))
#define WGKey(URL) [Warpgate keyForURL:URL]

NSString *const kWarpgateRouteURL = @"kWarpgateRouteURL";
NSString *const kWarpgateRouteCompletion = @"kWarpgateRouteCompletion";

@implementation Warpgate (Router)

+ (nonnull NSString*)keyForURL:(nonnull NSString*)urlStr {
    NSURL *URL = [NSURL URLWithString:urlStr];
    NSString *key = [NSString stringWithFormat:@"%@%@", URL.host, URL.path];
    return key;
}

+ (nullable NSDictionary*)parametersInURL:(nonnull NSString*)urlStr {
    NSURL *URL = [NSURL URLWithString:urlStr];
    NSMutableDictionary *params = nil;
    NSString *query = URL.query;
    if(query.length > 0) {
        params = [NSMutableDictionary dictionary];
        NSArray *list = [query componentsSeparatedByString:@"&"];
        for (NSString *param in list) {
            NSArray *elts = [param componentsSeparatedByString:@"="];
            if([elts count] < 2) continue;
            NSString *decodedStr = [[elts lastObject] stringByRemovingPercentEncoding];
            [params setObject:decodedStr forKey:[elts firstObject]];
        }
    }
    return params;
}

+ (NSMutableDictionary*)routes {
    @synchronized (self) {
        static NSMutableDictionary *_routes = nil;
        if (!_routes) {
            _routes = [NSMutableDictionary dictionary];
        }
        return _routes;
    }
}

+ (void)bindURL:(nonnull NSString *)urlStr toHandler:(nonnull WarpgateRouteHandler)handler {
    [self.routes setObject:handler forKey:WGKey(urlStr)];
}

+ (void)unbindURL:(nonnull NSString *)urlStr {
    [self.routes removeObjectForKey:WGKey(urlStr)];
}

+ (void)unbindAllURLs {
    [self.routes removeAllObjects];
}

+ (nullable WarpgateRouteHandler)handlerForURL:(nonnull NSString *)urlStr {
    return [self.routes objectForKey:WGKey(urlStr)];
}

+ (BOOL)canHandleURL:(nonnull NSString *)urlStr {
    if (urlStr.length == 0) {
        return NO;
    }
    if ([self handlerForURL:urlStr]) {
        return YES;
    } else {
        return NO;
    }
}

+ (nullable id)handleURL:(nonnull NSString *)urlStr {
    return [self handleURL:urlStr complexParams:nil completion:nil];
}

+ (nullable id)handleURL:(nonnull NSString *)urlStr
              completion:(nullable WarpgateRouteCompletion)completion {
    return [self handleURL:urlStr complexParams:nil completion:completion];
}

+ (nullable id)handleURL:(nonnull NSString *)urlStr
           complexParams:(nullable NSDictionary*)complexParams
              completion:(nullable WarpgateRouteCompletion)completion {
    id obj = nil;
    @try {
        WarpgateRouteHandler handler = [self handlerForURL:urlStr];
        NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:complexParams];
        [params addEntriesFromDictionary:[self.class parametersInURL:urlStr]];
        [params setObject:urlStr forKey:kWarpgateRouteURL];
        if (completion) {
            [params setObject:completion forKey:kWarpgateRouteCompletion];
        }
        if (!handler) {
            NSString *reason = [NSString stringWithFormat:@"Cannot find handler for route url %@", urlStr];
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            [userInfo setValue:@(WGExceptionUrlHandlerNotFound) forKey:kWarpgateExceptionCode];
            [userInfo setValue:urlStr forKey:kWarpgateExceptionURLStr];
            [userInfo setValue:params forKey:kWarpgateExceptionURLParams];
            NSException *exception = [[NSException alloc] initWithName:WarpgateExceptionName
                                                                reason:reason
                                                              userInfo:userInfo];
            WarpgateExceptionHandler handler = [self getExceptionHandler];
            if (handler) {
                obj = handler(exception);
            }
            WGLog(reason);
        } else {
            obj = handler(params);
        }
    } @catch (NSException *exception) {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:exception.userInfo];
        [userInfo setValue:@(WGExceptionDefaultCode) forKey:kWarpgateExceptionCode];
        [userInfo setValue:urlStr forKey:kWarpgateExceptionURLStr];
        [userInfo setValue:complexParams forKey:kWarpgateExceptionURLParams];
        NSException *ex = [[NSException alloc] initWithName:exception.name
                                                     reason:exception.reason
                                                   userInfo:userInfo];
        WarpgateExceptionHandler handler = [self getExceptionHandler];
        if (handler) {
            obj = handler(ex);
        }
        WGLog(exception.reason);
    } @finally {
        return obj;
    }
}

+ (void)completeWithParameters:(nullable NSDictionary*)params result:(_Nullable id)result {
    WarpgateRouteCompletion completion = params[kWarpgateRouteCompletion];
    if (completion) {
        completion(result);
    }
}

@end
