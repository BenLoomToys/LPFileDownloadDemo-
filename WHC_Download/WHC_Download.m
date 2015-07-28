//
//  WHC_Download.m
//  PhoneBookBag
//
//  Created by 吴海超 on 15/7/27.
//  Copyright (c) 2015年 吴海超. All rights reserved.
//

/*
 *  qq:712641411
 *  iOS大神qq群:460122071
 *  gitHub:https://github.com/netyouli
 *  csdn:http://blog.csdn.net/windwhc/article/category/3117381
 */

#import "WHC_Download.h"
#define kWHC_RequestTimeout                         (60)     //默认请求超时时间60s
#define kWHC_Domain                                 (@"WHC_Download")
#define kWHC_InvainUrl                              (@"无效的url%@")
#define kWHC_calculateFolderSpaceAvailableFailTxt   (@"计算文件夹存储空间失败")
#define kWHC_ErrorCode                              (@"错误码:%ld")
#define kWHC_FreeDiskSapceError                     (@"磁盘可用空间不足需要存储空间:%llu")
#define kWHC_RequestRange                           (@"bytes=%lld-")
#define kWHC_WriteSizeLen                           (1024 * 1024)
#define kWHC_DownloadSpeedDuring                    (1.5)
@interface WHC_Download (){
    NSURLConnection           *   _urlConnection;      //网络连接
    NSMutableData             *   _downloadData;       //文件数据存储
    unsigned long long            _localFileSizeLen;   //文件尺寸大小
    unsigned long long            _actualFileSizeLen;  //实际文件大小
    unsigned long long            _recvDataLen;        //接受数据长度
    unsigned long long            _orderTimeRecvLen;   //特定时间接受的长度
    NSFileHandle              *   _fileHandle;         //文件句柄
    NSTimer                   *   _timer;              //网速时钟
    NSString                  *   _downloadSpeed;      //下载速度
}
@end


@implementation WHC_Download

#pragma mark - OverrideProperty

- (NSString *)saveFileName{
    if(_saveFileName){
        return _saveFileName;
    }else{
        return [_downUrl lastPathComponent];
    }
}

- (NSString *)saveFilePath{
    return [_saveFilePath stringByAppendingString:self.saveFileName];
}

#pragma mark - OverrideMethod

- (void)start{
    NSMutableURLRequest  * urlRequest = [[NSMutableURLRequest alloc]initWithURL:_downUrl cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:kWHC_RequestTimeout];
    //检测该请求是否合法
    if(![NSURLConnection canHandleRequest:urlRequest]){
        [self handleDownloadError:nil];
    }else{
        __autoreleasing  NSError  * error = nil;
        NSFileManager  * fm = [NSFileManager defaultManager];
        if(![fm fileExistsAtPath:self.saveFilePath]){
            [fm createFileAtPath:self.saveFilePath contents:nil attributes:nil];
        }
        _localFileSizeLen = [[fm attributesOfItemAtPath:self.saveFilePath error:&error] fileSize];
        if(error == nil){
            NSString  * strRange = [NSString stringWithFormat:kWHC_RequestRange ,_localFileSizeLen];
            [urlRequest setValue:strRange forHTTPHeaderField:@"Range"];
            _fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.saveFilePath];
            [_fileHandle seekToEndOfFile];
            _downloadData = [NSMutableData new];
            if(_urlConnection == nil){
                _urlConnection = [[NSURLConnection alloc]initWithRequest:urlRequest delegate:self startImmediately:NO];
            }
            [_urlConnection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
            [self willChangeValueForKey:@"isExecuting"];
            [_urlConnection start];
            [self didChangeValueForKey:@"isExecuting"];
        }else{
            NSLog(kWHC_calculateFolderSpaceAvailableFailTxt);
        }
    }
}

- (BOOL)isFinished{
    return _urlConnection != nil;
}

- (BOOL)isCancelled{
    return _urlConnection != nil;
}

#pragma mark - privateMethod

- (void)handleDownloadError:(NSError *)error{
    if(error == nil){
        error = [[NSError alloc]initWithDomain:kWHC_Domain
                                          code:GeneralErrorInfo
                                      userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:kWHC_InvainUrl,_downUrl.path]}];
    }
    if(_delegate && [_delegate respondsToSelector:@selector(WHCDownload:error:)]){
        [_delegate WHCDownload:self error:error];
    }
}

- (void)cancelledDownloadNotify{
    if(_timer){
        [_timer invalidate];
        [_timer fire];
        _timer = nil;
    }
    [[NSNotificationCenter defaultCenter]postNotificationName:kWHC_DownloadDidCompleteNotification object:self];
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isCancelled"];
    [_urlConnection cancel];
    [_fileHandle closeFile];
    _fileHandle = nil;
    _urlConnection = nil;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    [self didChangeValueForKey:@"isCancelled"];
}

- (unsigned long long)calculateFreeDiskSpace{
    unsigned long long  freeDiskLen = 0;
    NSString * docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSFileManager  * fm   = [NSFileManager defaultManager];
    NSDictionary   * dict = [fm attributesOfFileSystemForPath:docPath error:nil];
    if(dict){
        freeDiskLen = [dict[NSFileSystemFreeSize] unsignedLongLongValue];
    }
    return freeDiskLen;
}

- (void)calculateDownloadSpeed{
    float downloadSpeed = (float)_orderTimeRecvLen / (kWHC_DownloadSpeedDuring * 1024.0);
    _downloadSpeed = [NSString stringWithFormat:@"%.1fKB/s", downloadSpeed];
    if(downloadSpeed >= 1024.0){
        downloadSpeed = ((float)_orderTimeRecvLen / 1024.0) / (kWHC_DownloadSpeedDuring * 1024.0);
        _downloadSpeed = [NSString stringWithFormat:@"%.1fMB/s",downloadSpeed];
    }
    _orderTimeRecvLen = 0;
}

#pragma mark - publicMothed

//添加依赖下载队列
- (void)addDependOnDownload:(WHC_Download *)download{
    [self addDependency:download];
}

//取消下载是否删除已下载的文件
- (void)cancelDownloadTaskAndDelFile:(BOOL)isDel{
    _downloadComplete = isDel;
    [self cancelledDownloadNotify];
    if(isDel){
        NSFileManager  * fm = [NSFileManager defaultManager];
        if([fm fileExistsAtPath:self.saveFilePath]){
            __autoreleasing  NSError  * error = nil;
            [fm removeItemAtPath:self.saveFilePath error:&error];
            if(error){
                [self handleDownloadError:error];
            }else{
                if(_delegate && [_delegate respondsToSelector:@selector(WHCDownload:filePath:isSuccess:)]){
                    [_delegate WHCDownload:self filePath:_downUrl.absoluteString  isSuccess:NO];
                }
            }
        }
    }
}



#pragma mark - NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
    [self cancelledDownloadNotify];
    [self handleDownloadError:error];
}

- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse *)response{
    _actualFileSizeLen = response.expectedContentLength + _localFileSizeLen;
    NSHTTPURLResponse  *  headerResponse = (NSHTTPURLResponse *)response;
    BOOL  isCancel = YES;
    if(headerResponse.statusCode >= 400){
        __autoreleasing NSError  * error = [[NSError alloc]initWithDomain:kWHC_Domain code:NetWorkErrorInfo userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:kWHC_ErrorCode,(long)headerResponse.statusCode]}];
        [self handleDownloadError:error];
    }else{
        if([self calculateFreeDiskSpace] < _actualFileSizeLen){
           __autoreleasing NSError  * error = [[NSError alloc]initWithDomain:kWHC_Domain code:FreeDiskSpaceLack userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:kWHC_FreeDiskSapceError,_actualFileSizeLen]}];
            [self handleDownloadError:error];
        }else{
            _recvDataLen = _localFileSizeLen;
            _orderTimeRecvLen = 0;
            _timer = [NSTimer scheduledTimerWithTimeInterval:kWHC_DownloadSpeedDuring target:self selector:@selector(calculateDownloadSpeed) userInfo:nil repeats:YES];
            isCancel = NO;
            [_downloadData setData:nil];
            if(_delegate && [_delegate respondsToSelector:@selector(WHCDownload:didReceiveResponse:)]){
                [_delegate WHCDownload:self didReceiveResponse:response];
            }
            [self calculateDownloadSpeed];
        }
    }
    if(isCancel){
        [self cancelDownloadTaskAndDelFile:NO];
    }
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData *)data{
    
    [_downloadData appendData:data];
    _recvDataLen += data.length;
    _orderTimeRecvLen += data.length;
    if(_downloadData.length > kWHC_WriteSizeLen && _fileHandle){
        [_fileHandle writeData:_downloadData];
        [_downloadData setData:nil];
    }
    if(_delegate && [_delegate respondsToSelector:@selector(WHCDownload:didReceivedLen:totalLen:networkSpeed:)]){
        [_delegate WHCDownload:self didReceivedLen:_recvDataLen totalLen:_actualFileSizeLen networkSpeed:_downloadSpeed];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection*)connection{
    if(_fileHandle){
        [_fileHandle writeData:_downloadData];
        [_downloadData setData:nil];
    }
    _downloadComplete = YES;
    if(_delegate && [_delegate respondsToSelector:@selector(WHCDownload:filePath:isSuccess:)]){
        [_delegate WHCDownload:self filePath:self.saveFilePath  isSuccess:YES];
    }
    [self cancelledDownloadNotify];
}
@end
