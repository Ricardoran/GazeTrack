import SwiftUI
import ARKit
import CoreML
import Foundation

// 校准数据结构
struct CalibrationPoint {
    let position: CGPoint
    let gazeVectors: [SIMD3<Float>]
}
// 测量数据结构
struct MeasurementPoint {
    let targetPosition: CGPoint
    let actualPosition: CGPoint
    let error: CGFloat  // 误差距离（pt）
}

// SVR 数据结构
struct SVRSample: Codable {
    let gaze: [Float]      // gaze 向量 [x, y, z]
    let screen: [Float]    // 屏幕坐标 [x, y]
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
    var modelX: SVRModel? = nil
    var modelY: SVRModel? = nil
    
    private let calibrationPositions: [(x: CGFloat, y: CGFloat)] = {
        let steps: [CGFloat] = [0.1,0.5,0.9]
        return steps.flatMap { y in
            steps.map { x in
                (x, y)
            }
        }
    }()
        
    private var calibrationPoints: [CalibrationPoint] = []
    private var currentPointGazeVectors: [SIMD3<Float>] = []
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
    func filterOutliers(from vectors: [SIMD3<Float>], threshold: Float = 0.01) -> [SIMD3<Float>] {
        guard !vectors.isEmpty else { return [] }
        let count = Float(vectors.count)
        
        // 计算平均向量
        let sum = vectors.reduce(SIMD3<Float>(0,0,0), +)
        let mean = sum / count

        // 保留距离均值小于 threshold 的向量
        return vectors.filter {
            simd_distance($0, mean) <= threshold
        }
    }
    // 收集视线向量
    private func showNextCalibrationPoint() {
        guard currentPointIndex < calibrationPositions.count else {
            finishCalibration()
            return
        }
        
        currentPointGazeVectors.removeAll()
        showCalibrationPoint = true
        self.isCollecting = true
        
        // 延长每个点的显示时间到3秒，给用户足够时间注视
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isCollecting = true
            if let currentPoint = self.currentCalibrationPoint {
                // 只有当收集到足够的数据时才继续
                if self.currentPointGazeVectors.count >= 5 { // 至少收集30个采样点
                let filteredVectors = self.filterOutliers(from: self.currentPointGazeVectors)
                if filteredVectors.count >= 5 {
                    self.calibrationPoints.append(
                        CalibrationPoint(
                            position: currentPoint,
                            gazeVectors: filteredVectors
                        )
                    )
                    self.currentPointGazeVectors.removeAll()
                    self.showCalibrationPoint = false
                    self.currentPointIndex += 1
                    self.showNextCalibrationPoint()
                } else {
                    print("⚠️ 剔除异常后数据不足，重新采集")
                    self.currentPointGazeVectors.removeAll()
                    self.showNextCalibrationPoint()
                }
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
    // 导出收集的模型
    func exportRawCalibrationData(to filename: String = "raw_gaze_data.json") {
        struct ExportPoint: Codable {
            let screen: [Float]
            let gaze: [[Float]]
            let count: Int  // ✅ 新增：数据点数量
        }

        let exportData: [ExportPoint] = calibrationPoints.map { point in
            ExportPoint(
                screen: [Float(point.position.x), Float(point.position.y)],
                gaze: point.gazeVectors.map { [$0.x, $0.y, $0.z] },
                count: point.gazeVectors.count
            )
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(exportData)

            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documents.appendingPathComponent(filename)

            try data.write(to: fileURL)
            print("✅ 已导出原始 gaze 数据：\(fileURL)")
            print("📊 总共导出了 \(exportData.count) 个校准点")
            exportData.forEach { print("🟢 点位置 \( $0.screen )，采样数量：\( $0.count )") }
        } catch {
            print("❌ 导出失败：\(error)")
        }
    }
    
    private func finishCalibration() {
        //导出数据
        self.exportRawCalibrationData()
        // debug，先不进行模型计算，直接返回成功，优先测量准确性
        let success = true
        isCalibrating = false
        calibrationCompleted = success
        print("校准完成，模型计算成功")
        // 1. 准备训练数据
        var X: [[Float]] = []
        var Yx: [Float] = []
        var Yy: [Float] = []

        for point in calibrationPoints {
            for vector in point.gazeVectors {
                X.append([vector.x, vector.y, vector.z])
                Yx.append(Float(point.position.x))
                Yy.append(Float(point.position.y))
            }
        }

        // 2. 使用 Swift 版 SVR 训练模型
            let flatGaze: [SIMD3<Float>] = calibrationPoints.flatMap { point in
                point.gazeVectors
            }
            let targetsX: [Float] = calibrationPoints.flatMap { point in
                Array(repeating: Float(point.position.x), count: point.gazeVectors.count)
            }
            let targetsY: [Float] = calibrationPoints.flatMap { point in
                Array(repeating: Float(point.position.y), count: point.gazeVectors.count)
            }

        self.modelX = SVRTrainer.train(fromGaze: flatGaze, targets: targetsX)
        self.modelY = SVRTrainer.train(fromGaze: flatGaze, targets: targetsY)
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

    // 使用校准模型预测屏幕坐标
    func predictScreenPoint(from faceAnchor: ARFaceAnchor) {
        guard let arView = self.arView,
            let modelX = self.modelX,
            let modelY = self.modelY else {
            print("❌ 模型未准备好")
            return
        }

        let gaze = faceAnchor.lookAtPoint
        let input = [gaze.x, gaze.y, gaze.z]
        let screenX = modelX.predictFromGaze(gaze)
        let screenY = modelY.predictFromGaze(gaze)

        let predictedPoint = CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))

        DispatchQueue.main.async {
            arView.lookAtPoint = predictedPoint
        }
    }
}
