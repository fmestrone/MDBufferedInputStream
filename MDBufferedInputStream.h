//
//  MDBufferedInputStream.h
//  A NSInputStream decorator that adds buffering and text parsing functionality
//  Text is returned line by line through the readLine method
//
//  Created by Federico Mestrone on 07/04/2010.
//  Copyright 2010 Moodsdesign Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MDBufferedInputStream : NSInputStream {
	// The decorated stream
	NSInputStream *stream;
	// The size of each chunk read from the stream into memory
	NSUInteger bufSize;
	// The encoding of the text represented by the underlying stream
	NSStringEncoding encoding;

	// Buffer containing the bytes of the current chunk read from the stream
	uint8_t *dataBuffer;
	
	// Temporary buffer of the bytes of the current line till a line termination marker is reached
	// Only when a line ending is reached can the bytes safely be decoded into a string
	NSMutableData *lineBuffer;
	// The position being read from the current chunk
	NSInteger pos;
	// The number of bytes read from the stream into the chunk
	NSInteger read;
	// The number of bytes actually processed so far
	NSUInteger bytesProcessed;
	// Whether the stream was opened by this decorator and should therefore be closed with it	
	BOOL shouldCloseStream;
	// Whether the object should return empty lines or not
	BOOL wantsEmptyLines;
	// Whether the object should trim lines before returning them
	BOOL trimLines;

    /**********************************
     CSV Files
     **********************************/
    NSArray *csvTitles;
    unichar quote;
    unichar separator;
}

// Returns the number of bytes that have currently been processed by the decorator
@property (readonly) NSUInteger bytesProcessed;
// Returns or sets whether the object returns empty lines or not
@property BOOL wantsEmptyLines;
// Returns or sets whether the object should trim lines before returning them
@property BOOL trimLines;

// Creates a new decorator with the given stream, chunk size, and encoding
- (id) initWithInputStream:(NSInputStream *)stream bufferSize:(NSUInteger)bufSize encoding:(NSStringEncoding)encoding;

// Read a new line of text from the underlying stream
- (NSString *) readLine;

/**********************************
 CSV Files
 **********************************/

// Returns or sets the titles for each field of a CSV file
@property (retain) NSArray *csvTitles;

// Read the line of CSV header titles from the underlying stream
- (NSArray *) csvReadHeader;
// Read a new line of CSV text data from the underlying stream
- (NSDictionary *) csvReadData;


@end
