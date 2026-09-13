#import <AppKit/AppKit.h>

static void appendUInt32BE(NSMutableData *data, uint32_t value) {
    uint8_t bytes[4] = {
        (uint8_t)((value >> 24) & 0xff),
        (uint8_t)((value >> 16) & 0xff),
        (uint8_t)((value >> 8) & 0xff),
        (uint8_t)(value & 0xff)
    };
    [data appendBytes:bytes length:sizeof(bytes)];
}

static void appendChunk(NSMutableData *body, const char type[4], NSData *payload) {
    [body appendBytes:type length:4];
    appendUInt32BE(body, (uint32_t)(8 + payload.length));
    [body appendData:payload];
}

static NSData *rleChannel(const uint8_t *pixels, NSUInteger size, NSUInteger channel) {
    NSMutableData *result = [NSMutableData data];
    NSUInteger total = size * size;
    NSUInteger index = 0;

    while (index < total) {
        uint8_t value = pixels[index * 4 + channel];
        NSUInteger run = 1;
        while (index + run < total && run < 130 &&
               pixels[(index + run) * 4 + channel] == value) {
            run += 1;
        }

        if (run >= 3) {
            uint8_t marker = (uint8_t)(0x80 | (run - 3));
            [result appendBytes:&marker length:1];
            [result appendBytes:&value length:1];
            index += run;
            continue;
        }

        NSUInteger literalStart = index;
        NSUInteger literalLength = 0;
        while (index < total && literalLength < 128) {
            NSUInteger nextRun = 1;
            uint8_t nextValue = pixels[index * 4 + channel];
            while (index + nextRun < total && nextRun < 3 &&
                   pixels[(index + nextRun) * 4 + channel] == nextValue) {
                nextRun += 1;
            }
            if (nextRun >= 3) {
                break;
            }
            index += 1;
            literalLength += 1;
        }

        uint8_t literalMarker = (uint8_t)(literalLength - 1);
        [result appendBytes:&literalMarker length:1];
        for (NSUInteger i = 0; i < literalLength; i++) {
            uint8_t literal = pixels[(literalStart + i) * 4 + channel];
            [result appendBytes:&literal length:1];
        }
    }
    return result;
}

static NSData *legacyColour(const uint8_t *pixels, NSUInteger size, BOOL hasHeader) {
    NSMutableData *result = [NSMutableData data];
    if (hasHeader) {
        uint8_t zeroes[4] = {0, 0, 0, 0};
        [result appendBytes:zeroes length:sizeof(zeroes)];
    }
    for (NSUInteger channel = 0; channel < 3; channel++) {
        [result appendData:rleChannel(pixels, size, channel)];
    }
    return result;
}

static NSData *legacyMask(const uint8_t *pixels, NSUInteger size) {
    NSMutableData *result = [NSMutableData dataWithLength:size * size];
    uint8_t *mask = result.mutableBytes;
    for (NSUInteger i = 0; i < size * size; i++) {
        mask[i] = pixels[i * 4 + 3];
    }
    return result;
}

static NSData *pixelsForImage(NSImage *image, NSUInteger size) {
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
                      pixelsWide:(NSInteger)size
                      pixelsHigh:(NSInteger)size
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSDeviceRGBColorSpace
                      bytesPerRow:0
                     bitsPerPixel:0];
    if (bitmap == nil) {
        fprintf(stderr, "bitmap allocation failed for %lu\n", (unsigned long)size);
        return nil;
    }

    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    if (context == nil) {
        fprintf(stderr, "graphics context allocation failed for %lu\n", (unsigned long)size);
        return nil;
    }
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    [image drawInRect:NSMakeRect(0, 0, size, size)
             fromRect:NSZeroRect
            operation:NSCompositingOperationCopy
             fraction:1.0
       respectFlipped:YES
                hints:@{NSImageHintInterpolation: @(NSImageInterpolationHigh)}];
    [NSGraphicsContext restoreGraphicsState];

    NSMutableData *result = [NSMutableData dataWithLength:size * size * 4];
    uint8_t *destination = result.mutableBytes;
    for (NSUInteger y = 0; y < size; y++) {
        for (NSUInteger x = 0; x < size; x++) {
            NSUInteger components[4] = {0, 0, 0, 0};
            [bitmap getPixel:components atX:(NSInteger)x y:(NSInteger)y];
            NSUInteger offset = (y * size + x) * 4;
            for (NSUInteger channel = 0; channel < 4; channel++) {
                destination[offset + channel] = (uint8_t)MIN(components[channel], 255);
            }
        }
    }
    return result;
}

static BOOL isLegacyType(const uint8_t *type) {
    return (memcmp(type, "is32", 4) == 0 || memcmp(type, "s8mk", 4) == 0 ||
            memcmp(type, "il32", 4) == 0 || memcmp(type, "l8mk", 4) == 0 ||
            memcmp(type, "it32", 4) == 0 || memcmp(type, "t8mk", 4) == 0);
}

int main(int argc, const char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "usage: make_icns input.icns output.icns\n");
        return 2;
    }

    @autoreleasepool {
        [NSApplication sharedApplication];
        NSString *inputPath = [NSString stringWithUTF8String:argv[1]];
        NSString *outputPath = [NSString stringWithUTF8String:argv[2]];
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:inputPath];
        NSData *input = [NSData dataWithContentsOfFile:inputPath];
        if (image == nil || input.length < 8 ||
            memcmp(input.bytes, "icns", 4) != 0) {
            fprintf(stderr, "invalid source ICNS\n");
            return 1;
        }

        NSMutableData *body = [NSMutableData data];
        const struct {
            char colour[4];
            char mask[4];
            NSUInteger size;
            BOOL hasHeader;
        } legacy[] = {
            {{'i','s','3','2'}, {'s','8','m','k'}, 16, NO},
            {{'i','l','3','2'}, {'l','8','m','k'}, 32, NO}
        };

        for (NSUInteger i = 0; i < sizeof(legacy) / sizeof(legacy[0]); i++) {
            NSData *pixels = pixelsForImage(image, legacy[i].size);
            if (pixels == nil) {
                fprintf(stderr, "could not render source ICNS\n");
                return 1;
            }
            appendChunk(body, legacy[i].colour,
                        legacyColour(pixels.bytes, legacy[i].size, legacy[i].hasHeader));
            appendChunk(body, legacy[i].mask,
                        legacyMask(pixels.bytes, legacy[i].size));
        }

        const uint8_t *bytes = input.bytes;
        NSUInteger offset = 8;
        while (offset + 8 <= input.length) {
            const uint8_t *type = bytes + offset;
            uint32_t length = ((uint32_t)bytes[offset + 4] << 24) |
                              ((uint32_t)bytes[offset + 5] << 16) |
                              ((uint32_t)bytes[offset + 6] << 8) |
                              (uint32_t)bytes[offset + 7];
            if (length < 8 || offset + length > input.length) {
                fprintf(stderr, "invalid ICNS element\n");
                return 1;
            }
            if (!isLegacyType(type) && memcmp(type, "info", 4) != 0) {
                [body appendBytes:bytes + offset length:length];
            }
            offset += length;
        }

        NSMutableData *output = [NSMutableData data];
        [output appendBytes:"icns" length:4];
        appendUInt32BE(output, (uint32_t)(8 + body.length));
        [output appendData:body];
        if (![output writeToFile:outputPath atomically:YES]) {
            fprintf(stderr, "could not write output ICNS\n");
            return 1;
        }
    }
    return 0;
}
