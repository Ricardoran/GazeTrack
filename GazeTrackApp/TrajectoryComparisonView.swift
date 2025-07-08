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
                VStack(spacing: 10) {
                    HStack {
                        Spacer()
                        
                        Text("轨迹对比分析")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Button("关闭") {
                            showVisualization = false
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(8)
                        
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
                                Text("目标轨迹 (Ground Truth)")
                                    .font(.caption)
                            }
                            
                            HStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.8))
                                    .frame(width: 6, height: 6)
                                Text("实际轨迹 (Eye Tracking)")
                                    .font(.caption)
                            }
                        }
                        
                        // ME(Mean Euclidean)显示 - 主要指标
                        VStack(spacing: 8) {
                            Text("ME(Mean Euclidean): \(String(format: "%.4f", trajectoryResults.meanEuclideanErrorInCM)) (CM)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                            
                            Text("Data size: \(trajectoryResults.dataSize)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        
                        // 其他统计信息
                        HStack(spacing: 20) {
                            VStack {
                                Text("平均误差")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(String(format: "%.1f", trajectoryResults.averageError)) pt")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                            
                            VStack {
                                Text("最大误差")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(String(format: "%.1f", trajectoryResults.maxError)) pt")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                            
                            VStack {
                                Text("覆盖率")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(String(format: "%.1f", trajectoryResults.coveragePercentage * 100))%")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                            
                            VStack {
                                Text("采样点数")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(sampleTrajectoryPoints().count)")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
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
    
    // 生成Ground Truth轨迹（8字形）
    private func generateGroundTruthTrajectory() -> [CGPoint] {
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
                error: 7.0
            )
        ]
        
        let sampleResult = TrajectoryMeasurementResult(
            trajectoryPoints: samplePoints,
            averageError: 50.0,
            maxError: 120.0,
            minError: 10.0,
            totalDuration: 30.0,
            coveragePercentage: 0.8
        )
        
        TrajectoryComparisonView(
            trajectoryResults: sampleResult,
            screenSize: CGSize(width: 400, height: 800),
            showVisualization: .constant(true)
        )
    }
}
#endif