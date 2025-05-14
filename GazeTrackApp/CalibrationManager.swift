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
    private var measurementStartTime: Date?  // 新增：测量开始时间
    weak var customARView: CustomARView?  // 新增：ARViewContainer的弱引用
    weak var arView: CustomARView?  // 新增：ARViewContainer的弱引用
    
    private let calibrationPositions: [(x: CGFloat, y: CGFloat)] = [
        (0.5, 0.5),  // 中心
        (0.2, 0.2),  // 左上
        (0.8, 0.2),  // 右上
        (0.2, 0.8),  // 左下
        (0.8, 0.8)   // 右下
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
        isMeasuring = true
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
        guard isCalibrating else { return }
        // 取出 gaze 向量
        self.faceAnchorCalibration = faceAnchor
        let vector = faceAnchor.lookAtPoint
        currentPointGazeVectors.append(vector)
    }
    /*
    func collectGazeVector(_ vector: SIMD3<Float>) {
        guard isCalibrating else { return }
        currentPointGazeVectors.append(vector)
    }
    */
    
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
                    print("已经收集到此校准点视线向量")
                    self.currentPointGazeVectors.removeAll()
                    print("请移动注视点，使得光标移动到校验点，并尽量保存不动")
                    self.correctprocess() 

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

        if let currentPoint = self.currentCalibrationPoint {
            if self.currentPointGazeVectors.count >= 30 {
                guard let faceAnchor = self.faceAnchorCalibration else { return  }
                let avgVector = self.currentPointGazeVectors.reduce(SIMD3<Float>(repeating: 0.0), +) / SIMD3<Float>(Float(self.currentPointGazeVectors.count))
                guard let arView = self.arView else { 
                    print("ARView 未初始化")
                    return
                 }
                let focusPoint = arView.detectGazePoint(faceAnchor:faceAnchor,overrideLookAtPoint:avgVector)
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
                print("对齐数据不足，重新采集当前点")
                self.currentPointGazeVectors.removeAll()
                self.correctprocess()
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
    private var correctionalVectors: [SIMD3<Float>]=[]  // 用于存储全部校准点的校准向量
    @Published var calibrationError: String?

    // 计算校准模型
    private func calculateCalibrationModel() -> Bool {
        guard calibrationPoints.count >= 5 else {
            calibrationError = "校准点数据不足"
            return false
        }
        for (index,(calib,correct))in zip(self.calibrationPoints,self.CorrectPoints).enumerated(){
            let originalVector = calib.gazeVectors.reduce(SIMD3<Float>(repeating: 0), +) / Float(calib.gazeVectors.count)
            let correctedVector = correct.correctedgazeVectors.reduce(SIMD3<Float>(repeating: 0), +) / Float(correct.correctedgazeVectors.count)
            let delta = correctedVector - originalVector
            self.correctionalVectors.append(delta) 
        }
        if self.correctionalVectors.count >= 5 {
            print("已经得到校准向量组，可以开始计算校准模型")
            return true
        }else{
            print("校准向量组不足")
            return false
        }
    }
    // 使用校准模型预测屏幕坐标
    func predictScreenPoint(from faceAnchor: ARFaceAnchor) -> CGPoint? {
        let correctionalVector = faceAnchor.lookAtPoint - (
                correctionalVectors.reduce(SIMD3<Float>(repeating: 0), +) / Float(correctionalVectors.count)
            )
        guard let arView = self.arView else {
            print("ARView 未初始化")
            return nil
        }
        return arView.detectGazePoint(faceAnchor: faceAnchor, overrideLookAtPoint: correctionalVector)
    }
}
