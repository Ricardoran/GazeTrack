import SwiftUI

struct TrajectoryDetailView: View {
    let record: GazeRecord
    @Environment(\.presentationMode) var presentationMode
    @State private var showPath = true
    @State private var showPoints = true
    @State private var animationProgress: CGFloat = 0
    @State private var isAnimating = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.opacity(0.9)
                    .ignoresSafeArea()
                
                VStack {
                    // Header
                    HStack {
                        Button("Close") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("Trajectory View")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Menu {
                            Button(action: { showPath.toggle() }) {
                                Label(showPath ? "Hide Path" : "Show Path", 
                                      systemImage: showPath ? "eye.slash" : "eye")
                            }
                            
                            Button(action: { showPoints.toggle() }) {
                                Label(showPoints ? "Hide Points" : "Show Points", 
                                      systemImage: showPoints ? "circle.slash" : "circle")
                            }
                            
                            Button(action: toggleAnimation) {
                                Label(isAnimating ? "Stop Animation" : "Start Animation", 
                                      systemImage: isAnimating ? "pause" : "play")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.white)
                                .font(.title2)
                        }
                    }
                    .padding()
                    
                    // Record info
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.formattedTitle)
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Text("\(record.formattedDuration) • \(record.gazePoints.count) points")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        if let method = record.metadata.trackingMethod {
                            Text(method)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.3))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Trajectory view
                    GeometryReader { geometry in
                        ZStack {
                            // Screen boundary
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            
                            // Trajectory visualization
                            TrajectoryCanvas(
                                record: record,
                                showPath: showPath,
                                showPoints: showPoints,
                                animationProgress: animationProgress,
                                canvasSize: geometry.size
                            )
                        }
                        .padding()
                    }
                    
                    // Animation controls
                    if !record.gazePoints.isEmpty {
                        VStack(spacing: 12) {
                            // Progress slider
                            Slider(value: $animationProgress, in: 0...1) { editing in
                                if editing {
                                    isAnimating = false
                                }
                            }
                            .accentColor(.blue)
                            
                            // Control buttons
                            HStack(spacing: 20) {
                                Button(action: {
                                    animationProgress = 0
                                    isAnimating = false
                                }) {
                                    Image(systemName: "backward.end")
                                        .foregroundColor(.white)
                                        .font(.title2)
                                }
                                
                                Button(action: toggleAnimation) {
                                    Image(systemName: isAnimating ? "pause" : "play")
                                        .foregroundColor(.white)
                                        .font(.title2)
                                }
                                
                                Button(action: {
                                    animationProgress = 1
                                    isAnimating = false
                                }) {
                                    Image(systemName: "forward.end")
                                        .foregroundColor(.white)
                                        .font(.title2)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private func toggleAnimation() {
        isAnimating.toggle()
        
        if isAnimating {
            withAnimation(.linear(duration: Double(record.duration) * (1 - animationProgress))) {
                animationProgress = 1.0
            }
        }
    }
}

struct TrajectoryCanvas: View {
    let record: GazeRecord
    let showPath: Bool
    let showPoints: Bool
    let animationProgress: CGFloat
    let canvasSize: CGSize
    
    private var visiblePoints: [GazePoint] {
        let totalPoints = record.gazePoints.count
        let visibleCount = Int(CGFloat(totalPoints) * animationProgress)
        return Array(record.gazePoints.prefix(visibleCount))
    }
    
    var body: some View {
        Canvas { context, size in
            // 计算缩放比例，以适应canvas
            let scaleX = size.width / record.metadata.screenSize.width
            let scaleY = size.height / record.metadata.screenSize.height
            let scale = min(scaleX, scaleY) * 0.9 // 留一些边距
            
            let offsetX = (size.width - record.metadata.screenSize.width * scale) / 2
            let offsetY = (size.height - record.metadata.screenSize.height * scale) / 2
            
            // 绘制路径
            if showPath && visiblePoints.count > 1 {
                var path = Path()
                
                for (index, point) in visiblePoints.enumerated() {
                    let x = CGFloat(point.x) * scale + offsetX
                    let y = CGFloat(point.y) * scale + offsetY
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                
                context.stroke(
                    path,
                    with: .color(.blue.opacity(0.7)),
                    lineWidth: 2
                )
            }
            
            // 绘制点
            if showPoints {
                for (index, point) in visiblePoints.enumerated() {
                    let x = CGFloat(point.x) * scale + offsetX
                    let y = CGFloat(point.y) * scale + offsetY
                    
                    // 颜色渐变：从绿色（开始）到红色（结束）
                    let progress = CGFloat(index) / CGFloat(max(1, visiblePoints.count - 1))
                    let color = Color(
                        red: progress,
                        green: 1 - progress,
                        blue: 0.3
                    )
                    
                    // 点的大小根据时间顺序变化
                    let radius = 2.0 + (3.0 * progress)
                    
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: x - radius,
                            y: y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )),
                        with: .color(color.opacity(0.8))
                    )
                }
            }
            
            // 绘制当前位置指示器
            if let currentPoint = visiblePoints.last {
                let x = CGFloat(currentPoint.x) * scale + offsetX
                let y = CGFloat(currentPoint.y) * scale + offsetY
                
                // 外圈
                context.stroke(
                    Path(ellipseIn: CGRect(x: x - 8, y: y - 8, width: 16, height: 16)),
                    with: .color(.white),
                    lineWidth: 2
                )
                
                // 内圈
                context.fill(
                    Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8)),
                    with: .color(.red)
                )
            }
        }
    }
}

#if DEBUG
struct TrajectoryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let samplePoints = [
            GazePoint(x: 100, y: 100, relativeTimestamp: 0),
            GazePoint(x: 200, y: 150, relativeTimestamp: 1),
            GazePoint(x: 300, y: 200, relativeTimestamp: 2)
        ]
        let sampleRecord = GazeRecord(
            gazePoints: samplePoints,
            metadata: RecordMetadata(trackingMethod: "LookAt + Matrix")
        )
        
        TrajectoryDetailView(record: sampleRecord)
    }
}
#endif