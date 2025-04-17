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
        self.session.delegate = self
        let configuration = ARFaceTrackingConfiguration()
        self.session.run(configuration)
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard eyeGazeActive, let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            return
        }
        
        detectGazePoint(faceAnchor: faceAnchor)
        detectWink(faceAnchor: faceAnchor)
        detectEyebrowRaise(faceAnchor: faceAnchor)
    }
    
    private func detectGazePoint(faceAnchor: ARFaceAnchor) {
        let lookAtPoint = faceAnchor.lookAtPoint
        
        guard let cameraTransform = session.currentFrame?.camera.transform else {
            return
        }
        
        let lookAtPointInWorld = faceAnchor.transform * simd_float4(lookAtPoint, 1)
        let transformedLookAtPoint = simd_mul(simd_inverse(cameraTransform), lookAtPointInWorld)
        
        // 获取安全区域
        let safeAreaInsets = getSafeAreaInsets()
        
        // 计算屏幕坐标（仅竖屏模式）
        let screenX = transformedLookAtPoint.y / (Float(Device.screenSize.width) / 2) * Float(Device.frameSize.width)
        let screenY = transformedLookAtPoint.x / (Float(Device.screenSize.height) / 2) * Float(Device.frameSize.height)
        
        // // 使用安全区域范围限制
        // let xRange = CGFloat(safeAreaInsets.left)...CGFloat(UIScreen.main.bounds.width - safeAreaInsets.right)
        // let yRange = CGFloat(safeAreaInsets.top)...CGFloat(UIScreen.main.bounds.height - safeAreaInsets.bottom)
        
        let focusPoint = CGPoint(
            x: CGFloat(screenX).clamped(to: Ranges.widthRange),
            y: CGFloat(screenY).clamped(to: Ranges.heightRange)
        )
        
        DispatchQueue.main.async {
            self.lookAtPoint = focusPoint
        }
    }
    
    private func getSafeAreaInsets() -> UIEdgeInsets {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets
        }
        return UIEdgeInsets.zero
    }
    
    private func detectWink(faceAnchor: ARFaceAnchor) {
        let blendShapes = faceAnchor.blendShapes
        
        if let leftEyeBlink = blendShapes[.eyeBlinkLeft] as? Float,
           let rightEyeBlink = blendShapes[.eyeBlinkRight] as? Float {
            isWinking = leftEyeBlink > 0.9 && rightEyeBlink > 0.9
        }
    }
    
    private func detectEyebrowRaise(faceAnchor: ARFaceAnchor) {
        let browInnerUp = faceAnchor.blendShapes[.browInnerUp] as? Float ?? 0.0
        let eyebrowRaiseThreshold: Float = 0.1
        isWinking = browInnerUp > eyebrowRaiseThreshold
    }
    
    @MainActor required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @MainActor required dynamic init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
}
