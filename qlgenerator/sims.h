//
//  sims.h
//  SIMS.qlgenerator
//
//  Created by Zan Peeters on 15-02-2018.
//  Copyright © 2018 Zan Peeters. All rights reserved.
//

#ifndef sims_h
#define sims_h

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>

#ifdef QUICKLOOKGENERATOR
#import <QuickLook/QuickLook.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Accelerate/Accelerate.h>
#import <AppKit/AppKit.h>
#endif

// Spacing between images, ROWSEP needs enough space for labels, depends on font size.
#define COLSEP 32
#define ROWSEP 32
#define FONTSIZE 22

// The idea for dealing with sub- and superscripts was taken from the Open Babel project,
// see <http://openbabel.sourceforge.net/>
// I have reimplemented it in objective-c as a static NSDictionary lookup table. All code is mine.
static const NSDictionary *superscripts;
static const NSDictionary *subscripts;

// FileTypes are all in the 10s, 255 for FileTypeLimit is an arbitrary limit
// and only used to determine file-endianness. Change it if Cameca changes the file format.
enum FileTypes {
    DepthProfileFile = 21,
    LinescanStageControlFile = 22,
    IsotopeFile = 26,
    ImageFile = 27,
    GrainModeFile = 29,
    CenteringFile = 31, // HMR, SIB, others?
    BeamStabilityFile = 35,
    LinescanImageFile = 39,
    LinescanBeamControlFile = 40,
    StageControlImage = 41,
    FileTypeLimit = 255  // Keep this last
};

@interface SIMSFile : NSObject;

@property NSString *filename;

@property NSData *data;
@property NSMutableArray *labels;
@property NSMutableArray *displayLabels;

@property int32_t fileType;
@property bool needByteSwap;
@property int32_t fileVersion;
@property int32_t headerSize;
@property bool hasData;
@property int32_t width;
@property int32_t height;
@property int32_t bytesPerPixel;
@property int32_t masses;
@property int32_t frames;
@property double raster;

- (id) initWithUrl: (CFURLRef) url;
- (id) initWithPath: (CFStringRef) path;

- (int32_t) readInt: (unsigned long) position;
- (int16_t) readShort: (unsigned long) position;

- (void) readHeader;

#ifdef QUICKLOOKGENERATOR
- (void) generatePreview: (QLPreviewRequestRef) preview;
- (void) generateThumbnail: (QLThumbnailRequestRef) thumbnail;
#endif

@end
#endif /* sims_h */
