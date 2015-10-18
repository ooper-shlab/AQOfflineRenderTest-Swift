//
//  MyViewController.swift
//  AQOfflineRenderTest
//
//  Created by 開発 on 2015/10/18.
//
//
/*
     File: MyViewController.h
     File: MyViewController.m
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

import UIKit
import AVFoundation

@objc(MyViewController)
class MyViewController: UIViewController, UINavigationBarDelegate, AVAudioPlayerDelegate {
    @IBOutlet private(set) var instructionsView: UIView!
    @IBOutlet private(set) var webView: UIWebView!
    @IBOutlet private(set) var contentView: UIView!
    
    @IBOutlet private(set) var startButton: UIButton!
    @IBOutlet private(set) var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet private(set) var flipButton: UIBarButtonItem!
    @IBOutlet private(set) var doneButton: UIBarButtonItem!
    
    private var sourceURL: NSURL?
    private var destinationURL: NSURL?
    
    let kTransitionDuration = 0.75
    
    let offlineRenderingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    
    override func viewDidLoad() {
        // create the URLs we'll use for source and destination
        sourceURL = NSBundle.mainBundle().URLForResource("soundalac", withExtension: "caf")
        
        let urls = NSFileManager.defaultManager().URLsForDirectory(NSSearchPathDirectory.DocumentDirectory, inDomains: NSSearchPathDomainMask.UserDomainMask)
        let documentsDirectory = urls[0]
        destinationURL = documentsDirectory.URLByAppendingPathComponent("output.caf")
        
        // load up the info text
        let infoSouceFile = NSBundle.mainBundle().URLForResource("info", withExtension: "html")!
        let infoText = try! String(contentsOfURL: infoSouceFile, encoding: NSUTF8StringEncoding)
        self.webView.loadHTMLString(infoText, baseURL: nil)
        
        // set up start button
        let greenImage = UIImage(named: "green_button.png")!.stretchableImageWithLeftCapWidth(12, topCapHeight: 0)
        let redImage = UIImage(named: "red_button.png")!.stretchableImageWithLeftCapWidth(12, topCapHeight: 0)
        
        startButton.setBackgroundImage(greenImage, forState: .Normal)
        startButton.setBackgroundImage(redImage, forState: .Disabled)
        startButton.enabled = true
        
        // add the subview
        self.view.addSubview(contentView)
        
        // add our custom flip buttons as the nav bars custom right view
        let infoButton = UIButton(type: .InfoLight)
        infoButton.addTarget(self, action: "flipAction:", forControlEvents: .TouchUpInside)
        
        flipButton = UIBarButtonItem(customView: infoButton)
        self.navigationItem.rightBarButtonItem = flipButton
        
        // create our done button as the nav bar's custom right view for the flipped view (used later)
        doneButton = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: "flipAction:")
    }
    
    override func didReceiveMemoryWarning() {
        // Invoke super's implementation to do the Right Thing, but also release the input controller since we can do that
        // In practice this is unlikely to be used in this application, and it would be of little benefit,
        // but the principle is the important thing.
        //
        super.didReceiveMemoryWarning()
    }
    
    //MARK:- Actions
    
    func flipAction(_: AnyObject) {
        UIView.setAnimationDelegate(self)
        UIView.setAnimationDidStopSelector("animationDidStop:animationIDfinished:finished:context:")
        UIView.beginAnimations(nil, context: nil)
        UIView.setAnimationDuration(kTransitionDuration)
        
        UIView.setAnimationTransition(self.contentView.superview != nil ? .FlipFromLeft : .FlipFromRight,
            forView: self.view,
            cache: true)
        
        if self.instructionsView.superview != nil {
            self.instructionsView.removeFromSuperview()
            self.view.addSubview(contentView)
        } else {
            self.contentView.removeFromSuperview()
            self.view.addSubview(instructionsView)
        }
        
        UIView.commitAnimations()
        
        // adjust our done/info buttons accordingly
        if instructionsView.superview != nil {
            self.navigationItem.rightBarButtonItem = doneButton
        } else {
            self.navigationItem.rightBarButtonItem = flipButton
        }
    }
    
    @IBAction func doSomethingAction(_: AnyObject) {
        self.startButton.setTitle("Rendering Audio...", forState: .Disabled)
        startButton.enabled = false
        
        self.activityIndicator.startAnimating()
        
        // run AQ code in a background thread
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            self.renderAudio()
        }
    }
    
    //MARK:- AVAudioPlayer
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        if !flag {NSLog("Playback finished unsuccessfully!")}
        
        player.delegate = nil
        self.player = nil
        
        startButton.enabled = true
    }
    
    private var player: AVAudioPlayer? = nil
    private func playAudio() {
        // play the result
        player = try? AVAudioPlayer(contentsOfURL: destinationURL!)
        
        player?.delegate = self
        player?.play()
    }
    
    //MARK:- AudioQueue
    
    private func renderAudio() {
        autoreleasepool{
            
            // delete the previous output file if it exists, not required but good for the test
            if let path = destinationURL?.path where NSFileManager.defaultManager().fileExistsAtPath(path) {
                _ = try? NSFileManager.defaultManager().removeItemAtPath(path)
            }
            
            DoAQOfflineRender(sourceURL!, destinationURL!)
            
            self.activityIndicator.stopAnimating()
            
            self.startButton.setTitle("Playing Rendered Audio...", forState: .Disabled)
            
            dispatch_async(dispatch_get_main_queue()) {
                self.playAudio()
            }
            
        }
    }
    
}