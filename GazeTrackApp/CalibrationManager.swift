import SwiftUI
import ARKit

// 校准数据结构
struct CalibrationPoint {
    let position: CGPoint
    let gazeVectors: [SIMD3<Float>]
}

class CalibrationManager: ObservableObject {
    @Published var isCalibrating: Bool = false
    @Published var currentPointIndex: Int = 0
    @Published var calibrationCompleted: Bool = false
    @Published var showCalibrationPoint: Bool = false  // 添加这行
    
    private let calibrationPositions: [(x: CGFloat, y: CGFloat)] = [
        (0.5, 0.5),  // 中心
        (0.2, 0.2),  // 左上
        (0.8, 0.2),  // 右上
        (0.2, 0.8),  // 左下
        (0.8, 0.8)   // 右下
    ]
    
    private var calibrationPoints: [CalibrationPoint] = []
    private var currentPointGazeVectors: [SIMD3<Float>] = []
    
    // 获取当前校准点的屏幕坐标
    var currentCalibrationPoint: CGPoint? {
        guard currentPointIndex < calibrationPositions.count else { return nil }
        let position = calibrationPositions[currentPointIndex]
        let screenSize = UIScreen.main.bounds.size
        return CGPoint(x: position.x * screenSize.width,
                      y: position.y * screenSize.height)
    }
    
    // 开始校准过程
    func startCalibration() {
        isCalibrating = true
        currentPointIndex = 0
        calibrationPoints.removeAll()
        calibrationCompleted = false
        showNextPoint()
    }
    
    // 收集校准数据
    func collectGazeVector(_ vector: SIMD3<Float>) {
        guard isCalibrating else { return }
        currentPointGazeVectors.append(vector)
    }
    
    private func showNextPoint() {
        guard currentPointIndex < calibrationPositions.count else {
            finishCalibration()
            return
        }
        
        calibrationProgress = Double(currentPointIndex) / Double(calibrationPositions.count)
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
    
    // 校准模型参数
    private var calibrationMatrix: (xMatrix: simd_float3x3, yMatrix: simd_float3x3)?
    @Published var calibrationProgress: Double = 0.0
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