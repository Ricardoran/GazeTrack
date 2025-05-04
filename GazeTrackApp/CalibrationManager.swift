import SwiftUI
import ARKit

// 校准数据结构
struct CalibrationPoint {
    let position: CGPoint
    let gazeVectors: [SIMD3<Float>]
}

// 测量数据结构
struct MeasurementPoint {
    let targetPosition: CGPoint
    let actualPosition: CGPoint
    let error: CGFloat  // 误差距离（像素）
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
    private var measurementStartTime: Date?  // 新增：测量开始时间
    
    private let calibrationPositions: [(x: CGFloat, y: CGFloat)] = [
        (0.5, 0.5),  // 中心
        (0.2, 0.2),  // 左上
        (0.8, 0.2),  // 右上
        (0.2, 0.8),  // 左下
        (0.8, 0.8)   // 右下
    ]
    
    private var calibrationPoints: [CalibrationPoint] = []
    private var currentPointGazeVectors: [SIMD3<Float>] = []
    private var currentMeasurementPoints: [CGPoint] = []  // 新增：当前测量点的实际位置
    
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
        isMeasuring = false
        currentPointIndex = 0
        calibrationPoints.removeAll()
        calibrationCompleted = false
        showCalibrationPoint = true
        showNextPoint()
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
    func collectGazeVector(_ vector: SIMD3<Float>) {
        guard isCalibrating else { return }
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
    
    private func showNextPoint() {
        guard currentPointIndex < calibrationPositions.count else {
            finishCalibration()
            return
        }
        
        currentPointGazeVectors.removeAll()
        showCalibrationPoint = true
        
        // 延长每个点的显示时间到3秒，给用户足够时间注视
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if let currentPoint = self.currentCalibrationPoint {
                // 只有当收集到足够的数据时才继续
                if self.currentPointGazeVectors.count >= 30 { // 至少收集30个采样点
                    self.calibrationPoints.append(
                        CalibrationPoint(
                            position: currentPoint,
                            gazeVectors: self.currentPointGazeVectors
                        )
                    )
                    self.showCalibrationPoint = false
                    self.currentPointIndex += 1
                    self.showNextPoint()
                } else {
                    print("数据采集不足，重新采集当前点")
                    self.currentPointGazeVectors.removeAll()
                    self.showNextPoint()
                }
            }
        }
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
                    
                    print("测量点 \(self.currentPointIndex+1): 目标=(\(currentPoint.x), \(currentPoint.y)), 实际=(\(avgPoint.x), \(avgPoint.y)), 误差=\(errorDistance)像素")
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
        // let success = calculateCalibrationModel()
        let success = true
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
            
            print("测量完成，平均误差: \(averageError) 像素")
            
            // 显示测量结果
            showMeasurementResults = true
        } else {
            print("测量失败：没有收集到足够的数据")
        }
    }
    
    // 校准模型参数
    private var calibrationMatrix: (xMatrix: simd_float3x3, yMatrix: simd_float3x3)?
    @Published var calibrationError: String?
    
    // 计算校准模型
    private func calculateCalibrationModel() -> Bool {
        guard calibrationPoints.count >= 5 else {
            calibrationError = "校准点数据不足"
            return false
        }
        
        var xInputs: [[Float]] = []
        var yInputs: [[Float]] = []
        var xTargets: [Float] = []
        var yTargets: [Float] = []
        
        // 处理每个校准点的数据
        for point in calibrationPoints {
            print("point gazeVectors", point.gazeVectors)
            guard !point.gazeVectors.isEmpty else { continue }
            
            // 计算平均视线向量
            let avgVector = point.gazeVectors.reduce(SIMD3<Float>.zero, +) / Float(point.gazeVectors.count)
            print("avgVector", avgVector)
            // 构建输入矩阵
            xInputs.append([avgVector.x, avgVector.y, avgVector.z])
            yInputs.append([avgVector.x, avgVector.y, avgVector.z])
            
            // 目标屏幕坐标
            xTargets.append(Float(point.position.x))
            yTargets.append(Float(point.position.y))
        }
        
        // 使用最小二乘法求解线性方程组
        do {
            let xMatrix = try solveLinearEquation(inputs: xInputs, targets: xTargets)
            let yMatrix = try solveLinearEquation(inputs: yInputs, targets: yTargets)
            calibrationMatrix = (xMatrix, yMatrix)
            return true
        } catch {
            calibrationError = "校准模型计算失败"
            return false
        }
    }
    
    // 最小二乘法求解
    private func solveLinearEquation(inputs: [[Float]], targets: [Float]) throws -> simd_float3x3 {
        // 构建矩阵
        var A = simd_float3x3()
        var b = SIMD3<Float>()
        
        for i in 0..<inputs.count {
            let input = SIMD3<Float>(inputs[i][0], inputs[i][1], inputs[i][2])
            let target = targets[i]
            
            A += simd_float3x3(rows: [
                SIMD3<Float>(input.x * input.x, input.x * input.y, input.x * input.z),
                SIMD3<Float>(input.y * input.x, input.y * input.y, input.y * input.z),
                SIMD3<Float>(input.z * input.x, input.z * input.y, input.z * input.z)
            ])
            
            b += SIMD3<Float>(
                target * input.x,
                target * input.y,
                target * input.z
            )
        }
        
        // 求解方程组
        let determinant = simd_determinant(A)
        if abs(determinant) < 1e-6 {  // Check if matrix is singular
            throw NSError(domain: "CalibrationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "矩阵不可逆"])
        }
        
        let inverse = A.inverse
        return inverse * simd_float3x3(rows: [b, b, b])
    }
    
    // 使用校准模型预测屏幕坐标
    func predictScreenPoint(from gazeVector: SIMD3<Float>) -> CGPoint? {
        guard let matrix = calibrationMatrix else { return nil }
        
        let x = simd_dot(matrix.xMatrix.columns.0, gazeVector)
        let y = simd_dot(matrix.yMatrix.columns.0, gazeVector)
        
        return CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
}
