//
//  MDBufferedInputStream.m
//  A NSInputStream decorator that adds buffering and text parsing functionality
//  Text is returned line by line through the readLine method
//
//  Created by Federico Mestrone on 07/04/2010.
//  Copyright 2010 Moodsdesign Ltd. All rights reserved.
//

/*
 TODO
 read the first kilobyte or so of a file, and scan for \r.  If you find
 one, look at the next character and see if it's a \n.  If so, it's a
 DOS-format (\r\n) file.  If not, it's an old-style Mac (\r) text
 file.  If you don't see a \r in the beginning of the file at all,
 assume it's a new-style Mac or Linux/Unix file (\n)
*/

#import "MDBufferedInputStream.h"

@interface MDBufferedInputStream (PrivateMethods)

- (NSString *) csvReadToken:(NSString *)line fromIndex:(int *)pos;

@end

@implementation MDBufferedInputStream

@synthesize bytesProcessed;
@synthesize wantsEmptyLines;
@synthesize trimLines;
@synthesize csvTitles;

#pragma mark -
#pragma mark Initialisation

- (id) initWithInputStream:(NSInputStream *)_stream bufferSize:(NSUInteger)_bufSize encoding:(NSStringEncoding)_encoding {
	if ( (self = [super init]) ) {
		stream = [_stream retain];
		bufSize = _bufSize;
		encoding = _encoding;
        wantsEmptyLines = NO;
        quote = '"';
        separator = ',';
	}
	return self;
}

#pragma mark -
#pragma mark MDBufferedInputStream methods

/*
 Breaks on \r\n and \n. Does not support \r-only (old Mac) line breaks.
 This method is not re-entrant.
 */
- (NSString *) readLine {
	// emptying out the line buffer - this method will keep on reading
	// from the byte buffer and the stream until it can return a string,
	// either because it found a new line, or because it reached EOF
	[lineBuffer setLength:0];
	// make sure you start from where we left off with the previous call
	NSUInteger offset = pos;
	// this specifies where in the byte buffer the new line element was
	// found, but also serves as flag (if -1, no new line was found)
	NSInteger found = -1;
	do {
		if ( pos >= read ) {
			// we have reached the end of the byte buffer, read another chunk
			read = [stream read:dataBuffer maxLength:bufSize];
			// reset position in buffer and offset
			pos = offset = 0;
			if ( read <= 0 ) {
				// nothing was read, we have reached EOF
				if ( [lineBuffer length] ) {
					// if there are bytes in the line buffer, make sure whatever is there
					// is returned as the last line of the file
					break;
				} else {
					// no byte in the byte buffer, so signal that we have finished parsing
					return nil;
				}
			}
		}
		// this loop looks for line termination markers
		for ( ; pos < read; ++pos ) {
            // don't break on \r, it will be removed later
			if ( dataBuffer[pos] == '\n' ) {
				// found one, save its position
				found = pos;
				// move the pointer forward to the character at the beginning of the new line
				++pos;
				break;
			}
		}
		// add the processed bytes to the line buffer
		[lineBuffer appendBytes:&dataBuffer[offset] length:(found < 0 ? read : found) - offset];
        // should not return empty lines?
        if ( found >= 0 && !wantsEmptyLines && ![lineBuffer length] ) {
            // if so, cannot exit now
            found = -1;
            // move to next character of new line (???)
            ++pos;
            // make sure you start from the new line
            offset = pos;
        }
	// if a new line was not found, read more from the stream and continue
	} while ( found < 0 /* && read */ );
	// TODO not very good multithread support - if bytesProcessed is read by another thread in the middle
	// of the execution of this method it will return inconsistent values - but it's ok for now
	// Also note we increase bytesProcessed in readLine as it doesn't invoke [self read:maxLength:],
	// but rather [stream read:maxLength:] directly, otherwise increasing in [MDBufferedInputStream read:maxLength:]
	// would be enough
    NSUInteger length = [lineBuffer length];
	bytesProcessed += length;
	// create a new string with the line buffer
	// TODO check for leak issues with this code

    const uint8_t *bytes = [lineBuffer bytes];
    if (length > 0 && bytes[length - 1] == '\r') {
        length -= 1; // remove last \r to interpret \r\n as line break
    }

	NSString *line = [[[NSString alloc] initWithBytes:bytes length:length encoding:encoding] autorelease];
    if ( trimLines ) {
        line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    return line;
}

#pragma mark -
#pragma mark Reading CSV Files

- (NSString *) csvReadToken:(NSString *)line fromIndex:(int *)p {
    if ( *p >= [line length] ) {
        return nil;
    }
    NSMutableString *buffer = [[NSMutableString alloc] init];
    BOOL atStart = YES;
    BOOL inQuote = NO;
    BOOL afterQuote = NO;

    for ( ; *p < [line length]; ++*p ) {
        unichar c = [line characterAtIndex:*p];
        if ( inQuote ) {
            if ( c == quote ) {
                inQuote = NO;
                afterQuote = YES;
            } else {
                [buffer appendString:[NSString stringWithFormat:@"%C", c]];
            }
            continue;
        } else if ( atStart && c == quote ) {
            inQuote = YES;
            atStart = NO;
            continue;
        }
        if ( c == separator ) {
            ++*p;
            break;
        }
        if ( (atStart || afterQuote) && [[NSCharacterSet whitespaceCharacterSet] characterIsMember:c] ) {
            continue;
        }
        atStart = NO;
        [buffer appendString:[NSString stringWithFormat:@"%C", c]];
    }

    return buffer;
}

// Read the line of CSV header titles from the underlying stream
- (NSArray *) csvReadHeader {
    NSString *headline = [self readLine];
    if ( !headline ) return nil;
    NSMutableArray *titles = [[NSMutableArray alloc] init];
    int p = 0;
    NSString *token;
    while ( (token = [self csvReadToken:headline fromIndex:&p]) ) {
        [titles addObject:token];
    }
    csvTitles = [titles retain];
    return titles;
}

// Read a new line of CSV text data from the underlying stream
- (NSDictionary *) csvReadData {
    NSString *dataline = [self readLine];
    if ( !dataline ) return nil;
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    int p = 0, f = 0;
    NSString *token;
    while ( (token = [self csvReadToken:dataline fromIndex:&p]) ) {
        NSString *fieldName;
        if ( csvTitles && f < [csvTitles count] ) {
            fieldName = [csvTitles objectAtIndex:f];
        } else {
            fieldName = [NSString stringWithFormat:@"field%d", f];
            if ( csvTitles ) {
                NSLog(@"Warning: possible error in following line\n%@\n", dataline);
            }
        }
        [dict setObject:token forKey:fieldName];
        ++f;
    }
    return dict;
}


#pragma mark -
#pragma mark NSInputStream methods

- (void) open {
	if ( (shouldCloseStream = ([stream streamStatus] == kCFStreamStatusNotOpen)) ) {
		// If the underlying stream is not already open, we open it ourselves
		// and we will close it when the decorator is closed
		[stream open];
	}
	lineBuffer = [[NSMutableData alloc] init];
	dataBuffer = calloc(bufSize, sizeof(uint8_t));
	pos = 0;
	read = 0;
	bytesProcessed = 0;
}

- (BOOL) hasBytesAvailable {
	return [stream hasBytesAvailable];
}

// TODO define the semantics of this method within the decorator
- (NSInteger) read:(uint8_t *)buffer maxLength:(NSUInteger)len {
	return (bytesProcessed += [stream read:buffer maxLength:len]);
}

- (BOOL) getBuffer:(uint8_t **)buffer length:(NSUInteger *)len {
	return [stream getBuffer:buffer length:len];
}

- (void) close {
    [csvTitles release];
	[lineBuffer release];
	free(dataBuffer);
    csvTitles = nil;
	lineBuffer = nil;
	dataBuffer = nil;
	if ( shouldCloseStream ) {
		// Close the underlying stream if is was opened by this decorator
		[stream close];
	}
}

#pragma mark -
#pragma mark Deallocation

- (void) dealloc {
	[self close];
    [stream release];
	[super dealloc];
}

@end
