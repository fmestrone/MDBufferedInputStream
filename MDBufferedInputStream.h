//
//  MDBufferedInputStream.h
//  iDEX
//
//  Created by Federico Mestrone on 07/04/2010.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MDBufferedInputStream : NSInputStream {
	NSInputStream *stream;
	NSUInteger bufSize;
	NSStringEncoding encoding;

	NSMutableData *lineBuffer;
	uint8_t *dataBuffer;
	NSInteger pos;
	NSInteger read;
	NSUInteger bytesProcessed;
	BOOL shouldCloseStream;
}

@property (readonly) NSUInteger bytesProcessed;

- (id)initWithInputStream:(NSInputStream *)stream bufferSize:(NSUInteger)bufSize encoding:(NSStringEncoding)encoding;
- (NSString *)readLine;

@end
