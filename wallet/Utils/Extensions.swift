//
//  Extensions.swift
//  wallet
//
//  Created by Chris Downie on 4/19/17.
//  Copyright © 2017 Learning Machine, Inc. All rights reserved.
//

import UIKit
import Foundation
import Blockcerts

extension UILabel {
    
    func isTruncated() -> Bool {
        guard let string = self.text else {
            return false
        }
        layoutIfNeeded()
        
        let size: CGSize = (string as NSString).boundingRect(
            with: CGSize(width: self.frame.size.width, height: CGFloat.greatestFiniteMagnitude),
            options: NSStringDrawingOptions.usesLineFragmentOrigin,
            attributes: [NSAttributedStringKey.font: self.font],
            context: nil).size
        
        return (size.height > self.bounds.size.height)
    }
}

extension Certificate {
    var filename : String? {
        return id.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
    }
}
