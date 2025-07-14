import Foundation
import CoreGraphics
import Combine

class DoubleEyesTrackManager: ObservableObject {
    @Published var leftEyeGaze: CGPoint = CGPoint.zero
    @Published var rightEyeGaze: CGPoint = CGPoint.zero
    @Published var averageGaze: CGPoint = CGPoint.zero
    @Published var isTracking: Bool = false
    @Published var currentEyeToScreenDistance: Float = 30.0 // 默认30cm
    
    // 使用SimpleGazeSmoothing进行平滑处理
    private let leftEyeSmoothing = SimpleGazeSmoothing(windowSize: 10)
    private let rightEyeSmoothing = SimpleGazeSmoothing(windowSize: 10)
    
    init() {
        resetTracking()
    }
    
    func startTracking() {
        isTracking = true
    }
    
    func stopTracking() {
        isTracking = false
    }
    
    func resetTracking() {
        leftEyeGaze = CGPoint.zero
        rightEyeGaze = CGPoint.zero
        averageGaze = CGPoint.zero
        leftEyeSmoothing.reset()
        rightEyeSmoothing.reset()
    }
    
    func updateEyeGaze(leftEye: CGPoint, rightEye: CGPoint) {
        // 使用SimpleGazeSmoothing进行平滑处理
        leftEyeGaze = leftEyeSmoothing.addPoint(leftEye)
        rightEyeGaze = rightEyeSmoothing.addPoint(rightEye)
        
        // Calculate average between both eyes
        averageGaze = CGPoint(
            x: (leftEyeGaze.x + rightEyeGaze.x) / 2,
            y: (leftEyeGaze.y + rightEyeGaze.y) / 2
        )
    }
    
    /// 动态更新平滑窗口大小
    func updateSmoothingWindowSize(_ windowSize: Int) {
        leftEyeSmoothing.updateWindowSize(windowSize)
        rightEyeSmoothing.updateWindowSize(windowSize)
    }
    
    /// 更新眼睛到屏幕距离
    func updateEyeToScreenDistance(_ distance: Float) {
        currentEyeToScreenDistance = distance
    }
    
}