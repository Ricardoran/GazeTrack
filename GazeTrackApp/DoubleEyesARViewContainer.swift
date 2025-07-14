import SwiftUI
import SceneKit
import ARKit

struct DoubleEyesARViewContainer: UIViewRepresentable {
    let manager: DoubleEyesTrackManager
    @Binding var smoothingWindowSize: Int
    @Binding var useLookAtPointMethod: Bool
    
    func makeUIView(context: Context) -> DoubleEyesARSCNView {
        let arView = DoubleEyesARSCNView(manager: manager, smoothingWindowSize: smoothingWindowSize, useLookAtPointMethod: useLookAtPointMethod)
        return arView
    }
    
    func updateUIView(_ uiView: DoubleEyesARSCNView, context: Context) {
        uiView.updateSmoothingWindowSize(smoothingWindowSize)
        uiView.updateTrackingMethod(useLookAtPointMethod)
    }
}

class DoubleEyesARSCNView: ARSCNView, ARSCNViewDelegate {
    private let manager: DoubleEyesTrackManager
    private let configuration = ARFaceTrackingConfiguration()
    
    // 缓存Device配置，避免在后台线程访问
    private let deviceScreenSize: CGSize
    private let deviceFrameSize: CGSize
    private let widthRange: ClosedRange<CGFloat>
    private let heightRange: ClosedRange<CGFloat>
    
    // Eye nodes - 完全复制原repo的实现
    var leftEyeNode: SCNNode = {
        let geometry = SCNCone(topRadius: 0.005, bottomRadius: 0, height: 0.1)
        geometry.radialSegmentCount = 3
        geometry.firstMaterial?.diffuse.contents = UIColor.red
        let node = SCNNode()
        node.geometry = geometry
        node.eulerAngles.x = -.pi / 2
        node.position.z = 0.1
        let parentNode = SCNNode()
        parentNode.addChildNode(node)
        return parentNode
    }()

    var rightEyeNode: SCNNode = {
        let geometry = SCNCone(topRadius: 0.005, bottomRadius: 0, height: 0.1)
        geometry.radialSegmentCount = 3
        geometry.firstMaterial?.diffuse.contents = UIColor.blue
        let node = SCNNode()
        node.geometry = geometry
        node.eulerAngles.x = -.pi / 2
        node.position.z = 0.1
        let parentNode = SCNNode()
        parentNode.addChildNode(node)
        return parentNode
    }()

    var endPointLeftEye: SCNNode = {
        let node = SCNNode()
        node.position.z = 2
        return node
    }()

    var endPointRightEye: SCNNode = {
        let node = SCNNode()
        node.position.z = 2
        return node
    }()

    var nodeInFrontOfScreen: SCNNode = {
        let screenGeometry = SCNPlane(width: 1, height: 1)
        screenGeometry.firstMaterial?.isDoubleSided = true
        screenGeometry.firstMaterial?.fillMode = .fill
        screenGeometry.firstMaterial?.diffuse.contents = UIColor.green.withAlphaComponent(0.5)

        let node = SCNNode()
        node.geometry = screenGeometry
        // 不设置position，让它相对于pointOfView定位
        return node
    }()
    
    // 使用SimpleGazeSmoothing进行平滑处理
    private let gazeSmoothing: SimpleGazeSmoothing
    private var useLookAtPointMethod: Bool
    
    init(manager: DoubleEyesTrackManager, smoothingWindowSize: Int, useLookAtPointMethod: Bool) {
        self.manager = manager
        self.gazeSmoothing = SimpleGazeSmoothing(windowSize: smoothingWindowSize)
        self.useLookAtPointMethod = useLookAtPointMethod
        // 在主线程初始化时缓存Device配置和范围
        self.deviceScreenSize = Device.screenSize
        self.deviceFrameSize = Device.frameSize
        self.widthRange = Ranges.widthRange
        self.heightRange = Ranges.heightRange
        super.init(frame: .zero, options: nil)
        setupARSCNView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupARSCNView() {
        guard ARFaceTrackingConfiguration.isSupported else {
            print("❌ Face tracking is not supported on this device")
            return
        }
        
        delegate = self
        session.run(configuration)
        
        // 延迟添加节点，确保pointOfView已经设置
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pointOfView?.addChildNode(self.nodeInFrontOfScreen)
        }
    }
    
    // 存储当前的faceAnchor，在didUpdate中更新
    private var currentFaceAnchor: ARFaceAnchor?
    
    // 主入口：根据设置选择方法
    func hitTest() {
        if useLookAtPointMethod {
            hitTestWithLookAtPoint()
        } else {
            hitTestWithDualEyes()
        }
    }
    
    // 方法A: lookAtPoint + hitTestWithSegment
    private func hitTestWithLookAtPoint() {
        guard let faceAnchor = currentFaceAnchor else {
            return
        }
        
        // 使用ARKit的lookAtPoint (面部坐标系中的3D点，不是方向)
        let lookAtPoint = faceAnchor.lookAtPoint
        
        // 正确方法：创建从面部中心指向lookAtPoint的射线
        // 面部中心在面部坐标系中是原点 (0,0,0)
        let faceOrigin = SIMD3<Float>(0, 0, 0)
        
        // lookAtPoint就是目标点，我们需要延长这个向量
        let lookDirection = simd_normalize(lookAtPoint - faceOrigin)  // 正确的方向向量
        
        // 创建射线：从面部中心开始，沿lookDirection延伸
        let rayStart = faceOrigin
        let rayEnd = faceOrigin + lookDirection * 2.0  // 延长2米
        
        // 将面部坐标系的射线转换到世界坐标系
        let worldRayStart = faceAnchor.transform * simd_float4(rayStart, 1)
        let worldRayEnd = faceAnchor.transform * simd_float4(rayEnd, 1)
        
        // 使用hitTestWithSegment投影到屏幕
        let hitResult = nodeInFrontOfScreen.hitTestWithSegment(
            from: SCNVector3(worldRayStart.x, worldRayStart.y, worldRayStart.z),
            to: SCNVector3(worldRayEnd.x, worldRayEnd.y, worldRayEnd.z),
            options: nil
        )
        
        if let result = hitResult.first {
            // 转换hitTest结果到屏幕坐标，分两步处理Y坐标(与双眼方法一致)
            let rawHitLocation = CGPoint(
                x: CGFloat(result.localCoordinates.x) / (deviceScreenSize.width / 2) * deviceFrameSize.width,
                y: CGFloat(result.localCoordinates.y) / (deviceScreenSize.height / 2) * deviceFrameSize.height
            )
            
            // 边界限制，Y坐标需要取负值(与双眼方法一致)
            let clampedPoint = CGPoint(
                x: rawHitLocation.x.clamped(to: widthRange),
                y: (-rawHitLocation.y).clamped(to: heightRange)
            )
            
            // 临时debug输出
            if arc4random_uniform(60) == 0 { // 每秒输出一次
                print("🔍 [LOOKATPOINT+HITTEST DEBUG]")
                print("lookAtPoint:", lookAtPoint)
                print("lookDirection:", lookDirection)
                print("worldRayStart:", worldRayStart)
                print("worldRayEnd:", worldRayEnd)
                print("hitResult localCoordinates:", result.localCoordinates)
                print("deviceScreenSize:", deviceScreenSize)
                print("deviceFrameSize:", deviceFrameSize)
                print("widthRange:", widthRange)
                print("heightRange:", heightRange)
                print("rawHitLocation (before Y negation):", rawHitLocation)
                print("clampedPoint (after Y negation & clamp):", clampedPoint)
                print("================")
            }
            
            // 对于lookAtPoint方法，左右眼点相同
            setNewPoint(leftPoint: clampedPoint, rightPoint: clampedPoint, averagePoint: clampedPoint)
        } else {
            // 没有hitTest结果
            if arc4random_uniform(120) == 0 { // 每2秒输出一次
                print("❌ [LOOKATPOINT+HITTEST] No hit result found")
                print("lookAtPoint:", lookAtPoint)
                print("lookDirection:", lookDirection)
            }
        }
    }
    
    // 方法B: 双眼分别计算 + hitTestWithSegment (原始方法)
    private func hitTestWithDualEyes() {
        var leftEyeLocation = CGPoint()
        var rightEyeLocation = CGPoint()

        let leftEyeResult = nodeInFrontOfScreen.hitTestWithSegment(from: endPointLeftEye.worldPosition,
                                                      to: leftEyeNode.worldPosition,
                                                      options: nil)

        let rightEyeResult = nodeInFrontOfScreen.hitTestWithSegment(from: endPointRightEye.worldPosition,
                                                       to: rightEyeNode.worldPosition,
                                                       options: nil)

        if leftEyeResult.count > 0 && rightEyeResult.count > 0,
           let leftResult = leftEyeResult.first, 
           let rightResult = rightEyeResult.first {

            // 使用缓存的Device配置进行坐标转换
            leftEyeLocation.x = CGFloat(leftResult.localCoordinates.x) / (deviceScreenSize.width / 2) * deviceFrameSize.width
            leftEyeLocation.y = CGFloat(leftResult.localCoordinates.y) / (deviceScreenSize.height / 2) * deviceFrameSize.height

            rightEyeLocation.x = CGFloat(rightResult.localCoordinates.x) / (deviceScreenSize.width / 2) * deviceFrameSize.width
            rightEyeLocation.y = CGFloat(rightResult.localCoordinates.y) / (deviceScreenSize.height / 2) * deviceFrameSize.height

            // 使用缓存的边界范围进行限制
            let leftPoint = CGPoint(
                x: CGFloat(leftEyeLocation.x).clamped(to: widthRange),
                y: CGFloat(-leftEyeLocation.y).clamped(to: heightRange)
            )
            
            let rightPoint = CGPoint(
                x: CGFloat(rightEyeLocation.x).clamped(to: widthRange),
                y: CGFloat(-rightEyeLocation.y).clamped(to: heightRange)
            )

            let averagePoint: CGPoint = {
                let pointX = (leftEyeLocation.x + rightEyeLocation.x) / 2
                let pointY = -(leftEyeLocation.y + rightEyeLocation.y) / 2

                return CGPoint(
                    x: CGFloat(pointX).clamped(to: widthRange),
                    y: CGFloat(pointY).clamped(to: heightRange)
                )
            }()

            setNewPoint(leftPoint: leftPoint, rightPoint: rightPoint, averagePoint: averagePoint)
        }
    }
    
    private func setNewPoint(leftPoint: CGPoint, rightPoint: CGPoint, averagePoint: CGPoint) {

        DispatchQueue.main.async {
            // 分别设置左右眼和平均点
            self.manager.updateEyeGaze(leftEye: leftPoint, rightEye: rightPoint)
        }
    }
    
    /// 更新平滑窗口大小
    func updateSmoothingWindowSize(_ windowSize: Int) {
        gazeSmoothing.updateWindowSize(windowSize)
    }
    
    /// 更新追踪方法
    func updateTrackingMethod(_ useLookAtPoint: Bool) {
        useLookAtPointMethod = useLookAtPoint
    }
    
}

// MARK: - ARSCNViewDelegate
extension DoubleEyesARSCNView {
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let device = device else {
            return nil
        }

        let faceGeometry = ARSCNFaceGeometry(device: device)
        let node = SCNNode(geometry: faceGeometry)
        node.geometry?.firstMaterial?.fillMode = .lines

        node.addChildNode(leftEyeNode)
        leftEyeNode.addChildNode(endPointLeftEye)
        node.addChildNode(rightEyeNode)
        rightEyeNode.addChildNode(endPointRightEye)

        return node
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor,
              let faceGeometry = node.geometry as? ARSCNFaceGeometry else {
                return
        }

        // 存储当前faceAnchor供hitTest使用
        currentFaceAnchor = faceAnchor
        
        leftEyeNode.simdTransform = faceAnchor.leftEyeTransform
        rightEyeNode.simdTransform = faceAnchor.rightEyeTransform

        faceGeometry.update(from: faceAnchor.geometry)
        hitTest()
    }
}
