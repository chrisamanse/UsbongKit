//
//  UsbongTree.swift
//  UsbongKit
//
//  Created by Chris Amanse on 12/27/15.
//  Copyright © 2015 Usbong Social Systems, Inc. All rights reserved.
//

import Foundation
import SWXMLHash

public class UsbongTree {
    public let treeRootURL: NSURL
    
    public let title: String
    public let baseLanguage: String
    public var currentLanguage: String {
        didSet {
            reloadCurrentTaskNode()
            loadHintsDictionary()
        }
    }
    public var currentLanguageCode: String {
        return UsbongLanguage(language: currentLanguage).languageCode
    }
    public let availableLanguages: [String]
    
    public private(set) var backgroundImageURL: NSURL?
    public private(set) var backgroundAudioURL: NSURL?
    public private(set) var currentVoiceOverAudioURL: NSURL?
    
    internal var taskNodeNames: [String] = []
    
    internal private(set) var checklistTargetNumberOfTicks = 0
    internal private(set) var currentTransitionInfo: [String: String] = [:]
    internal var currentTargetTransitionName: String {
        get {
            // If current task node type is radio buttons, ignore selected module (transition to any)
            switch currentNode {
            case let checklistNode as ChecklistNode:
                if checklistNode.selectionModule.selectedIndices.count >= checklistTargetNumberOfTicks {
                    return "Yes"
                } else {
                    return "No"
                }
            case let radioButtonsNode as RadioButtonsNode:
                if let taskNodeType = currentTaskNodeType {
                    switch taskNodeType {
                    case .Link:
                        guard let module = radioButtonsNode.selectionModule as? RadioButtonsModule else {
                            break
                        }
                        guard let selectedIndex = module.selectedIndex else {
                            break
                        }
                        print(module.options[selectedIndex])
                        return module.options[selectedIndex]
                    default:
                        break
                    }
                }
                return "Any"
            default:
                return "Any"
            }
        }
    }
    internal var nextTaskNodeName: String? {
        return currentTransitionInfo[currentTargetTransitionName]
    }
    
    internal let languageXMLURLs: [NSURL]
    internal let hintsXMLURLs: [NSURL]
    public private(set) var hintsDictionary: [String: String] = [:]
    
    private let treeXMLIndexer: XMLIndexer
    
    private var processDefinitionIndexer: XMLIndexer {
        return treeXMLIndexer[XMLIdentifier.processDefinition]
    }
    
    public internal(set) var currentNode: Node?
    
    public init(treeRootURL: NSURL) {
        let fileManager = NSFileManager.defaultManager()
        
        self.treeRootURL = treeRootURL
        
        // Fetch main XML URL
        let fileName = treeRootURL.URLByDeletingPathExtension?.lastPathComponent ?? ""
        let XMLURL = treeRootURL.URLByAppendingPathComponent(fileName).URLByAppendingPathExtension("xml")
        let XMLData = NSData(contentsOfURL: XMLURL) ?? NSData()
        
        // Set title, if blank, set to "Untitled"
        let title: String
        if fileName.stringByReplacingOccurrencesOfString(" ", withString: "").characters.count == 0 {
            title = "Untitled"
        } else {
            title = fileName
        }
        self.title = title
        
        // Set property
        treeXMLIndexer = SWXMLHash.parse(XMLData)
        
        // Set base and current language
        let processDefinitionIndexer = treeXMLIndexer[XMLIdentifier.processDefinition]
        baseLanguage = processDefinitionIndexer.element?.attributes[XMLIdentifier.lang] ?? "Unknown"
        currentLanguage = baseLanguage
        
        // Fetch URLs for language XMLs
        let transURL = treeRootURL.URLByAppendingPathComponent("trans", isDirectory: true)
        languageXMLURLs = (try? fileManager.contentsOfDirectoryAtURL(transURL,
                includingPropertiesForKeys: nil, options: .SkipsSubdirectoryDescendants)) ?? []
        
        // Set available languages and also include base language
        var availableLanguages: [String] = []
        languageXMLURLs.forEach { url in
            let language = url.URLByDeletingPathExtension?.lastPathComponent ?? "Unknown"
            availableLanguages.append(language)
        }
        
        if !availableLanguages.contains(baseLanguage) {
            availableLanguages.append(baseLanguage)
        }
        availableLanguages.sortInPlace()
        
        self.availableLanguages = availableLanguages
        
        // Fetch URLs for hints XMLs
        let hintsURL = treeRootURL.URLByAppendingPathComponent("hints", isDirectory: true)
        hintsXMLURLs = (try? fileManager.contentsOfDirectoryAtURL(hintsURL,
                includingPropertiesForKeys: nil, options: .SkipsSubdirectoryDescendants)) ?? []
        loadHintsDictionary()
        
        // Fetch starting task node
        if let element = processDefinitionIndexer[XMLIdentifier.startState][XMLIdentifier.transition].element {
            if let startName = element.attributes[XMLIdentifier.to] {
                taskNodeNames.append(startName)
                currentNode = nodeWithName(startName)
            }
        }
    }
    
    internal func reloadCurrentTaskNode() {
        if let currentTaskNodeName = taskNodeNames.last {
            currentNode = nodeWithName(currentTaskNodeName)
        }
    }
    
    internal var currentTaskNodeType: TaskNodeType?
    internal func nodeWithName(taskNodeName: String) -> Node {
        var node: Node = TextNode(text: "Unknown Node")
        if let (nodeIndexer, type) = nodeIndexerAndTypeWithName(taskNodeName) {
            let nameInfo = XMLNameInfo(name: taskNodeName, language: currentLanguage, treeRootURL: treeRootURL)
            print(nameInfo.type)
            
            // Get urls for assets
            backgroundAudioURL = nameInfo.backgroundAudioURL
            backgroundImageURL = nameInfo.backgroundImageURL
            currentVoiceOverAudioURL = nameInfo.audioURL
            
            switch type {
            case .TaskNode, .Decision:
                guard let taskNodeType = nameInfo.type else {
                    break
                }
                if type == .Decision {
                    currentTaskNodeType = .Link // Decision type is same as link
                } else {
                    currentTaskNodeType = taskNodeType
                }
                
                var fetchedTransitionInfo: [String: String] = [:]
                let finalText = parseText(translateText(nameInfo.text))
                switch taskNodeType {
                case .TextDisplay:
                    node = TextNode(text: finalText)
                case .ImageDisplay:
                    node = ImageNode(image: nameInfo.image)
                case .TextImageDisplay:
                    node = TextImageNode(text: finalText, image: nameInfo.image)
                case .ImageTextDisplay:
                    node = ImageTextNode(image: nameInfo.image, text: finalText)
                case _ where type == .Decision, .Link, .RadioButtons, .Checklist, .Classification:
                    var tasks: [String] = []
                    
                    // Fetch tasks (and transition info from task elements if link)
                    let taskIndexers = nodeIndexer[XMLIdentifier.task].all
                    taskIndexers.forEach({ taskIndexer in
                        guard let name = taskIndexer.element?.attributes[XMLIdentifier.name] else {
                            return
                        }
                        var nameComponents = name.componentsSeparatedByString("~")
                        let key = nameComponents.removeLast()
                        
                        let value = nameComponents.joinWithSeparator("~")
                        tasks.append(key)
                        
                        // Link type need to have more than one component
                        if taskNodeType == .Link && nameComponents.count > 1 {
                            
                            // Add transition info
                            fetchedTransitionInfo[key] = value
                        }
                        
                    })
                    
                    // Create node
                    switch taskNodeType {
                    case .Checklist:
                        node = ChecklistNode(text: finalText, options: tasks)
                        checklistTargetNumberOfTicks = nameInfo.targetNumberOfChoices
                    case .Classification:
                        // Add indices
                        var options: [String] = []
                        let count = tasks.count
                        for i in 0..<count {
                            options.append("\(i+1)) \(tasks[i])")
                        }
                        
                        node = ClassificationNode(text: finalText, list: options)
                    case _ where type == .Decision, .Link, .RadioButtons:
                        node = RadioButtonsNode(text: finalText, options: tasks)
                    default:
                        break
                    }
                    
                default:
                    break
                }
                
                // Get transition info
                currentTransitionInfo = fetchedTransitionInfo
                let additionalTransitionInfo = transitionInfoFromTransitionIndexers(nodeIndexer[XMLIdentifier.transition].all, andTaskNodeType: taskNodeType)
                for (key, value) in additionalTransitionInfo {
                    currentTransitionInfo[key] = value
                }
            case .EndState:
                node = TextNode(text: "You've now reached the end")
                currentTransitionInfo = [:]
            }
        }
        
        return node
    }
    
    // MARK: Get transition info from transition elements
    private func transitionInfoFromTransitionIndexers(transitionIndexers: [XMLIndexer], andTaskNodeType type: TaskNodeType) -> [String: String]{
        var transitionInfo: [String: String] = [:]
        
        for indexer in transitionIndexers {
            guard let attributes = indexer.element?.attributes else {
                continue
            }
            
            // Get value of name
            let name = attributes[XMLIdentifier.name] ?? "Any"
            
            // Get value of to
            var to = attributes[XMLIdentifier.to] ?? ""
            
            // Remove identifier for link transition
            if type == .Link {
                var components = to.componentsSeparatedByString("~")
                components.removeLast()
                to = components.joinWithSeparator("~")
            }
            
            transitionInfo[name] = to
        }
        
        return transitionInfo
    }
    
    // MARK: Get XML Indexer of task nodes
    private func taskNodeIndexerWithName(name: String) -> XMLIndexer? {
        return try? processDefinitionIndexer[XMLIdentifier.taskNode].withAttr(XMLIdentifier.name, name)
    }
    private func endStateIndexerWithName(name: String) -> XMLIndexer? {
        return try? processDefinitionIndexer[XMLIdentifier.endState].withAttr(XMLIdentifier.name, name)
    }
    private func decisionIndexerWithName(name: String) -> XMLIndexer? {
        return try? processDefinitionIndexer[XMLIdentifier.decision].withAttr(XMLIdentifier.name, name)
    }
    internal func nodeIndexerAndTypeWithName(name: String) -> (indexer: XMLIndexer, type: NodeType)? {
        var indexer: XMLIndexer?
        var type = NodeType.TaskNode
        
        // Find task node
        indexer = taskNodeIndexerWithName(name)
        
        // Find end state, if task node not found
        if indexer == nil {
            indexer = endStateIndexerWithName(name)
            type = .EndState
        }
        
        // Find decision if end state not found
        if indexer == nil {
            indexer = decisionIndexerWithName(name)
            type = .Decision
        }
        
        if let nodeIndexer = indexer {
            return (nodeIndexer, type)
        } else {
            return nil
        }
    }
    
    // MARK: Language
    
    private var currentLanguageXMLURL: NSURL? {
        for url in languageXMLURLs {
            // Check if file name is equal to language
            let name = url.URLByDeletingPathExtension?.lastPathComponent ?? "Unknown"
            if currentLanguage == name {
                return url
            }
        }
        return nil
    }
    
    private func translateText(text: String) -> String {
        guard text.characters.count > 0 else {
            return ""
        }
        
        var translatedText = text
        
        // Fetch translation from XML
        if let languageXMLURL = currentLanguageXMLURL {
            let languageXML = SWXMLHash.parse(NSData(contentsOfURL: languageXMLURL) ?? NSData())
            let resources = languageXML[XMLIdentifier.resources]
            
            if let stringElement = try? resources[XMLIdentifier.string].withAttr(XMLIdentifier.name, text) {
                translatedText = stringElement.element?.text ?? text
            }
        }
        
        return translatedText
    }
    
    private func parseText(text: String) -> String {
        guard text.characters.count > 0 else {
            return ""
        }
        
        return text.stringByReplacingOccurrencesOfString("{br}", withString: "\n", options: .CaseInsensitiveSearch, range: nil)
    }
    
    // MARK: Hints
    
    private func loadHintsDictionary() {
        hintsDictionary.removeAll()
        for url in hintsXMLURLs {
            // Check if file name is equal to language
            let name = url.URLByDeletingPathExtension?.lastPathComponent ?? "Unknown"
            if currentLanguage == name {
                var hints = [String: String]()
                
                // Fetch hints from XML
                let hintsXML = SWXMLHash.parse(NSData(contentsOfURL: url) ?? NSData())
                let resources = hintsXML[XMLIdentifier.resources]
                
                let stringXMLIndexers = resources[XMLIdentifier.string].all
                for stringXMLIndexer in stringXMLIndexers {
                    if let key = stringXMLIndexer.element?.attributes[XMLIdentifier.name], let value = stringXMLIndexer.element?.text {
                        hints[key] = value
                    }
                }
                
                hintsDictionary = hints
                break
            }
        }
    }
    
    // MARK: End state
    
    public var currentNodeIsEndState: Bool {
        guard let name = taskNodeNames.last else {
            return true
        }
        guard let (_, type) = nodeIndexerAndTypeWithName(name) else {
            return true
        }
        
        return type == .EndState
    }
    public var nextNodeIsEndState: Bool {
        guard let name = nextTaskNodeName else {
            return true
        }
        guard let (_, type) = nodeIndexerAndTypeWithName(name) else {
            return true
        }
        
        return type == .EndState
    }
    
    // MARK: Prevent next
    
    public var shouldPreventTransitionToNextTaskNode: Bool {
        return !(currentNode is ChecklistNode) && currentNodeIsSelectionType && nothingSelected
    }
}

// MARK: - NodeType
internal enum NodeType {
    case TaskNode
    case EndState
    case Decision
}
