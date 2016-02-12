//
//  TextFieldTableViewCell.swift
//  UsbongKit
//
//  Created by Joe Amanse on 12/02/2016.
//  Copyright © 2016 Usbong Social Systems, Inc. All rights reserved.
//

import UIKit

public class TextFieldTableViewCell: UITableViewCell, NibReusable {
    @IBOutlet public weak var textField: UITextField! {
        didSet {
            textField.delegate = self
        }
    }
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override public func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}

extension TextFieldTableViewCell: UITextFieldDelegate {
    public func textFieldShouldReturn(textField: UITextField) -> Bool {
        if textField == self.textField {
            textField.resignFirstResponder()
            return false
        }
        
        return true
    }
}