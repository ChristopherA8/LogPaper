#import <Cocoa/Cocoa.h>

@interface VerboseBootCoreTextScrollView : NSScrollView

- (void)appendLine:(NSString *)line;
- (void)clear;

@end