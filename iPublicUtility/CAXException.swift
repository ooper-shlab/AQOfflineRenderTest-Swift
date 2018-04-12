//
//  CAXException.swift
//  AQOfflineRenderTest
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/10/18.
//
//
/*
     File: CAXException.h
     File: CAXException.cpp
 Abstract:
  Version: 1.2

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

 Copyright (C) 2010 Apple Inc. All Rights Reserved.

*/

import Foundation


class CAX4CCString {
    init(error: OSStatus) {
        // see if it appears to be a 4-char-code
        var str: [UInt8] = Array(repeating: 0, count: 16)
        str[1] = UInt8((error >> 24) & 0xFF)
        str[2] = UInt8((error >> 16) & 0xFF)
        str[3] = UInt8((error >> 8) & 0xFF)
        str[4] = UInt8(error & 0xFF)
        if isprint(Int32(str[1])) != 0 && isprint(Int32(str[2])) != 0 && isprint(Int32(str[3])) != 0 && isprint(Int32(str[4])) != 0 {
            str[0] = UInt8(ascii: "\'")
            str[5] = UInt8(ascii: "\'")
            str[6] = 0
            mStr = String(cString: str)
        } else if error > -200000 && error < 200000 {
            // no, format it as an integer
            mStr = String(Int32(error))
        } else {
            mStr = "0x" + String(UInt32(bitPattern: error), radix: 16)
        }
    }
    func get() -> String {
        return mStr
    }
    private(set) var mStr: String
}

// An extended exception class that includes the name of the failed operation
class CAXException: OOPException {
    init(operation: String?, err: OSStatus) {
        mError = err
        if operation == nil {
            mOperation = ""
        } else {
            
            mOperation = operation!
        }
    }
    
    func formatError() -> String {
        return type(of: self).formatError(mError)
    }
    
    var mOperation: String
    private(set) var mError: OSStatus
    
    // -------------------------------------------------
    
    typealias WarningHandler = (String, OSStatus) -> Void
    
    
    class func formatError(_ error: OSStatus) -> String {
        return CAX4CCString(error: error).get()
    }
    
    class func warning(_ s: String, error: OSStatus) {
        sWarningHandler?(s, error)
    }
    
    class func setWarningHandler(_ f: @escaping WarningHandler) { sWarningHandler = f }
    private static var sWarningHandler: WarningHandler? = nil
    
    override var description: String {
        return "Error \(formatError()) in operation: \(mOperation)"
    }
}

func XThrowIfError(_ error: NSError?, _ operation: String) throws {
    if error != nil && error!.code != 0 {
        throw CAXException(operation: operation, err: OSStatus(error!.code))
    }
}
func XFailIfError(_ error: NSError?, _ operation: String) {
    if error != nil && error!.code != 0 {
        XFailIfError(OSStatus(error!.code), operation)
    }
}
func XThrowIfError(_ error: OSStatus, _ operation: String) throws {
    if error != 0 {
        throw CAXException(operation: operation, err: error)
    }
}
func XFailIfError(_ error: OSStatus, _ operation: String) {
    if error != 0 {
        fatalError(CAXException(operation: operation, err: error).description)
    }
}
