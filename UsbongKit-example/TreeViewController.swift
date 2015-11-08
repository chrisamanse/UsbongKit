//
//  TreeViewController.swift
//  UsbongKit
//
//  Created by Joe Amanse on 07/11/2015.
//  Copyright © 2015 Usbong Social Systems, Inc. All rights reserved.
//

import UIKit
import UsbongKit

class TreeViewController: UIViewController {

    @IBOutlet weak var taskNodeView: TaskNodeView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        taskNodeView.taskNode = TextDisplayTaskNode(text: "Hello, World!\nHello!")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func didPressExit(sender: AnyObject) {
        print("Did Press Exit")
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func didPressMore(sender: AnyObject) {
        print("Did Press More")
    }
    
    @IBAction func didPressPrevious(sender: AnyObject) {
        print("Did Press Previous")
    }
    
    @IBAction func didPressNext(sender: AnyObject) {
        print("Did Press Next")
    }
}
