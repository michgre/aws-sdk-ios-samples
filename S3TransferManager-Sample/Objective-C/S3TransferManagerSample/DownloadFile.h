//
//  DownloadFile.h
//  S3TransferManagerSample
//
//  Created by Michael Green on 10/31/14.
//  Copyright (c) 2014 Amazon Web Services. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "S3.h"

@interface DownloadFile : NSObject

@property NSString *fileName;
@property NSURL *url;  // URL to what?
@property AWSS3TransferManagerDownloadRequest *downloadRequest;
@property BOOL downloadComplete;
@property NSInteger *fileSize;
@property NSInteger *bytesWritten;

@end
