//  Utils.swift
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
        
        let (ppi, screenWidthInMeter, screenHeightInMeter) = {
            // 默认使用 iPhone 配置（如 iPhone 14 Pro）
            return (460.0, 0.0651318, 0.1412057)
        }()

//         Updated PPI for iPad air 4
//         let ppi: CGFloat = 264
//         // actual screen size in meters for ipad air 4 10.9 inch
//         let screenWidthInMeter = 0.159778
//         let screenHeightInMeter = 0.229921

        let a_ratio = (screenWidthPixel / ppi) / screenWidthInMeter
        let b_ratio = (screenHeightPixel / ppi) / screenHeightInMeter

        return CGSize(width: (screenWidthPixel / ppi) / a_ratio,
                      height: (screenHeightPixel / ppi) / b_ratio)
    }
    
    // 添加打印屏幕尺寸的函数
    static func printScreenSize() {
        print("设备尺寸", Device.screenSize)
        print("屏幕分辨率:",UIScreen.main.nativeBounds.width, UIScreen.main.nativeBounds.height)
        print("屏幕尺寸: 宽度 = \(UIScreen.main.bounds.size.width), 高度 = \(UIScreen.main.bounds.size.height)")
        print("宽度范围: \(Ranges.widthRange)", "高度范围: \(Ranges.heightRange)")
        print("Safe Frame尺寸: \(safeFrameSize)")
        print("UIScreen.main.scale", UIScreen.main.scale)
    }
    
    // 竖屏模式下的屏幕尺寸
    static var frameSize: CGSize {
        let safeAreaInsets = getSafeAreaInsets()
        return CGSize(width: UIScreen.main.bounds.size.width,
                      height: UIScreen.main.bounds.size.height - safeAreaInsets.top - safeAreaInsets.bottom)
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
    // 竖屏模式下的宽度范围
    static var widthRange: ClosedRange<CGFloat> {
        let safeAreaInsets = Device.getSafeAreaInsets()
        return (safeAreaInsets.left...(UIScreen.main.bounds.width - safeAreaInsets.right))
    }
    // 竖屏模式下的高度范围
    static var heightRange: ClosedRange<CGFloat> {
        return 0.0...Device.frameSize.height
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
