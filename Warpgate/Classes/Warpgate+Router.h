//
//  Warpgate+Router.h
//  Warpgate
//
//  Created by 吕浩轩 on 2021/1/20.
//

#import "Warpgate.h"

NS_ASSUME_NONNULL_BEGIN

#define BFComplete(Params, Result) [Warpgate completeWithParameters:Params result:Result]

// default keys in the parameters of WarpgateRouteHandler
extern NSString * const kWarpgateRouteURL; //the key for the raw url
extern NSString * const kWarpgateRouteCompletion; //the key for the completion block.

/**
 The handler for a binded url
 
 @param parameters containers above 2 keys and parameters from the query string and complexParams
 @return the obj returned by the handler
 */
typedef _Nullable id (^WarpgateRouteHandler)( NSDictionary * _Nullable parameters);

/**
 The completion block to be invoked at the end of the router handler block
 
 @param result completion result. defaultly it is the returned object of the WarpgateRouteHandler.
 */
typedef void (^WarpgateRouteCompletion)(_Nullable id result);

@interface Warpgate (Router)

/**
 The method to bind a URL to handler
 
 @param urlStr The URL string. Only scheme, host and api path will be used here.
 Its query string will be ignore here.
 @param handler the handler block.
 The WarpgateRouteCompletion should be invoked at the end of the block
 */
+ (void)bindURL:(NSString *)urlStr toHandler:(WarpgateRouteHandler)handler;

/**
 The method to unbind a URL
 
 @param urlStr The URL string. Only scheme, host and api path will be used here.
 Its query string will be ignore here.
 */
+ (void)unbindURL:(NSString *)urlStr;

/**
 Method to unbind all URLs
 */
+ (void)unbindAllURLs;

/**
 The method to check whether a url can be handled
 
 @param urlStr The URL string. Only scheme, host and api path will be used here.
 Its query string will be ignore here.
 */
+ (BOOL)canHandleURL:(NSString *)urlStr;

/**
 Method to handle the URL
 
 @param urlStr URL string
 @return the returned object of the url's WarpgateRouteHandler
 */
+ (nullable id)handleURL:(NSString *)urlStr;

/**
 Method to handle the url with completion block
 
 @param urlStr URL string
 @param completion The completion block
 @return the returned object of the url's WarpgateRouteHandler
 */
+ (nullable id)handleURL:(NSString *)urlStr
              completion:(nullable WarpgateRouteCompletion)completion;

/**
 The method to handle URL with complex parameters and completion block
 
 @param urlStr URL string
 @param complexParams complex parameters that can't be put in the url query strings
 @param completion The completion block
 @return the returned object of the url's WarpgateRouteHandler
 */
+ (nullable id)handleURL:(NSString *)urlStr
           complexParams:(nullable NSDictionary*)complexParams
              completion:(nullable WarpgateRouteCompletion)completion;

/**
 Invoke the completion block in the parameters of WarpgateRouteHandler.
 Recommend to use macro BFComplete for convenient.
 
 @param params parameters of WarpgateRouteHandler
 @param result the result for the WarpgateRouteCompletion
 */
+ (void)completeWithParameters:(nullable NSDictionary*)params result:(nullable id)result;

@end

NS_ASSUME_NONNULL_END
