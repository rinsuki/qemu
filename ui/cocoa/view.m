/*
 * QEMU Cocoa CG display driver
 *
 * Copyright (c) 2008 Mike Kronenberg
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "qemu/osdep.h"

#include "ui/cocoa.h"
#include "ui/input.h"
#include "sysemu/sysemu.h"
#include "qemu/error-report.h"
#include "qemu/main-loop.h"
#include <Carbon/Carbon.h>

#define cgrect(nsrect) (*(CGRect *)&(nsrect))

// Mac to QKeyCode conversion
static const int mac_to_qkeycode_map[] = {
    [kVK_ANSI_A] = Q_KEY_CODE_A,
    [kVK_ANSI_B] = Q_KEY_CODE_B,
    [kVK_ANSI_C] = Q_KEY_CODE_C,
    [kVK_ANSI_D] = Q_KEY_CODE_D,
    [kVK_ANSI_E] = Q_KEY_CODE_E,
    [kVK_ANSI_F] = Q_KEY_CODE_F,
    [kVK_ANSI_G] = Q_KEY_CODE_G,
    [kVK_ANSI_H] = Q_KEY_CODE_H,
    [kVK_ANSI_I] = Q_KEY_CODE_I,
    [kVK_ANSI_J] = Q_KEY_CODE_J,
    [kVK_ANSI_K] = Q_KEY_CODE_K,
    [kVK_ANSI_L] = Q_KEY_CODE_L,
    [kVK_ANSI_M] = Q_KEY_CODE_M,
    [kVK_ANSI_N] = Q_KEY_CODE_N,
    [kVK_ANSI_O] = Q_KEY_CODE_O,
    [kVK_ANSI_P] = Q_KEY_CODE_P,
    [kVK_ANSI_Q] = Q_KEY_CODE_Q,
    [kVK_ANSI_R] = Q_KEY_CODE_R,
    [kVK_ANSI_S] = Q_KEY_CODE_S,
    [kVK_ANSI_T] = Q_KEY_CODE_T,
    [kVK_ANSI_U] = Q_KEY_CODE_U,
    [kVK_ANSI_V] = Q_KEY_CODE_V,
    [kVK_ANSI_W] = Q_KEY_CODE_W,
    [kVK_ANSI_X] = Q_KEY_CODE_X,
    [kVK_ANSI_Y] = Q_KEY_CODE_Y,
    [kVK_ANSI_Z] = Q_KEY_CODE_Z,

    [kVK_ANSI_0] = Q_KEY_CODE_0,
    [kVK_ANSI_1] = Q_KEY_CODE_1,
    [kVK_ANSI_2] = Q_KEY_CODE_2,
    [kVK_ANSI_3] = Q_KEY_CODE_3,
    [kVK_ANSI_4] = Q_KEY_CODE_4,
    [kVK_ANSI_5] = Q_KEY_CODE_5,
    [kVK_ANSI_6] = Q_KEY_CODE_6,
    [kVK_ANSI_7] = Q_KEY_CODE_7,
    [kVK_ANSI_8] = Q_KEY_CODE_8,
    [kVK_ANSI_9] = Q_KEY_CODE_9,

    [kVK_ANSI_Grave] = Q_KEY_CODE_GRAVE_ACCENT,
    [kVK_ANSI_Minus] = Q_KEY_CODE_MINUS,
    [kVK_ANSI_Equal] = Q_KEY_CODE_EQUAL,
    [kVK_Delete] = Q_KEY_CODE_BACKSPACE,
    [kVK_CapsLock] = Q_KEY_CODE_CAPS_LOCK,
    [kVK_Tab] = Q_KEY_CODE_TAB,
    [kVK_Return] = Q_KEY_CODE_RET,
    [kVK_ANSI_LeftBracket] = Q_KEY_CODE_BRACKET_LEFT,
    [kVK_ANSI_RightBracket] = Q_KEY_CODE_BRACKET_RIGHT,
    [kVK_ANSI_Backslash] = Q_KEY_CODE_BACKSLASH,
    [kVK_ANSI_Semicolon] = Q_KEY_CODE_SEMICOLON,
    [kVK_ANSI_Quote] = Q_KEY_CODE_APOSTROPHE,
    [kVK_ANSI_Comma] = Q_KEY_CODE_COMMA,
    [kVK_ANSI_Period] = Q_KEY_CODE_DOT,
    [kVK_ANSI_Slash] = Q_KEY_CODE_SLASH,
    [kVK_Space] = Q_KEY_CODE_SPC,

    [kVK_ANSI_Keypad0] = Q_KEY_CODE_KP_0,
    [kVK_ANSI_Keypad1] = Q_KEY_CODE_KP_1,
    [kVK_ANSI_Keypad2] = Q_KEY_CODE_KP_2,
    [kVK_ANSI_Keypad3] = Q_KEY_CODE_KP_3,
    [kVK_ANSI_Keypad4] = Q_KEY_CODE_KP_4,
    [kVK_ANSI_Keypad5] = Q_KEY_CODE_KP_5,
    [kVK_ANSI_Keypad6] = Q_KEY_CODE_KP_6,
    [kVK_ANSI_Keypad7] = Q_KEY_CODE_KP_7,
    [kVK_ANSI_Keypad8] = Q_KEY_CODE_KP_8,
    [kVK_ANSI_Keypad9] = Q_KEY_CODE_KP_9,
    [kVK_ANSI_KeypadDecimal] = Q_KEY_CODE_KP_DECIMAL,
    [kVK_ANSI_KeypadEnter] = Q_KEY_CODE_KP_ENTER,
    [kVK_ANSI_KeypadPlus] = Q_KEY_CODE_KP_ADD,
    [kVK_ANSI_KeypadMinus] = Q_KEY_CODE_KP_SUBTRACT,
    [kVK_ANSI_KeypadMultiply] = Q_KEY_CODE_KP_MULTIPLY,
    [kVK_ANSI_KeypadDivide] = Q_KEY_CODE_KP_DIVIDE,
    [kVK_ANSI_KeypadEquals] = Q_KEY_CODE_KP_EQUALS,
    [kVK_ANSI_KeypadClear] = Q_KEY_CODE_NUM_LOCK,

    [kVK_UpArrow] = Q_KEY_CODE_UP,
    [kVK_DownArrow] = Q_KEY_CODE_DOWN,
    [kVK_LeftArrow] = Q_KEY_CODE_LEFT,
    [kVK_RightArrow] = Q_KEY_CODE_RIGHT,

    [kVK_Help] = Q_KEY_CODE_INSERT,
    [kVK_Home] = Q_KEY_CODE_HOME,
    [kVK_PageUp] = Q_KEY_CODE_PGUP,
    [kVK_PageDown] = Q_KEY_CODE_PGDN,
    [kVK_End] = Q_KEY_CODE_END,
    [kVK_ForwardDelete] = Q_KEY_CODE_DELETE,

    [kVK_Escape] = Q_KEY_CODE_ESC,

    /* The Power key can't be used directly because the operating system uses
     * it. This key can be emulated by using it in place of another key such as
     * F1. Don't forget to disable the real key binding.
     */
    /* [kVK_F1] = Q_KEY_CODE_POWER, */

    [kVK_F1] = Q_KEY_CODE_F1,
    [kVK_F2] = Q_KEY_CODE_F2,
    [kVK_F3] = Q_KEY_CODE_F3,
    [kVK_F4] = Q_KEY_CODE_F4,
    [kVK_F5] = Q_KEY_CODE_F5,
    [kVK_F6] = Q_KEY_CODE_F6,
    [kVK_F7] = Q_KEY_CODE_F7,
    [kVK_F8] = Q_KEY_CODE_F8,
    [kVK_F9] = Q_KEY_CODE_F9,
    [kVK_F10] = Q_KEY_CODE_F10,
    [kVK_F11] = Q_KEY_CODE_F11,
    [kVK_F12] = Q_KEY_CODE_F12,
    [kVK_F13] = Q_KEY_CODE_PRINT,
    [kVK_F14] = Q_KEY_CODE_SCROLL_LOCK,
    [kVK_F15] = Q_KEY_CODE_PAUSE,

    // JIS keyboards only
    [kVK_JIS_Yen] = Q_KEY_CODE_YEN,
    [kVK_JIS_Underscore] = Q_KEY_CODE_RO,
    [kVK_JIS_KeypadComma] = Q_KEY_CODE_KP_COMMA,
    [kVK_JIS_Eisu] = Q_KEY_CODE_MUHENKAN,
    [kVK_JIS_Kana] = Q_KEY_CODE_HENKAN,

    /*
     * The eject and volume keys can't be used here because they are handled at
     * a lower level than what an Application can see.
     */
};

static int cocoa_keycode_to_qemu(int keycode)
{
    if (ARRAY_SIZE(mac_to_qkeycode_map) <= keycode) {
        error_report("(cocoa) warning unknown keycode 0x%x", keycode);
        return 0;
    }
    return mac_to_qkeycode_map[keycode];
}

static CGRect compute_cursor_clip_rect(int screen_height,
                                       int given_mouse_x, int given_mouse_y,
                                       int cursor_width, int cursor_height)
{
    CGRect rect;

    rect.origin.x = MAX(0, -given_mouse_x);
    rect.origin.y = 0;
    rect.size.width = MIN(cursor_width, cursor_width + given_mouse_x);
    rect.size.height = cursor_height - rect.origin.x;

    return rect;
}

@implementation QemuCocoaView
- (id)initWithFrame:(NSRect)frameRect
             screen:(QEMUScreen *)given_screen
{
    COCOA_DEBUG("QemuCocoaView: initWithFrame\n");

    self = [super initWithFrame:frameRect];
    if (self) {

        screen = given_screen;

        screen_width = frameRect.size.width;
        screen_height = frameRect.size.height;

        /* Used for displaying pause on the screen */
        pauseLabel = [NSTextField new];
        [pauseLabel setBezeled:YES];
        [pauseLabel setDrawsBackground:YES];
        [pauseLabel setBackgroundColor: [NSColor whiteColor]];
        [pauseLabel setEditable:NO];
        [pauseLabel setSelectable:NO];
        [pauseLabel setStringValue: @"Paused"];
        [pauseLabel setFont: [NSFont fontWithName: @"Helvetica" size: 90]];
        [pauseLabel setTextColor: [NSColor blackColor]];
        [pauseLabel sizeToFit];

    }
    return self;
}

- (void) dealloc
{
    if (pauseLabel) {
        [pauseLabel release];
    }

    [super dealloc];
}

- (BOOL) isOpaque
{
    return YES;
}

- (void) removeTrackingRect
{
    if (trackingArea) {
        [self removeTrackingArea:trackingArea];
        [trackingArea release];
        trackingArea = nil;
    }
}

- (void) frameUpdated
{
    [self removeTrackingRect];

    if ([self window]) {
        NSTrackingAreaOptions options = NSTrackingActiveInKeyWindow |
                                        NSTrackingMouseEnteredAndExited |
                                        NSTrackingMouseMoved;
        trackingArea = [[NSTrackingArea alloc] initWithRect:[self frame]
                                                    options:options
                                                      owner:self
                                                   userInfo:nil];
        [self addTrackingArea:trackingArea];
        [self updateUIInfo];
    }
}

- (void) viewDidMoveToWindow
{
    [self resizeWindow];
    [self frameUpdated];
}

- (void) viewWillMoveToWindow:(NSWindow *)newWindow
{
    [self removeTrackingRect];
}

- (void) hideCursor
{
    if (screen->cursor_show) {
        return;
    }
    [NSCursor hide];
}

- (void) unhideCursor
{
    if (screen->cursor_show) {
        return;
    }
    [NSCursor unhide];
}

- (CGRect) convertCursorClipRectToDraw:(CGRect)rect
                          screenHeight:(int)given_screen_height
                                mouseX:(int)mouse_x
                                mouseY:(int)mouse_y
{
    CGFloat d = [self frame].size.height / (CGFloat)given_screen_height;

    rect.origin.x = (rect.origin.x + mouse_x) * d;
    rect.origin.y = (given_screen_height - rect.origin.y - mouse_y - rect.size.height) * d;
    rect.size.width *= d;
    rect.size.height *= d;

    return rect;
}

- (void) drawRect:(NSRect) rect
{
    COCOA_DEBUG("QemuCocoaView: drawRect\n");

#ifdef CONFIG_OPENGL
    if (display_opengl) {
        return;
    }
#endif

    // get CoreGraphic context
    CGContextRef viewContextRef = [[NSGraphicsContext currentContext] CGContext];

    CGContextSetInterpolationQuality (viewContextRef, kCGInterpolationNone);
    CGContextSetShouldAntialias (viewContextRef, NO);

    qemu_mutex_lock(&screen->draw_mutex);

    // draw screen bitmap directly to Core Graphics context
    if (!screen->surface) {
        // Draw request before any guest device has set up a framebuffer:
        // just draw an opaque black rectangle
        CGContextSetRGBFillColor(viewContextRef, 0, 0, 0, 1.0);
        CGContextFillRect(viewContextRef, NSRectToCGRect(rect));
    } else {
        int w = surface_width(screen->surface);
        int h = surface_height(screen->surface);
        int bitsPerPixel = PIXMAN_FORMAT_BPP(surface_format(screen->surface));
        int stride = surface_stride(screen->surface);

        CGDataProviderRef dataProviderRef = CGDataProviderCreateWithData(
            NULL,
            surface_data(screen->surface),
            stride * h,
            NULL
        );

        CGImageRef imageRef = CGImageCreate(
            w, //width
            h, //height
            DIV_ROUND_UP(bitsPerPixel, 8) * 2, //bitsPerComponent
            bitsPerPixel, //bitsPerPixel
            stride, //bytesPerRow
            CGColorSpaceCreateWithName(kCGColorSpaceSRGB), //colorspace
            kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst, //bitmapInfo
            dataProviderRef, //provider
            NULL, //decode
            0, //interpolate
            kCGRenderingIntentDefault //intent
        );
        // selective drawing code (draws only dirty rectangles) (OS X >= 10.4)
        const NSRect *rectList;
        NSInteger rectCount;
        int i;
        CGImageRef clipImageRef;
        CGRect clipRect;
        CGFloat d = (CGFloat)h / [self frame].size.height;

        [self getRectsBeingDrawn:&rectList count:&rectCount];
        for (i = 0; i < rectCount; i++) {
            clipRect.origin.x = rectList[i].origin.x * d;
            clipRect.origin.y = (float)h - (rectList[i].origin.y + rectList[i].size.height) * d;
            clipRect.size.width = rectList[i].size.width * d;
            clipRect.size.height = rectList[i].size.height * d;
            clipImageRef = CGImageCreateWithImageInRect(
                                                        imageRef,
                                                        clipRect
                                                        );
            CGContextDrawImage (viewContextRef, cgrect(rectList[i]), clipImageRef);
            CGImageRelease (clipImageRef);
        }
        CGImageRelease (imageRef);
        CGDataProviderRelease(dataProviderRef);

        if (screen->mouse_on) {
            size_t cursor_width = CGImageGetWidth(screen->cursor_cgimage);
            size_t cursor_height = CGImageGetHeight(screen->cursor_cgimage);
            clipRect = compute_cursor_clip_rect(h, screen->mouse_x, screen->mouse_y,
                                                cursor_width,
                                                cursor_height);
            CGRect drawRect = [self convertCursorClipRectToDraw:clipRect
                                                   screenHeight:h
                                                         mouseX:screen->mouse_x
                                                         mouseY:screen->mouse_y];
            clipImageRef = CGImageCreateWithImageInRect(
                                                        screen->cursor_cgimage,
                                                        clipRect
                                                        );
            CGContextDrawImage(viewContextRef, drawRect, clipImageRef);
            CGImageRelease (clipImageRef);
        }
    }

    qemu_mutex_unlock(&screen->draw_mutex);
}

- (NSSize) computeUnzoomedSize
{
    CGFloat width = screen_width / [[self window] backingScaleFactor];
    CGFloat height = screen_height / [[self window] backingScaleFactor];

    return NSMakeSize(width, height);
}

- (NSSize) fixZoomedFullScreenSize:(NSSize)proposedSize
{
    NSSize size;

    size.width = (CGFloat)screen_width * proposedSize.height;
    size.height = (CGFloat)screen_height * proposedSize.width;

    if (size.width < size.height) {
        size.width /= screen_height;
        size.height = proposedSize.height;
    } else {
        size.width = proposedSize.width;
        size.height /= screen_width;
    }

    return size;
}

- (void) resizeWindow
{
    [[self window] setContentAspectRatio:NSMakeSize(screen_width, screen_height)];

    if (([[self window] styleMask] & NSWindowStyleMaskResizable) == 0) {
        [[self window] setContentSize:[self computeUnzoomedSize]];
        [[self window] center];
    } else if (([[self window] styleMask] & NSWindowStyleMaskFullScreen) != 0) {
        [[self window] setContentSize:[self fixZoomedFullScreenSize:[[[self window] screen] frame].size]];
        [[self window] center];
    }
}

- (void) updateUIInfo
{
    NSSize frameSize;
    QemuUIInfo info;

    if (!screen->inited) {
        return;
    }

    if ([self window]) {
        NSDictionary *description = [[[self window] screen] deviceDescription];
        CGDirectDisplayID display = [[description objectForKey:@"NSScreenNumber"] unsignedIntValue];

        CGDisplayModeRef displayMode = CGDisplayCopyDisplayMode(display);
        double refreshRate = CGDisplayModeGetRefreshRate(displayMode);
        CGDisplayModeRelease(displayMode);

        NSSize screenSize = [[[self window] screen] frame].size;
        CGSize screenPhysicalSize = CGDisplayScreenSize(display);

        if (([[self window] styleMask] & NSWindowStyleMaskFullScreen) == 0) {
            frameSize = [self frame].size;
        } else {
            frameSize = screenSize;
        }

        if (refreshRate) {
            update_displaychangelistener(&screen->dcl, 1000.0 / refreshRate);
            info.refresh_rate = refreshRate * 1000;
        }

        info.width_mm = frameSize.width / screenSize.width * screenPhysicalSize.width;
        info.height_mm = frameSize.height / screenSize.height * screenPhysicalSize.height;
    } else {
        frameSize = [self frame].size;
        info.width_mm = 0;
        info.height_mm = 0;
    }

    NSSize frameBackingSize = [self convertSizeToBacking:frameSize];

    info.xoff = 0;
    info.yoff = 0;
    info.width = frameBackingSize.width;
    info.height = frameBackingSize.height;

    dpy_set_ui_info(screen->dcl.con, &info);
}

- (void) updateScreenWidth:(int)w height:(int)h
{
    COCOA_DEBUG("QemuCocoaView: updateScreenWidth:height:\n");

    if (w != screen_width || h != screen_height) {
        COCOA_DEBUG("updateScreenWidth:height: new size %d x %d\n", w, h);
        screen_width = w;
        screen_height = h;
        [self resizeWindow];
    }
}

- (void) toggleModifier: (int)keycode {
    // Toggle the stored state.
    modifiers_state[keycode] = !modifiers_state[keycode];
    // Send a keyup or keydown depending on the state.
    qemu_input_event_send_key_qcode(screen->dcl.con, keycode, modifiers_state[keycode]);
}

- (void) clearModifier: (int)keycode {
    if (!modifiers_state[keycode]) {
        return;
    }

    // Clear the stored state.
    modifiers_state[keycode] = NO;
    // Send a keyup.
    qemu_input_event_send_key_qcode(screen->dcl.con, keycode, false);
}

- (void) setStatefulModifier: (int)keycode down:(BOOL)down {
    if (down == modifiers_state[keycode]) {
        return;
    }

    // Toggle the stored state.
    modifiers_state[keycode] = down;
    // Generate keydown and keyup.
    qemu_input_event_send_key_qcode(screen->dcl.con, keycode, true);
    qemu_input_event_send_key_qcode(screen->dcl.con, keycode, false);
}

// Does the work of sending input to the monitor
- (void) handleMonitorInput:(NSEvent *)event
{
    int keysym = 0;
    int control_key = 0;

    // if the control key is down
    if ([event modifierFlags] & NSEventModifierFlagControl) {
        control_key = 1;
    }

    /* translates Macintosh keycodes to QEMU's keysym */

    int without_control_translation[] = {
        [0 ... 0xff] = 0,   // invalid key

        [kVK_UpArrow]       = QEMU_KEY_UP,
        [kVK_DownArrow]     = QEMU_KEY_DOWN,
        [kVK_RightArrow]    = QEMU_KEY_RIGHT,
        [kVK_LeftArrow]     = QEMU_KEY_LEFT,
        [kVK_Home]          = QEMU_KEY_HOME,
        [kVK_End]           = QEMU_KEY_END,
        [kVK_PageUp]        = QEMU_KEY_PAGEUP,
        [kVK_PageDown]      = QEMU_KEY_PAGEDOWN,
        [kVK_ForwardDelete] = QEMU_KEY_DELETE,
        [kVK_Delete]        = QEMU_KEY_BACKSPACE,
    };

    int with_control_translation[] = {
        [0 ... 0xff] = 0,   // invalid key

        [kVK_UpArrow]       = QEMU_KEY_CTRL_UP,
        [kVK_DownArrow]     = QEMU_KEY_CTRL_DOWN,
        [kVK_RightArrow]    = QEMU_KEY_CTRL_RIGHT,
        [kVK_LeftArrow]     = QEMU_KEY_CTRL_LEFT,
        [kVK_Home]          = QEMU_KEY_CTRL_HOME,
        [kVK_End]           = QEMU_KEY_CTRL_END,
        [kVK_PageUp]        = QEMU_KEY_CTRL_PAGEUP,
        [kVK_PageDown]      = QEMU_KEY_CTRL_PAGEDOWN,
    };

    if (control_key != 0) { /* If the control key is being used */
        if ([event keyCode] < ARRAY_SIZE(with_control_translation)) {
            keysym = with_control_translation[[event keyCode]];
        }
    } else {
        if ([event keyCode] < ARRAY_SIZE(without_control_translation)) {
            keysym = without_control_translation[[event keyCode]];
        }
    }

    // if not a key that needs translating
    if (keysym == 0) {
        NSString *ks = [event characters];
        if ([ks length] > 0) {
            keysym = [ks characterAtIndex:0];
        }
    }

    if (keysym) {
        kbd_put_keysym(keysym);
    }
}

- (bool) handleEvent:(NSEvent *)event
{
    qemu_mutex_lock_iothread();
    bool handled = [self handleEventLocked:event];
    qemu_mutex_unlock_iothread();
    return handled;
}

- (bool) handleEventLocked:(NSEvent *)event
{
    /* Return true if we handled the event, false if it should be given to OSX */
    COCOA_DEBUG("QemuCocoaView: handleEvent\n");
    NSUInteger modifiers = [event modifierFlags];
    int keycode = 0;

    // emulate caps lock keydown and keyup
    [self setStatefulModifier:Q_KEY_CODE_CAPS_LOCK down:!!(modifiers & NSEventModifierFlagCapsLock)];

    if (qemu_console_is_graphic(NULL)) {
        if (!(modifiers & NSEventModifierFlagShift)) {
            [self clearModifier:Q_KEY_CODE_SHIFT];
            [self clearModifier:Q_KEY_CODE_SHIFT_R];
        }
        if (!(modifiers & NSEventModifierFlagControl)) {
            [self clearModifier:Q_KEY_CODE_CTRL];
            [self clearModifier:Q_KEY_CODE_CTRL_R];
        }
        if (!(modifiers & NSEventModifierFlagOption)) {
            [self clearModifier:Q_KEY_CODE_ALT];
            [self clearModifier:Q_KEY_CODE_ALT_R];
        }
        if (!(modifiers & NSEventModifierFlagCommand)) {
            [self clearModifier:Q_KEY_CODE_META_L];
            [self clearModifier:Q_KEY_CODE_META_R];
        }
    }

    switch ([event type]) {
        case NSEventTypeFlagsChanged:
            if (!qemu_console_is_graphic(NULL)) {
                return true;
            }

            switch ([event keyCode]) {
                case kVK_Shift:
                    if (!!(modifiers & NSEventModifierFlagShift)) {
                        [self toggleModifier:Q_KEY_CODE_SHIFT];
                    }
                    return true;

                case kVK_RightShift:
                    if (!!(modifiers & NSEventModifierFlagShift)) {
                        [self toggleModifier:Q_KEY_CODE_SHIFT_R];
                    }
                    return true;

                case kVK_Control:
                    if (!!(modifiers & NSEventModifierFlagControl)) {
                        [self toggleModifier:Q_KEY_CODE_CTRL];
                    }
                    return true;

                case kVK_Option:
                    if (!!(modifiers & NSEventModifierFlagOption)) {
                        [self toggleModifier:Q_KEY_CODE_ALT];
                    }
                    return true;

                case kVK_RightOption:
                    if (!!(modifiers & NSEventModifierFlagOption)) {
                        [self toggleModifier:Q_KEY_CODE_ALT_R];
                    }
                    return true;

                /* Don't pass command key changes to guest unless mouse is grabbed */
                case kVK_Command:
                    if (isMouseGrabbed &&
                        !!(modifiers & NSEventModifierFlagCommand)) {
                        [self toggleModifier:Q_KEY_CODE_META_L];
                    }
                    return true;

                case kVK_RightCommand:
                    if (isMouseGrabbed &&
                        !!(modifiers & NSEventModifierFlagCommand)) {
                        [self toggleModifier:Q_KEY_CODE_META_R];
                    }
                    return true;

                default:
                    return true;
            }

        case NSEventTypeKeyDown:
            keycode = cocoa_keycode_to_qemu([event keyCode]);

            // forward command key combos to the host UI unless the mouse is grabbed
            if (!isMouseGrabbed && ([event modifierFlags] & NSEventModifierFlagCommand)) {
                return false;
            }

            // default

            // handle control + alt Key Combos (ctrl+alt+[1..9,g] is reserved for QEMU)
            if (([event modifierFlags] & NSEventModifierFlagControl) && ([event modifierFlags] & NSEventModifierFlagOption)) {
                NSString *keychar = [event charactersIgnoringModifiers];
                if ([keychar length] == 1) {
                    char key = [keychar characterAtIndex:0];
                    switch (key) {

                        // enable graphic console
                        case '1' ... '9':
                            console_select(key - '0' - 1); /* ascii math */
                            return true;

                        // release the mouse grab
                        case 'g':
                            [self ungrabMouseLocked];
                            return true;
                    }
                }
            }

            if (qemu_console_is_graphic(NULL)) {
                qemu_input_event_send_key_qcode(screen->dcl.con, keycode, true);
            } else {
                [self handleMonitorInput: event];
            }
            return true;
        case NSEventTypeKeyUp:
            keycode = cocoa_keycode_to_qemu([event keyCode]);

            // don't pass the guest a spurious key-up if we treated this
            // command-key combo as a host UI action
            if (!isMouseGrabbed && ([event modifierFlags] & NSEventModifierFlagCommand)) {
                return true;
            }

            if (qemu_console_is_graphic(NULL)) {
                qemu_input_event_send_key_qcode(screen->dcl.con, keycode, false);
            }
            return true;
        case NSEventTypeScrollWheel:
            /*
             * Send wheel events to the guest regardless of window focus.
             * This is in-line with standard Mac OS X UI behaviour.
             */

            /*
             * When deltaY is zero, it means that this scrolling event was
             * either horizontal, or so fine that it only appears in
             * scrollingDeltaY. So we drop the event.
             */
            if ([event deltaY] != 0) {
            /* Determine if this is a scroll up or scroll down event */
                int buttons = ([event deltaY] > 0) ?
                    INPUT_BUTTON_WHEEL_UP : INPUT_BUTTON_WHEEL_DOWN;
                qemu_input_queue_btn(screen->dcl.con, buttons, true);
                qemu_input_event_sync();
                qemu_input_queue_btn(screen->dcl.con, buttons, false);
                qemu_input_event_sync();
            }
            /*
             * Since deltaY also reports scroll wheel events we prevent mouse
             * movement code from executing.
             */
            return true;
        default:
            return false;
    }
}

- (void) handleMouseEvent:(NSEvent *)event
{
    if (!isMouseGrabbed) {
        return;
    }

    qemu_mutex_lock_iothread();

    if (isAbsoluteEnabled) {
        CGFloat d = (CGFloat)screen_height / [self frame].size.height;
        NSPoint p = [event locationInWindow];
        // Note that the origin for Cocoa mouse coords is bottom left, not top left.
        qemu_input_queue_abs(screen->dcl.con, INPUT_AXIS_X, p.x * d, 0, screen_width);
        qemu_input_queue_abs(screen->dcl.con, INPUT_AXIS_Y, screen_height - p.y * d, 0, screen_height);
    } else {
        CGFloat d = (CGFloat)screen_height / [self convertSizeToBacking:[self frame].size].height;
        qemu_input_queue_rel(screen->dcl.con, INPUT_AXIS_X, [event deltaX] * d);
        qemu_input_queue_rel(screen->dcl.con, INPUT_AXIS_Y, [event deltaY] * d);
    }

    qemu_input_event_sync();

    qemu_mutex_unlock_iothread();
}

- (void) handleMouseEvent:(NSEvent *)event button:(InputButton)button down:(bool)down
{
    if (!isMouseGrabbed) {
        return;
    }

    qemu_mutex_lock_iothread();
    qemu_input_queue_btn(screen->dcl.con, button, down);
    qemu_mutex_unlock_iothread();

    [self handleMouseEvent:event];
}

- (void) mouseExited:(NSEvent *)event
{
    if (isAbsoluteEnabled && isMouseGrabbed) {
        [self ungrabMouse];
    }
}

- (void) mouseEntered:(NSEvent *)event
{
    if (isAbsoluteEnabled && !isMouseGrabbed) {
        [self grabMouse];
    }
}

- (void) mouseMoved:(NSEvent *)event
{
    [self handleMouseEvent:event];
}

- (void) mouseDown:(NSEvent *)event
{
    [self handleMouseEvent:event button:INPUT_BUTTON_LEFT down:true];
}

- (void) rightMouseDown:(NSEvent *)event
{
    [self handleMouseEvent:event button:INPUT_BUTTON_RIGHT down:true];
}

- (void) otherMouseDown:(NSEvent *)event
{
    [self handleMouseEvent:event button:INPUT_BUTTON_MIDDLE down:true];
}

- (void) mouseDragged:(NSEvent *)event
{
    [self handleMouseEvent:event];
}

- (void) rightMouseDragged:(NSEvent *)event
{
    [self handleMouseEvent:event];
}

- (void) otherMouseDragged:(NSEvent *)event
{
    [self handleMouseEvent:event];
}

- (void) mouseUp:(NSEvent *)event
{
    if (!isMouseGrabbed) {
        [self grabMouse];
    }

    [self handleMouseEvent:event button:INPUT_BUTTON_LEFT down:false];
}

- (void) rightMouseUp:(NSEvent *)event
{
    [self handleMouseEvent:event button:INPUT_BUTTON_RIGHT down:false];
}

- (void) otherMouseUp:(NSEvent *)event
{
    [self handleMouseEvent:event button:INPUT_BUTTON_MIDDLE down:false];
}

- (void) grabMouse
{
    COCOA_DEBUG("QemuCocoaView: grabMouse\n");

    if (qemu_name)
        [[self window] setTitle:[NSString stringWithFormat:@"QEMU %s - (Press ctrl + alt + g to release Mouse)", qemu_name]];
    else
        [[self window] setTitle:@"QEMU - (Press ctrl + alt + g to release Mouse)"];
    [self hideCursor];
    CGAssociateMouseAndMouseCursorPosition(isAbsoluteEnabled);
    isMouseGrabbed = TRUE; // while isMouseGrabbed = TRUE, QemuCocoaApp sends all events to [cocoaView handleEvent:]
}

- (void) ungrabMouse
{
    qemu_mutex_lock_iothread();
    [self ungrabMouseLocked];
    qemu_mutex_unlock_iothread();
}

- (void) ungrabMouseLocked
{
    COCOA_DEBUG("QemuCocoaView: ungrabMouseLocked\n");

    if (qemu_name)
        [[self window] setTitle:[NSString stringWithFormat:@"QEMU %s", qemu_name]];
    else
        [[self window] setTitle:@"QEMU"];
    [self unhideCursor];
    CGAssociateMouseAndMouseCursorPosition(TRUE);
    isMouseGrabbed = FALSE;
    [self raiseAllButtonsLocked];
}

- (void) setAbsoluteEnabled:(BOOL)tIsAbsoluteEnabled {
    isAbsoluteEnabled = tIsAbsoluteEnabled;
    if (isMouseGrabbed) {
        CGAssociateMouseAndMouseCursorPosition(isAbsoluteEnabled);
    }
}
- (BOOL) isMouseGrabbed {return isMouseGrabbed;}
- (BOOL) isAbsoluteEnabled {return isAbsoluteEnabled;}

/*
 * Makes the target think all down keys are being released.
 * This prevents a stuck key problem, since we will not see
 * key up events for those keys after we have lost focus.
 */
- (void) raiseAllKeys
{
    const int max_index = ARRAY_SIZE(modifiers_state);
    int index;

    qemu_mutex_lock_iothread();

    for (index = 0; index < max_index; index++) {
        if (modifiers_state[index]) {
            modifiers_state[index] = 0;
            qemu_input_event_send_key_qcode(screen->dcl.con, index, false);
        }
    }

    qemu_mutex_unlock_iothread();
}

- (void) raiseAllButtonsLocked
{
    qemu_input_queue_btn(screen->dcl.con, INPUT_BUTTON_LEFT, false);
    qemu_input_queue_btn(screen->dcl.con, INPUT_BUTTON_RIGHT, false);
    qemu_input_queue_btn(screen->dcl.con, INPUT_BUTTON_MIDDLE, false);
}

- (void) setNeedsDisplayForCursorX:(int)x
                                 y:(int)y
                             width:(int)width
                            height:(int)height
                      screenHeight:(int)given_screen_height
{
    CGRect clip_rect = compute_cursor_clip_rect(given_screen_height, x, y,
                                                width, height);
    CGRect draw_rect = [self convertCursorClipRectToDraw:clip_rect
                                            screenHeight:given_screen_height
                                                  mouseX:x
                                                  mouseY:y];
    [self setNeedsDisplayInRect:draw_rect];
}

/* Displays the word pause on the screen */
- (void)displayPause
{
    /* Coordinates have to be calculated each time because the window can change its size */
    int xCoord, yCoord, width, height;
    xCoord = ([[self window] frame].size.width - [pauseLabel frame].size.width)/2;
    yCoord = [[self window] frame].size.height - [pauseLabel frame].size.height - ([pauseLabel frame].size.height * .5);
    width = [pauseLabel frame].size.width;
    height = [pauseLabel frame].size.height;
    [pauseLabel setFrame: NSMakeRect(xCoord, yCoord, width, height)];
    [self addSubview: pauseLabel];
}

/* Removes the word pause from the screen */
- (void)removePause
{
    [pauseLabel removeFromSuperview];
}
@end
