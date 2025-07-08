import SwiftUI
import ARKit

// 测量数据结构
struct MeasurementPoint {
    let targetPosition: CGPoint
    let actualPosition: CGPoint
    let error: CGFloat  // 误差距离（pt）
}

class MeasurementManager: ObservableObject {
    @Published var isMeasuring: Bool = false
    @Published var currentPointIndex: Int = 0
    @Published var measurementCompleted: Bool = false
    @Published var measurementResults: [MeasurementPoint] = []
    @Published var averageError: CGFloat = 0
    @Published var showMeasurementResults: Bool = false
    @Published var showCalibrationPoint: Bool = false
    
    private var measurementStartTime: Date?
    private var currentMeasurementPoints: [CGPoint] = []
    
    // 测量点位置（与校准相同的5个点）
    private let measurementPositions: [(x: CGFloat, y: CGFloat)] = [
        (0.5, 0.5),  // 中心
        (0.1, 0.1),  // 左上
        (0.9, 0.1),  // 右上
        (0.1, 0.9),  // 左下
        (0.9, 0.9)   // 右下
    ]
    
    // 获取当前测量点的屏幕坐标
    var currentMeasurementPoint: CGPoint? {
        guard currentPointIndex < measurementPositions.count else { return nil }
        let position = measurementPositions[currentPointIndex]
        let frameSize = Device.frameSize
        return CGPoint(x: position.x * frameSize.width,
                       y: position.y * frameSize.height)
    }
    
    // 开始测量过程
    func startMeasurement() {
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
    
    // 收集测量数据点
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
    
    // 显示下一个测量点
    private func showNextMeasurementPoint() {
        guard currentPointIndex < measurementPositions.count else {
            finishMeasurement()
            return
        }
        
        currentMeasurementPoints.removeAll()
        measurementStartTime = nil  // 重置测量开始时间
        showCalibrationPoint = true
        
        // 显示每个点5秒，给用户更充足的时间注视
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            // 检查测量是否仍在进行
            guard self.isMeasuring else { return }
            
            if let currentPoint = self.currentMeasurementPoint {
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
    
    // 完成测量
    func finishMeasurement() {
        // 检查测量是否仍在进行，如果已停止则直接返回
        guard isMeasuring else { return }
        
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
    
    // 停止测量
    func stopMeasurement() {
        isMeasuring = false
        measurementCompleted = false
        showCalibrationPoint = false
        showMeasurementResults = false
        currentPointIndex = 0
        currentMeasurementPoints.removeAll()
        measurementResults.removeAll()
        measurementStartTime = nil
    }
}