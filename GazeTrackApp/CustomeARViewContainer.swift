//  CustomARViewContainer.swift
//  Eye-Tracker
//
//  Created by Haoran Zhang on 03/07 2025.
//
//  A custom AR view container that handles face tracking and eye gaze detection
//  This component integrates ARKit face tracking to enable eye gaze tracking
//  and facial expression detection features
//

import SwiftUI
import ARKit
import RealityKit

struct CustomARViewContainer: UIViewRepresentable {
    
    @Binding var eyeGazeActive: Bool
    @Binding var lookAtPoint: CGPoint?
    @Binding var isWinking: Bool
    
    func makeUIView(context: Context) -> CustomARView {
        return CustomARView(eyeGazeActive: $eyeGazeActive, lookAtPoint: $lookAtPoint, isWinking: $isWinking)
    }
    
    func updateUIView(_ uiView: CustomARView, context: Context) {}
}


class CustomARView: ARView, ARSessionDelegate {
    
    @Binding var eyeGazeActive: Bool
    @Binding var lookAtPoint: CGPoint?
    @Binding var isWinking: Bool
    
    init(eyeGazeActive: Binding<Bool>, lookAtPoint: Binding<CGPoint?>, isWinking: Binding<Bool>) {
        _eyeGazeActive = eyeGazeActive
        _lookAtPoint = lookAtPoint
        _isWinking = isWinking
        
        super.init(frame: .zero)
        
    //    self.debugOptions = [.showAnchorOrigins]
        
        self.session.delegate = self
        
        let configuration = ARFaceTrackingConfiguration()
        self.session.run(configuration)
    }
    
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        
        guard eyeGazeActive, let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            return
        }
        
        /// 1. Locate Gaze point
        detectGazePoint(faceAnchor: faceAnchor)
        // eyeGazeActive.toggle()
        
        /// 2. Detect winks
         detectWink(faceAnchor: faceAnchor)
        
        /// 3. Detect eyebrow raise
        detectEyebrowRaise(faceAnchor: faceAnchor)
    }
    
    private func detectGazePoint(faceAnchor: ARFaceAnchor) {
        let lookAtPoint = faceAnchor.lookAtPoint
        
        guard let cameraTransform = session.currentFrame?.camera.transform else {
            return
        }
        
        let lookAtPointInWorld = faceAnchor.transform * simd_float4(lookAtPoint, 1)
        
        let transformedLookAtPoint = simd_mul(simd_inverse(cameraTransform), lookAtPointInWorld)
        
        // 获取界面方向
        let interfaceOrientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
        
        // 根据界面方向调整坐标计算
        var screenX: Float = 0
        var screenY: Float = 0
        
        // 获取屏幕尺寸
        let screenBounds = UIScreen.main.bounds
        let screenWidth = Float(screenBounds.width)
        let screenHeight = Float(screenBounds.height)
        
        switch interfaceOrientation {
        case .landscapeLeft:
            // 横屏左模式下的坐标映射
            screenX = transformedLookAtPoint.x / (Float(Device.screenSize.height) / 2) * Float(Device.frameSize.height)
            screenY = -transformedLookAtPoint.y / (Float(Device.screenSize.width) / 2) * Float(Device.frameSize.width)  // 需要取反
            
            // // 调整映射关系
            // let tempX = screenX
            // screenX = screenY                // Y轴直接变成X轴（方向已经正确）
            // screenY = tempX                  // X轴变成Y轴
            
                    
        case .landscapeRight:
            // 横屏右模式下的坐标映射
            screenX = -transformedLookAtPoint.x / (Float(Device.screenSize.height) / 2) * Float(Device.frameSize.height)
            screenY = transformedLookAtPoint.y / (Float(Device.screenSize.width) / 2) * Float(Device.frameSize.width) 
            
        default:
            // 竖屏模式保持不变
            screenX = transformedLookAtPoint.y / (Float(Device.screenSize.width) / 2) * Float(Device.frameSize.width)
            screenY = transformedLookAtPoint.x / (Float(Device.screenSize.height) / 2) * Float(Device.frameSize.height)
        }
        
        // 根据屏幕方向设置范围限制
        let xRange: ClosedRange<CGFloat>
        let yRange: ClosedRange<CGFloat>
        
        if interfaceOrientation.isLandscape {
            xRange = 0...CGFloat(screenHeight)
            yRange = 0...CGFloat(screenWidth)
            print("isLandscape: \(interfaceOrientation.isLandscape)", "xRange: \(xRange)")
            print("isLandscape: \(interfaceOrientation.isLandscape)", "yRange: \(yRange)")
        } else {
            xRange = 0...CGFloat(screenWidth)
            yRange = 0...CGFloat(screenHeight)
            print("isLandscape: \(interfaceOrientation.isLandscape)", "xRange: \(xRange)")
            print("isLandscape: \(interfaceOrientation.isLandscape)", "yRange: \(yRange)")
        }
        
        // 使用 Ranges 结构体处理不同方向的范围限制
        let focusPoint = CGPoint(
            x: CGFloat(screenX).clamped(to: Ranges.widthRange),
            y: CGFloat(screenY).clamped(to: Ranges.heightRange)
        )
        
        DispatchQueue.main.async {
            self.lookAtPoint = focusPoint
        }
    }
    
    private func detectWink(faceAnchor: ARFaceAnchor) {
        
        let blendShapes = faceAnchor.blendShapes
        
        if let leftEyeBlink = blendShapes[.eyeBlinkLeft] as? Float,
           let rightEyeBlink = blendShapes[.eyeBlinkRight] as? Float {
            if leftEyeBlink > 0.9 && rightEyeBlink > 0.9 {
                isWinking = true
            } else {
                isWinking = false
            }
        }
    }
    
    private func detectEyebrowRaise(faceAnchor: ARFaceAnchor){
        
        let browInnerUp = faceAnchor.blendShapes[.browInnerUp] as? Float ?? 0.0
        
        let eyebrowRaiseThreshold: Float = 0.1
        
        let isEyebrowRaised = browInnerUp > eyebrowRaiseThreshold
        
        if isEyebrowRaised {
            isWinking = true
        }else{
            isWinking = false
        }
    }
    
    @MainActor required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @MainActor required dynamic init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
}
