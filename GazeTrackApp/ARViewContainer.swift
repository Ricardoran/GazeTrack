//  ARViewContainer.swift
//  Eye-Tracker
//
//  Created by Haoran Zhang on 03/07 2025.
//
//  A AR view container that handles face tracking and eye gaze detection
//  This component integrates ARKit face tracking to enable eye gaze tracking
//  and facial expression detection features
//

import SwiftUI
import ARKit
import RealityKit

struct ARViewContainer: UIViewRepresentable {
    @Binding var eyeGazeActive: Bool
    @Binding var lookAtPoint: CGPoint?
    @Binding var isWinking: Bool
    @StateObject var calibrationManager: CalibrationManager  // 添加校准管理器
    
    func makeUIView(context: Context) -> CustomARView {
        return CustomARView(
            eyeGazeActive: $eyeGazeActive,
            lookAtPoint: $lookAtPoint,
            isWinking: $isWinking,
            calibrationManager: calibrationManager
        )
    }
    
    func updateUIView(_ uiView: CustomARView, context: Context) {}
}

class CustomARView: ARView, ARSessionDelegate {
    @Binding var eyeGazeActive: Bool
    @Binding var lookAtPoint: CGPoint?
    @Binding var isWinking: Bool
    var calibrationManager: CalibrationManager
    
    init(eyeGazeActive: Binding<Bool>,
         lookAtPoint: Binding<CGPoint?>,
         isWinking: Binding<Bool>,
         calibrationManager: CalibrationManager) {
        self.calibrationManager = calibrationManager
        _eyeGazeActive = eyeGazeActive
        _lookAtPoint = lookAtPoint
        _isWinking = isWinking
        super.init(frame: .zero)
        //self.debugOptions = [.showAnchorOrigins]
        self.session.delegate = self
        calibrationManager.arView = self  // 将ARView传递给校准管理器
        let configuration = ARFaceTrackingConfiguration()
        self.session.run(configuration)
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            return
        }
        
        // 如果在校准模式下，收集校准数据
        if calibrationManager.isCalibrating {
            calibrationManager.collectGazeVector(from:faceAnchor)
        }
        
        // 更新lookAtPoint（无论在什么模式下）
        updateDetectGazePoint(faceAnchor: faceAnchor)
        
        // 如果在测量模式下，收集测量数据
        if calibrationManager.isMeasuring && calibrationManager.showCalibrationPoint {
            if let point = lookAtPoint {
                calibrationManager.collectMeasurementPoint(point)
            }
        }
        
        // 如果在追踪模式下，使用校准后的模型
        if eyeGazeActive {
            if calibrationManager.calibrationCompleted{
                print("已经完成了校准，开始追踪模式")
                calibrationManager.predictScreenPoint(from:faceAnchor)

            } else {
                // 如果没有校准或校准失败，使用原始坐标计算方法
                print("没有完成校准，使用原始坐标计算方法")
                updateDetectGazePoint(faceAnchor: faceAnchor)
            }
        }
        // 显示注视向量
        // self.showLocalLookVector(from: faceAnchor)        
        detectWink(faceAnchor: faceAnchor)
        detectEyebrowRaise(faceAnchor: faceAnchor)
    }
    
    //使用重载的方法使得允许传入自定义向量
    func detectGazePoint(faceAnchor: ARFaceAnchor)->CGPoint {
        let lookAtPoint = faceAnchor.lookAtPoint
        let focusPoint=detectGazePoint(faceAnchor: faceAnchor, overrideLookAtPoint: lookAtPoint)
        return focusPoint
    }

    func detectGazePoint(faceAnchor: ARFaceAnchor, overrideLookAtPoint: SIMD3<Float>)-> CGPoint {
        // get the lookAtPoint from faceAnchor local coordinate
        let lookAtPoint = overrideLookAtPoint
        guard let cameraTransform = session.currentFrame?.camera.transform else {
            return .zero
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
        return focusPoint
    }
    // 对lookAtPoint进行屏幕校准（AR以右上角为原点，UIkit以左上角因此需要对换）
    func adjustScreenPoint(_ point: CGPoint) -> CGPoint {
        guard let orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation else {
            return point
        }

        let size = UIScreen.main.bounds.size
        let adjusted: CGPoint

        // UIKit 以左上角为原点，ARKit 以右上角为原点，方向需转换
        switch orientation {
        case .landscapeRight, .landscapeLeft:
            adjusted = CGPoint(x: size.width - point.x, y: size.height - point.y)
        case .portrait, .portraitUpsideDown:
            adjusted = CGPoint(x: size.width - point.x, y: size.height - point.y)
        default:
            assertionFailure("Unknown orientation")
            return point
        }

        return adjusted
    }
    func updateCGPoint(faceAnchor: ARFaceAnchor) -> CGPoint {
        guard let frame = self.session.currentFrame else { return .zero }
        guard let orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation else { return .zero }

        let lookAtVector = faceAnchor.lookAtPoint
        let worldLookAt = faceAnchor.transform * SIMD4<Float>(lookAtVector, 1)

        let projected = frame.camera.projectPoint(
            SIMD3<Float>(worldLookAt.x, worldLookAt.y, worldLookAt.z),
            orientation: orientation,
            viewportSize: UIScreen.main.bounds.size
        )

        // ✅ 关键：人为缩放以增强可视响应
        let scaleFactor: CGFloat = 9 // 推荐 1.5～3.0
        let center = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
        let relative = CGPoint(x: projected.x - center.x, y: projected.y - center.y)

        let scaled = CGPoint(
            x: center.x + relative.x * scaleFactor,
            y: center.y + relative.y * scaleFactor
        )
        let adjusted = adjustScreenPoint(scaled)

        let clamped = CGPoint(
            x: adjusted.x.clamped(to: Ranges.widthRange),
            y: adjusted.y.clamped(to: Ranges.heightRange)
        )

        DispatchQueue.main.async {
            self.lookAtPoint = clamped
        }

        return clamped
    }



    func updateDetectGazePoint(faceAnchor: ARFaceAnchor){
        let focusPoint=detectGazePoint(faceAnchor: faceAnchor)
        DispatchQueue.main.async {
            self.lookAtPoint = focusPoint
        }
    }
    func updateDetectGazePoint(faceAnchor: ARFaceAnchor,overrideLookAtPoint: SIMD3<Float>){
        let focusPoint=detectGazePoint(faceAnchor: faceAnchor,overrideLookAtPoint: overrideLookAtPoint)
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
    // 4debug 显示faceAnchor的gaze射线
    /// 可视化 faceAnchor 的局部注视向量（相对于 face 原点）
    /*
    func showLocalLookVector(from faceAnchor: ARFaceAnchor) {
        if let oldAnchor = self.scene.anchors.first(where: { $0.name == "localLookVectorAnchor" }) {
            self.scene.anchors.remove(oldAnchor)
        }

        let localLookAt = faceAnchor.lookAtPoint
        let vectorLength = simd_length(localLookAt)
        guard vectorLength > 0.001 else { return }

        // 🟢 起点球体（face local 原点）
        let startSphere = ModelEntity(
            mesh: .generateSphere(radius: 0.006),
            materials: [SimpleMaterial(color: .green, isMetallic: false)]
        )
        startSphere.position = [0, 0, 0]

        // ✅ 将球体添加到以 faceAnchor.transform 为变换的 anchor 上
        let anchor = AnchorEntity()
        anchor.transform.matrix = faceAnchor.transform
        anchor.name = "localLookVectorAnchor"
        anchor.addChild(startSphere)

        self.scene.anchors.append(anchor)

        print("🟢 显示 face 原点球体 ✅ gazeLength=\(vectorLength)")
    }
    */

    @MainActor required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @MainActor required dynamic init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
}
