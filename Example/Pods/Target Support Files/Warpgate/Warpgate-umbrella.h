#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "Warpgate+Router.h"
#import "Warpgate.h"
#import "WarpgateHeader.h"
#import "WarpgateProtocol.h"

FOUNDATION_EXPORT double WarpgateVersionNumber;
FOUNDATION_EXPORT const unsigned char WarpgateVersionString[];

