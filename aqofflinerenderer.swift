//
//  aqofflinerenderer.swift
//  AQOfflineRenderTest
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/10/18.
//
//
/*
    File: aqofflinerender.cpp
Abstract: Demonstrates the use of AudioQueueOfflineRender
 Version: 1.0

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
Inc. ("Apple") in consideration of your agreement to the following
terms, and your use, installation, modification or redistribution of
this Apple software constitutes acceptance of these terms.  If you do
not agree with these terms, please do not use, install, modify or
redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software.
Neither the name, trademarks, service marks or logos of Apple Inc. may
be used to endorse or promote products derived from the Apple Software
without specific prior written permission from Apple.  Except as
expressly stated in this notice, no other rights or licenses, express or
implied, are granted by Apple herein, including but not limited to any
patent rights that may be infringed by your derivative works or by other
works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright (C) 2009 Apple Inc. All Rights Reserved.

*/

// standard includes
import UIKit
import AudioToolbox.AudioQueue
import AudioToolbox.AudioFile
import AudioToolbox.ExtendedAudioFile

// helpers

// the application specific info we keep track of
struct AQTestInfo {
    var mAudioFile: AudioFileID? = nil
    var mDataFormat: CAStreamBasicDescription = CAStreamBasicDescription()
    var mQueue: AudioQueueRef? = nil
    var mBuffer: AudioQueueBufferRef? = nil
    var mCurrentPacket: Int64 = 0
    var mNumPacketsToRead: UInt32 = 0
    var mPacketDescs: UnsafeMutablePointer<AudioStreamPacketDescription>? = nil
    var mFlushed: Bool = false
    var mDone: Bool = false
    var mBufferByteSize: UInt32 = 0 //###
}

//MARK:- Helper Functions
// ***********************
// CalculateBytesForTime Utility Function

// we only use time here as a guideline
// we are really trying to get somewhere between 16K and 64K buffers, but not allocate too much if we don't need it
private func CalculateBytesForTime(_ inDesc: CAStreamBasicDescription, _ inMaxPacketSize: UInt32, _ inSeconds: Double, _ outBufferSize: inout UInt32, _ outNumPackets: inout UInt32) {
    let maxBufferSize: UInt32 = 0x10000;   // limit size to 64K
    let minBufferSize: UInt32 = 0x4000;    // limit size to 16K
    
    if inDesc.mFramesPerPacket != 0 {
        let numPacketsForTime = inDesc.mSampleRate / Double(inDesc.mFramesPerPacket) * inSeconds
        outBufferSize = UInt32(numPacketsForTime * Double(inMaxPacketSize))
    } else {
        // if frames per packet is zero, then the codec has no predictable packet == time
        // so we can't tailor this (we don't know how many Packets represent a time period
        // we'll just return a default buffer size
        outBufferSize = maxBufferSize > inMaxPacketSize ? maxBufferSize : inMaxPacketSize
    }
    
    // we're going to limit our size to our default
    if outBufferSize > maxBufferSize && outBufferSize > inMaxPacketSize {
        outBufferSize = maxBufferSize
    } else {
        // also make sure we're not too small - we don't want to go the disk for too small chunks
        if outBufferSize < minBufferSize {
            outBufferSize = minBufferSize
        }
    }
    
    outNumPackets = outBufferSize / inMaxPacketSize
}

//MARK:- AQOutputCallback
// ***********************
// AudioQueueOutputCallback function used to push data into the audio queue

private let AQTestBufferCallback: AudioQueueOutputCallback = {(inUserData, inAQ, inCompleteAQBuffer)->Void in
//private let AQTestBufferCallback: AudioQueueOutputCallback = {(_ inUserData: UnsafeMutablePointer<Void>, _ inAQ: AudioQueueRef, _ inCompleteAQBuffer: AudioQueueBufferRef)->Void in
    guard let myInfo = inUserData?.assumingMemoryBound(to: AQTestInfo.self) else {return}
    if myInfo.pointee.mDone {return}
    var numBytes: UInt32 = myInfo.pointee.mBufferByteSize //###
    //print("numBytes=",numBytes)
    var nPackets: UInt32 = myInfo.pointee.mNumPacketsToRead
    var result = AudioFileReadPacketData(myInfo.pointee.mAudioFile!,      // The audio file from which packets of audio data are to be read.
        false,                   // Set to true to cache the data. Otherwise, set to false.
        &numBytes,               // On output, a pointer to the number of bytes actually returned.
        myInfo.pointee.mPacketDescs,    // A pointer to an array of packet descriptions that have been allocated.
        myInfo.pointee.mCurrentPacket,  // The packet index of the first packet you want to be returned.
        &nPackets,               // On input, a pointer to the number of packets to read. On output, the number of packets actually read.
        inCompleteAQBuffer.pointee.mAudioData); // A pointer to user-allocated memory.
    if result != noErr {
        DebugMessageN1("Error reading from file: %d\n", Int32(result))
        exit(1)
    }
    
    // we have some data
    if nPackets > 0 {
        inCompleteAQBuffer.pointee.mAudioDataByteSize = numBytes
        
        result = AudioQueueEnqueueBuffer(inAQ,                                  // The audio queue that owns the audio queue buffer.
            inCompleteAQBuffer,                    // The audio queue buffer to add to the buffer queue.
            (myInfo.pointee.mPacketDescs != nil ? nPackets : 0), // The number of packets of audio data in the inBuffer parameter. See Docs.
            myInfo.pointee.mPacketDescs);                 // An array of packet descriptions. Or NULL. See Docs.
        if result != noErr {
            DebugMessageN1("Error enqueuing buffer: %d\n", Int32(result))
            exit(1)
        }
        
        myInfo.pointee.mCurrentPacket += Int64(nPackets)
        
    } else {
        // **** This ensures that we flush the queue when done -- ensures you get all the data out ****
        
        if !myInfo.pointee.mFlushed {
            result = AudioQueueFlush(myInfo.pointee.mQueue!)
            
            if result != noErr {
                DebugMessageN1("AudioQueueFlush failed: %d", Int32(result))
                exit(1)
            }
            
            myInfo.pointee.mFlushed = true
        }
        
        result = AudioQueueStop(myInfo.pointee.mQueue!, false)
        if result != noErr {
            DebugMessageN1("AudioQueueStop(false) failed: %d", Int32(result))
            exit(1)
        }
        
        // reading nPackets == 0 is our EOF condition
        myInfo.pointee.mDone = true
    }
}

// ***********************
//MARK:- Main Render Function

func DoAQOfflineRender(_ sourceURL: URL, _ destinationURL: URL) {
    // main audio queue code
    do {
        var myInfoPtr: UnsafeMutablePointer<AQTestInfo>? = nil
        var myInfo: AQTestInfo {
            get {
                if myInfoPtr == nil {
                    myInfoPtr = .allocate(capacity: 1)
                    myInfoPtr!.initialize(to: AQTestInfo())
                }
                return myInfoPtr!.pointee
            }
            set {
                if let myInfoPtr = myInfoPtr {
                    myInfoPtr.pointee = newValue
                } else {
                    myInfoPtr = .allocate(capacity: 1)
                    myInfoPtr!.initialize(to: newValue)
                }
            }
        }
        myInfo = AQTestInfo()
        defer {
            myInfoPtr?.pointee.mPacketDescs?.deallocate()
            myInfoPtr?.deinitialize(count: 1)
            myInfoPtr?.deallocate()
        }
        
        myInfo.mDone = false
        myInfo.mFlushed = false
        myInfo.mCurrentPacket = 0
        
        // get the source file
        let fsRdPerm = AudioFilePermissions(rawValue: 0x01)!
        var audioFile: AudioFileID? = nil
        try XThrowIfError(AudioFileOpenURL(sourceURL as CFURL, fsRdPerm, 0/*inFileTypeHint*/, &audioFile), "AudioFileOpen failed")
        myInfo.mAudioFile = audioFile
        
        var size = UInt32(MemoryLayout<CAStreamBasicDescription>.size)
        var dataFormat: CAStreamBasicDescription = CAStreamBasicDescription()
        try XThrowIfError(AudioFileGetProperty(myInfo.mAudioFile!, kAudioFilePropertyDataFormat, &size, &dataFormat), "couldn't get file's data format")
        myInfo.mDataFormat = dataFormat

        print("File format: \(myInfo.mDataFormat)")
        
        // create a new audio queue output
        var queue: AudioQueueRef? = nil
        try XThrowIfError(AudioQueueNewOutput(&dataFormat,      // The data format of the audio to play. For linear PCM, only interleaved formats are supported.
            AQTestBufferCallback,     // A callback function to use with the playback audio queue.
            myInfoPtr,                  // A custom data structure for use with the callback function.
            CFRunLoopGetCurrent(),    // The event loop on which the callback function pointed to by the inCallbackProc parameter is to be called.
            // If you specify NULL, the callback is invoked on one of the audio queue’s internal threads.
            CFRunLoopMode.commonModes.rawValue,    // The run loop mode in which to invoke the callback function specified in the inCallbackProc parameter.
            0,                        // Reserved for future use. Must be 0.
            &queue),          // On output, the newly created playback audio queue object.
            "AudioQueueNew failed")
        myInfo.mQueue = queue
        
        var bufferByteSize: UInt32 = 0
        
        // we need to calculate how many packets we read at a time and how big a buffer we need
        // we base this on the size of the packets in the file and an approximate duration for each buffer
        do {
            let isFormatVBR = (myInfo.mDataFormat.mBytesPerPacket == 0 || myInfo.mDataFormat.mFramesPerPacket == 0)
            
            // first check to see what the max size of a packet is - if it is bigger
            // than our allocation default size, that needs to become larger
            var maxPacketSize: UInt32 = 0
            size = UInt32(MemoryLayout<UInt32>.size)
            try XThrowIfError(AudioFileGetProperty(myInfo.mAudioFile!, kAudioFilePropertyPacketSizeUpperBound, &size, &maxPacketSize), "couldn't get file's max packet size")
            
            // adjust buffer size to represent about a second of audio based on this format
            var numPacketsToRead: UInt32 = 0
            CalculateBytesForTime(myInfo.mDataFormat, maxPacketSize, 1.0/*seconds*/, &bufferByteSize, &numPacketsToRead)
            myInfo.mNumPacketsToRead = numPacketsToRead
            
            if isFormatVBR {
                myInfo.mPacketDescs = UnsafeMutablePointer.allocate(capacity: Int(myInfo.mNumPacketsToRead))
            } else {
                myInfo.mPacketDescs = nil // we don't provide packet descriptions for constant bit rate formats (like linear PCM)
            }
            myInfo.mBufferByteSize = bufferByteSize //###
            
            print("Buffer Byte Size: \(bufferByteSize), Num Packets to Read: \(myInfo.mNumPacketsToRead)")
        }
        
        // if the file has a magic cookie, we should get it and set it on the AQ
        size = UInt32(MemoryLayout<UInt32>.size)
        let result = AudioFileGetPropertyInfo(myInfo.mAudioFile!, kAudioFilePropertyMagicCookieData, &size, nil)
        
        if result == 0 && size != 0 {
            let cookie = UnsafeMutablePointer<CChar>.allocate(capacity: Int(size))
            try XThrowIfError(AudioFileGetProperty(myInfo.mAudioFile!, kAudioFilePropertyMagicCookieData, &size, cookie), "get cookie from file")
            try XThrowIfError(AudioQueueSetProperty(myInfo.mQueue!, kAudioQueueProperty_MagicCookie, cookie, size), "set cookie on queue")
            cookie.deallocate()
        }
        
        // channel layout?
        let err = AudioFileGetPropertyInfo(myInfo.mAudioFile!, kAudioFilePropertyChannelLayout, &size, nil)
        var rawAcl: UnsafeMutableRawPointer? = nil
        var acl: UnsafeMutablePointer<AudioChannelLayout>? = nil
        var aclSize = 0
        if err == noErr && size > 0 {
            aclSize = Int(size)
            rawAcl = UnsafeMutableRawPointer.allocate(byteCount: aclSize, alignment: MemoryLayout<AudioChannelLayout>.alignment)
            acl = rawAcl?.bindMemory(to: AudioChannelLayout.self, capacity: 1)
            try XThrowIfError(AudioFileGetProperty(myInfo.mAudioFile!, kAudioFilePropertyChannelLayout, &size, acl!), "get audio file's channel layout")
            try XThrowIfError(AudioQueueSetProperty(myInfo.mQueue!, kAudioQueueProperty_ChannelLayout, acl!, size), "set channel layout on queue")
        }
        
        //allocate the input read buffer
        var buffer: AudioQueueBufferRef? = nil
        try XThrowIfError(AudioQueueAllocateBuffer(myInfo.mQueue!, bufferByteSize, &buffer), "AudioQueueAllocateBuffer")
        myInfo.mBuffer = buffer
        
        // prepare a canonical interleaved capture format
        var captureFormat: CAStreamBasicDescription = CAStreamBasicDescription()
        captureFormat.mSampleRate = myInfo.mDataFormat.mSampleRate
        captureFormat.setAUCanonical(myInfo.mDataFormat.mChannelsPerFrame, interleaved: true) // interleaved
        try XThrowIfError(AudioQueueSetOfflineRenderFormat(myInfo.mQueue!, &captureFormat, acl), "set offline render format")
        
        var captureFile: ExtAudioFileRef? = nil
        
        // prepare a 16-bit int file format, sample channel count and sample rate
        var dstFormat = CAStreamBasicDescription()
        dstFormat.mSampleRate = myInfo.mDataFormat.mSampleRate
        dstFormat.mChannelsPerFrame = myInfo.mDataFormat.mChannelsPerFrame
        dstFormat.mFormatID = kAudioFormatLinearPCM
        dstFormat.mFormatFlags = kLinearPCMFormatFlagIsPacked | kLinearPCMFormatFlagIsSignedInteger; // little-endian
        dstFormat.mBitsPerChannel = 16
        dstFormat.mBytesPerFrame = 2 * dstFormat.mChannelsPerFrame
        dstFormat.mBytesPerPacket = dstFormat.mBytesPerFrame
        dstFormat.mFramesPerPacket = 1
        
        // create the capture file
        try XThrowIfError(ExtAudioFileCreateWithURL(destinationURL as CFURL, kAudioFileCAFType, &dstFormat, acl, AudioFileFlags.eraseFile.rawValue, &captureFile), "ExtAudioFileCreateWithURL")
        
        // set the capture file's client format to be the canonical format from the queue
        try XThrowIfError(ExtAudioFileSetProperty(captureFile!, kExtAudioFileProperty_ClientDataFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.stride), &captureFormat), "set ExtAudioFile client format")
        
        // allocate the capture buffer, just keep it at half the size of the enqueue buffer
        // we don't ever want to pull any faster than we can push data in for render
        // this 2:1 ratio keeps the AQ Offline Render happy
        let captureBufferByteSize = bufferByteSize / 2
        
        var captureBuffer: AudioQueueBufferRef? = nil
        var captureABL: AudioBufferList = AudioBufferList()
        
        try XThrowIfError(AudioQueueAllocateBuffer(myInfo.mQueue!, captureBufferByteSize, &captureBuffer), "AudioQueueAllocateBuffer")
        
        captureABL.mNumberBuffers = 1 //### for statically allocated AudioBufferList, this needs to be 1.
        captureABL.mBuffers.mData = captureBuffer?.pointee.mAudioData
        captureABL.mBuffers.mNumberChannels = captureFormat.mChannelsPerFrame
        
        // lets start playing now - stop is called in the AQTestBufferCallback when there's
        // no more to read from the file
        try XThrowIfError(AudioQueueStart(myInfo.mQueue!, nil), "AudioQueueStart failed")
        
        var ts = AudioTimeStamp()
        ts.mFlags = .sampleTimeValid
        ts.mSampleTime = 0
        
        // we need to call this once asking for 0 frames
        try XThrowIfError(AudioQueueOfflineRender(myInfo.mQueue!, &ts, captureBuffer!, 0), "AudioQueueOfflineRender")
        
        // we need to enqueue a buffer after the queue has started
        AQTestBufferCallback(myInfoPtr, myInfo.mQueue!, myInfo.mBuffer!)
        
        while true {
            let reqFrames = captureBufferByteSize / captureFormat.mBytesPerFrame
            
            try XThrowIfError(AudioQueueOfflineRender(myInfo.mQueue!, &ts, captureBuffer!, reqFrames), "AudioQueueOfflineRender")
            
            captureABL.mBuffers.mData = captureBuffer?.pointee.mAudioData
            captureABL.mBuffers.mDataByteSize = (captureBuffer?.pointee.mAudioDataByteSize)!
            let writeFrames = captureABL.mBuffers.mDataByteSize / captureFormat.mBytesPerFrame
            
            print("t = \(ts.mSampleTime): AudioQueueOfflineRender:  req \(reqFrames) fr/\(captureBufferByteSize) bytes, got \(writeFrames) fr/\(captureABL.mBuffers.mDataByteSize) bytes")
            
            try XThrowIfError(ExtAudioFileWrite(captureFile!, writeFrames, &captureABL), "ExtAudioFileWrite")
            
            if myInfo.mFlushed {break}
            
            ts.mSampleTime += Double(writeFrames)
        }
        
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 1, false)
        
        try XThrowIfError(AudioQueueDispose(myInfo.mQueue!, true), "AudioQueueDispose(true) failed")
        try XThrowIfError(AudioFileClose(myInfo.mAudioFile!), "AudioQueueDispose(false) failed")
        try XThrowIfError(ExtAudioFileDispose(captureFile!), "ExtAudioFileDispose failed")
        
        if let rawAcl = rawAcl {rawAcl.deallocate()}
    } catch let e as CAXException {
        fputs("Error: \(e.mOperation) \(e.formatError())", stderr)
    } catch _ {
        fatalError("Unknown error")
    }
    
}
