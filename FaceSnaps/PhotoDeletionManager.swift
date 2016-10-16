//
//  PhotoDeletionManager.swift
//  FaceSnaps
//
//  Created by Patrick Montalto on 10/16/16.
//  Copyright © 2016 Patrick Montalto. All rights reserved.
//

import Foundation
import UIKit

protocol PhotoDeletionManagerDelegate: class {
    func didTapDelete(atRow row: Int)
}

// Communicates to PhotoListController user actions taken to delete photo
class PhotoDeletionManager {
    
    weak var delegate: PhotoDeletionManagerDelegate?
    
    @objc func deletePhoto(sender: UIButton) {
        let row = sender.tag
        delegate?.didTapDelete(atRow: row)
    }
}
