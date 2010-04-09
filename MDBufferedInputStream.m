//
//  MDBufferedInputStream.m
//  iDEX
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


@implementation MDBufferedInputStream

@synthesize bytesProcessed;

#pragma mark -
#pragma mark Initialisation

- (id) initWithInputStream:(NSInputStream *)_stream bufferSize:(NSUInteger)_bufSize encoding:(NSStringEncoding)_encoding {
	if ( self = [super init] ) {
		stream = _stream;
		bufSize = _bufSize;
		encoding = _encoding;
	}
	return self;
}

#pragma mark -
#pragma mark MDBufferedInputStream methods

- (NSString *) readLine {
	[lineBuffer setLength:0];
	NSUInteger offset = pos;
	NSInteger found = -1;
	do {
		if ( pos >= read ) {
			read = [stream read:dataBuffer maxLength:bufSize];
			pos = offset = 0;
			if ( !read ) {
				if ( [lineBuffer length] ) {
					break;
				} else {
					return nil;
				}
			}
		}
		for ( ; pos < read; ++pos ) {
			if ( dataBuffer[pos] == 0x0A || dataBuffer[pos] == 0x0D ) {
				found = pos;
				++pos;
				break;
			}
		}
		[lineBuffer appendBytes:&dataBuffer[offset] length:(found < 0 ? read : found) - offset];
	} while ( (found < 0) && read );
	bytesProcessed += [lineBuffer length];
	return [[[NSString alloc] initWithData:lineBuffer encoding:encoding] autorelease];
}

#pragma mark -
#pragma mark NSInputStream methods

- (void) open {
	if ( shouldCloseStream = ([stream streamStatus] == kCFStreamStatusNotOpen) ) {
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

- (NSInteger) read:(uint8_t *)buffer maxLength:(NSUInteger)len {
	return (bytesProcessed += [stream read:buffer maxLength:len]);
}

- (BOOL) getBuffer:(uint8_t **)buffer length:(NSUInteger *)len {
	return [stream getBuffer:buffer length:len];
}

- (void) close {
	[lineBuffer release];
	free(dataBuffer);
	lineBuffer = nil;
	dataBuffer = nil;
	if ( shouldCloseStream ) {
		[stream close];
	}
}

#pragma mark -
#pragma mark Deallocation

- (void) dealloc {
	[self close];
	[super dealloc];
}

@end
