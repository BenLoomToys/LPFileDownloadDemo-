//
//  WHC_DownFileCenter.m
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

#import "WHC_DownloadFileCenter.h"
#define kWHC_FilePathCreateFailTxt  (@"WHC_DownloadFileCenter ：文件存储路径创建失败")
#define kWHC_FilePathErrorTxt       (@"WHC_DownloadFileCenter ：文件存储路径错误不能为空")
#define kWHC_DownloadObjectNilTxt   (@"下载对象为Nil")

@interface WHC_DownloadFileCenter (){
    NSOperationQueue      *     _WHCDownloadQueue;   //下载队列
    NSMutableArray        *     _allDownloadArr;     //所有下载
    NSMutableArray        *     _cancleDownloadArr;  //所取消的下载
    
    NSUInteger                  _maxDownloadCount;   //最大下载数
}

@end

@implementation WHC_DownloadFileCenter

static  WHC_DownloadFileCenter  * downloadFileCenter = nil;

+ (instancetype)sharedWHCDownloadFileCenter{
    
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        downloadFileCenter = [WHC_DownloadFileCenter new];
    });
    return downloadFileCenter;
}

- (instancetype)init{
    self = [super init];
    if(self){
        _WHCDownloadQueue = [[NSOperationQueue alloc]init];
        _WHCDownloadQueue.maxConcurrentOperationCount = kWHC_DefaultMaxDownloadCount;
        _maxDownloadCount = kWHC_DefaultMaxDownloadCount;
        _allDownloadArr = [NSMutableArray new];
        _cancleDownloadArr = [NSMutableArray new];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDownloadDidCompleteNotification:) name:kWHC_DownloadDidCompleteNotification object:nil];
    }
    return self;
}

- (void)handleDownloadDidCompleteNotification:(NSNotification *)notify{
    WHC_Download  * download = notify.object;
    if([_allDownloadArr containsObject:download]){
        BOOL isFinished = download.downloadComplete;
        if(!isFinished){
            [_cancleDownloadArr addObject:download];
        }
        [_allDownloadArr removeObject:download];
        if(isFinished){
            download = nil;
        }
    }
}

#pragma mark - publicMethod

/**
 参数说明：
 url:下载路径
 savePath:文件本地存储路径
 delegate:下载状态监控代理
 */
- (WHC_Download *)startDownloadWithURL:(NSURL *)url
                              savePath:(NSString *)savePath
                              delegate:(id<WHCDownloadDelegate>)delegate{
    
    return [self startDownloadWithURL:url savePath:savePath savefileName:nil delegate:delegate];
}

/**
 参数说明：
 url:下载路径
 savePath:文件本地存储路径
 savefileName:下载要存储的文件名
 delegate:下载状态监控代理
 */
- (WHC_Download *)startDownloadWithURL:(NSURL *)url
                              savePath:(NSString *)savePath
                          savefileName:(NSString*)savefileName
                              delegate:(id<WHCDownloadDelegate>)delegate{
    
    WHC_Download  * download = nil;
    if([self createFileSavePath:savePath]){
        download = [WHC_Download new];
        download.delegate = delegate;
        download.saveFileName = savefileName;
        download.saveFilePath = savePath;
        download.downUrl = url;
        [_WHCDownloadQueue addOperation:download];
        [_allDownloadArr addObject:download];
    }
    return download;
}

/**
 说明：
 在外部创建下载队列进行下载
 */
- (WHC_Download *)startDownloadWithWHCDownload:(WHC_Download *)download{
    if(download){
        [_WHCDownloadQueue addOperation:download];
        [_allDownloadArr addObject:download];
    }else{
        NSLog(kWHC_DownloadObjectNilTxt);
    }
    return download;
}

/**
 note:该方法必须在开始下载之前调用
 说明：
 设置最大下载数量
 */
- (void)setMaxDownloadCount:(NSUInteger)count{
    _maxDownloadCount = count;
    _WHCDownloadQueue.maxConcurrentOperationCount = _maxDownloadCount;
}

/**
 说明：
 取消所有等待的下载并是否取消删除文件
 */
- (void)cancelAllWaitDownloadTaskAndDelFile:(BOOL)isDel{
    for (WHC_Download * download in _WHCDownloadQueue.operations) {
        [download cancelDownloadTaskAndDelFile:isDel];
    }
}

/**
 说明：
 取消指定等待的下载url的下载
 */
- (void)cancelWaitDownloadWithDownUrl:(NSURL *)downUrl delFile:(BOOL)delFile{
    for(WHC_Download * download in _WHCDownloadQueue.operations){
        if([download.downUrl.absoluteString isEqualToString:downUrl.absoluteString]){
            [download cancelDownloadTaskAndDelFile:delFile];
            break;
        }
    }
}

/**
 说明：
 取消指定等待的下载文件名的下载
 */
- (void)cancelWaitDownloadWithFileName:(NSString *)fileName delFile:(BOOL)delFile{
    for(WHC_Download * download in _WHCDownloadQueue.operations){
        if([download.saveFileName isEqualToString:fileName]){
            [download cancelDownloadTaskAndDelFile:delFile];
            break;
        }
    }
}

/**
 说明：
 取消所有正下载并是否取消删除文件
 */
- (void)cancelAllDownloadTaskAndDelFile:(BOOL)isDel{
    for (WHC_Download * download in _allDownloadArr) {
        if(![_WHCDownloadQueue.operations containsObject:download]){
            [download cancelDownloadTaskAndDelFile:isDel];
        }
    }
}

/**
 说明：
 取消指定正下载url的下载
 */
- (void)cancelDownloadWithDownUrl:(NSURL *)downUrl delFile:(BOOL)delFile{
    for(WHC_Download * download in _allDownloadArr){
        if([download.downUrl.absoluteString isEqualToString:downUrl.absoluteString]){
            if(![_WHCDownloadQueue.operations containsObject:download]){
                [download cancelDownloadTaskAndDelFile:delFile];
            }
            break;
        }
    }
}

/**
 说明：
 取消指定正下载文件名的下载
 */
- (void)cancelDownloadWithFileName:(NSString *)fileName delFile:(BOOL)delFile{
    for(WHC_Download * download in _allDownloadArr){
        if([download.saveFileName isEqualToString:fileName]){
            if(![_WHCDownloadQueue.operations containsObject:download]){
                [download cancelDownloadTaskAndDelFile:delFile];
            }
            break;
        }
    }
}

/**
 说明：
 恢复指定暂停正下载文件名的下载并返回新下载
 */
- (WHC_Download *)recoverDownloadWithName:(NSString *)fileName{
    
    for (int i = 0; i < _cancleDownloadArr.count; i++) {
        WHC_Download * download = _cancleDownloadArr[i];
        if([download.saveFileName isEqualToString:fileName]){
            WHC_Download * nDownload = nil;
            NSString  * strSavePath = [download.saveFilePath stringByReplacingOccurrencesOfString:download.saveFileName withString:@""];
            nDownload = [self startDownloadWithURL:download.downUrl
                                          savePath:strSavePath
                                      savefileName:download.saveFileName
                                          delegate:download.delegate];
            [_cancleDownloadArr removeObject:download];
            download = nil;
            return nDownload;
        }
    }
    return nil;
}


/**
 说明：
 恢复指暂停下载url的下载并返回新下载
 */
- (WHC_Download *)recoverDownloadWithDownUrl:(NSURL *)downUrl{
    
    for (int i = 0; i < _cancleDownloadArr.count; i++) {
        WHC_Download * download = _cancleDownloadArr[i];
        if([download.downUrl.absoluteString isEqualToString:downUrl.absoluteString]){
            WHC_Download * nDownload = nil;
            NSString  * strSavePath = [download.saveFilePath stringByReplacingOccurrencesOfString:download.saveFileName withString:@""];
            nDownload = [self startDownloadWithURL:download.downUrl
                                          savePath:strSavePath
                                      savefileName:download.saveFileName
                                          delegate:download.delegate];
            [_cancleDownloadArr removeObject:download];
            download = nil;
            return nDownload;
        }
    }
    return nil;
}

/**
 说明：
 恢复指定暂停的下载并返回新下载
 */

- (WHC_Download *)recoverDownload:(WHC_Download *)download{
    
    if(download){
        for (int i = 0; i < _cancleDownloadArr.count; i++) {
            WHC_Download * tempDownload = _cancleDownloadArr[i];
            if([tempDownload isEqual:download]){
                WHC_Download * nDownload = nil;
                NSString  * strSavePath = [tempDownload.saveFilePath stringByReplacingOccurrencesOfString:tempDownload.saveFileName withString:@""];
                nDownload = [self startDownloadWithURL:tempDownload.downUrl
                                              savePath:strSavePath
                                          savefileName:tempDownload.saveFileName
                                              delegate:tempDownload.delegate];
                [_cancleDownloadArr removeObject:tempDownload];
                tempDownload = nil;
                return nDownload;
            }
        }
    }
    return nil;
}

/**
 说明：
 恢复所有暂停的下载并返回新下载集合
 */
- (NSArray *)recoverAllDownloadTask{
    NSMutableArray  * downloadArr = [NSMutableArray new];
    for (int i = 0; i < _cancleDownloadArr.count; i++) {
        WHC_Download * download = _cancleDownloadArr[i];
        WHC_Download * nDownload = nil;
        NSString  * strSavePath = [download.saveFilePath stringByReplacingOccurrencesOfString:download.saveFileName withString:@""];
        nDownload = [self startDownloadWithURL:download.downUrl
                                      savePath:strSavePath
                                  savefileName:download.saveFileName
                                      delegate:download.delegate];
        [_cancleDownloadArr removeObject:download];
        download = nil;
        [downloadArr addObject:nDownload];
    }
    return downloadArr;
}

#pragma mark - privateMothed

- (BOOL)createFileSavePath:(NSString *)savePath{
    BOOL  result = YES;
    if(savePath != nil && savePath.length > 0){
        NSFileManager  * fm = [NSFileManager defaultManager];
        if(![fm fileExistsAtPath:savePath]){
            __autoreleasing NSError *error = nil;
            [fm createDirectoryAtPath:savePath withIntermediateDirectories:YES attributes:nil error:&error];
            if(error){
                result = NO;
                NSLog(kWHC_FilePathCreateFailTxt);
            }
        }
    }else{
        result = NO;
        NSLog(kWHC_FilePathErrorTxt);
    }
    return result;
}
@end
