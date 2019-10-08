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

#import "logging_api.h"
#import "platform_sys.h"
#import "srt.h"
#import "srt4udt.h"
#import "udt.h"
#import "udt_wrapper.h"
#import "version.h"
#import "ShaderDefinitions.h"

FOUNDATION_EXPORT double VideoCastVersionNumber;
FOUNDATION_EXPORT const unsigned char VideoCastVersionString[];

