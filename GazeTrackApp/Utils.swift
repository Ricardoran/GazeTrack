//  Utils.swift
//  GazeTrackApp
//
//  Created by Haoran Zhang on 3/2/25.
//

import SwiftUI
import UIKit
import AVFoundation

struct Device {
    // MARK: - Device Orientation Detection
    static var currentOrientation: UIInterfaceOrientation {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return scene.interfaceOrientation
        }
        return .portrait
    }
    
    static var isLandscape: Bool {
        let orientation = currentOrientation
        return orientation == .landscapeLeft || orientation == .landscapeRight
    }
    
    static var isPortrait: Bool {
        let orientation = currentOrientation
        return orientation == .portrait || orientation == .portraitUpsideDown
    }
    
    // 详细的横屏方向检测
    // 注意：UIInterfaceOrientation的定义可能与直觉相反
    static var isLandscapeLeft: Bool {
        // landscapeLeft = 设备逆时针转90度 = 摄像头在右侧
        return currentOrientation == .landscapeLeft
    }
    
    static var isLandscapeRight: Bool {
        // landscapeRight = 设备顺时针转90度 = 摄像头在左侧  
        return currentOrientation == .landscapeRight
    }
    
    // 基于摄像头位置的判断（更直观）
    static var isCameraOnLeft: Bool {
        return currentOrientation == .landscapeRight
    }
    
    static var isCameraOnRight: Bool {
        return currentOrientation == .landscapeLeft
    }
    
    // MARK: - Screen Size Calculations
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
    
    // 方向感知的逻辑屏幕尺寸（用于坐标计算）
    static var orientationAwareLogicalSize: CGSize {
        let bounds = UIScreen.main.bounds.size
        // 在横屏模式下，bounds已经是正确的方向，无需调换
        return bounds
    }
    
    // 方向感知的物理屏幕尺寸（物理尺寸，根据方向调整）
    static var orientationAwareScreenSize: CGSize {
        let baseSize = screenSize
        return isLandscape ? 
            CGSize(width: baseSize.height, height: baseSize.width) : 
            baseSize
    }
    
    // 添加打印屏幕尺寸的函数
    static func printScreenSize() {
        let safeAreaInsets = getSafeAreaInsets()
        let orientation = currentOrientation
        
        print("=== 设备尺寸和方向信息 ===")
        print("设备尺寸", Device.screenSize)
        print("方向感知设备尺寸", Device.orientationAwareScreenSize)
        print("当前方向:", orientation.rawValue, Device.isCameraOnLeft ? "(摄像头在左)" : Device.isCameraOnRight ? "(摄像头在右)" : Device.isPortrait ? "(竖屏)" : "(未知)")
        print("屏幕分辨率:",UIScreen.main.nativeBounds.width, UIScreen.main.nativeBounds.height)
        print("屏幕尺寸: 宽度 = \(UIScreen.main.bounds.size.width), 高度 = \(UIScreen.main.bounds.size.height)")
        
        print("=== Safe Area详细信息 ===")
        print("Safe Area Insets - top:\(safeAreaInsets.top), bottom:\(safeAreaInsets.bottom), left:\(safeAreaInsets.left), right:\(safeAreaInsets.right)")
        print("宽度范围: \(Ranges.widthRange)", "高度范围: \(Ranges.heightRange)")
        print("Safe Frame尺寸: \(safeFrameSize)")
        print("UIScreen.main.scale", UIScreen.main.scale)
        print("===============================")
    }
    
    // 方向感知的屏幕尺寸（去除安全区域）
    static var frameSize: CGSize {
        let safeAreaInsets = getSafeAreaInsets()
        let bounds = UIScreen.main.bounds.size
        return CGSize(width: bounds.width,
                      height: bounds.height - safeAreaInsets.top - safeAreaInsets.bottom)
    }
    
    // 获取安全区域的尺寸
    static func getSafeAreaInsets() -> UIEdgeInsets {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let insets = window.safeAreaInsets
            
            // 横屏模式下手动修正Safe Area，保持与竖屏逻辑一致
            if isLandscape {
                // 竖屏：top=59, bottom=34, left=0, right=0
                // 横屏应该：top=0, bottom=0, left=59, right=34
                let correctedInsets = UIEdgeInsets(
                    top: 0.0,
                    left: 59.0,  // 对应竖屏的top
                    bottom: 0.0,
                    right: 34.0  // 对应竖屏的bottom
                )
                
                #if DEBUG
                if arc4random_uniform(180) == 0 {
                    print("=== Safe Area 手动修正 ===")
                    print("原始横屏Safe Area:", "top=\(insets.top), bottom=\(insets.bottom), left=\(insets.left), right=\(insets.right)")
                    print("修正后Safe Area:", "top=\(correctedInsets.top), bottom=\(correctedInsets.bottom), left=\(correctedInsets.left), right=\(correctedInsets.right)")
                    print("修正说明: 让横屏与竖屏保持逻辑一致")
                    print("===============================")
                }
                #endif
                
                return correctedInsets
            }
            
            return insets
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
    // 方向感知的宽度范围
    static var widthRange: ClosedRange<CGFloat> {
        let safeAreaInsets = Device.getSafeAreaInsets()
        let bounds = UIScreen.main.bounds
        
        // 在横屏模式下，需要特别处理摄像头侧的安全区域
        if Device.isLandscape {
            // 横屏模式：使用修正后的Safe Area计算范围
            let leftBound: CGFloat = safeAreaInsets.left   // 59 (对应竖屏top)
            let rightBound: CGFloat = bounds.width - safeAreaInsets.right  // 852 - 34 = 818 (对应竖屏bottom)
            
            #if DEBUG
            if arc4random_uniform(300) == 0 { // 每300帧打印一次
                print("横屏宽度范围计算(修正后Safe Area): left=\(leftBound), right=\(rightBound)")
                print("修正后safeArea.left=\(safeAreaInsets.left), safeArea.right=\(safeAreaInsets.right)")
                print("bounds.width=\(bounds.width)")
            }
            #endif
            
            return leftBound...rightBound
        } else {
            // 竖屏模式：left和right通常为0
            return safeAreaInsets.left...(bounds.width - safeAreaInsets.right)
        }
    }
    
    // 方向感知的高度范围
    static var heightRange: ClosedRange<CGFloat> {
        let safeAreaInsets = Device.getSafeAreaInsets()
        let bounds = UIScreen.main.bounds
        
        if Device.isLandscape {
            // 横屏模式：使用修正后的Safe Area计算范围
            let topBound: CGFloat = safeAreaInsets.top    // 0 (修正后)
            let bottomBound: CGFloat = bounds.height - safeAreaInsets.bottom  // 393 - 0 = 393 (修正后)
            
            #if DEBUG
            if arc4random_uniform(300) == 0 { // 每300帧打印一次
                print("横屏高度范围计算(修正后Safe Area): top=\(topBound), bottom=\(bottomBound)")
                print("frameSize.height=\(Device.frameSize.height), bounds.height=\(bounds.height)")
                print("修正后safeArea.top=\(safeAreaInsets.top), safeArea.bottom=\(safeAreaInsets.bottom)")
            }
            #endif
            
            return topBound...bottomBound
        } else {
            // 竖屏模式：使用原有逻辑
            return 0.0...Device.frameSize.height
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

extension View {
    func getRootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else { return nil }
        return window.rootViewController
    }
}

func showCameraSettingsAlert(presentingViewController: UIViewController) {
    let alert = UIAlertController(title: "需要摄像头权限", message: "请在设置中开启摄像头权限以继续使用该功能。", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
    alert.addAction(UIAlertAction(title: "去设置", style: .default, handler: { _ in
        if let appSettings = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(appSettings)
        }
    }))
    presentingViewController.present(alert, animated: true, completion: nil)
}
