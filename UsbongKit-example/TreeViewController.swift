//
//  TreeViewController.swift
//  UsbongKit
//
//  Created by Chris Amanse on 12/29/15.
//  Copyright © 2015 Usbong Social Systems, Inc. All rights reserved.
//

import UIKit
import AVFoundation
import UsbongKit

class TreeViewController: UIViewController, PlayableTree, AutoPlayableTree, HintsTextViewDelegate {
    
    @IBOutlet weak var previousNextSegmentedControl: UISegmentedControl!
    
    @IBOutlet weak var nodeView: NodeView!
    var tree: UsbongTree?
    
    var treeURL: NSURL?
    var treeRootURL: NSURL?
    
    lazy var speechSynthesizer = AVSpeechSynthesizer()
    var backgroundAudioPlayer: AVAudioPlayer?
    var voiceOverAudioPlayer: AVAudioPlayer?
    
    var lastSpeechUtterance: AVSpeechUtterance?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let url = treeURL {
            if let treeRootURL = UsbongFileManager.defaultManager().unpackTreeToCacheDirectoryWithTreeURL(url) {
                self.treeRootURL = treeRootURL
                print(treeRootURL)
                
                tree = UsbongTree(treeRootURL: treeRootURL)
                
                reloadNode()
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        stopVoiceOver()
        
        // Print output
        let output: String = tree?.generateOutput(UsbongAnswersGeneratorDefaultCSVString.self) ?? ""
        print("Output: \(output)")
        
        // Save csv on exit
        tree?.saveOutputData(UsbongAnswersGeneratorDefaultCSVString.self) { (success, filePath) in
            print("Answers saved to \(filePath): \(success)")
        }
    }
    
    // MARK: - Actions
    
    @IBAction func didPressExit(sender: AnyObject?) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func didPressMore(sender: AnyObject) {
        showAvailableActions(sender)
    }
    @IBAction func didChangeSegmentedControllerValue(sender: AnyObject?) {
        if let segmentedControl = sender as? UISegmentedControl {
            let index = segmentedControl.selectedSegmentIndex
            switch index {
            case 0:
                transitionToPreviousNode()
            case 1:
                transitionToNextNode()
            default:
                break
            }
        }
    }
}

extension TreeViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(synthesizer: AVSpeechSynthesizer, didFinishSpeechUtterance utterance: AVSpeechUtterance) {
        if autoPlay && lastSpeechUtterance == utterance {
            transitionToNextNode()
        }
    }
}
