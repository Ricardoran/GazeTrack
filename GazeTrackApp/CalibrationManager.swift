import SwiftUI
import ARKit

// 校准数据结构
struct CalibrationPoint {
    let position: CGPoint
    let gazeVectors: [SIMD3<Float>]
}
// 修正后的数据结构
struct CorrectPoint{
    let position: CGPoint
    let correctedgazeVectors: [SIMD3<Float>]
}

class CalibrationManager: ObservableObject {
    @Published var isCalibrating: Bool = false
    @Published var currentPointIndex: Int = 0
    @Published var calibrationCompleted: Bool = false
    @Published var showCalibrationPoint: Bool = false
    @Published var temporaryMessage: String? = nil
    
    weak var arView: CustomARView?
    var isCollecting: Bool = false
    
    
    // 9 个校准点，分布为 3x3 网格
    private let calibrationPositions: [(x: CGFloat, y: CGFloat)] = [
        (0.1, 0.1),  // 左上
        (0.5, 0.1),  // 上中
        (0.9, 0.1),  // 右上
        (0.1, 0.5),  // 左中
        (0.5, 0.5),  // 中心
        (0.9, 0.5),  // 右中
        (0.1, 0.9),  // 左下
        (0.5, 0.9),  // 下中
        (0.9, 0.9)   // 右下
    ]
    
    private var calibrationPoints: [CalibrationPoint] = []
    private var currentPointGazeVectors: [SIMD3<Float>] = []
    private var CorrectPoints: [CorrectPoint] = []
    var faceAnchorCalibration: ARFaceAnchor?
    
    // 获取当前校准点的屏幕坐标
    var currentCalibrationPoint: CGPoint? {
        guard currentPointIndex < calibrationPositions.count else { return nil }
        let position = calibrationPositions[currentPointIndex]
        let frameSize = Device.frameSize
        return CGPoint(x: position.x * frameSize.width,
                       y: position.y * frameSize.height)
    }
    
    // 开始校准过程
    func startCalibration() {
        isCalibrating = true
        currentPointIndex = 0
        calibrationPoints.removeAll()
        calibrationCompleted = false
        showCalibrationPoint = true
        showNextCalibrationPoint()
    }
    
    
    // 收集校准数据
    func collectGazeVector(from faceAnchor: ARFaceAnchor) {
        guard isCalibrating && isCollecting else { return }
        // 取出 gaze 向量
        self.faceAnchorCalibration = faceAnchor
        let vector = faceAnchor.lookAtPoint
        currentPointGazeVectors.append(vector)
    }

    
    private func showNextCalibrationPoint() {
        guard currentPointIndex < calibrationPositions.count else {
            finishCalibration()
            return
        }
        
        currentPointGazeVectors.removeAll()
        showCalibrationPoint = true
        self.isCollecting = true
        
        // 延长每个点的显示时间到3秒，给用户足够时间注视
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // 检查校准是否仍在进行
            guard self.isCalibrating else { return }
            
            self.isCollecting = false
            if let currentPoint = self.currentCalibrationPoint {
                // 只有当收集到足够的数据时才继续
                if self.currentPointGazeVectors.count >= 30 { // 至少收集30个采样点
                    self.calibrationPoints.append(
                        CalibrationPoint(
                            position: currentPoint,
                            gazeVectors: self.currentPointGazeVectors
                        )
                    )
                    self.currentPointGazeVectors.removeAll()
                    self.temporaryMessage = "⏱ 5秒等待结束，开始执行校准，请使用余光注视，使光标移动至校准点并等待完成"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        guard self.isCalibrating else { return }
                        self.temporaryMessage = nil
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        guard self.isCalibrating else { return }
                        self.isCollecting = true
                        self.correctprocess()
                    }

                } else {
                    print("数据采集不足，重新采集当前点")
                    self.currentPointGazeVectors.removeAll()
                    self.showNextCalibrationPoint()
                }
            }
        }
        // 开始倒计时，停止收集数据，3秒等待，用户调整自己的视线。

    }
    private func correctprocess() { 
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // 检查校准是否仍在进行
            guard self.isCalibrating else { return }
            
            if let currentPoint = self.currentCalibrationPoint {
                if self.currentPointGazeVectors.count >= 30 {
                    guard let faceAnchor = self.faceAnchorCalibration else { return  }
                    let avgVector = self.currentPointGazeVectors.reduce(SIMD3<Float>(repeating: 0.0), +) / SIMD3<Float>(repeating: Float(self.currentPointGazeVectors.count))
                    guard let arView = self.arView else { 
                        print("ARView 未初始化")
                        return
                    }
                    let focusPoint = arView.detectGazePointAfterCalibration(faceAnchor:faceAnchor,overrideLookAtPoint:avgVector)
                    let distance = sqrt(pow(focusPoint.x-currentPoint.x, 2) + pow(focusPoint.y-currentPoint.y, 2))
                    if distance < 50{
                        print("已对齐校准点。")
                        self.CorrectPoints.append(
                            CorrectPoint(
                                position: currentPoint,
                                correctedgazeVectors: self.currentPointGazeVectors
                            )
                        )
                        self.currentPointGazeVectors.removeAll()
                        self.showCalibrationPoint = false
                        self.currentPointIndex += 1
                        self.showNextCalibrationPoint()

                    }else{
                        print("未对齐校准点，重新采集当前点")
                        self.currentPointGazeVectors.removeAll()
                        self.correctprocess()
                    }
                }else{
                    if(self.isCalibrating == false){
                        return
                    }
                    print("对齐数据不足，重新采集当前点")
                    self.currentPointGazeVectors.removeAll()
                    self.correctprocess()
                }

            }
        }
    }

    
    func finishCalibration() {
        let success = calculateCalibrationModel()
        isCalibrating = false
        calibrationCompleted = success
        
        if success {
            print("✅ [CALIBRATION] 校准完成，模型计算成功")
            print("✅ [CALIBRATION] 校准向量数量: \(correctionalVectors.count)")
            print("✅ [CALIBRATION] 校准状态设置为: \(calibrationCompleted)")
        } else {
            print("❌ [CALIBRATION] 校准失败：\(calibrationError ?? "未知错误")")
        }
    }
    
    // 校准模型参数
    private var correctionalVectors: [SIMD3<Float>]=[]  // 用于存储全部校准点的校准向量
    @Published var calibrationError: String?

    // 计算校准模型
    func calculateCalibrationModel() -> Bool {
        guard calibrationPoints.count >= 5 else {

            calibrationError = "校准点数据不足"
            return false
        }
        for (_,(calib,correct))in zip(self.calibrationPoints,self.CorrectPoints).enumerated(){
            let originalVector = calib.gazeVectors.reduce(SIMD3<Float>(repeating: 0), +) / Float(calib.gazeVectors.count)
            let correctedVector = correct.correctedgazeVectors.reduce(SIMD3<Float>(repeating: 0), +) / Float(correct.correctedgazeVectors.count)
            let delta = correctedVector - originalVector
            self.correctionalVectors.append(delta) 
        }
        if self.correctionalVectors.count >= 9 {
            print("已经得到校准向量组，可以开始计算校准模型")
            return true
        }else{
            print("校准向量组不足")
            return false
        }
    }
    // 高斯距离加权平均 => 计算校准向量

    func computeCalibrationPoints(from positions: [(x: CGFloat, y: CGFloat)]) -> [CGPoint] {
        let frameSize = Device.frameSize
        return positions.map { position in
            CGPoint(
                x: position.x * frameSize.width,
                y: position.y * frameSize.height
            )
        }
    }
    /// 根据 gaze 投影点，使用所有校准点的矫正向量进行高斯加权平均
    func guessCorrectionalVector(for gazePoint: CGPoint) -> SIMD3<Float> {
        let screenPoints = computeCalibrationPoints(from: calibrationPositions)
        
        // 控制影响范围的参数，建议为屏幕宽度的 1/4
        let sigma: CGFloat = Device.frameSize.width / 3.0
        
        var weightedSum = SIMD3<Float>(repeating: 0)
        var totalWeight: CGFloat = 0
        
        for (index, calibrationPoint) in screenPoints.enumerated() {
            guard index < correctionalVectors.count else { continue }
            
            let correction = correctionalVectors[index]
            let distance = hypot(gazePoint.x - calibrationPoint.x, gazePoint.y - calibrationPoint.y)
            
            // 高斯权重计算
            let weight = exp(-pow(distance, 2) / pow(sigma, 2))
            
            // 加权累加
            weightedSum += correction * Float(weight)
            totalWeight += weight
        }
        
        guard totalWeight > 0 else {
            // 没有权重说明 gaze 点太远，返回默认矫正
            return SIMD3<Float>(repeating: 0)
        }
        
        return weightedSum / Float(totalWeight)
    }

    func stopCalibration() {
        isCalibrating = false
        showCalibrationPoint = false
        temporaryMessage = nil
        calibrationError = nil
        isCollecting = false
        currentPointIndex = 0
        currentPointGazeVectors.removeAll()
        faceAnchorCalibration = nil
    }

    
    // 使用校准模型预测屏幕坐标
    func predictScreenPoint(from faceAnchor: ARFaceAnchor) {
        guard let arView = self.arView else {
            print("❌ [PREDICTION] ARView 未初始化")
            return 
        }
        let lookAtPointOnScreen = arView.detectGazePoint(faceAnchor: faceAnchor)
        let correctionalVector = guessCorrectionalVector(for : lookAtPointOnScreen) * 0.6
        let overrideLookAtPoint = faceAnchor.lookAtPoint + correctionalVector
      
        #if DEBUG
        if arc4random_uniform(500) == 0 {
            print("🎯 [PREDICTION] 原始注视点: \(lookAtPointOnScreen)")
            print("🎯 [PREDICTION] 校准向量: \(correctionalVector)")
            print("🎯 [PREDICTION] 修正后向量: \(overrideLookAtPoint)")
        }
        #endif
        
        arView.updateDetectGazePointAfterCalibration(faceAnchor: faceAnchor, overrideLookAtPoint: overrideLookAtPoint)
    }

}
