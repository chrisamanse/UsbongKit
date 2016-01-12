//
//  PlayableTree.swift
//  UsbongKit
//
//  Created by Chris Amanse on 1/12/16.
//  Copyright © 2016 Usbong Social Systems, Inc. All rights reserved.
//

import Foundation
import AVFoundation

public protocol PlayableTree: class {
    var nodeView: NodeView! { get set }
    var tree: UsbongTree? { get set }
    
    var voiceOverOn: Bool { get set }
    var speechSynthesizer: AVSpeechSynthesizer { get set }
    var backgroundAudioPlayer: AVAudioPlayer? { get set }
    var voiceOverAudioPlayer: AVAudioPlayer? { get set }
    
    // Node
    func reloadNode()
    func transitionToPreviousNode()
    func transitionToNextNode()
    
    // View controllers
    func showAvailableActions(sender: AnyObject?)
    func showChooseLanguageScreen()
    
    // Background audio
    func loadBackgroundAudio()
    
    // Voice-over
    func startVoiceOver()
    func stopVoiceOver()
    func startVoiceOverAudio() -> Bool
    func stopVoiceOverAudio()
    func startTextToSpeech()
    func stopTextToSpeech()
}

public extension PlayableTree where Self: UIViewController {
    // MARK: Transitioning nodes
    func transitionToPreviousNode() {
        guard let tree = self.tree else {
            return
        }
        
        if !tree.previousNodeIsAvailable {
            dismissViewControllerAnimated(true, completion: nil)
            return
        }
        
        tree.transitionToPreviousNode()
        reloadNode()
    }
    
    func transitionToNextNode() {
        guard let tree = self.tree else {
            return
        }
        
        if tree.shouldPreventTransitionToNextTaskNode {
            // Present no selection alert
            let alertController = UIAlertController(title: "No Selection", message: "Please select one of the choices", preferredStyle: .Alert)
            let okayAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
            alertController.addAction(okayAction)
            
            presentViewController(alertController, animated: true, completion: nil)
            return
        } else if !tree.nextNodeIsAvailable {
            dismissViewControllerAnimated(true, completion: nil)
            return
        }
        
        tree.transitionToNextNode()
        reloadNode()
    }
    
    func showAvailableActions(sender: AnyObject?) {
        let actionController = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        
        let onOrOffText = voiceOverOn ? "Off" : "On"
        let speechAction = UIAlertAction(title: "Speech \(onOrOffText)", style: .Default) { (action) -> Void in
            let turnOn = !self.voiceOverOn
            
            // If toggled to on, start voice-over
            if turnOn {
                self.startVoiceOverAudio()
            } else {
                self.stopVoiceOver()
            }
            
            self.voiceOverOn = turnOn
        }
        let setLanguageAction = UIAlertAction(title: "Set Language", style: .Default) { (action) -> Void in
            self.showChooseLanguageScreen()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        
        actionController.addAction(speechAction)
        actionController.addAction(setLanguageAction)
        actionController.addAction(cancelAction)
        
        // For iPad action sheet behavior (similar to a popover)
        if let popover = actionController.popoverPresentationController {
            if let barButtonItem = sender as? UIBarButtonItem {
                popover.barButtonItem = barButtonItem
            } else if let view = sender as? UIView {
                popover.sourceView = view
            }
        }
        
        presentViewController(actionController, animated: true, completion: nil)
    }
}

public extension PlayableTree {
    var voiceOverOn: Bool {
        get {
            // Default to true if not yet set
            let standardUserDefaults = NSUserDefaults.standardUserDefaults()
            if standardUserDefaults.objectForKey("SpeechOn") == nil {
                standardUserDefaults.setBool(true, forKey: "SpeechOn")
            }
            return standardUserDefaults.boolForKey("SpeechOn")
        }
        set {
            NSUserDefaults.standardUserDefaults().setBool(newValue, forKey: "SpeechOn")
        }
    }
    
    func reloadNode() {
        guard let tree = self.tree else {
            return
        }
        guard let node = tree.currentNode else {
            return
        }
        
        stopVoiceOver()
        
        nodeView.node = node
        nodeView.hintsDictionary = tree.hintsDictionary
        
        if let delegate = self as? HintsTextViewDelegate {
            nodeView.hintsTextViewDelegate = delegate
        }
        
        // Background image
        if let backgroundImagePath = tree.backgroundImageURL?.path {
            nodeView.backgroundImage = UIImage(contentsOfFile: backgroundImagePath)
        }
        
        // Background audio - change only if not empty and different
        if let currentURL = backgroundAudioPlayer?.url {
            if let newURL = tree.backgroundAudioURL {
                if newURL != currentURL {
                    backgroundAudioPlayer?.stop()
                    backgroundAudioPlayer = nil
                    
                    loadBackgroundAudio()
                }
            }
        } else {
            // If current URL is empty, attempt load
            loadBackgroundAudio()
        }
        
        // Voice-over
        if voiceOverOn {
            startVoiceOver()
        }
    }
    
    // MARK: Background audio
    func loadBackgroundAudio() {
        guard let url = tree?.backgroundAudioURL else {
            return
        }
        
        do {
            let audioPlayer = try AVAudioPlayer(contentsOfURL: url)
            audioPlayer.numberOfLoops = -1
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            audioPlayer.volume = 0.4
            
            backgroundAudioPlayer = audioPlayer
        } catch let error {
            print("Error loading background audio: \(error)")
        }
    }
    
    // MARK: Voice-over
    func startVoiceOver() {
        // Attempt to play speech from audio file, if failed, resort to text-to-speech
        if !startVoiceOverAudio() {
            // Start text-to-speech instead
            startTextToSpeech()
        }
    }
    func stopVoiceOver() {
        stopVoiceOverAudio()
        stopTextToSpeech()
    }
    
    func startVoiceOverAudio() -> Bool {
        guard let voiceOverAudioURL = tree?.currentVoiceOverAudioURL else {
            return false
        }
        
        do {
            let audioPlayer = try AVAudioPlayer(contentsOfURL: voiceOverAudioURL)
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            print("Playing voice-over audio...")
            
            voiceOverAudioPlayer = audioPlayer
            return true
        } catch let error {
            print("Error loading voice-over audio: \(error)")
            return false
        }
    }
    
    func stopVoiceOverAudio() {
        guard let audioPlayer = voiceOverAudioPlayer else {
            return
        }
        
        if audioPlayer.playing {
            audioPlayer.stop()
        }
    }
    
    func startTextToSpeech() {
        guard let node = tree?.currentNode else {
            return
        }
        
        for module in node.modules where module is SpeakableTextTypeModule {
            let texts = (module as! SpeakableTextTypeModule).speakableTexts
            
            for text in texts {
                let utterance = AVSpeechUtterance(string: text)
                
                utterance.voice = AVSpeechSynthesisVoice(language: "en-EN")
                
                // Speak
                speechSynthesizer.speakUtterance(utterance)
            }
        }
    }
    func stopTextToSpeech() {
        if speechSynthesizer.speaking {
            speechSynthesizer.stopSpeakingAtBoundary(.Immediate)
        }
    }
}
