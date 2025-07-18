import SwiftUI
import ARKit
import os.log

// 注意：网格校准已移除，现在使用简单的线性校准

class CalibrationManager: ObservableObject {
    @Published var isCalibrating: Bool = false
    @Published var currentPointIndex: Int = 0
    @Published var calibrationCompleted: Bool = false
    @Published var showCalibrationPoint: Bool = false
    @Published var temporaryMessage: String? = nil
    
    // 调试开关：强制使用未校准模式进行对比
    @Published var forceUncalibratedMode: Bool = false
    
    // 日志记录器
    private let logger = Logger(subsystem: "com.gazetrack.calibration", category: "CalibrationManager")
    
    // 线性校准相关属性
    @Published var isLinearCalibrationEnabled: Bool = false
    @Published var linearCalibrationMode: Bool = false
    
    // 线性校准配置常量
    static let LINEAR_CALIBRATION_POINTS = 5  // 5点校准：四个角落+中心
    
    weak var arView: CustomARView?
    var isCollecting: Bool = false
    var faceAnchorCalibration: ARFaceAnchor?
    
    // 获取当前校准点的屏幕坐标 (现在使用线性校准)
    var currentCalibrationPoint: CGPoint? {
        return currentLinearCalibrationPoint
    }
    
    // MARK: - 线性校准系统
    
    // 线性变换模型
    struct LinearTransform {
        let a11: Float, a12: Float, a13: Float  // x = a11*u + a12*v + a13
        let a21: Float, a22: Float, a23: Float  // y = a21*u + a22*v + a23
        
        func predict(gazeVector: SIMD3<Float>) -> CGPoint {
            let u = gazeVector.x
            let v = gazeVector.y
            
            let x = a11 * u + a12 * v + a13
            let y = a21 * u + a22 * v + a23
            
            // 允许一定程度的外推，避免过度限制
            let bounds = Device.frameSize
            let extrapolationMargin: CGFloat = min(bounds.width, bounds.height) * 0.2  // 允许20%外推
            let clampedX = CGFloat(x).clamped(to: -extrapolationMargin...(bounds.width + extrapolationMargin))
            let clampedY = CGFloat(y).clamped(to: -extrapolationMargin...(bounds.height + extrapolationMargin))
            
            return CGPoint(x: clampedX, y: clampedY)
        }
    }
    
    // 校准点数据
    struct CalibrationPoint {
        let screenPosition: CGPoint
        let gazeVectors: [SIMD3<Float>]
    }
    
    // 线性校准状态
    private var linearTransform: LinearTransform?
    private var calibrationPoints: [CalibrationPoint] = []
    private var currentCalibrationIndex: Int = 0
    private var currentGazeVectors: [SIMD3<Float>] = []
    
    // 5个校准点的屏幕位置
    private var calibrationPositions: [CGPoint] {
        let bounds = Device.frameSize
        let margin: CGFloat = bounds.width * 0.15  // 15% margin，避免过于靠近边缘
        return [
            CGPoint(x: bounds.width * 0.5, y: bounds.height * 0.5), // 中心点（最重要）
            CGPoint(x: margin, y: margin),                           // 左上
            CGPoint(x: bounds.width - margin, y: margin),            // 右上
            CGPoint(x: margin, y: bounds.height - margin),           // 左下
            CGPoint(x: bounds.width - margin, y: bounds.height - margin)  // 右下
        ]
    }
    
    // 开始校准过程 (现在使用线性校准)
    func startCalibration() {
        logger.info("🔄 Starting linear calibration process")
        startLinearCalibration()
    }
    
    // 收集校准数据 (现在使用线性校准)
    func collectGazeVector(from faceAnchor: ARFaceAnchor) {
        self.faceAnchorCalibration = faceAnchor
        collectLinearGazeVector(from: faceAnchor)
    }
    
    // 停止校准 (现在使用线性校准)
    func stopCalibration() {
        stopLinearCalibration()
    }
    
    // 主要预测函数 (现在使用线性校准)
    func predictScreenPoint(from faceAnchor: ARFaceAnchor) {
        predictWithLinearCalibration(from: faceAnchor)
    }
    
    // MARK: - 线性校准核心功能
    
    // 开始线性校准
    func startLinearCalibration() {
        print("🎯 [LINEAR CALIBRATION] 开始5点线性校准")
        linearCalibrationMode = true
        isCalibrating = true
        calibrationCompleted = false
        
        // 清理之前的数据
        calibrationPoints.removeAll()
        currentCalibrationIndex = 0
        currentGazeVectors.removeAll()
        linearTransform = nil
        
        // 开始第一个校准点
        moveToNextCalibrationPoint()
    }
    
    // 停止线性校准
    func stopLinearCalibration() {
        print("🛑 [LINEAR CALIBRATION] 停止线性校准")
        linearCalibrationMode = false
        isCalibrating = false
        currentGazeVectors.removeAll()
    }
    
    // 移动到下一个校准点
    private func moveToNextCalibrationPoint() {
        guard currentCalibrationIndex < CalibrationManager.LINEAR_CALIBRATION_POINTS else {
            // 所有点已校准，计算线性变换
            finishLinearCalibration()
            return
        }
        
        currentGazeVectors.removeAll()
        showCalibrationPoint = true
        isCollecting = true
        
        let position = calibrationPositions[currentCalibrationIndex]
        let pointName = currentCalibrationIndex == 0 ? "中心" : "角落\(currentCalibrationIndex)"
        print("📍 [LINEAR CALIBRATION] 开始校准点 \(currentCalibrationIndex + 1)/5 (\(pointName)) at \(position)")
        
        // 3秒后自动移动到下一个点
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            guard self.linearCalibrationMode else { return }
            self.finishCurrentCalibrationPoint()
        }
    }
    
    // 完成当前校准点
    private func finishCurrentCalibrationPoint() {
        isCollecting = false
        showCalibrationPoint = false
        
        let position = calibrationPositions[currentCalibrationIndex]
        let pointName = currentCalibrationIndex == 0 ? "中心" : "角落\(currentCalibrationIndex)"
        print("📊 [LINEAR CALIBRATION] 点 \(currentCalibrationIndex + 1) (\(pointName)) 收集了 \(currentGazeVectors.count) 个数据点")
        
        if currentGazeVectors.count >= 10 {  // 至少需要10个数据点
            let calibrationPoint = CalibrationPoint(
                screenPosition: position,
                gazeVectors: currentGazeVectors
            )
            calibrationPoints.append(calibrationPoint)
        } else {
            print("⚠️ [LINEAR CALIBRATION] 点 \(currentCalibrationIndex + 1) 数据不足，跳过")
        }
        
        currentCalibrationIndex += 1
        
        // 短暂延迟后移动到下一个点
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard self.linearCalibrationMode else { return }
            self.moveToNextCalibrationPoint()
        }
    }
    
    // 完成线性校准
    private func finishLinearCalibration() {
        print("🎯 [LINEAR CALIBRATION] 完成数据收集，开始计算线性变换")
        
        guard calibrationPoints.count >= 3 else {
            print("❌ [LINEAR CALIBRATION] 校准点不足 (\(calibrationPoints.count)/5)")
            linearCalibrationMode = false
            isCalibrating = false
            calibrationCompleted = false
            return
        }
        
        // 计算线性变换
        if let transform = calculateLinearTransform() {
            linearTransform = transform
            isLinearCalibrationEnabled = true
            calibrationCompleted = true
            print("🎉 [LINEAR CALIBRATION] 线性校准成功，\(calibrationPoints.count)/5个点有效")
        } else {
            print("❌ [LINEAR CALIBRATION] 线性变换计算失败")
            calibrationCompleted = false
        }
        
        linearCalibrationMode = false
        isCalibrating = false
    }
    
    // 收集线性校准数据
    func collectLinearGazeVector(from faceAnchor: ARFaceAnchor) {
        guard linearCalibrationMode && isCollecting else { return }
        
        let vector = faceAnchor.lookAtPoint
        
        // 基本质量检查
        if abs(vector.x) < 1.0 && abs(vector.y) < 1.0 {
            currentGazeVectors.append(vector)
        }
    }
    
    // 计算线性变换矩阵
    private func calculateLinearTransform() -> LinearTransform? {
        // 准备数据点：每个校准点使用其gaze向量的平均值
        var gazePoints: [SIMD3<Float>] = []
        var screenPoints: [CGPoint] = []
        
        for calibrationPoint in calibrationPoints {
            // 计算该点的平均gaze向量
            let avgGaze = calibrationPoint.gazeVectors.reduce(SIMD3<Float>(0,0,0), +) / Float(calibrationPoint.gazeVectors.count)
            gazePoints.append(avgGaze)
            screenPoints.append(calibrationPoint.screenPosition)
        }
        
        guard gazePoints.count >= 3 else { return nil }
        
        // 使用最小二乘法求解线性变换
        // 系统: [x] = [a11 a12 a13] [u]
        //       [y]   [a21 a22 a23] [v]
        //                          [1]
        
        let n = gazePoints.count
        var A = Array(repeating: Array(repeating: Float(0), count: 3), count: n)
        var bx = Array(repeating: Float(0), count: n)
        var by = Array(repeating: Float(0), count: n)
        
        for i in 0..<n {
            A[i][0] = gazePoints[i].x  // u
            A[i][1] = gazePoints[i].y  // v
            A[i][2] = 1.0              // 常数项
            bx[i] = Float(screenPoints[i].x)
            by[i] = Float(screenPoints[i].y)
        }
        
        // 求解 A * x = b 的最小二乘解
        guard let xCoeffs = solveLeastSquares(A, bx),
              let yCoeffs = solveLeastSquares(A, by) else {
            return nil
        }
        
        return LinearTransform(
            a11: xCoeffs[0], a12: xCoeffs[1], a13: xCoeffs[2],
            a21: yCoeffs[0], a22: yCoeffs[1], a23: yCoeffs[2]
        )
    }
    
    // 最小二乘法求解
    private func solveLeastSquares(_ A: [[Float]], _ b: [Float]) -> [Float]? {
        let n = A.count  // 方程数
        let m = A[0].count  // 变量数 (3)
        
        guard n >= m else { return nil }
        
        // 计算 A^T * A
        var ATA = Array(repeating: Array(repeating: Float(0), count: m), count: m)
        for i in 0..<m {
            for j in 0..<m {
                for k in 0..<n {
                    ATA[i][j] += A[k][i] * A[k][j]
                }
            }
        }
        
        // 计算 A^T * b
        var ATb = Array(repeating: Float(0), count: m)
        for i in 0..<m {
            for k in 0..<n {
                ATb[i] += A[k][i] * b[k]
            }
        }
        
        // 求解 3x3 系统
        return solve3x3System(ATA, ATb)
    }
    
    // 3x3线性方程组求解（克拉默法则）
    private func solve3x3System(_ A: [[Float]], _ b: [Float]) -> [Float]? {
        let det = determinant3x3(A)
        guard abs(det) > 1e-10 else { return nil }  // 避免奇异矩阵
        
        var result = Array(repeating: Float(0), count: 3)
        
        for i in 0..<3 {
            var Ai = A
            for j in 0..<3 {
                Ai[j][i] = b[j]
            }
            result[i] = determinant3x3(Ai) / det
        }
        
        return result
    }
    
    // 3x3矩阵行列式
    private func determinant3x3(_ matrix: [[Float]]) -> Float {
        let m = matrix
        return m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
               m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
               m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])
    }
    
    // 使用线性校准预测屏幕坐标
    func predictWithLinearCalibration(from faceAnchor: ARFaceAnchor) {
        guard let arView = self.arView else { return }
        
        // 检查是否强制使用未校准模式
        guard !forceUncalibratedMode else {
            let _ = arView.detectGazePoint(faceAnchor: faceAnchor)
            return
        }
        
        var predictedPoint: CGPoint?
        var predictionMethod = "未校准"
        
        // 使用线性校准
        if isLinearCalibrationEnabled && calibrationCompleted, let transform = linearTransform {
            predictedPoint = transform.predict(gazeVector: faceAnchor.lookAtPoint)
            predictionMethod = "线性校准"
            
            #if DEBUG
            if arc4random_uniform(120) == 0 {
                print("🎯 [LINEAR PREDICTION] \(faceAnchor.lookAtPoint) → \(predictedPoint!)")
            }
            #endif
        }
        
        // 如果线性校准失败，使用原始检测
        if predictedPoint == nil {
            predictedPoint = arView.detectGazePoint(faceAnchor: faceAnchor)
            predictionMethod = "原始检测"
        }
        
        #if DEBUG
        if arc4random_uniform(180) == 0 {
            print("🎯 [PREDICTION METHOD] 使用\(predictionMethod): \(predictedPoint!)")
        }
        #endif
        
        // 更新AR视图
        arView.updateDetectGazePointAfterCalibration(faceAnchor: faceAnchor, predictedPoint: predictedPoint!)
    }
    
    // 获取当前线性校准点的屏幕坐标
    var currentLinearCalibrationPoint: CGPoint? {
        guard currentCalibrationIndex < CalibrationManager.LINEAR_CALIBRATION_POINTS else { return nil }
        return calibrationPositions[currentCalibrationIndex]
    }
    
    // MARK: - 兼容性函数（用于现有UI）
    
    // 校准坐标计算工具函数
    func computeCalibrationPoints(from positions: [(x: CGFloat, y: CGFloat)]) -> [CGPoint] {
        let frameSize = Device.frameSize
        return positions.map { position in
            CGPoint(
                x: position.x * frameSize.width,
                y: position.y * frameSize.height
            )
        }
    }
    
    #if DEBUG
    // 获取当前校准模型信息
    func getCalibrationInfo() -> String {
        if isLinearCalibrationEnabled {
            return "线性校准已激活 - \(calibrationPoints.count)/5个点有效"
        } else {
            return "线性校准未启用"
        }
    }
    #endif
}
