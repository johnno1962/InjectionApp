//
//  main.m
//  injectSource
//
//  Created by John Holdsworth on 22/12/2016.
//  Copyright © 2016 John Holdsworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        NSString *service = @"Injection/Inject Source";
        if ( argc > 1 ) {
            NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
            [pasteboard clearContents];
            [pasteboard writeObjects:@[url]];
            service = @"Injection/Inject File";
        }
        NSPerformService(service, pasteboard);
    }
    return 0;
}

