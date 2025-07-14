import SwiftUI
import SceneKit
import ARKit

struct DoubleEyesARViewContainer: UIViewRepresentable {
    let manager: DoubleEyesTrackManager
    @Binding var smoothingWindowSize: Int
    
    func makeUIView(context: Context) -> DoubleEyesARSCNView {
        let arView = DoubleEyesARSCNView(manager: manager, smoothingWindowSize: smoothingWindowSize)
        return arView
    }
    
    func updateUIView(_ uiView: DoubleEyesARSCNView, context: Context) {
        uiView.updateSmoothingWindowSize(smoothingWindowSize)
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
    
    init(manager: DoubleEyesTrackManager, smoothingWindowSize: Int) {
        self.manager = manager
        self.gazeSmoothing = SimpleGazeSmoothing(windowSize: smoothingWindowSize)
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
    
    // 完全复制原repo的hitTest实现
    func hitTest() {
        var leftEyeLocation = CGPoint()
        var rightEyeLocation = CGPoint()

        let leftEyeResult = nodeInFrontOfScreen.hitTestWithSegment(from: endPointLeftEye.worldPosition,
                                                      to: leftEyeNode.worldPosition,
                                                      options: nil)

        let rightEyeResult = nodeInFrontOfScreen.hitTestWithSegment(from: endPointRightEye.worldPosition,
                                                       to: rightEyeNode.worldPosition,
                                                       options: nil)

        if leftEyeResult.count > 0 || rightEyeResult.count > 0 {
            // 修改guard条件 - 只要有一个眼睛有结果就处理
            if leftEyeResult.count > 0 && rightEyeResult.count > 0,
               let leftResult = leftEyeResult.first, 
               let rightResult = rightEyeResult.first {

            // 使用缓存的Device配置进行坐标转换
            
            // 使用我们的转换公式：localCoordinates / (screenSize/2) * frameSize
            leftEyeLocation.x = CGFloat(leftResult.localCoordinates.x) / (deviceScreenSize.width / 2) * deviceFrameSize.width
            leftEyeLocation.y = CGFloat(leftResult.localCoordinates.y) / (deviceScreenSize.height / 2) * deviceFrameSize.height

            rightEyeLocation.x = CGFloat(rightResult.localCoordinates.x) / (deviceScreenSize.width / 2) * deviceFrameSize.width
            rightEyeLocation.y = CGFloat(rightResult.localCoordinates.y) / (deviceScreenSize.height / 2) * deviceFrameSize.height

            // 使用缓存的边界范围进行限制
            let leftPoint = CGPoint(
                x: CGFloat(leftEyeLocation.x).clamped(to: widthRange),
                y: CGFloat(-leftEyeLocation.y).clamped(to: heightRange) // 使用负Y
            )
            
            let rightPoint = CGPoint(
                x: CGFloat(rightEyeLocation.x).clamped(to: widthRange),
                y: CGFloat(-rightEyeLocation.y).clamped(to: heightRange) // 使用负Y
            )

            let averagePoint: CGPoint = {
                let pointX = (leftEyeLocation.x + rightEyeLocation.x) / 2
                let pointY = -(leftEyeLocation.y + rightEyeLocation.y) / 2 // 使用负Y

                // 使用缓存的边界范围进行限制
                return CGPoint(
                    x: CGFloat(pointX).clamped(to: widthRange),
                    y: CGFloat(pointY).clamped(to: heightRange)
                )
            }()

                
                setNewPoint(leftPoint: leftPoint, rightPoint: rightPoint, averagePoint: averagePoint)
            }
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

        leftEyeNode.simdTransform = faceAnchor.leftEyeTransform
        rightEyeNode.simdTransform = faceAnchor.rightEyeTransform

        faceGeometry.update(from: faceAnchor.geometry)
        hitTest()
    }
}
