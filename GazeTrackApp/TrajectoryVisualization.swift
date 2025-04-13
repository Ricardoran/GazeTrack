//
//  TrajectoryVisualization.swift
//  GazeTrackApp
//
//  Created by Haoran Zhang on 3/2/25.
//

import SwiftUI

// 轨迹可视化视图
struct TrajectoryVisualizationView: View {
    let gazeTrajectory: [GazeData]
    let opacity: Double
    let screenSize: CGSize
    
    var body: some View {
        ZStack {
            // 绘制轨迹线
            TrajectoryLineView(gazeTrajectory: gazeTrajectory)
                .stroke(Color.red, lineWidth: 2)
                .opacity(opacity)
            
            // 绘制注视点
            ForEach(0..<gazeTrajectory.count, id: \.self) { index in
                let point = gazeTrajectory[index]
                let size = getPointSize(index: index)
                
                Circle()
                    .fill(getPointColor(index: index))
                    .frame(width: size, height: size)
                    .position(x: point.x, y: point.y)
                    .opacity(opacity * 0.7)
            }
            
            // 添加坐标轴标签
            VStack {
                HStack {
                    Spacer()
                    Text("时间轴：蓝色 → 红色")
                        .font(.caption)
                        .foregroundColor(.black)
                        .padding(8)
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(5)
                        .padding(10)
                }
                Spacer()
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    // 根据点的位置获取颜色（从蓝色渐变到红色）
    private func getPointColor(index: Int) -> Color {
        let progress = min(1.0, Double(index) / Double(max(1, gazeTrajectory.count - 1)))
        return Color(
            red: progress,
            green: 0.2,
            blue: 1.0 - progress
        )
    }
    
    // 根据点的位置获取大小（越靠后的点越大）
    private func getPointSize(index: Int) -> CGFloat {
        let baseSize: CGFloat = 5
        let maxSize: CGFloat = 15
        let progress = min(1.0, Double(index) / Double(max(1, gazeTrajectory.count - 1)))
        
        return baseSize + CGFloat(progress) * (maxSize - baseSize)
    }
}

// 轨迹线视图
struct TrajectoryLineView: Shape {
    let gazeTrajectory: [GazeData]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard !gazeTrajectory.isEmpty else { return path }
        
        // 移动到第一个点
        path.move(to: CGPoint(x: gazeTrajectory[0].x, y: gazeTrajectory[0].y))
        
        // 连接所有点
        for point in gazeTrajectory.dropFirst() {
            path.addLine(to: CGPoint(x: point.x, y: point.y))
        }
        
        return path
    }
}

// 轨迹数据分析工具（为未来扩展准备）
struct TrajectoryAnalyzer {
    static func calculateFixations(from trajectory: [GazeData], distanceThreshold: CGFloat = 50, timeThreshold: TimeInterval = 0.2) -> [GazeData] {
        // 这里将来可以实现注视点检测算法
        return []
    }
    
    static func calculateSaccades(from trajectory: [GazeData]) -> [(start: GazeData, end: GazeData)] {
        // 这里将来可以实现眼跳检测算法
        return []
    }
}