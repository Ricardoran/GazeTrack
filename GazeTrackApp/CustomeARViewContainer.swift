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
        // get the lookAtPoint from faceAnchor local coordinate
        let lookAtPoint = faceAnchor.lookAtPoint
        
        guard let cameraTransform = session.currentFrame?.camera.transform else {
            return
        }
        
        // convert the lookAtPoint from local coordinate into world coordinate
        let lookAtPointInWorld = faceAnchor.transform * simd_float4(lookAtPoint, 1)

        // convert the lookAtPoint from world coordinate into camera coordinate
        let lookAtPointInCamera = simd_mul(simd_inverse(cameraTransform), lookAtPointInWorld)
        
        // 计算focus point在手机屏幕的坐标（仅竖屏模式）
        let screenX = lookAtPointInCamera.y / (Float(Device.screenSize.width) / 2) * Float(Device.frameSize.width)
        let screenY = lookAtPointInCamera.x / (Float(Device.screenSize.height) / 2) * Float(Device.frameSize.height)
        
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
