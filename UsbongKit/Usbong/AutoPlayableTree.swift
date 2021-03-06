//
//  AutoPlayableTree.swift
//  UsbongKit
//
//  Created by Chris Amanse on 3/26/16.
//  Copyright © 2016 Usbong Social Systems, Inc. All rights reserved.
//

import Foundation
import AVFoundation

public protocol AutoPlayableTree: PlayableTree, VoiceOverCoordinatorDelegate {
    var autoPlay: Bool { get set }
    
    var voiceOverCoordinator: VoiceOverCoordinator { get set }
}

public extension AutoPlayableTree {
    var autoPlay: Bool {
        get {
            // Default to true if not yet set
            let standardUserDefaults = UserDefaults.standard
            if standardUserDefaults.object(forKey: "UsbongKit.AutoPlayableTree.autoPlay") == nil {
                standardUserDefaults.set(false, forKey: "UsbongKit.AutoPlayableTree.autoPlay")
            }
            
            return standardUserDefaults.bool(forKey: "UsbongKit.AutoPlayableTree.autoPlay")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "UsbongKit.AutoPlayableTree.autoPlay")
            
            // If set to on/true, also turn on voice-over
            if newValue {
                voiceOverOn = true
            }
        }
    }
}
