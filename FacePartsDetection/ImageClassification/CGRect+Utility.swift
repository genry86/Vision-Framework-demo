//
//  CGRect+Utility.swift
//  ImageClassification
//
//  Created by Genry on 08.05.2025.
//

import UIKit

extension CGRect {
    var invertRect: CGRect {
        .init(x: origin.y, y: origin.x, width: size.height, height: size.width)
    }
}
