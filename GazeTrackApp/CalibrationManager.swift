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
// 测量数据结构
struct MeasurementPoint {
    let targetPosition: CGPoint
    let actualPosition: CGPoint
    let error: CGFloat  // 误差距离（pt）
}

class CalibrationManager: ObservableObject {
    @Published var isCalibrating: Bool = false
    @Published var isMeasuring: Bool = false  // 新增：测量模式标志
    @Published var currentPointIndex: Int = 0
    @Published var calibrationCompleted: Bool = false
    @Published var showCalibrationPoint: Bool = false
    @Published var measurementCompleted: Bool = false  // 新增：测量完成标志
    @Published var measurementResults: [MeasurementPoint] = []  // 新增：测量结果
    @Published var averageError: CGFloat = 0  // 新增：平均误差
    @Published var showMeasurementResults: Bool = false  // 新增：显示测量结果
    @Published var temporaryMessage: String? = nil
    private var measurementStartTime: Date?  // 新增：测量开始时间
    weak var customARView: CustomARView?  // 新增：ARViewContainer的弱引用
    weak var arView: CustomARView?  // 新增：ARViewContainer的弱引用
    var isCollecting: Bool = false
    
    /*
    private let calibrationPositions: [(x: CGFloat, y: CGFloat)] = {
        let steps: [CGFloat] = [0.1, 0.3, 0.5, 0.7, 0.9]
        return steps.flatMap { y in
            steps.map { x in
                (x, y)
            }
        }
    }()
    */
    private let calibrationPositions: [(x: CGFloat, y: CGFloat)] = [
        (0.5, 0.5),  // 中心
    ]
        
    private var calibrationPoints: [CalibrationPoint] = []
    private var currentPointGazeVectors: [SIMD3<Float>] = []
    private var CorrectPoints: [CorrectPoint] = [] // 储存修正后的视线向量 
    private var currentMeasurementPoints: [CGPoint] = []  // 新增：当前测量点的实际位置
    var faceAnchorCalibration: ARFaceAnchor?  // 新增：保存faceAnchor
    
    // 获取当前校准点的屏幕坐标
    var currentCalibrationPoint: CGPoint? {
        guard currentPointIndex < calibrationPositions.count else { return nil }
        let position = calibrationPositions[currentPointIndex]
        let safeFrameSize = Device.safeFrameSize
        return CGPoint(x: position.x * safeFrameSize.width,
                       y: position.y * safeFrameSize.height)
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
    
    // 新增：开始测量过程
    func startMeasurement() {
        isCalibrating = false
        isMeasuring = true
        currentPointIndex = 0
        measurementResults.removeAll()
        currentMeasurementPoints.removeAll()
        measurementStartTime = nil
        measurementCompleted = false
        showCalibrationPoint = true
        showMeasurementResults = false
        showNextMeasurementPoint()
    }
    
    // 收集校准数据
    func collectGazeVector(from faceAnchor: ARFaceAnchor) {
        guard isCalibrating && isCollecting else { return }
        // 取出 gaze 向量
        self.faceAnchorCalibration = faceAnchor
        let vector = faceAnchor.lookAtPoint
        currentPointGazeVectors.append(vector)
    }

    
    // 新增：收集测量数据（优化版）
    func collectMeasurementPoint(_ point: CGPoint) {
        guard isMeasuring && showCalibrationPoint else { return }
        
        // 初始化开始时间
        if measurementStartTime == nil {
            measurementStartTime = Date()
            return
        }
        
        // 计算经过的时间（秒）
        let elapsedTime = Date().timeIntervalSince(measurementStartTime!)
        
        // 只在1-3秒之间的稳定窗口内采集数据
        if elapsedTime >= 1.0 && elapsedTime <= 3.0 {
            currentMeasurementPoints.append(point)
        }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isCollecting = true
            if let currentPoint = self.currentCalibrationPoint {
                // 只有当收集到足够的数据时才继续
                if self.currentPointGazeVectors.count >= 20 { // 至少收集30个采样点
                    self.calibrationPoints.append(
                        CalibrationPoint(
                            position: currentPoint,
                            gazeVectors: self.currentPointGazeVectors
                        )
                    )
                    self.currentPointGazeVectors.removeAll()
                    self.showCalibrationPoint = false
                    self.currentPointIndex += 1
                    self.showNextCalibrationPoint()

                } else {
                    print("数据采集不足，重新采集当前点")
                    self.currentPointGazeVectors.removeAll()
                    self.showNextCalibrationPoint()
                }
            }
        }
        // 开始倒计时，停止收集数据，3秒等待，用户调整自己的视线。

    }


    // 新增：显示下一个测量点（优化版）
    private func showNextMeasurementPoint() {
        guard currentPointIndex < calibrationPositions.count else {
            finishMeasurement()
            return
        }
        
        currentMeasurementPoints.removeAll()
        measurementStartTime = nil  // 重置测量开始时间
        showCalibrationPoint = true
        
        // 显示每个点5秒，给用户更充足的时间注视
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if let currentPoint = self.currentCalibrationPoint {
                // 计算当前点的平均注视位置
                if !self.currentMeasurementPoints.isEmpty {
                    let avgX = self.currentMeasurementPoints.map { $0.x }.reduce(0, +) / CGFloat(self.currentMeasurementPoints.count)
                    let avgY = self.currentMeasurementPoints.map { $0.y }.reduce(0, +) / CGFloat(self.currentMeasurementPoints.count)
                    let avgPoint = CGPoint(x: avgX, y: avgY)
                    
                    // 计算误差（欧几里得距离）
                    let errorDistance = sqrt(pow(avgPoint.x - currentPoint.x, 2) + pow(avgPoint.y - currentPoint.y, 2))
                    
                    // 添加到测量结果
                    self.measurementResults.append(
                        MeasurementPoint(
                            targetPosition: currentPoint,
                            actualPosition: avgPoint,
                            error: errorDistance
                        )
                    )
                    
                    print("测量点 \(self.currentPointIndex+1): 目标=(\(currentPoint.x), \(currentPoint.y)), 实际=(\(avgPoint.x), \(avgPoint.y)), 误差=\(errorDistance)pt")
                    print("采集数据点数量: \(self.currentMeasurementPoints.count)，采集窗口: 1-3秒（总5秒）")
                } else {
                    print("警告：测量点 \(self.currentPointIndex+1) 没有采集到数据")
                }
                
                self.showCalibrationPoint = false
                self.currentPointIndex += 1
                self.showNextMeasurementPoint()
            }
        }
    }
    
    private func finishCalibration() {
        // debug，先不进行模型计算，直接返回成功，优先测量准确性
        let success = calculateCalibrationModel()
        //let success = true
        isCalibrating = false
        calibrationCompleted = success
        
        if success {
            print("校准完成，模型计算成功")
        } else {
            print("校准失败：\(calibrationError ?? "未知错误")")
        }
    }
    
    // 新增：完成测量
    private func finishMeasurement() {
        isMeasuring = false
        measurementCompleted = true
        showCalibrationPoint = false
        
        // 计算平均误差
        if !measurementResults.isEmpty {
            averageError = measurementResults.map { $0.error }.reduce(0, +) / CGFloat(measurementResults.count)
            
            print("测量完成，平均误差: \(averageError) pt")
            
            // 显示测量结果
            showMeasurementResults = true
        } else {
            print("测量失败：没有收集到足够的数据")
        }
    }
    
    // 校准模型参数
    private var correctionalVectors: [CGVector] = [] // 用于存储全部校准点的校准向量
    @Published var calibrationError: String?

    // 计算校准模型
    private func calculateCalibrationModel() -> Bool {
        guard calibrationPoints.count >= 1 else {
            calibrationError = "校准点数据不足"
            return false
        }

        // 清空原有 correctionalVectors
        self.correctionalVectors.removeAll()
        let screenPoints = computeCalibrationPoints(from: calibrationPositions)

        for (index, calib) in calibrationPoints.enumerated() {
            guard index < screenPoints.count,
                let faceAnchor = self.faceAnchorCalibration,
                let arView = self.arView else {
                continue
            }

            // 1. 原始 gaze 向量取平均
            let originalVector = calib.gazeVectors.reduce(SIMD3<Float>(repeating: 0), +) / Float(calib.gazeVectors.count)
            // 2. 映射到屏幕预测点
            let focusPoint = arView.detectGazePoint(faceAnchor: faceAnchor,overrideLookAtPoint: originalVector)
            // 3. 获取实际校准点
            let groundTruthPoint = screenPoints[index]

            // 4. 计算偏移量
            let deltaX = focusPoint.x - groundTruthPoint.x
            let deltaY = focusPoint.y - groundTruthPoint.y
            let distance = hypot(deltaX, deltaY)

            // 5. 若距离过小，则不修正（添加近距离忽略机制）
            let minDistanceThreshold: CGFloat = 20.0
            let correction: CGVector = distance < minDistanceThreshold
                ? CGVector(dx: 0, dy: 0)
                : CGVector(dx: deltaX, dy: deltaY)

            self.correctionalVectors.append(correction)
        }

        if self.correctionalVectors.count >= 1 {
            print("已经得到屏幕校准向量组，可以开始计算校准模型")
            return true
        } else {
            print("校准向量组不足")
            return false
        }
    }
    // 高斯距离加权平均-》 选择最优校准计算校准向量

    func computeCalibrationPoints(from positions: [(x: CGFloat, y: CGFloat)]) -> [CGPoint] {
        let safeFrameSize = Device.safeFrameSize
        return positions.map { position in
            CGPoint(
                x: position.x * safeFrameSize.width,
                y: position.y * safeFrameSize.height
            )
        }
    }

    /// 根据 gaze 投影点，使用所有校准点的屏幕偏移向量进行高斯加权平均
    func guessCorrectionalVector(for gazePoint: CGPoint) -> CGVector {
        let screenPoints = computeCalibrationPoints(from: calibrationPositions)

        // 控制影响范围的高斯 sigma，建议设为屏幕宽度的 1/3
        let sigma: CGFloat = Device.frameSize.width / 3.0

        var weightedDx: CGFloat = 0
        var weightedDy: CGFloat = 0
        var totalWeight: CGFloat = 0

        for (index, calibrationPoint) in screenPoints.enumerated() {
            guard index < correctionalVectors.count else { continue }

            // correctionalVectors 现在是 [CGVector] 类型，表示屏幕偏移量
            let correction = correctionalVectors[index]

            let distance = hypot(gazePoint.x - calibrationPoint.x, gazePoint.y - calibrationPoint.y)
            let weight = exp(-pow(distance, 2) / pow(sigma, 2))  // 高斯衰减

            weightedDx += correction.dx * weight
            weightedDy += correction.dy * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else {
            // 如果没有任何有效权重，返回零偏移
            return CGVector(dx: 0, dy: 0)
        }

        return CGVector(dx: weightedDx / totalWeight, dy: weightedDy / totalWeight)
    }

    // 使用校准模型预测屏幕坐标
    func predictScreenPoint(from faceAnchor: ARFaceAnchor) {
        guard let arView = self.arView else {
            print("ARView 未初始化")
            return 
        }
        let lookScreenPoint = arView.detectGazePoint(faceAnchor: faceAnchor)
        let correctionalVector = guessCorrectionalVector(for : lookScreenPoint) 
        print("已经得到校准向量:")
        print(correctionalVector)
        print("屏幕观测点")
        print(lookScreenPoint)
        print("修正后的屏幕观测点")
        arView.updateCGPoint(faceAnchor: faceAnchor)
    }
}
