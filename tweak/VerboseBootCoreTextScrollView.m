#import "VerboseBootCoreTextScrollView.h"
#import <CoreText/CoreText.h>

// -------------------------
// Internal CoreText view
// -------------------------
@interface VerboseBootCoreTextView : NSView
@property (nonatomic, strong) NSMutableArray<NSString *> *lines;
@property (nonatomic) CTFontRef font;
@property (nonatomic) CGFloat lineHeight;
@end

@implementation VerboseBootCoreTextView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = NSColor.blackColor.CGColor;

        _lines = [NSMutableArray new];

        // Monospaced font
        _font = CTFontCreateWithName(CFSTR("Menlo"), 10, NULL);
        _lineHeight = CTFontGetAscent(_font) + CTFontGetDescent(_font) + CTFontGetLeading(_font);

        // Pre-allocate a tall view to prevent initial jump
        CGFloat initialHeight = MAX(5000 * _lineHeight, frame.size.height);
        [self setFrame:NSMakeRect(0, 0, frame.size.width, initialHeight)];
        self.autoresizingMask = NSViewWidthSizable;
    }
    return self;
}

- (BOOL)isFlipped { return NO; } // top-left is origin

- (void)appendLine:(NSString *)line {
    if (!line) return;

    [_lines addObject:line];

    // limit buffer
    const NSInteger maxLines = 5000;
    if (_lines.count > maxLines) {
        [_lines removeObjectsInRange:NSMakeRange(0, _lines.count - maxLines)];
    }

    [self setNeedsDisplay:YES];
}

- (void)clear {
    [_lines removeAllObjects];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    CGContextRef ctx = (CGContextRef)[[NSGraphicsContext currentContext] CGContext];

    // Fill background
    CGContextSetFillColorWithColor(ctx, NSColor.blackColor.CGColor);
    CGContextFillRect(ctx, self.bounds);

    CGContextSetFillColorWithColor(ctx, NSColor.whiteColor.CGColor);

    CGFloat y = self.bounds.size.height - _lineHeight - 5; // top padding

    for (NSString *line in _lines) {
        if (y < 0) break;

        CFStringRef cfLine = (__bridge CFStringRef)line;
        CFMutableAttributedStringRef attrLine = CFAttributedStringCreateMutable(NULL, 0);
        CFAttributedStringReplaceString(attrLine, CFRangeMake(0, 0), cfLine);
        CFAttributedStringSetAttribute(attrLine, CFRangeMake(0, CFStringGetLength(cfLine)),
                                       kCTFontAttributeName, _font);
        CFAttributedStringSetAttribute(attrLine, CFRangeMake(0, CFStringGetLength(cfLine)),
                                       kCTForegroundColorAttributeName, NSColor.whiteColor.CGColor);

        CTLineRef ctLine = CTLineCreateWithAttributedString(attrLine);
        CGContextSetTextPosition(ctx, 5, y);
        CTLineDraw(ctLine, ctx);

        CFRelease(ctLine);
        CFRelease(attrLine);

        y -= _lineHeight;
    }
}

- (void)dealloc {
    if (_font) CFRelease(_font);
}

@end

// -------------------------
// Scroll view
// -------------------------
@interface VerboseBootCoreTextScrollView ()
@property (nonatomic, strong) VerboseBootCoreTextView *bootView;
@end

@implementation VerboseBootCoreTextScrollView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.hasVerticalScroller = NO;
        self.hasHorizontalScroller = NO;
        self.verticalScrollElasticity = NSScrollElasticityNone;
        self.horizontalScrollElasticity = NSScrollElasticityNone;

        // Disable user scrolling
        self.postsBoundsChangedNotifications = NO;

        _bootView = [[VerboseBootCoreTextView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height)];
        _bootView.autoresizingMask = NSViewWidthSizable;

        self.documentView = _bootView;
    }
    return self;
}

// Override scrollWheel to prevent user scrolling
- (void)scrollWheel:(NSEvent *)event {
    // ignore user scroll
}

- (void)appendLine:(NSString *)line {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.bootView appendLine:line];

        // Auto-scroll to bottom
        NSClipView *clipView = self.contentView;
        CGFloat offsetY = MAX(0, self.bootView.bounds.size.height - clipView.bounds.size.height);
        [clipView scrollToPoint:CGPointMake(0, offsetY)];
        [self reflectScrolledClipView:clipView];
    });
}

- (void)clear {
    [self.bootView clear];
}

@end