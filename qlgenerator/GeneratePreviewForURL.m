#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuickLook/QuickLook.h>

#import "sims.h"

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
    @autoreleasepool {
        SIMSFile *sims = [[SIMSFile alloc] initWithUrl:url];
        if (sims.fileType != 27 && sims.fileType != 39) {
            NSLog(@"File %@ is not a SIMS image (found type: %d).\n", sims.filename, sims.fileType);
            return 1;
        }
        [sims generatePreview:preview];
        return noErr;
    }
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview)
{
    // Implement only if supported
}
