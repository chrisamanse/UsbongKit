//
//  CommunityTableViewCell.swift
//  usbong
//
//  Created by Chris Amanse on 15/09/2015.
//  Copyright 2015 Usbong Social Systems, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import UIKit

public class CommunityTableViewCell: UITableViewCell {

    @IBOutlet public weak var titleLabel: UILabel!
    @IBOutlet public weak var authorLabel: UILabel!
    @IBOutlet public weak var downloadCountLabel: UILabel!
    @IBOutlet public weak var customImageView: UIImageView!
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override public func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}
