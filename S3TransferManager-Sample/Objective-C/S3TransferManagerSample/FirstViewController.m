/*
 * Copyright 2010-2014 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

#import "FirstViewController.h"
#import "S3.h"
#import "Constants.h"

// Enum used to set UI state
typedef enum UIState
{
    Paused, Cancelled, Ready, Uploading, Completed, Failed
} UIState;

@interface FirstViewController ()

// URLs for test files
@property (nonatomic, strong) NSURL *testFileURL1;
@property (nonatomic, strong) NSURL *testFileURL2;
@property (nonatomic, strong) NSURL *testFileURL3;

// Labels to display downloaded file names
@property (weak, nonatomic) IBOutlet UILabel *file1Label;
@property (weak, nonatomic) IBOutlet UILabel *file2Label;
@property (weak, nonatomic) IBOutlet UILabel *file3Label;

// Upload Requests for test files
@property (nonatomic, strong) AWSS3TransferManagerUploadRequest *uploadRequest1;
@property (nonatomic, strong) AWSS3TransferManagerUploadRequest *uploadRequest2;
@property (nonatomic, strong) AWSS3TransferManagerUploadRequest *uploadRequest3;

// Data used to calculate progress bar display
@property (nonatomic) uint64_t file1Size;
@property (nonatomic) uint64_t file2Size;
@property (nonatomic) uint64_t file3Size;
@property (nonatomic) uint64_t file1AlreadyUpload;
@property (nonatomic) uint64_t file2AlreadyUpload;
@property (nonatomic) uint64_t file3AlreadyUpload;

@property (nonatomic, strong) NSMutableDictionary *downloadedBytes;

@end

@implementation FirstViewController

// Set button state based on UIState enum
- (void) updateUIForState:(enum UIState )state
{
    switch (state)
    {
        case Paused:
            self.uploadStatusLabel.text = StatusLabelReady;
            self.uploadButton.enabled = false;
            self.pauseButton.enabled = false;
            self.resumeButton.enabled = true;
            self.cancelButton.enabled = true;
            break;
            
        case Cancelled:
            self.uploadStatusLabel.text = StatusLabelReady;
            self.uploadButton.enabled = true;
            self.cancelButton.enabled = false;
            self.pauseButton.enabled = false;
            self.resumeButton.enabled = false;
            break;
            
        case Ready:
            self.uploadStatusLabel.text = StatusLabelReady;
            self.uploadButton.enabled = true;
            self.cancelButton.enabled = false;
            self.pauseButton.enabled = false;
            self.resumeButton.enabled = false;
            self.file1Label.text = S3KeyUploadName1;
            self.file2Label.text = S3KeyUploadName2;
            self.file3Label.text = S3KeyUploadName3;
            break;
            
        case Uploading:
            self.uploadStatusLabel.text = StatusLabelUploading;
            
            self.file1Label.text = S3KeyUploadName1;
            self.file2Label.text = S3KeyUploadName2;
            self.file3Label.text = S3KeyUploadName3;
            self.uploadButton.enabled = false;
            self.cancelButton.enabled = true;
            self.pauseButton.enabled = true;
            self.resumeButton.enabled = false;
            break;
            
        case Completed:
            self.uploadStatusLabel.text = StatusLabelCompleted;
            self.uploadButton.enabled = true;
            self.cancelButton.enabled = false;
            self.pauseButton.enabled = false;
            self.resumeButton.enabled = false;
            break;
            
        case Failed:
            self.uploadStatusLabel.text = StatusLabelFailed;
            self.uploadButton.enabled = false;
            self.pauseButton.enabled = false;
            self.resumeButton.enabled = false;
            self.cancelButton.enabled = false;
            break;
    }
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self cleanProgress];
    
    self.downloadedBytes = [NSMutableDictionary new];
    
    // Create 3 text files to upload to S3
    BFTask *task = [BFTask taskWithResult:nil];
    [[task continueWithBlock:^id(BFTask *task) {
        
        // Creates a text file in the temporary directory
        self.testFileURL1 = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:S3KeyUploadName1]];
        
        // Create some text for the file
        NSMutableString *dataString = [NSMutableString new];
        for (int32_t i = 1; i < 2000000; i++) {
            [dataString appendFormat:@"%d\n", i];
        }
        
        // Write the text to the file
        NSError *error = nil;
        [dataString writeToURL:self.testFileURL1
                    atomically:YES
                      encoding:NSUTF8StringEncoding
                         error:&error];
        
        // Creates a text file in the temporary directory
        self.testFileURL2 = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:S3KeyUploadName2]];
        
        // Write the text to the file
        [dataString writeToURL:self.testFileURL2
                    atomically:YES
                      encoding:NSUTF8StringEncoding
                         error:&error];
        
        // Creates a text file in the temporary directory
        self.testFileURL3 = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:S3KeyUploadName3]];
        
        // Write the text to the file
        [dataString writeToURL:self.testFileURL3
                    atomically:YES
                      encoding:NSUTF8StringEncoding
                         error:&error];
        
        self.file1Size = self.file2Size = self.file3Size = [dataString length];
        
        return nil;
    }] continueWithExecutor:[BFExecutor mainThreadExecutor] withBlock:^id(BFTask *task) {
        [self updateUIForState:Ready];
        
        return nil;
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) submitUploadRequest:(AWSS3TransferManagerUploadRequest *)uploadRequest
{
    // Submit an asynchronous upload request
    AWSS3TransferManager *transferManager = [AWSS3TransferManager defaultS3TransferManager];
    static int completedCount = 0;
    
    [[transferManager upload:uploadRequest] continueWithExecutor:[BFExecutor mainThreadExecutor]
                                                        withBlock:^id(BFTask *task)
    {
        // An task.error will be non-nil when an upload is paused or cancelled. This is expected behavior, so update the UI
        if (task.error != nil)
        {
            if (task.error.code == AWSS3TransferManagerErrorCancelled)
            {
                NSLog(@"Upload cancelled for: %@", uploadRequest.key);
                [self updateUIForState:Ready];
            }
            else if (task.error.code == AWSS3TransferManagerErrorPaused)
            {
                NSLog(@"%s %@","Upload paused for :", uploadRequest.key);
                [self updateUIForState:Paused];
            }
            else /* an actual error occured */
            {
                NSLog(@"%s %@","Error uploading :", uploadRequest.key);
                [self updateUIForState:Failed];
            }
        }
        else
        {
            // The download operation completed without error
            completedCount++;
                                                                
            NSLog(@"Upload of %@ completed", uploadRequest.key);
            NSLog(@"completedCount = %d", completedCount);
                                                                
            // Only update the UI to completed when all three uploads complete
            if (completedCount == 3)
            {
                [self updateUIForState:Completed];
                completedCount = 0;
            }
        }
        return nil;
    }];
}

- (IBAction)uploadButtonPressed:(id)sender {

    __weak typeof(self) weakSelf = self;
    
    // Create the upload requests
    self.uploadRequest1 = [AWSS3TransferManagerUploadRequest new];
    self.uploadRequest1.bucket = S3BucketName;
    self.uploadRequest1.key = S3KeyUploadName1;
    self.uploadRequest1.body = self.testFileURL1;
    
    // Create a code block that S3 will call with progress updates
    self.uploadRequest1.uploadProgress =  ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend){
        dispatch_sync(dispatch_get_main_queue(), ^{
            weakSelf.file1AlreadyUpload = totalBytesSent;
            weakSelf.file1Size = totalBytesExpectedToSend;
            [weakSelf updateProgress];
        });
    };

    self.uploadRequest2 = [AWSS3TransferManagerUploadRequest new];
    self.uploadRequest2.bucket = S3BucketName;
    self.uploadRequest2.key = S3KeyUploadName2;
    self.uploadRequest2.body = self.testFileURL2;
    
    // Create a code block that S3 will call with progress updates
    self.uploadRequest2.uploadProgress =  ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend){
        dispatch_sync(dispatch_get_main_queue(), ^{
            weakSelf.file2AlreadyUpload = totalBytesSent;
            weakSelf.file2Size = totalBytesExpectedToSend;
            [weakSelf updateProgress];
        });
    };
  
    self.uploadRequest3 = [AWSS3TransferManagerUploadRequest new];
    self.uploadRequest3.bucket = S3BucketName;
    self.uploadRequest3.key = S3KeyUploadName3;
    self.uploadRequest3.body = self.testFileURL3;
    
    // Create a code block that S3 will call with progress updates
    self.uploadRequest3.uploadProgress =  ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend){
        dispatch_sync(dispatch_get_main_queue(), ^{
            weakSelf.file3AlreadyUpload = totalBytesSent;
            weakSelf.file3Size = totalBytesExpectedToSend;
            [weakSelf updateProgress];
        });
    };

    // Update the UI
    [self updateUIForState:Uploading];
    [self cleanProgress];
    
    // Upload files
    [self uploadFiles];
    
}

- (void) uploadFiles
{
    // Submit ansychronous calls to upload the files
    if (self.uploadRequest1.state == AWSS3TransferManagerRequestStateRunning || self.uploadRequest1.state == AWSS3TransferManagerRequestStatePaused)
        [self submitUploadRequest:self.uploadRequest1];
    
    if (self.uploadRequest2.state == AWSS3TransferManagerRequestStateRunning || self.uploadRequest2.state == AWSS3TransferManagerRequestStatePaused)
        [self submitUploadRequest:self.uploadRequest2];
    
    if (self.uploadRequest3.state == AWSS3TransferManagerRequestStateRunning || self.uploadRequest3.state == AWSS3TransferManagerRequestStatePaused)
        [self submitUploadRequest:self.uploadRequest3];
}

- (IBAction)cancelButtonPressed:(id)sender
{
    // Cancel the download requests and update the UI when all operations complete.
    NSMutableArray *tasksToCancel = [[NSMutableArray alloc] init];
    
    [tasksToCancel addObject:[self.uploadRequest1 cancel]];
    [tasksToCancel addObject:[self.uploadRequest2 cancel]];
    [tasksToCancel addObject:[self.uploadRequest3 cancel]];
    
    [[BFTask taskForCompletionOfAllTasks:tasksToCancel] continueWithExecutor:[BFExecutor mainThreadExecutor] withBlock:^id(BFTask *task) {
        [self updateUIForState:Cancelled];
        return task;
    }];
}

- (IBAction)pauseButtonPressed:(id)sender {

    // Pause the current upload operations and update the UI when all operations complete
    // NOTE: If the files you are uploading are < 5MB the upload will simply be cancelled. If the files you are uploading are > 5MB the S3 Transfer Manager will pause the upload operation
    NSMutableArray *tasksToPause = [[NSMutableArray alloc] init];
    
    [tasksToPause addObject:[self.uploadRequest1 pause]];
    [tasksToPause addObject:[self.uploadRequest2 pause]];
    [tasksToPause addObject:[self.uploadRequest3 pause]];
    
    [[BFTask taskForCompletionOfAllTasks:tasksToPause] continueWithExecutor:[BFExecutor mainThreadExecutor] withBlock:^id(BFTask *task) {
        [self updateUIForState:Paused];
        return task;
    }];
}

- (IBAction)resumeButtonPressed:(id)sender
{
    // The SDK will automatically handle restarting the upload if the file is > 5MB, otherwise the upload will start over
    [self uploadFiles];
    [self updateUIForState:Uploading];
}

- (void) updateProgress
{
    // Calculate length of progress bar
    if (self.file1AlreadyUpload <= self.file1Size)
    {
        self.progressView1.progress = (float)self.file1AlreadyUpload / (float)self.file1Size;
    }
    
    if (self.file2AlreadyUpload <= self.file2Size)
    {
        self.progressView2.progress = (float)self.file2AlreadyUpload / (float)self.file2Size;
    }
    
    if (self.file3AlreadyUpload <= self.file3Size)
    {
        self.progressView3.progress = (float)self.file3AlreadyUpload / (float)self.file3Size;
    }
}

- (void) cleanProgress
{
    // reset progress bars and values used to calculate progress bar completion.
    self.progressView1.progress = 0;
    self.progressView2.progress = 0;
    self.progressView3.progress = 0;
    
    self.file1Size = 0;
    self.file1AlreadyUpload = 0;
    self.file2Size = 0;
    self.file2AlreadyUpload = 0;
    self.file3Size = 0;
    self.file3AlreadyUpload = 0;
}


@end
