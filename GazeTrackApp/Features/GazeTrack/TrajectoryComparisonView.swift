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
                // 顶部标题栏 - 统一水平布局
                HStack {
                    // 返回按钮
                    UnifiedButton(
                        action: { showVisualization = false },
                        icon: "chevron.left",
                        text: "返回结果",
                        backgroundColor: Color.blue.opacity(0.8),
                        style: .compact
                    )
                    
                    Spacer()
                    
                    // 标题
                    Text("轨迹对比分析")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    // 图例切换按钮
                    UnifiedButton(
                        action: { showLegend.toggle() },
                        icon: showLegend ? "eye.slash" : "eye",
                        text: showLegend ? "隐藏图例" : "显示图例",
                        backgroundColor: Color.blue.opacity(0.8),
                        style: .compact
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                .padding(.bottom, 10)
                
                // 轨迹可视化区域
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
                
                // 底部图例和统计信息
                if showLegend {
                    VStack(spacing: 12) {
                        // 图例说明
                        HStack(spacing: 25) {
                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(Color.red)
                                    .frame(width: 24, height: 4)
                                    .cornerRadius(2)
                                Text("目标轨迹")
                                    .font(.subheadline)
                                    .foregroundColor(.black)
                            }
                            
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.blue.opacity(0.8))
                                    .frame(width: 8, height: 8)
                                Text("实际轨迹")
                                    .font(.subheadline)
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(.bottom, 8)
                        
                        // 统计数据 - 优化布局
                        VStack(spacing: 12) {
                            // 第一行：主要误差指标
                            HStack(spacing: 15) {
                                StatCard(
                                    title: "平均距离误差",
                                    value: "\(String(format: "%.3f", trajectoryResults.meanEuclideanErrorInCM)) cm",
                                    color: .red
                                )
                                
                                StatCard(
                                    title: "平均角度误差",
                                    value: "\(String(format: "%.3f", trajectoryResults.meanEuclideanErrorInDegrees))°",
                                    color: .blue
                                )
                            }
                            
                            // 第二行：辅助信息
                            HStack(spacing: 15) {
                                StatCard(
                                    title: "采样点数",
                                    value: "\(sampleTrajectoryPoints().count)",
                                    color: .green
                                )
                                
                                StatCard(
                                    title: "观测距离",
                                    value: "\(String(format: "%.1f", trajectoryResults.averageEyeToScreenDistance)) cm",
                                    color: .purple
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
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

// 统计卡片组件
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(color.opacity(0.08))
        .cornerRadius(8)
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