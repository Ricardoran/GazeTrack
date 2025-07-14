//
//  TrajectoryComparisonView.swift
//  GazeTrackApp
//
//  Created by Claude AI on 2025-07-08.
//

import SwiftUI

struct TrajectoryComparisonView: View {
    let trajectoryResults: TrajectoryMeasurementResult
    let screenSize: CGSize
    @State private var showLegend = true
    @Binding var showVisualization: Bool
    
    init(trajectoryResults: TrajectoryMeasurementResult, screenSize: CGSize, showVisualization: Binding<Bool>) {
        self.trajectoryResults = trajectoryResults
        self.screenSize = screenSize
        self._showVisualization = showVisualization
    }
    
    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            
            VStack {
                // 标题
                VStack(spacing: 20) {
                    HStack {
                        Spacer()
                        
                        Text("轨迹对比分析")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        
                        Spacer()
                    }
                    .padding(.top, 10)
                    
                    HStack {
                        BackButton(action: {
                            showVisualization = false
                        })
                        
                        Spacer()
                        
                        Button(showLegend ? "隐藏图例" : "显示图例") {
                            showLegend.toggle()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .padding(.top, 40)
                
                // 轨迹可视化
                GeometryReader { geometry in
                    let scale = min(geometry.size.width / screenSize.width, 
                                   geometry.size.height / screenSize.height) * 0.9
                    let scaledWidth = screenSize.width * scale
                    let scaledHeight = screenSize.height * scale
                    let offsetX = (geometry.size.width - scaledWidth) / 2
                    let offsetY = (geometry.size.height - scaledHeight) / 2
                    
                    ZStack {
                        // 背景框
                        Rectangle()
                            .stroke(Color.gray, lineWidth: 2)
                            .frame(width: scaledWidth, height: scaledHeight)
                            .position(x: geometry.size.width/2, y: geometry.size.height/2)
                        
                        // Ground Truth 轨迹（8字形）
                        Path { path in
                            let groundTruthPoints = generateGroundTruthTrajectory()
                            
                            for (index, point) in groundTruthPoints.enumerated() {
                                let scaledX = offsetX + point.x * scale
                                let scaledY = offsetY + point.y * scale
                                let scaledPoint = CGPoint(x: scaledX, y: scaledY)
                                
                                if index == 0 {
                                    path.move(to: scaledPoint)
                                } else {
                                    path.addLine(to: scaledPoint)
                                }
                            }
                        }
                        .stroke(Color.red, lineWidth: 3)
                        
                        
                        // 采样点标记 - 加粗显示
                        ForEach(Array(sampleTrajectoryPoints().enumerated()), id: \.offset) { index, point in
                            Circle()
                                .fill(Color.blue.opacity(0.8))
                                .frame(width: 6, height: 6)  // 加粗从4增加到6
                                .position(x: offsetX + point.x * scale, 
                                         y: offsetY + point.y * scale)
                        }
                        
                    }
                }
                
                // 图例和统计信息
                if showLegend {
                    VStack(spacing: 15) {
                        // 图例
                        HStack(spacing: 30) {
                            HStack {
                                Rectangle()
                                    .fill(Color.red)
                                    .frame(width: 20, height: 3)
                                Text("目标轨迹")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            HStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.8))
                                    .frame(width: 6, height: 6)
                                Text("实际轨迹")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // 测量结果 - 2x2网格布局
                        VStack(spacing: 16) {
                            // 第一行：距离误差 和 角度误差
                            HStack(spacing: 20) {
                                // 距离误差
                                VStack(spacing: 8) {
                                    Text("平均距离误差")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                    Text("\(String(format: "%.4f", trajectoryResults.meanEuclideanErrorInCM)) cm")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.black)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                                
                                // 角度误差
                                VStack(spacing: 8) {
                                    Text("平均角度误差")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                    Text("\(String(format: "%.4f", trajectoryResults.meanEuclideanErrorInDegrees))°")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            // 第二行：采样点数 和 眼睛到屏幕距离
                            HStack(spacing: 20) {
                                // 采样点数
                                VStack(spacing: 8) {
                                    Text("采样点数")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                    Text("\(sampleTrajectoryPoints().count)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)
                                
                                // 眼睛到屏幕距离
                                VStack(spacing: 8) {
                                    Text("眼睛到屏幕距离")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                    Text("\(String(format: "%.1f", trajectoryResults.averageEyeToScreenDistance)) cm")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.purple)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding()
                }
            }
        }
    }
    
    // 生成Ground Truth轨迹（根据轨迹类型）
    private func generateGroundTruthTrajectory() -> [CGPoint] {
        switch trajectoryResults.trajectoryType {
        case .figure8:
            return generateFigure8Trajectory()
        case .sinusoidalTrajectory:
            return generateSinusoidalTrajectory()
        }
    }
    
    // 生成8字形轨迹
    private func generateFigure8Trajectory() -> [CGPoint] {
        var points: [CGPoint] = []
        let centerX = screenSize.width / 2
        let centerY = screenSize.height / 2
        
        // 计算边距和半径（与MeasurementManager保持一致）
        let marginX: CGFloat = 30.0
        let marginY: CGFloat = 30.0
        let maxRadiusFromWidth = (screenSize.width - marginX * 2) / 2
        let maxRadiusFromHeight = min(centerY - marginY, screenSize.height - marginY - centerY) / 2
        let circleRadius = min(maxRadiusFromWidth, maxRadiusFromHeight)
        
        let upperCenterY = centerY - circleRadius
        let lowerCenterY = centerY + circleRadius
        
        // 生成足够密集的点来绘制平滑的8字形
        let totalPoints = 200
        
        for i in 0...totalPoints {
            let progress = Float(i) / Float(totalPoints)
            
            let x: CGFloat
            let y: CGFloat
            
            if progress <= 0.5 {
                // 上圆
                let circleProgress = progress * 2
                let angle = circleProgress * 2 * Float.pi
                let adjustedAngle = Float.pi / 2 + angle
                x = centerX + circleRadius * CGFloat(cos(adjustedAngle))
                y = upperCenterY + circleRadius * CGFloat(sin(adjustedAngle))
            } else {
                // 下圆
                let circleProgress = (progress - 0.5) * 2
                let angle = circleProgress * 2 * Float.pi
                let adjustedAngle = 3 * Float.pi / 2 - angle
                x = centerX + circleRadius * CGFloat(cos(adjustedAngle))
                y = lowerCenterY + circleRadius * CGFloat(sin(adjustedAngle))
            }
            
            let clampedX = max(marginX, min(screenSize.width - marginX, x))
            let clampedY = max(marginY, min(screenSize.height - marginY, y))
            points.append(CGPoint(x: clampedX, y: clampedY))
        }
        
        return points
    }
    
    // 生成正弦函数轨迹
    private func generateSinusoidalTrajectory() -> [CGPoint] {
        var points: [CGPoint] = []
        let totalPoints = 200
        
        for i in 0...totalPoints {
            let progress = Float(i) / Float(totalPoints)
            points.append(generateSinusoidalTrajectoryPoint(at: progress))
        }
        
        return points
    }
    
    // 生成基于正弦波的正弦函数轨迹（带反向传播，与MeasurementManager保持一致）
    private func generateSinusoidalTrajectoryPoint(at progress: Float) -> CGPoint {
        // 计算安全边距（考虑灵动岛和home indicator）
        let marginX: CGFloat = 30.0
        let marginY: CGFloat = 60.0  // 增加Y边距以避开灵动岛和home indicator
        
        // 计算可用区域
        let availableWidth = screenSize.width - 2 * marginX
        let availableHeight = screenSize.height - 2 * marginY
        
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
            let centerX = screenSize.width / 2.0
            
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
            let centerX = screenSize.width / 2.0
            
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
        let clampedX = max(marginX, min(screenSize.width - marginX, x))
        let clampedY = max(marginY, min(screenSize.height - marginY, y))
        
        return CGPoint(x: clampedX, y: clampedY)
    }
    
    // 辅助函数：两点间线性插值
    private func interpolatePoints(from start: CGPoint, to end: CGPoint, t: CGFloat) -> CGPoint {
        let x = start.x + (end.x - start.x) * t
        let y = start.y + (end.y - start.y) * t
        return CGPoint(x: x, y: y)
    }
    
    // 对轨迹数据进行合适的采样
    private func sampleTrajectoryPoints() -> [CGPoint] {
        let allPoints = trajectoryResults.trajectoryPoints
        guard !allPoints.isEmpty else { return [] }
        
        // 每10个点采样一个，保持合理的密度
        let sampleRate = 10
        var sampledPoints: [CGPoint] = []
        
        for i in stride(from: 0, to: allPoints.count, by: sampleRate) {
            sampledPoints.append(allPoints[i].actualPosition)
        }
        
        // 确保包含最后一个点
        if let lastPoint = allPoints.last {
            sampledPoints.append(lastPoint.actualPosition)
        }
        
        return sampledPoints
    }
}

#if DEBUG
struct TrajectoryComparisonView_Previews: PreviewProvider {
    static var previews: some View {
        let samplePoints = [
            TrajectoryMeasurementPoint(
                targetPosition: CGPoint(x: 200, y: 400),
                actualPosition: CGPoint(x: 195, y: 405),
                timestamp: 0.0,
                error: 7.0,
                eyeToScreenDistance: 30.0
            )
        ]
        
        let sampleResult = TrajectoryMeasurementResult(
            trajectoryPoints: samplePoints,
            averageError: 50.0,
            maxError: 120.0,
            minError: 10.0,
            totalDuration: 30.0,
            coveragePercentage: 0.8,
            trajectoryType: .figure8
        )
        
        TrajectoryComparisonView(
            trajectoryResults: sampleResult,
            screenSize: CGSize(width: 400, height: 800),
            showVisualization: .constant(true)
        )
    }
}
#endif