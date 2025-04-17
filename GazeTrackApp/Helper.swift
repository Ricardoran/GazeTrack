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
    
    // 添加打印屏幕尺寸的函数
    static func printScreenSize() {
        print("屏幕尺寸: 宽度 = \(UIScreen.main.bounds.size.width), 高度 = \(UIScreen.main.bounds.size.height)")
    }
    
    // You might update the frameSize if needed; this one remains similar to the original.
    static var frameSize: CGSize {  // iPhone XR frame size example; adjust if needed for iPhone 14 Pro.
        return CGSize(width: UIScreen.main.bounds.size.width,
                      height: UIScreen.main.bounds.size.height)
    }
    
    // 获取当前界面方向的辅助方法
    static func getCurrentOrientation() -> UIInterfaceOrientation {
        // 使用新的API获取界面方向
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.interfaceOrientation
        }
        return .portrait
    }
    
    // 获取安全区域的尺寸
    static func getSafeAreaInsets() -> UIEdgeInsets {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets
        }
        return UIEdgeInsets.zero
    }
    
    // 获取考虑安全区域的屏幕尺寸
    static var safeFrameSize: CGSize {
        let safeAreaInsets = getSafeAreaInsets()
        return CGSize(
            width: UIScreen.main.bounds.size.width - safeAreaInsets.left - safeAreaInsets.right,
            height: UIScreen.main.bounds.size.height - safeAreaInsets.top - safeAreaInsets.bottom
        )
    }
}

struct Ranges {
    static var widthRange: ClosedRange<CGFloat> {
        let interfaceOrientation = Device.getCurrentOrientation()
        let safeAreaInsets = Device.getSafeAreaInsets()
        
        if interfaceOrientation.isLandscape {
            return (safeAreaInsets.left...(UIScreen.main.bounds.height - safeAreaInsets.right))
        } else {
            return (safeAreaInsets.left...(UIScreen.main.bounds.width - safeAreaInsets.right))
        }
    }
    
    static var heightRange: ClosedRange<CGFloat> {
        let interfaceOrientation = Device.getCurrentOrientation()
        let safeAreaInsets = Device.getSafeAreaInsets()
        
        if interfaceOrientation.isLandscape {
            return (safeAreaInsets.top...(UIScreen.main.bounds.width - safeAreaInsets.bottom))
        } else {
            return (safeAreaInsets.top...(UIScreen.main.bounds.height - safeAreaInsets.bottom))
        }
    }
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
