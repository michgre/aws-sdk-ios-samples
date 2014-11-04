//
//  DownloadFile.m
//  S3TransferManagerSample
//
//  Created by Michael Green on 10/31/14.
//  Copyright (c) 2014 Amazon Web Services. All rights reserved.
//

#import "DownloadFile.h"

@implementation DownloadFile

- (instancetype) init:(NSString *)filename
{
    self = [super init];
    
    if (self)
    {
        self.fileName = filename;
        self.downloadComplete = false;
    }
    return self;
}
@end
