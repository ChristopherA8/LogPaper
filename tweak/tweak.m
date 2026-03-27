#include "VerboseBootCoreTextScrollView.h"
#include <AppKit/AppKit.h>
#import <Cocoa/Cocoa.h>
#include <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@interface TView : NSView {
    struct CGSize _maxSize;
    struct CGSize _minSize;
    bool _isFlipped;
    bool _isOpaque;
    bool _delayWindowOrderingOnClickThrough;
    NSColor * _backgroundColor;
    NSObject<CAAnimationDelegate> * _animationDelegate;
    bool _shouldBeVibrant;
}
@property (nonatomic) struct CGSize maxSize;
@property (nonatomic) struct CGSize minSize;
@property (nonatomic) bool isFlipped;
@property (nonatomic) bool isOpaque;
@property (nonatomic) bool delayWindowOrderingOnClickThrough;
@property (nonatomic) NSObject<CAAnimationDelegate> * animationDelegate;
@property (nonatomic) bool shouldBeVibrant;
+ (void)notifyView:(id)v1 willMoveToWindow:(id)v2;
+ (void)notifyViewDidMoveToWindow:(id)v1;
+ (void)notifyView:(id)v1 willMoveToSuperview:(id)v2;
+ (void)notifyViewDidMoveToSuperview:(id)v1;
+ (void)notifyViewDidChangeBackingProperties:(id)v1;
+ (void)notifyWindowChangedKeyState:(id)v1;
- (id)initWithCoder:(id)v1;
- (id)initWithFrame:(struct CGRect)v1;
- (void)initCommon;
- (void)dealloc;
- (bool)shouldDelayWindowOrderingForEvent:(id)v1;
- (id)backgroundColor;
- (void)setBackgroundColor:(id)v1;
- (void)viewWillMoveToWindow:(id)v1;
- (void)viewDidMoveToWindow;
- (void)viewWillMoveToSuperview:(id)v1;
- (void)viewDidMoveToSuperview;
- (void)viewDidChangeBackingProperties;
- (void)_windowChangedKeyState;
- (bool)allowsVibrancy;
- (void)configureAnimations:(bool)v1;
- (void)setWantsLayer:(bool)v1;
- (void)setFrameSize:(struct CGSize)v1;
- (void)setBoundsSize:(struct CGSize)v1;
@end

@interface TUpdateLayerView : TView
@property (retain,nonatomic) NSColor * backgroundColor;
- (void)initCommon;
- (bool)wantsUpdateLayer;
- (void)updateLayer;
@end

@interface TDesktopWindow : TUpdateLayerView
- (id)init;
- (void)setCanHostLayersInWindowServer:(BOOL)v1;
@end

static id (*orig_init)(id self, SEL _cmd);

static id hook_init(id self, SEL _cmd) {
    NSLog(@"[LogPaper] we working");

    id orig = orig_init(self, _cmd);
    [orig setBackgroundColor:[NSColor blackColor]];

    NSScreen *mainScreen = [NSScreen mainScreen];
    CGRect visibleFrame = [mainScreen visibleFrame];

    VerboseBootCoreTextScrollView *bootView =
        [[VerboseBootCoreTextScrollView alloc] initWithFrame:[mainScreen frame]];

    [[orig contentView] addSubview:bootView];

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/log";
    task.arguments = @[@"stream", @"--style", @"syslog"];

    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;

    NSFileHandle *handle = pipe.fileHandleForReading;

    handle.readabilityHandler = ^(NSFileHandle *fh) {

        NSData *data = fh.availableData;
        if (!data.length) return;

        NSString *string =
            [[NSString alloc] initWithData:data
                                  encoding:NSUTF8StringEncoding];

        dispatch_async(dispatch_get_main_queue(), ^{
            [bootView appendLine:string];
        });
    };

    [task launch];

    return orig;
}


__attribute__((constructor))
void tweak_init() {
    NSLog(@"[LogPaper] init");

    // Start swizzling
    Class cls = objc_getClass("TDesktopWindow");
    SEL sel = @selector(init);
    Method m = class_getInstanceMethod(cls, sel);
    orig_init = (void *)method_getImplementation(m);
    method_setImplementation(m, (IMP)hook_init);
}
