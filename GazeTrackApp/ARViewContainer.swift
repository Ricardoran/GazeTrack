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
        
        // 更新lookAtPoint用于测量模式（无论是否在追踪模式下都需要基础的gaze point）
        if !eyeGazeActive || (eyeGazeActive && !calibrationManager.calibrationCompleted) {
            updateDetectGazePoint(faceAnchor: faceAnchor)
        }
        
        // 如果在测量模式下，收集测量数据
        if calibrationManager.isMeasuring && calibrationManager.showCalibrationPoint {
            if let point = lookAtPoint {
                calibrationManager.collectMeasurementPoint(point)
            }
        }
        
        // 如果在追踪模式下，且校准完成，使用校准后的模型
        if eyeGazeActive {
            if calibrationManager.calibrationCompleted{
                #if DEBUG
                if arc4random_uniform(300) == 0 {
                    print("已经完成了校准，开启眼动追踪")
                }
                #endif
                calibrationManager.predictScreenPoint(from:faceAnchor)
            }
        }
//        self.configureDebugOptions()
//        self.showLocalLookVector(from: faceAnchor)
        detectWink(faceAnchor: faceAnchor)
        detectEyebrowRaise(faceAnchor: faceAnchor)
    }
    
    func detectGazePoint(faceAnchor: ARFaceAnchor)->CGPoint {
        let lookAtPoint = faceAnchor.lookAtPoint
        let focusPoint = detectGazePointAfterCalibration(faceAnchor: faceAnchor, overrideLookAtPoint: lookAtPoint)
        return focusPoint
    }

    func detectGazePointAfterCalibration(faceAnchor: ARFaceAnchor, overrideLookAtPoint: SIMD3<Float>)-> CGPoint {
        // get the lookAtPoint from faceAnchor local coordinate
        let lookAtPoint = overrideLookAtPoint
        guard let cameraTransform = session.currentFrame?.camera.transform else {
            return .zero
        }
        
        // convert the lookAtPoint from local coordinate into world coordinate
        let lookAtPointInWorld = faceAnchor.transform * simd_float4(lookAtPoint, 1)

        // convert the lookAtPoint from world coordinate into camera coordinate
        let lookAtPointInCamera = simd_mul(simd_inverse(cameraTransform), lookAtPointInWorld)
        
        // 计算focus point在手机屏幕的坐标（支持横竖屏）
        let screenX: Float
        let screenY: Float
        
        if Device.isCameraOnLeft {
            // 摄像头在左侧（landscapeRight）
            let orientationAwarePhysicalSize = Device.orientationAwareScreenSize
            let frameSize = Device.frameSize
            screenX = lookAtPointInCamera.x / (Float(orientationAwarePhysicalSize.width) / 2) * Float(frameSize.width)
            screenY = -lookAtPointInCamera.y / (Float(orientationAwarePhysicalSize.height) / 2) * Float(frameSize.height)
        } else if Device.isCameraOnRight {
            // 摄像头在右侧（landscapeLeft）
            let orientationAwarePhysicalSize = Device.orientationAwareScreenSize
            let frameSize = Device.frameSize
            screenX = -lookAtPointInCamera.x / (Float(orientationAwarePhysicalSize.width) / 2) * Float(frameSize.width)
            screenY = lookAtPointInCamera.y / (Float(orientationAwarePhysicalSize.height) / 2) * Float(frameSize.height)
        } else {
            // Portrait模式：使用原有逻辑
            screenX = lookAtPointInCamera.y / (Float(Device.screenSize.width) / 2) * Float(Device.frameSize.width)
            screenY = lookAtPointInCamera.x / (Float(Device.screenSize.height) / 2) * Float(Device.frameSize.height)
        }
        
        let focusPoint = CGPoint(
            x: CGFloat(screenX).clamped(to: Ranges.widthRange),
            y: CGFloat(screenY).clamped(to: Ranges.heightRange)
        )
        
        #if DEBUG
        if arc4random_uniform(300) == 0 {
            let safeAreaInsets = Device.getSafeAreaInsets()
            let rawFocusPoint = CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))
            
            
            print("=== 眼动追踪坐标转换调试 ===")
            print("当前方向:", Device.isCameraOnLeft ? "摄像头在左" : Device.isCameraOnRight ? "摄像头在右" : "竖屏")
            print("Camera坐标:", lookAtPointInCamera)
            if Device.isCameraOnLeft {
                let orientationAwarePhysicalSize = Device.orientationAwareScreenSize
                let bounds = UIScreen.main.bounds.size
                print("摄像头在左计算详情(使用bounds尺寸):")
                print("  - 物理尺寸:", orientationAwarePhysicalSize)
                print("  - X计算: \(lookAtPointInCamera.x) / (\(orientationAwarePhysicalSize.width)/2) * \(bounds.width) = \(screenX)")
                print("  - Y计算: -\(lookAtPointInCamera.y) / (\(orientationAwarePhysicalSize.height)/2) * \(bounds.height) = \(screenY)")
            } else if Device.isCameraOnRight {
                let orientationAwarePhysicalSize = Device.orientationAwareScreenSize
                let bounds = UIScreen.main.bounds.size
                print("摄像头在右计算详情(使用bounds尺寸):")
                print("  - 物理尺寸:", orientationAwarePhysicalSize)
                print("  - X计算: -\(lookAtPointInCamera.x) / (\(orientationAwarePhysicalSize.width)/2) * \(bounds.width) = \(screenX)")
                print("  - Y计算: \(lookAtPointInCamera.y) / (\(orientationAwarePhysicalSize.height)/2) * \(bounds.height) = \(screenY)")
            } else {
                print("竖屏计算详情:")
                print("  - 物理尺寸:", Device.screenSize)
                print("  - X计算: \(lookAtPointInCamera.y) / (\(Device.screenSize.width)/2) * \(Device.frameSize.width) = \(screenX)")
                print("  - Y计算: \(lookAtPointInCamera.x) / (\(Device.screenSize.height)/2) * \(Device.frameSize.height) = \(screenY)")
            }
            print("计算后屏幕坐标(未限制):", rawFocusPoint)
            print("focusPoint:", focusPoint)
            print("方向感知屏幕尺寸:", Device.orientationAwareScreenSize)
            print("安全区域的屏幕尺寸:", Device.frameSize)
            print("安全区域的margin:", "top=\(safeAreaInsets.top), bottom=\(safeAreaInsets.bottom), left=\(safeAreaInsets.left), right=\(safeAreaInsets.right)")
            print("X范围: \(Ranges.widthRange), Y范围: \(Ranges.heightRange)")
            print("摄像头侧边界检查:", Device.isCameraOnLeft ? "左侧边界=\(Ranges.widthRange.lowerBound)" : "右侧边界=\(Ranges.widthRange.upperBound)")
            print("=======================")

        }
        #endif
        
        return focusPoint
    }
    func updateDetectGazePoint(faceAnchor: ARFaceAnchor){
        let focusPoint=detectGazePoint(faceAnchor: faceAnchor)
        DispatchQueue.main.async {
            self.lookAtPoint = focusPoint
        }
    }
    func updateDetectGazePointAfterCalibration(faceAnchor: ARFaceAnchor,overrideLookAtPoint: SIMD3<Float>){
        let focusPoint=detectGazePointAfterCalibration(faceAnchor: faceAnchor,overrideLookAtPoint: overrideLookAtPoint)
        DispatchQueue.main.async {
            self.lookAtPoint = focusPoint
        }
    }

    func showLocalLookVector(from faceAnchor: ARFaceAnchor) {
        if let oldAnchor = self.scene.anchors.first(where: { $0.name == "localLookVectorAnchor" }) {
            self.scene.anchors.remove(oldAnchor)
        }

        let localLookAt = faceAnchor.lookAtPoint
        let vectorLength = simd_length(localLookAt)
        guard vectorLength > 0.001 else { return }

        // 🟢 起点球体（face local 原点）
        let startSphere = ModelEntity(
            mesh: .generateSphere(radius: 0.05),
            materials: [SimpleMaterial(color: .green, isMetallic: false)]
        )
        startSphere.position = [0, 0, 0]

        // ✅ 将球体添加到以 faceAnchor.transform 为变换的 anchor 上
        let anchor = AnchorEntity()
        anchor.transform.matrix = faceAnchor.transform
        anchor.name = "localLookVectorAnchor"
        anchor.addChild(startSphere)

        self.scene.anchors.append(anchor)
    }
    
    func configureDebugOptions() {
        self.debugOptions = [
            .showStatistics,         // 显示帧率和性能信息
            .showWorldOrigin,        // 显示世界坐标原点
            .showAnchorOrigins,      // 显示 Anchor 原点
            .showAnchorGeometry,     // 显示 Anchor 检测几何图形
            .showFeaturePoints,      // 显示点云信息
            .showSceneUnderstanding  // 若 iOS ≥ 13.4 且使用 Scene Reconstruction 可启用
        ]
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
    
    @MainActor @preconcurrency required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @MainActor @preconcurrency required dynamic init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
}
