//
//  sims.m
//  SIMS.qlgenerator
//
//  Created by Zan Peeters on 15-02-2018.
//  Copyright © 2018 Zan Peeters. All rights reserved.
//

#import "sims.h"

@implementation SIMSFile

// Lookup tables for converting atom number and charge to superscript
// and atom counts to subscripts. Uses UTF-8 sub- and superscript versions of the numbers.
static const NSDictionary *superscripts = nil;
static const NSDictionary *subscripts = nil;

+ (void) initialize {
    superscripts = @{
        @"0": @"\xE2\x81\xB0",
        @"1": @"\xC2\xB9",
        @"2": @"\xC2\xB2",
        @"3": @"\xC2\xB3",
        @"4": @"\xE2\x81\xB4",
        @"5": @"\xE2\x81\xB5",
        @"6": @"\xE2\x81\xB6",
        @"7": @"\xE2\x81\xB7",
        @"8": @"\xE2\x81\xB8",
        @"9": @"\xE2\x81\xB9",
        @"+": @"\xE2\x81\xBA",
        @"-": @"\xE2\x81\xBB"
    };
    
    subscripts = @{
        @"0": @"\xE2\x82\x80",
        @"1": @"\xE2\x82\x81",
        @"2": @"\xE2\x82\x82",
        @"3": @"\xE2\x82\x83",
        @"4": @"\xE2\x82\x84",
        @"5": @"\xE2\x82\x85",
        @"6": @"\xE2\x82\x86",
        @"7": @"\xE2\x82\x87",
        @"8": @"\xE2\x82\x88",
        @"9": @"\xE2\x82\x89"
    };
}

- (id) initWithUrl: (CFURLRef) url {
    self = [super init];
    if (self) {
        self.filename = [(__bridge NSURL *)url path];
        [self readHeader];
    }
    return self;
}

- (id) initWithPath: (CFStringRef) path {
    self = [super init];
    if (self) {
        self.filename = (__bridge NSString *)path;
        [self readHeader];
    }
    return self;
}

- (int16_t) readShort: (unsigned long) position {
    int16_t value;
    [self.data getBytes:&value range:NSMakeRange(position, 2)];
    if (self.needByteSwap) {
        value = CFSwapInt16(value);
    }
    return value;
}

- (int32_t) readInt: (unsigned long) position {
    int32_t value;
    [self.data getBytes:&value range:NSMakeRange(position, 4)];
    if (self.needByteSwap) {
        value = CFSwapInt32(value);
    }
    return value;
}

// There is no built in function for byteswappig 64-bit doubles.
// Don't use sizeof, value in file is always 8 bytes.
- (double) readDouble: (unsigned long) position {
    union {
        double d;
        unsigned char bytes[8];
    } conv;
    [self.data getBytes:&conv.bytes range:NSMakeRange(position, 8)];

    if (self.needByteSwap) {
        unsigned char copy[8];
        memcpy(copy, conv.bytes, 8);
        copy[0] = conv.bytes[7];
        copy[1] = conv.bytes[6];
        copy[2] = conv.bytes[5];
        copy[3] = conv.bytes[4];
        copy[4] = conv.bytes[3];
        copy[5] = conv.bytes[2];
        copy[6] = conv.bytes[1];
        copy[7] = conv.bytes[0];
        memcpy(conv.bytes, copy, 8);
    }
    return conv.d;
}

- (void) readHeader {
    NSError *error;

    // Mapped data reading, only read from file when necessary.
    self.data = [NSData dataWithContentsOfFile: self.filename
                                       options: NSDataReadingMappedAlways
                                         error: &error];
    if (!self.data) {
        NSLog(@"%@\n", error);
        return;
    }

    // On a LE machine, a LE file will have fileType < 255.
    // On a BE machine, a BE file will have fileType < 255.
    // In other cases, we need to byteswap.
    [self.data getBytes:&_fileType range:NSMakeRange(4, 4)];
    self.needByteSwap = false;
    if (self.fileType > FileTypeLimit) {
        self.needByteSwap = true;
        self.fileType = CFSwapInt32(self.fileType);
    }

    self.fileVersion = [self readInt:0];
    self.headerSize = [self readInt:8];
    self.hasData = (bool)[self readInt:20];
    
    // Get frames from start of header, rest follows later
    int frames_pos;
    switch (self.fileType) {
        case DepthProfileFile:
        case IsotopeFile:
        case BeamStabilityFile:
            frames_pos = 148;
            break;
        case LinescanStageControlFile:
        case StageControlImage:
            frames_pos = 172;
        default:
            // ImageFile, GrainModeFile, LinescanImageFile
            frames_pos = 144;
            break;
    }
    self.frames = [self readInt:frames_pos];

    // MassTable
    // Find start of MassTable for different fileTypes.
    // For explanation of numbers, see sims.py project.
    int mass_pos = 124 + 160;
    switch (self.fileType) {
        case ImageFile:
        case GrainModeFile:
        case LinescanImageFile:
            mass_pos += 48 + 76;
            break;
        case DepthProfileFile:
        case IsotopeFile:
            mass_pos += 52 + 76 + 112 + 24;
            break;
        case BeamStabilityFile:
            mass_pos += 76 + 76 + 112;
            break;
        case LinescanStageControlFile:
        case StageControlImage:
            mass_pos += 64 + 76 + 112 + 4;
            break;
//        case LinescanBeamControlFile:
//
//            break;
    }

    self.masses = [self readInt:mass_pos];

    // MassPtrList, length depends on fileType and fileVersion.
    int n = 1;
    switch (self.fileType) {
        case DepthProfileFile:
        case IsotopeFile:
        case ImageFile:
        case GrainModeFile:
        case BeamStabilityFile:
        case LinescanImageFile:
            if (self.fileVersion >= 4108) {
                n += 60;
            } else {
                n += 10;
            }
            break;
        case LinescanStageControlFile:
        case LinescanBeamControlFile:
        case StageControlImage:
            n += 20;
            break;
    }
    mass_pos += 4 * n;

    // To trim null-bytes and whitespace characters, create a charset containing both
    NSMutableCharacterSet *trimset = [NSMutableCharacterSet characterSetWithCharactersInString:@"\0"];
    [trimset formUnionWithCharacterSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    // Sub- and superscripts:
    // Each label is made up of units, separated by space.
    // The last unit (optional) may be + or -.
    // Each unit is made up of subunits atom-number|element|count, without a separator.
    // Element is mandatory and aways letters, atom number and count are optional
    // and always numeric.
    NSRegularExpression *unit_rx = [NSRegularExpression regularExpressionWithPattern:@"([0-9]*)?([A-Z][a-z]*)([0-9]*)?"
                                                                             options:kNilOptions
                                                                               error:&error];
    
    // Find labels in MassTable
    // Each mass in table:
    //    4 byte int (index) + 61 bytes + 64 byte string (label) + 63 bytes
    int trolleyIndex;
    self.labels = [[NSMutableArray alloc] initWithCapacity:self.masses];
    for (int m=0; m < self.masses; m++) {
        trolleyIndex = [self readInt:(mass_pos + m * 192)];
        NSString *label = [[NSString alloc] initWithData: [self.data subdataWithRange:NSMakeRange(mass_pos + 65 + m * 192, 64)]
                                                encoding: NSISOLatin1StringEncoding];
        label = [label stringByTrimmingCharactersInSet: trimset];
        
        // Handle charge separately.
        NSString *charge = @"";
        if ([label hasSuffix:@"+"]) {
            [label substringToIndex:-2];
            charge = @"\xE2\x81\xBA";
        } else if ([label hasSuffix:@"-"]) {
            [label substringToIndex:-2];
            charge = @"\xE2\x81\xBB";
        }

        // Split label into parts by regex.
        NSArray<NSTextCheckingResult *> *units = [unit_rx matchesInString:label
                                                                  options:kNilOptions
                                                                    range:NSMakeRange(0, label.length)];
        NSMutableArray *displayLabelList = [[NSMutableArray alloc] init];
        for (NSTextCheckingResult *unit in units) {
            NSMutableString *atomNumber = [[label substringWithRange:[unit rangeAtIndex:1]] mutableCopy];
            NSString *element = [label substringWithRange:[unit rangeAtIndex:2]];
            NSMutableString *count = [[label substringWithRange:[unit rangeAtIndex:3]] mutableCopy];
            
            // Replace atom number with superscript, count with subscript.
            for (NSString *s in superscripts) {
                [atomNumber replaceOccurrencesOfString: s
                                            withString: [superscripts objectForKey:s]
                                               options: NSLiteralSearch
                                                 range: NSMakeRange(0, atomNumber.length)
                 ];
            }
            for (NSString *s in subscripts) {
                [count replaceOccurrencesOfString: s
                                       withString: [subscripts objectForKey:s]
                                          options: NSLiteralSearch
                                            range: NSMakeRange(0, count.length)
                 ];
            }
            
            [displayLabelList addObject:atomNumber];
            [displayLabelList addObject:element];
            [displayLabelList addObject:count];
        }
        [displayLabelList addObject:charge];
        
        // Put everything back together, no separators needed.
        NSString *displayLabel = [displayLabelList componentsJoinedByString:@""];

        if (trolleyIndex == 8) {
            displayLabel = @"SE";
        }
        [self.labels addObject: displayLabel];
    }

    // For image types, pertinent information is stored in the ImageHeader,
    // which occupies the last 84 bytes of the entire header.
    if (self.fileType == ImageFile || self.fileType == LinescanImageFile) {
        self.width = (int32_t)[self readShort:self.headerSize - 78];
        self.height = (int32_t)[self readShort:self.headerSize - 76];
        self.bytesPerPixel = (int32_t)[self readShort:self.headerSize - 74];
        self.masses = (int32_t)[self readShort:self.headerSize - 72];
        self.frames = (int32_t)[self readShort:self.headerSize - 70];
        self.raster = (double)[self readInt:self.headerSize - 68]/1000;
    } else {
        // For other fileTypes, we need to find raster in PrimaryBeam section and pixel width
        // and height in nanoSIMS header
        
        // These labels may (or not) occur in various combinations.
        // Find last occurance, nanoSIMS header starts after.
        NSRange poly_pos = [self.data rangeOfData:[NSData dataWithBytes:"Poly_list\x00" length:10]
                                          options:NSDataSearchBackwards
                                            range:NSMakeRange(0, self.headerSize)];
        NSRange champs_pos = [self.data rangeOfData:[NSData dataWithBytes:"Champs_list\x00" length:12]
                                            options:NSDataSearchBackwards
                                              range:NSMakeRange(0, self.headerSize)];
        NSRange offset_pos = [self.data rangeOfData:[NSData dataWithBytes:"Offset_list\x00" length:12]
                                            options:NSDataSearchBackwards
                                              range:NSMakeRange(0, self.headerSize)];

        // These labels come after the MassTable
        unsigned long nsheader_pos = mass_pos + self.masses * 192;
        if (poly_pos.location == NSNotFound) {
            nsheader_pos += 216;
        } else if ((champs_pos.location == NSNotFound && offset_pos.location == NSNotFound) ||
                   (champs_pos.location < offset_pos.location && offset_pos.location < poly_pos.location)) {
            int poly_length = [self readInt:poly_pos.location + 16];
            nsheader_pos = poly_pos.location + 16 + 4 + 4 + poly_length * 144;
        } else if (poly_pos.location < champs_pos.location < offset_pos.location) {
            // So far, all Champs and Offset lists I have encountered have been empty.
            // Let's hope it stays that way, because I don't know how to read them.
            int offset_length = [self readInt:offset_pos.location + 16];
            if (offset_length != 0) {
                NSLog(@"Found non-empty Offset_list in header of file %@, don't know how to continue.\n", self.filename);
                return;
            }
            nsheader_pos = offset_pos.location + 16 + 4 + 4;
        } else {
            NSLog(@"Don't know where nanoSIMS header starts in file %@.\n", self.filename);
            return;
        }

        if (self.fileType == LinescanStageControlFile || self.fileType == StageControlImage) {
            // Stage delta x & y
            self.width = [self readInt:nsheader_pos + 20];
            self.height = [self readInt:nsheader_pos + 24];
        } else {
            // Working frame
            self.width = [self readInt:nsheader_pos + 28];
            self.height = [self readInt:nsheader_pos + 32];
        }
        
        NSRange primarybeam_pos = [self.data rangeOfData:[NSData dataWithBytes:"Anal_param_nano\x00" length:16]
                                                 options:kNilOptions
                                                   range:NSMakeRange(0, self.headerSize)];
        
        if (primarybeam_pos.location == NSNotFound) {
            NSLog(@"Could not find label 'Anal_param_nano' in header, don't know where primary beam header starts in file %@.\n", self.filename);
            return;
        }
        self.raster = [self readDouble:primarybeam_pos.location + 448];
    }
}

#ifdef QUICKLOOKGENERATOR
// For preview, take time to read all data and sum frames.
// Then, stretch histogram for maximum contrast.
// Finally, create page with all images and add labels.
- (void) generatePreview: (QLPreviewRequestRef) preview {
    if (!self.hasData) {
        return;
    }
    unsigned long dataLength = self.data.length - self.headerSize;
    unsigned long pixels = dataLength/self.bytesPerPixel;
    unsigned char *rawData = malloc(dataLength);
    float *pixelData = malloc(pixels * sizeof(float));
    [self.data getBytes:rawData range:NSMakeRange(self.headerSize, dataLength)];

    // Cast to float and byte swap (if needed) all in one loop.
    if (self.bytesPerPixel == 2) {
        if (self.needByteSwap) {
            for (int i = 0; i < dataLength; i += 2) {
                pixelData[i/2] = (float)((rawData[i] << 8) +
                                         (rawData[i + 1]));
            }
        } else {
            for (int i = 0; i < dataLength; i += 2) {
                pixelData[i/2] = (float)((rawData[i]) +
                                         (rawData[i + 1] << 8));
            }
        }
    } else if (self.bytesPerPixel == 4) {
        if (self.needByteSwap) {
            for (int i = 0; i < dataLength; i += 4) {
                pixelData[i/4] = (float)((rawData[i] << 24) +
                                         (rawData[i + 1] << 16) +
                                         (rawData[i + 2] << 8) +
                                         (rawData[i + 3]));
            }
        } else {
            for (int i = 0; i < dataLength; i += 4) {
                pixelData[i/4] = (float)((rawData[i]) +
                                         (rawData[i + 1] << 8) +
                                         (rawData[i + 2] << 16) +
                                         (rawData[i + 3] << 24));
            }
        }
    } else {
        NSLog(@"Pixels with byte-size other than 2 or 4 not supported, got %d bytes per pixel.\n", self.bytesPerPixel);
        free(rawData);
        free(pixelData);
        return;
    }
    free(rawData);

    // sum frames
    float *sum = malloc(self.height * self.width * self.masses * sizeof(float));
    memset(sum, 0, self.height * self.width * self.masses * sizeof(float));
    
    // large test file (512x512 px, 6 masses, 15 frames, 4 bytes/px, 94 MB on disk)
    // Test from command line with:
    //    qlmanage -g path/to/QuickLookSIMS.qlgenerator -c com.cameca.sims.image -p -z path/to/test_file.im
    //
    // 4 loops
    // Debug (-O0): 1.8 s
    // Release (-Os): 1.8 s
    // Release (-O3): 1.3 s
    // Release (-O3 -funroll-loops): 1.3 s
    //
    // 3 loops + dispatch
    // Debug (-O0, dispatch over width): 1.3 s
    // Debug (-O0, dispatch mass): 0.9 s
    // Release (-Os, dispatch over mass): 0.6 s
    // Release (-O3 or -O3 -funroll-loops or -Ofast): 0.6 s
    //
    // 1 loop + dispatch over masses*width*height
    // Debug (-O0): 0.7 s
    // Release (-Os): 0.53 s
    // Release (-O3): 0.48 s
    //
    // dispatch over masses*width*height + vDSP_sve sum of vector
    // Debug (-O0): 0.56 s
    // Release (-Os): 0.41 s
    // Release (-O3): 0.40 s
    //
    // dispatch over masses, loop over frames, vDSP_vadd frames
    // Debug (-O0): 0.47 s
    // Release (-Os): 0.35 s
    // Release (-O3): 0.34 s

// 4 for loops
//    for (int f = 0; f < self.frames; f++) {
//        for (int m = 0; m < self.masses; m++) {
//            for (int h = 0; h < self.height; h++) {
//                for (int w = 0; w < self.width; w++) {
//                    sum[m * self.height * self.width + h * self.width + w] +=
//                        pixelData[f * self.masses * self.height * self.width + m * self.height * self.width + h * self.width + w];
//                }
//            }
//        }
//    }

// 3 loops + dispatch
//    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//    dispatch_apply(self.masses, queue, ^(size_t m){
//            for (int f = 0; f < self.frames; f++) {
//                for (int h = 0; h < self.height; h++) {
//                    for (int w = 0; w < self.width; w++) {
//                        sum[m * self.height * self.width + h * self.width + w] +=
//                            pixelData[f * self.masses * self.height * self.width + m * self.height * self.width + h * self.width + w];
//                    }
//                }
//            }
//    });

// 1 loop + dispatch over masses*width*height
//    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//    int pixelsPerFrame = self.masses * self.height * self.width;
//    dispatch_apply(pixelsPerFrame, queue, ^(size_t i){
//        for (int f = 0; f < self.frames; f++) {
//            sum[i] += pixelData[i + f * pixelsPerFrame];
//        }
//    });

// dispatch over masses*width*height + vDSP_sve sum of vector
//    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//    int pixelsPerFrame = self.masses * self.height * self.width;
//    dispatch_apply(pixelsPerFrame, queue, ^(size_t i){
//        vDSP_sve(&pixelData[i], pixelsPerFrame, &sum[i], self.frames);
//    });

    // dispatch over masses, loop over frames, vDSP_vadd frames
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    int pixelsPerSingleFrame = self.height * self.width;
    int pixelsPerLargeFrame = self.masses * self.height * self.width;
    dispatch_apply(self.masses, queue, ^(size_t m){
        for (int f = 0; f < self.frames; f++) {
            vDSP_vadd(&sum[m * pixelsPerSingleFrame], 1,
                      &pixelData[m * pixelsPerSingleFrame + f * pixelsPerLargeFrame], 1,
                      &sum[m * pixelsPerSingleFrame], 1,
                      pixelsPerSingleFrame);
        }
    });
    free(pixelData);

    // Set up buffers for vImageContrastStretch_PlanarF and vImageConvert_PlanarFtoPlanar8
    int pixelsPerMass = self.width * self.height;
    float *srcbuf = malloc(pixelsPerMass * sizeof(float));
    float *intermedbuf = malloc(pixelsPerMass * sizeof(float));
    uint8_t *destbuf = malloc(pixelsPerMass * sizeof(uint8_t));

    vImage_Buffer src, intermed, dest;
    src.data = srcbuf;
    src.height = (vImagePixelCount)self.height;
    src.width = (vImagePixelCount)self.width;
    src.rowBytes = (vImagePixelCount)(self.width * sizeof(float));

    intermed = src;
    intermed.data = intermedbuf;

    dest = src;
    dest.data = destbuf;
    dest.rowBytes = (vImagePixelCount)(self.width * sizeof(uint8_t));

    vImage_Error vIerr;
    
    // Set up bitmap and colourspace info for CGContexts
    CGBitmapInfo bminfo = kCGBitmapByteOrderDefault;
    CGColorSpaceRef cspace = CGColorSpaceCreateDeviceGray();

    int rows, cols = 1;
    if (self.masses < 4) {
        rows = 1;
        cols = self.masses;
    } else if (self.masses == 4) {
        rows = 2;
        cols = 2;
    } else if (self.masses == 5 || self.masses == 6) {
        rows = 2;
        cols = 3;
    } else {  // mass 7 or 8
        rows = 2;
        cols = 4;
    }

    int masterWidth = cols * self.width + (cols - 1) * COLSEP;
    int masterHeight = rows * (self.height + ROWSEP);

    NSDictionary *qlOptions = @{
        (NSString *)kQLPreviewPropertyHeightKey: [NSNumber numberWithInt: masterHeight],
        (NSString *)kQLPreviewPropertyWidthKey: [NSNumber numberWithInt: masterWidth]
    };
    CGContextRef master = QLPreviewRequestCreateContext(preview, CGSizeMake(masterWidth, masterHeight), true, (__bridge CFDictionaryRef)(qlOptions));

    // Flip coordinates so that 0,0 is top left.
    CGContextScaleCTM(master, 1.0, -1.0);
    CGContextTranslateCTM(master, 0.0, -1 * masterHeight);

    int col, row;
    
    // Stretch histogram to use full range, then convert to 8bit gray.
    // Trying to use dispatch instead of for loop actually slow down by 0.02 s
    for (int m = 0; m < self.masses; m++) {
        memcpy(srcbuf, sum + m * pixelsPerMass, pixelsPerMass * sizeof(float));

        vIerr = vImageContrastStretch_PlanarF(&src, &intermed, NULL, 255, 0, 1, kvImageNoFlags);
        if (vIerr != kvImageNoError) {
            NSLog(@"Some error with vImage histogram: %zd\n", vIerr);
            CGColorSpaceRelease(cspace);
            free(sum);
            free(srcbuf);
            free(intermedbuf);
            free(destbuf);
            CGContextRelease(master);
            return;
        }
        
        vIerr = vImageConvert_PlanarFtoPlanar8(&intermed, &dest, 1, 0, kvImageNoFlags);
        if (vIerr != kvImageNoError) {
            NSLog(@"Some error with vImage conversion from PlanarF to Planar8: %zd\n", vIerr);
            CGColorSpaceRelease(cspace);
            free(sum);
            free(srcbuf);
            free(intermedbuf);
            free(destbuf);
            CGContextRelease(master);
            return;
        }
        
        CGContextRef context = CGBitmapContextCreateWithData(
            dest.data,                    // data
            self.width,                   // single image width
            self.height,                  // single image height
            8 * sizeof(uint8_t),          // bits per component
            self.width *sizeof(uint8_t),  // bytes per row
            cspace,                       // colorspace
            bminfo,                       // bitmapinfo
            NULL,                         // callback
            NULL                          // release callback
        );
        
        CGImageRef image = CGBitmapContextCreateImage(context);
        
        col = (int)m % cols;
        row = (int)m/cols;
        CGRect rect = CGRectMake(col*(self.width + COLSEP), row*(self.height + ROWSEP), self.width, self.height);
        CGContextDrawImage(master, rect, image);
        
        CGImageRelease(image);
        CGContextRelease(context);
    }
    CGColorSpaceRelease(cspace);
    free(sum);
    free(srcbuf);
    free(intermedbuf);
    free(destbuf);

    // Draw labels
    NSDictionary *fontAttributes = @{NSFontAttributeName: [NSFont systemFontOfSize:FONTSIZE]};
    CGContextSetTextMatrix(master, CGAffineTransformMakeScale(1.0, -1.0));
    float xpos, ypos;
    for (NSString *lbl in self.labels) {
        CFAttributedStringRef string = CFAttributedStringCreate(kCFAllocatorDefault,
                                                                (__bridge CFStringRef)lbl,
                                                                (__bridge CFDictionaryRef)fontAttributes);
        CTLineRef line = CTLineCreateWithAttributedString(string);
        CGRect bounds = CTLineGetImageBounds(line, master);
        unsigned long m = [self.labels indexOfObject:lbl];
        col = (int)m % cols;
        row = (int)m/cols;
        xpos = col * (self.width + COLSEP) + self.width/2 - bounds.size.width/2;
        ypos = (row + 1) * (self.height + ROWSEP) - ROWSEP/2 + bounds.size.height/2;
        CGContextSetTextPosition(master, xpos, ypos);
        CTLineDraw(line, master);
        CFRelease(line);
        CFRelease(string);
    }
    QLPreviewRequestFlushContext(preview, master);
    CGContextRelease(master);
}

// For thumbnail, only process first frame of first mass => speed.
// Stretch histogram for maximum contrast.
// Generate thumbnail from single image without label.
- (void) generateThumbnail: (QLThumbnailRequestRef) thumbnail {
    if (!self.hasData) {
        return;
    }
    unsigned long pixels = self.width * self.height;
    unsigned long dataLength = pixels * self.bytesPerPixel;
    unsigned char *rawData = malloc(dataLength);
    float *pixelData = malloc(pixels * sizeof(float));
    [self.data getBytes:rawData range:NSMakeRange(self.headerSize, dataLength)];
    
    // Cast to float and byte swap (if needed) all in one loop.
    if (self.bytesPerPixel == 2) {
        if (self.needByteSwap) {
            for (int i = 0; i < dataLength; i += 2) {
                pixelData[i/2] = (float)((rawData[i] << 8) +
                                         (rawData[i + 1]));
            }
        } else {
            for (int i = 0; i < dataLength; i += 2) {
                pixelData[i/2] = (float)((rawData[i]) +
                                         (rawData[i + 1] << 8));
            }
        }
    } else if (self.bytesPerPixel == 4) {
        if (self.needByteSwap) {
            for (int i = 0; i < dataLength; i += 4) {
                pixelData[i/4] = (float)((rawData[i] << 24) +
                                         (rawData[i + 1] << 16) +
                                         (rawData[i + 2] << 8) +
                                         (rawData[i + 3]));
            }
        } else {
            for (int i = 0; i < dataLength; i += 4) {
                pixelData[i/4] = (float)((rawData[i]) +
                                         (rawData[i + 1] << 8) +
                                         (rawData[i + 2] << 16) +
                                         (rawData[i + 3] << 24));
            }
        }
    } else {
        NSLog(@"Pixels with byte-size other than 2 or 4 not supported, got %d bytes per pixel.\n", self.bytesPerPixel);
        free(rawData);
        free(pixelData);
        return;
    }
    free(rawData);
    
    float *intermedbuf = malloc(pixels * sizeof(float));
    uint8_t *destbuf = malloc(pixels * sizeof(uint8_t));
    
    vImage_Buffer src, intermed, dest;
    src.data = pixelData;
    src.height = (vImagePixelCount)self.height;
    src.width = (vImagePixelCount)self.width;
    src.rowBytes = (vImagePixelCount)(self.width * sizeof(float));
    
    intermed = src;
    intermed.data = intermedbuf;
    
    dest = src;
    dest.data = destbuf;
    dest.rowBytes = (vImagePixelCount)(self.width * sizeof(uint8_t));
    
    vImage_Error vIerr = vImageContrastStretch_PlanarF(&src, &intermed, NULL, 255, 0, 1, kvImageNoFlags);
    if (vIerr != kvImageNoError) {
        NSLog(@"Some error with vImage histogram: %zd\n", vIerr);
        free(pixelData);
        free(intermedbuf);
        free(destbuf);
        return;
    }
    free(pixelData);
    
    vIerr = vImageConvert_PlanarFtoPlanar8(&intermed, &dest, 1, 0, kvImageNoFlags);
    if (vIerr != kvImageNoError) {
        NSLog(@"Some error with vImage conversion from PlanarF to Planar8: %zd\n", vIerr);
        free(intermedbuf);
        free(destbuf);
        return;
    }
    free(intermedbuf);
    
    CGBitmapInfo bminfo = kCGBitmapByteOrderDefault;
    CGColorSpaceRef cspace = CGColorSpaceCreateDeviceGray();
    CGContextRef master = QLThumbnailRequestCreateContext(thumbnail, CGSizeMake(self.width, self.height), true, nil);

    CGContextRef context = CGBitmapContextCreateWithData(
        dest.data,                    // data
        self.width,                   // single image width
        self.height,                  // single image height
        8 * sizeof(uint8_t),            // bits per component
        self.width * sizeof(uint8_t),   // bytes per row
        cspace,                       // colorspace
        bminfo,                       // bitmapinfo
        NULL,                         // callback
        NULL                          // release callback
    );
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextDrawImage(master, CGRectMake(0, 0, self.width, self.height), image);

    QLThumbnailRequestFlushContext(thumbnail, master);
    
    CGImageRelease(image);
    CGContextRelease(context);
    CGContextRelease(master);
    CGColorSpaceRelease(cspace);
    free(destbuf);
}
#endif // QUICKLOOKGENERATOR

@end

