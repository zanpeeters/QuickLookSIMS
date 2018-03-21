//
//  GetMetadataForFile.m
//  SIMS.mdimporter
//
//  Created by Zan Peeters on 21-02-2018.
//
// https://stackoverflow.com/questions/16354044/custom-spotlight-importer-and-finders-get-info-more-info-section

#import <CoreServices/CoreServices.h>
#import "sims.h"

Boolean GetMetadataForFile(void* thisInterface,
                           CFMutableDictionaryRef attributes,
                           CFStringRef contentTypeUTI,
                           CFStringRef pathToFile)
{
    @autoreleasepool {
        NSMutableDictionary *attrs = (__bridge NSMutableDictionary *)attributes;
//        NSString *uti = (__bridge NSString *)contentTypeUTI;
        
        SIMSFile *sims = [[SIMSFile alloc] initWithPath:pathToFile];
        if (sims) {
                [attrs setObject:[[NSNumber alloc] initWithInt:sims.bytesPerPixel*8]
                          forKey:(NSString *)kMDItemBitsPerSample];
                [attrs setObject:[[NSNumber alloc] initWithInt:sims.height]
                          forKey:(NSString *)kMDItemPixelHeight];
                [attrs setObject:[[NSNumber alloc] initWithInt:sims.width]
                          forKey:(NSString *)kMDItemPixelWidth];
                [attrs setObject:sims.labels
                          forKey:@"com_cameca_sims_labels"];
                [attrs setObject:sims.displayLabels
                          forKey:@"com_cameca_sims_displaylabels"];
                [attrs setObject:[[NSNumber alloc] initWithFloat:sims.raster]
                          forKey:@"com_cameca_sims_raster"];
                [attrs setObject:[[NSNumber alloc] initWithInt:sims.masses]
                          forKey:@"com_cameca_sims_masses"];
                [attrs setObject:[[NSNumber alloc] initWithInt:sims.frames]
                          forKey:@"com_cameca_sims_frames"];
                return true;
        }
        return false;
    }
}
