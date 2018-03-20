#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuickLook/QuickLook.h>

#import "sims.h"

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize);
void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail);

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
    @autoreleasepool {
        SIMSFile *sims = [[SIMSFile alloc] initWithUrl:url];
        if (sims.fileType != 27 && sims.fileType != 39) {
            NSLog(@"File %@ is not a SIMS image (found type: %d).\n", sims.filename, sims.fileType);
            return 1;
        }
        [sims generateThumbnail:thumbnail];
        return noErr;
    }
}

void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail)
{
    // Implement only if supported
}
