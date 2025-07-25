import SwiftUI
import ARKit

// 轨迹测量类型
enum TrajectoryType {
    case figure8    // 8字形轨迹
    case sinusoidalTrajectory   // 正弦函数轨迹
}


// 8字形轨迹测量数据结构
struct TrajectoryMeasurementPoint {
    let targetPosition: CGPoint
    let actualPosition: CGPoint
    let timestamp: TimeInterval
    let error: CGFloat
    let eyeToScreenDistance: Float  // 眼睛到屏幕的距离（厘米）
}

// 轨迹测量结果
struct TrajectoryMeasurementResult {
    let trajectoryPoints: [TrajectoryMeasurementPoint]
    let averageError: CGFloat
    let maxError: CGFloat
    let minError: CGFloat
    let totalDuration: TimeInterval
    let coveragePercentage: Float  // 屏幕覆盖率
    let trajectoryType: TrajectoryType  // 轨迹类型
    
    // 计算ME(Mean Euclidean)误差，以厘米为单位
    var meanEuclideanErrorInCM: Double {
        return Device.pointsToCentimeters(averageError)
    }
    
    // 计算平均眼睛到屏幕距离（基于实际测量数据）
    var averageEyeToScreenDistance: Double {
        guard !trajectoryPoints.isEmpty else { return Device.defaultEyeToScreenDistance }
        let totalDistance = trajectoryPoints.map { Double($0.eyeToScreenDistance) }.reduce(0, +)
        return totalDistance / Double(trajectoryPoints.count)
    }
    
    // 计算ME(Mean Euclidean)误差，以角度为单位（使用实际测量的平均距离）
    var meanEuclideanErrorInDegrees: Double {
        let errorInCM = meanEuclideanErrorInCM
        return Device.centimetersToDegrees(errorInCM, eyeToScreenDistance: averageEyeToScreenDistance)
    }
    
    // 计算ME(Mean Euclidean)误差，以角度为单位（使用自定义距离）
    func meanEuclideanErrorInDegrees(eyeToScreenDistance: Double) -> Double {
        let errorInCM = meanEuclideanErrorInCM
        return Device.centimetersToDegrees(errorInCM, eyeToScreenDistance: eyeToScreenDistance)
    }
    
    // 计算最大误差，以角度为单位
    var maxErrorInDegrees: Double {
        let maxErrorInCM = Device.pointsToCentimeters(maxError)
        return Device.centimetersToDegrees(maxErrorInCM, eyeToScreenDistance: averageEyeToScreenDistance)
    }
    
    // 计算最小误差，以角度为单位
    var minErrorInDegrees: Double {
        let minErrorInCM = Device.pointsToCentimeters(minError)
        return Device.centimetersToDegrees(minErrorInCM, eyeToScreenDistance: averageEyeToScreenDistance)
    }
    
    // 数据点数量
    var dataSize: Int {
        return trajectoryPoints.count
    }
}

class MeasurementManager: ObservableObject {
    // 测量完成后的回调
    var onMeasurementCompleted: (() -> Void)?
    
    // 轨迹测量相关属性（支持8字形和正弦函数轨迹）
    @Published var isTrajectoryMeasuring: Bool = false
    @Published var trajectoryMeasurementCompleted: Bool = false
    @Published var trajectoryResults: TrajectoryMeasurementResult?
    @Published var showTrajectoryResults: Bool = false
    @Published var currentTrajectoryPoint: CGPoint = .zero
    @Published var showTrajectoryPoint: Bool = false
    @Published var showTrajectoryVisualization: Bool = false
    @Published var currentEyeToScreenDistance: Float = 30.0
    @Published var currentTrajectoryType: TrajectoryType = .figure8
    
    // 倒计时相关属性
    @Published var isTrajectoryCountingDown: Bool = false
    @Published var trajectoryCountdownValue: Int = 3
    @Published var showTrajectoryCountdown: Bool = false
    
    
    // 8字形轨迹测量相关私有属性
    private var trajectoryStartTime: Date?
    private var trajectoryMeasurementPoints: [TrajectoryMeasurementPoint] = []
    private var trajectoryTimer: Timer?
    private var trajectoryCountdownTimer: Timer?
    @Published var trajectoryProgress: Float = 0.0
    private var trajectoryDuration: TimeInterval {
        // 根据轨迹类型设置不同的时长
        switch currentTrajectoryType {
        case .figure8:
            return 30.0  // 8字测量30秒
        case .sinusoidalTrajectory:
            return 45.0  // 正弦函数轨迹测量45秒
        }
    }
    
    
    
    // MARK: - 轨迹测量功能（8字形和正弦函数轨迹）
    
    // 生成基于正弦波的正弦函数轨迹（带反向传播）
    private func generateSinusoidalTrajectoryPath(at progress: Float) -> CGPoint {
        let frameSize = Device.frameSize
        
        // 计算安全边距（考虑灵动岛和home indicator）
        let marginX: CGFloat = 30.0
        let marginY: CGFloat = 60.0  // 增加Y边距以避开灵动岛和home indicator
        
        // 计算可用区域
        let availableWidth = frameSize.width - 2 * marginX
        let availableHeight = frameSize.height - 2 * marginY
        
        // 将整个轨迹分为两个阶段：前进和反向
        let phase1Duration: Float = 0.5  // 前50%时间用于第一阶段
        let phase2Duration: Float = 0.5  // 后50%时间用于第二阶段
        
        let x: CGFloat
        let y: CGFloat
        
        if progress <= phase1Duration {
            // 第一阶段：从左上角开始的正弦波，从上到下
            let phase1Progress = progress / phase1Duration
            let waveFrequency: Float = 3.0  // 3个完整波形
            let amplitude = availableWidth / 2.0
            let centerX = frameSize.width / 2.0
            
            // Y坐标从上到下
            y = marginY + CGFloat(phase1Progress) * availableHeight
            
            // X坐标按正弦波变化，调整起始相位让轨迹从左上角开始
            // 左上角对应的相位：sin(phase) = -1，即 phase = 3π/2
            let startPhase: Float = 3.0 * Float.pi / 2.0  // 从左上角开始
            let wavePhase = startPhase + phase1Progress * waveFrequency * 2.0 * Float.pi
            let waveOffset = amplitude * CGFloat(sin(wavePhase))
            x = centerX + waveOffset
            
        } else {
            // 第二阶段：从下到上的正弦波（反向传播，改变频率以减少重叠）
            let phase2Progress = (progress - phase1Duration) / phase2Duration
            let waveFrequency: Float = 2.5  // 改变频率为2.5个波形，减少重叠
            let amplitude = availableWidth / 2.0
            let centerX = frameSize.width / 2.0
            
            // Y坐标从下到上（反向）
            y = marginY + availableHeight - CGFloat(phase2Progress) * availableHeight
            
            // X坐标按正弦波变化，但加上相位偏移确保连续性
            // 计算第一阶段结束时的X位置，确保第二阶段从这个位置开始
            let phase1StartPhase: Float = 3.0 * Float.pi / 2.0  // 第一阶段起始相位
            let phase1EndPhase = phase1StartPhase + 1.0 * 3.0 * 2.0 * Float.pi  // 第一阶段结束时的相位
            let phase1EndX = centerX + amplitude * CGFloat(sin(phase1EndPhase))
            
            // 第二阶段的起始相位，确保从第一阶段结束位置开始
            let phase2StartPhase = asin(Float((phase1EndX - centerX) / amplitude))
            let wavePhase = phase2StartPhase + phase2Progress * waveFrequency * 2.0 * Float.pi
            let waveOffset = amplitude * CGFloat(sin(wavePhase))
            x = centerX + waveOffset
        }
        
        // 确保坐标在屏幕边界内
        let clampedX = max(marginX, min(frameSize.width - marginX, x))
        let clampedY = max(marginY, min(frameSize.height - marginY, y))
        
        return CGPoint(x: clampedX, y: clampedY)
    }
    
    // 辅助函数：两点间线性插值
    private func interpolatePoints(from start: CGPoint, to end: CGPoint, t: CGFloat) -> CGPoint {
        let x = start.x + (end.x - start.x) * t
        let y = start.y + (end.y - start.y) * t
        return CGPoint(x: x, y: y)
    }
    
    // 生成8字形路径上的点
    private func generate8ShapePath(at progress: Float) -> CGPoint {
        let frameSize = Device.frameSize
        let centerX = frameSize.width / 2
        let centerY = frameSize.height / 2
        
        // 计算边距
        let marginX: CGFloat = 30.0
        let marginY: CGFloat = 30.0
        
        // 计算圆的半径 - 最大化利用屏幕空间
        let availableWidth = frameSize.width - marginX * 2
        
        // 水平方向约束：圆不能超出左右边界
        let maxRadiusFromWidth = availableWidth / 2
        
        // 垂直方向约束：两个圆需要能完全显示在屏幕内
        // 上圆最高点：centerY - 2*radius，需要 >= marginY
        // 下圆最低点：centerY + 2*radius，需要 <= frameSize.height - marginY
        // 所以：centerY - 2*radius >= marginY 且 centerY + 2*radius <= frameSize.height - marginY
        // 即：2*radius <= min(centerY - marginY, frameSize.height - marginY - centerY)
        let maxRadiusFromHeight = min(centerY - marginY, frameSize.height - marginY - centerY) / 2
        
        let circleRadius = min(maxRadiusFromWidth, maxRadiusFromHeight)
        
        // 上下圆心位置
        let upperCenterY = centerY - circleRadius
        let lowerCenterY = centerY + circleRadius
        
        let x: CGFloat
        let y: CGFloat
        
        if progress <= 0.5 {
            // 前半部分：从屏幕中心开始，顺时针画上面的圆，回到中心
            let circleProgress = progress * 2  // 0.0 到 1.0
            let angle = circleProgress * 2 * Float.pi  // 0 到 2π
            
            // 屏幕中心在上圆的底部，对应角度 π/2
            // 顺时针：从 π/2 开始，角度增加
            let adjustedAngle = Float.pi / 2 + angle
            x = centerX + circleRadius * CGFloat(cos(adjustedAngle))
            y = upperCenterY + circleRadius * CGFloat(sin(adjustedAngle))
        } else {
            // 后半部分：从屏幕中心开始，逆时针画下面的圆，回到中心
            let circleProgress = (progress - 0.5) * 2  // 0.0 到 1.0
            let angle = circleProgress * 2 * Float.pi  // 0 到 2π
            
            // 屏幕中心在下圆的顶部，对应角度 3π/2
            // 逆时针：从 3π/2 开始，角度减少
            let adjustedAngle = 3 * Float.pi / 2 - angle
            x = centerX + circleRadius * CGFloat(cos(adjustedAngle))
            y = lowerCenterY + circleRadius * CGFloat(sin(adjustedAngle))
        }
        
        // 确保坐标在屏幕范围内
        let clampedX = max(marginX, min(frameSize.width - marginX, x))
        let clampedY = max(marginY, min(frameSize.height - marginY, y))
        
        return CGPoint(x: clampedX, y: clampedY)
    }
    
    // 开始8字形轨迹测量
    func startTrajectoryMeasurement() {
        startTrajectoryMeasurement(type: .figure8)
    }
    
    // 开始正弦函数轨迹测量
    func startSinusoidalTrajectoryMeasurement() {
        startTrajectoryMeasurement(type: .sinusoidalTrajectory)
    }
    
    // 通用轨迹测量开始方法
    private func startTrajectoryMeasurement(type: TrajectoryType) {
        
        // 设置轨迹类型
        currentTrajectoryType = type
        
        // 重置所有状态
        isTrajectoryMeasuring = false  // 还没真正开始测量
        trajectoryMeasurementCompleted = false
        showTrajectoryResults = false
        trajectoryMeasurementPoints.removeAll()
        trajectoryProgress = 0.0
        trajectoryStartTime = nil  // 暂时不设置开始时间
        showTrajectoryPoint = true  // 倒计时期间显示起始轨迹点，让用户准备
        
        // 设置起始点位置（屏幕中心）
        let frameSize = Device.frameSize
        currentTrajectoryPoint = CGPoint(x: frameSize.width / 2, y: frameSize.height / 2)
        
        // 开始倒计时
        startTrajectoryCountdown()
    }
    
    // 开始轨迹测量倒计时
    private func startTrajectoryCountdown() {
        isTrajectoryCountingDown = true
        showTrajectoryCountdown = true
        trajectoryCountdownValue = 3
        
        let measurementType = currentTrajectoryType == .figure8 ? "8字测量" : "正弦函数轨迹测量"
        print("开始\(measurementType)倒计时...")
        
        trajectoryCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            
            self.trajectoryCountdownValue -= 1
            
            if self.trajectoryCountdownValue <= 0 {
                // 倒计时结束，开始真正的轨迹测量
                timer.invalidate()
                self.trajectoryCountdownTimer = nil
                self.finishCountdownAndStartTrajectory()
            }
        }
    }
    
    // 倒计时结束，开始真正的轨迹测量
    private func finishCountdownAndStartTrajectory() {
        isTrajectoryCountingDown = false
        showTrajectoryCountdown = false
        
        // 现在开始真正的轨迹测量
        isTrajectoryMeasuring = true
        trajectoryStartTime = Date()
        showTrajectoryPoint = true
        
        let measurementType = currentTrajectoryType == .figure8 ? "8字测量" : "正弦函数轨迹测量"
        print("倒计时结束，开始\(measurementType)，总时长: \(trajectoryDuration)秒")
        
        // 启动定时器，每16ms更新一次（约60fps）
        trajectoryTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] timer in
            self?.updateTrajectoryMeasurement()
        }
    }
    
    // 更新8字形轨迹测量
    private func updateTrajectoryMeasurement() {
        guard let startTime = trajectoryStartTime else { return }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        trajectoryProgress = Float(elapsedTime / trajectoryDuration)
        
        if trajectoryProgress >= 1.0 {
            // 测量完成
            finishTrajectoryMeasurement()
            return
        }
        
        // 更新当前目标点（根据轨迹类型）
        switch currentTrajectoryType {
        case .figure8:
            currentTrajectoryPoint = generate8ShapePath(at: trajectoryProgress)
        case .sinusoidalTrajectory:
            currentTrajectoryPoint = generateSinusoidalTrajectoryPath(at: trajectoryProgress)
        }
    }
    
    // 收集8字形轨迹测量数据
    func collectTrajectoryMeasurementPoint(_ actualPoint: CGPoint, eyeToScreenDistance: Float = 30.0) {
        // 只在真正的轨迹测量期间收集数据，倒计时期间不收集
        guard isTrajectoryMeasuring && !isTrajectoryCountingDown,
              let startTime = trajectoryStartTime else { return }
        
        // 更新实时距离显示
        currentEyeToScreenDistance = eyeToScreenDistance
        
        let currentTime = Date().timeIntervalSince(startTime)
        let targetPoint = currentTrajectoryPoint
        
        // 计算误差
        let error = sqrt(pow(actualPoint.x - targetPoint.x, 2) + pow(actualPoint.y - targetPoint.y, 2))
        
        // 创建轨迹测量点，包含实际测量的距离
        let trajectoryPoint = TrajectoryMeasurementPoint(
            targetPosition: targetPoint,
            actualPosition: actualPoint,
            timestamp: currentTime,
            error: error,
            eyeToScreenDistance: eyeToScreenDistance
        )
        
        trajectoryMeasurementPoints.append(trajectoryPoint)
        
        #if DEBUG
        if trajectoryMeasurementPoints.count % 60 == 0 {  // 每秒打印一次
            let measurementType = currentTrajectoryType == .figure8 ? "8字测量" : "正弦函数轨迹测量"
            print("\(measurementType)进度: \(Int(trajectoryProgress * 100))%, 当前误差: \(String(format: "%.1f", error))pt, 距离: \(String(format: "%.1f", eyeToScreenDistance))cm, 已采集: \(trajectoryMeasurementPoints.count)点")
        }
        #endif
    }
    
    // 完成8字形轨迹测量
    private func finishTrajectoryMeasurement() {
        trajectoryTimer?.invalidate()
        trajectoryTimer = nil
        
        isTrajectoryMeasuring = false
        trajectoryMeasurementCompleted = true
        showTrajectoryPoint = false
        
        // 计算统计结果
        if !trajectoryMeasurementPoints.isEmpty {
            let errors = trajectoryMeasurementPoints.map { $0.error }
            let avgError = errors.reduce(0, +) / CGFloat(errors.count)
            let maxError = errors.max() ?? 0
            let minError = errors.min() ?? 0
            let duration = trajectoryMeasurementPoints.last?.timestamp ?? 0
            
            // 计算屏幕覆盖率（简化版本）
            let frameSize = Device.frameSize
            let gridSize = 20
            var coveredCells: Set<String> = []
            
            for point in trajectoryMeasurementPoints {
                let gridX = Int(point.actualPosition.x / frameSize.width * CGFloat(gridSize))
                let gridY = Int(point.actualPosition.y / frameSize.height * CGFloat(gridSize))
                coveredCells.insert("\(gridX),\(gridY)")
            }
            
            let coveragePercentage = Float(coveredCells.count) / Float(gridSize * gridSize)
            
            trajectoryResults = TrajectoryMeasurementResult(
                trajectoryPoints: trajectoryMeasurementPoints,
                averageError: avgError,
                maxError: maxError,
                minError: minError,
                totalDuration: duration,
                coveragePercentage: coveragePercentage,
                trajectoryType: currentTrajectoryType
            )
            
            let measurementType = currentTrajectoryType == .figure8 ? "8字测量" : "正弦函数轨迹测量"
            print("\(measurementType)完成！")
            print("- 平均误差: \(String(format: "%.1f", avgError))pt")
            print("- 最大误差: \(String(format: "%.1f", maxError))pt")
            print("- 最小误差: \(String(format: "%.1f", minError))pt")
            print("- 测量时长: \(String(format: "%.1f", duration))秒")
            print("- 屏幕覆盖率: \(String(format: "%.1f", coveragePercentage * 100))%")
            print("- 采集数据点: \(trajectoryMeasurementPoints.count)个")
            
            showTrajectoryResults = true
            
            // 自动关闭gaze track以节省能耗
            onMeasurementCompleted?()
        } else {
            let measurementType = currentTrajectoryType == .figure8 ? "8字测量" : "正弦函数轨迹测量"
            print("\(measurementType)失败：没有收集到数据")
        }
    }
    
    // 停止8字形轨迹测量
    func stopTrajectoryMeasurement() {
        // 停止所有定时器
        trajectoryTimer?.invalidate()
        trajectoryTimer = nil
        trajectoryCountdownTimer?.invalidate()
        trajectoryCountdownTimer = nil
        
        // 重置所有状态
        isTrajectoryMeasuring = false
        isTrajectoryCountingDown = false
        trajectoryMeasurementCompleted = false
        showTrajectoryPoint = false
        showTrajectoryResults = false
        showTrajectoryCountdown = false
        showTrajectoryVisualization = false
        trajectoryMeasurementPoints.removeAll()
        trajectoryResults = nil
        trajectoryStartTime = nil
        trajectoryProgress = 0.0
        trajectoryCountdownValue = 3
        currentEyeToScreenDistance = 30.0
    }
    
    // 强制关闭结果页面和可视化页面
    func forceCloseResultsAndVisualization() {
        DispatchQueue.main.async {
            self.showTrajectoryResults = false
            self.showTrajectoryVisualization = false
        }
    }
}
