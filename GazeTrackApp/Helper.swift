//
//  Helper.swift
//  GazeTrackApp
//
//  Created by Haoran Zhang on 3/2/25.
//

import SwiftUI
import UIKit

struct Device {
    static var screenSize: CGSize {
        
        let screenWidthPixel: CGFloat = UIScreen.main.nativeBounds.width
        let screenHeightPixel: CGFloat = UIScreen.main.nativeBounds.height
        
        // Updated PPI for iPhone 14 Pro
        let ppi: CGFloat = 460
        
        // Updated calibration ratios for iPhone 14 Pro:
        // Using a reference resolution of 1179 x 2556 (portrait mode)
        // Normalization factor (458) and measured calibration constants remain unchanged,
        // resulting in ratios of approximately 41.3.
        let a_ratio = (1179 / 458) / 0.0623908297
        let b_ratio = (2556 / 458) / 0.135096943231532

        return CGSize(width: (screenWidthPixel / ppi) / a_ratio,
                      height: (screenHeightPixel / ppi) / b_ratio)
    }
    
    // You might update the frameSize if needed; this one remains similar to the original.
    static var frameSize: CGSize {  // iPhone XR frame size example; adjust if needed for iPhone 14 Pro.
        return CGSize(width: UIScreen.main.bounds.size.width,
                      height: UIScreen.main.bounds.size.height - 82)
    }
}

struct Ranges {
    static let widthRange: ClosedRange<CGFloat> = (0...Device.frameSize.width)
    static let heightRange: ClosedRange<CGFloat> = (0...Device.frameSize.height)
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        if self < range.lowerBound {
            return range.lowerBound
        } else if self > range.upperBound {
            return range.upperBound
        } else {
            return self
        }
    }
}
