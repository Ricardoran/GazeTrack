//  Utils.swift
//  GazeTrackApp
//
//  Created by Haoran Zhang on 3/2/25.
//

import SwiftUI
import UIKit
import AVFoundation
import ARKit

struct Device {
    static var currentOrientation: UIInterfaceOrientation {
        // 确保在主线程调用
        if Thread.isMainThread {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                return scene.interfaceOrientation
            }
        } else {
            // 如果在后台线程，返回缓存的值或默认值
            return DispatchQueue.main.sync {
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    return scene.interfaceOrientation
                }
                return .portrait
            }
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
    
    // 基于摄像头位置的判断（更直观）
    static var isCameraOnLeft: Bool {
        return currentOrientation == .landscapeRight
    }
    
    static var isCameraOnRight: Bool {
        return currentOrientation == .landscapeLeft
    }
    
    // MARK: - TrueDepth Camera Support Detection
    static var supportsTrueDepthCamera: Bool {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTrueDepthCamera],
            mediaType: .video,
            position: .front
        )
        return !discoverySession.devices.isEmpty
    }
    
    
    // Screen Size Calculations
    static var screenSize: CGSize {
        
        // 这里的screen size是定死的，不会受屏幕旋转而改变
        let screenWidthPixel: CGFloat = UIScreen.main.nativeBounds.width
        let screenHeightPixel: CGFloat = UIScreen.main.nativeBounds.height
        
        let (ppi, screenWidthInMeter, screenHeightInMeter) = {
            // 默认使用 iPhone 配置（如 iPhone 14 Pro）
            return (460.0, 0.0651318, 0.1412057)
            // return (264.0, 0.159778, 0.229921)
        }()


        let a_ratio = (screenWidthPixel / ppi) / screenWidthInMeter
        let b_ratio = (screenHeightPixel / ppi) / screenHeightInMeter

        return CGSize(width: (screenWidthPixel / ppi) / a_ratio,
                      height: (screenHeightPixel / ppi) / b_ratio)
    }
    
    // 方向感知的逻辑屏幕尺寸（用于坐标计算）
    static var orientationAwareLogicalSize: CGSize {
        let bounds = UIScreen.main.bounds.size
        return bounds
    }
    
    // 方向感知的物理屏幕尺寸（物理尺寸，根据方向调整）
    static var orientationAwareScreenSize: CGSize {
        let baseSize = screenSize
        return isLandscape ?
            CGSize(width: baseSize.height, height: baseSize.width) : 
            baseSize
    }
    
    // 方向感知的屏幕尺寸（去除安全区域）
    static var frameSize: CGSize {
        let safeAreaInsets = getSafeAreaInsets()
        let bounds = UIScreen.main.bounds.size
        return CGSize(width: bounds.width - safeAreaInsets.left - safeAreaInsets.right,
                      height: bounds.height - safeAreaInsets.top - safeAreaInsets.bottom)
    }
    
    // 将屏幕上的点距离转换为厘米
    static func pointsToCentimeters(_ points: CGFloat) -> Double {
        // 获取设备的scale factor (1x, 2x, 3x等)
        let scale = UIScreen.main.scale
        
        // 将iOS点转换为实际像素
        let pixels = Double(points) * Double(scale)
        
        // iPhone 14 Pro 配置
        let ppi: Double = 460.0  // 像素每英寸
        
        // 直接使用PPI转换：像素 → 英寸 → 厘米
        let inches = pixels / ppi
        let centimeters = inches * 2.54
        
        return centimeters
    }
    
    // 将厘米误差转换为角度误差（度）
    static func centimetersToDegrees(_ centimeters: Double, eyeToScreenDistance: Double) -> Double {
        // 使用眼动追踪研究的标准公式计算角度误差
        // θ = arctan(distance_on_screen / viewing_distance) × (180/π)
        // 参考: PMC6165570, SR Research等权威眼动追踪研究
        let angleRadians = atan(centimeters / eyeToScreenDistance)
        let angleDegrees = angleRadians * (180.0 / Double.pi)
        
        return angleDegrees
    }
    
    // 预估默认的眼睛到屏幕距离（厘米）
    static var defaultEyeToScreenDistance: Double {
        // 根据研究，人眼到手机屏幕的典型距离约为25-40厘米
        // 我们使用30厘米作为默认值
        return 30.0
    }
    
    // 获取安全区域的尺寸
    static func getSafeAreaInsets() -> UIEdgeInsets {
        // 确保在主线程调用
        if Thread.isMainThread {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let insets = window.safeAreaInsets
                return insets
            }
        } else {
            // 如果在后台线程，同步调用主线程
            return DispatchQueue.main.sync {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    return window.safeAreaInsets
                }
                return UIEdgeInsets.zero
            }
        }
        return UIEdgeInsets.zero
    }
    

}

struct Ranges {
    // 方向感知的宽度范围
    static var widthRange: ClosedRange<CGFloat> {
            return 0.0...Device.frameSize.width
    }
    
    // 方向感知的高度范围
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

extension View {
    func getRootViewController() -> UIViewController? {
        // 确保在主线程调用
        if Thread.isMainThread {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first(where: { $0.isKeyWindow }) else { return nil }
            return window.rootViewController
        } else {
            return DispatchQueue.main.sync {
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = scene.windows.first(where: { $0.isKeyWindow }) else { return nil }
                return window.rootViewController
            }
        }
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
