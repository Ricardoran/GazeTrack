import SwiftUI

enum EyeTrackingMethod: CaseIterable {
    case dualEyesHitTest       // 双眼分别计算 + hitTest
    case lookAtPointMatrix     // lookAtPoint + 矩阵变换 (主要gaze track方法)
    case lookAtPointHitTest    // lookAtPoint + hitTest
    
    var displayName: String {
        switch self {
        case .dualEyesHitTest:
            return "Binocular + HitTest"
        case .lookAtPointMatrix:
            return "LookAt + Matrix"
        case .lookAtPointHitTest:
            return "LookAt + HitTest"
        }
    }
    
    var shortName: String {
        switch self {
        case .dualEyesHitTest:
            return "D+H"
        case .lookAtPointMatrix:
            return "L+M"
        case .lookAtPointHitTest:
            return "L+H"
        }
    }
    
    var color: Color {
        switch self {
        case .dualEyesHitTest:
            return .orange
        case .lookAtPointMatrix:
            return .blue
        case .lookAtPointHitTest:
            return .purple
        }
    }
}

struct GazeTrackLabView: View {
    @Binding var currentView: AppView
    @StateObject private var labManager = GazeTrackLabManager()
    @StateObject private var uiManager = UIManager()
    @State private var smoothingWindowSize: Int = 10 // 默认10点窗口
    @State private var currentMethod: EyeTrackingMethod = .dualEyesHitTest // 当前追踪方法
    @State private var showGrid: Bool = false // 是否显示网格标识
    
    var body: some View {
        ZStack {
            // AR View Container
            GazeTrackLabARViewContainer(manager: labManager, smoothingWindowSize: $smoothingWindowSize, trackingMethod: $currentMethod)
                .ignoresSafeArea()
                .onTapGesture {
                    uiManager.showButtons = true
                    uiManager.resetButtonHideTimer()
                }
            
            VStack {
                // Top controls
                HStack {
                    BackButton(action: {
                        currentView = .landing
                    })
                    
                    Spacer()
                    
                    // 方法切换按钮 (原来的标题位置)
                    Button(action: {
                        // 循环切换到下一个方法
                        let allMethods = EyeTrackingMethod.allCases
                        if let currentIndex = allMethods.firstIndex(of: currentMethod) {
                            let nextIndex = (currentIndex + 1) % allMethods.count
                            currentMethod = allMethods[nextIndex]
                        }
                        uiManager.resetButtonHideTimer()
                    }) {
                        VStack(spacing: 2) {
                            Text("Gaze Track Lab")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(currentMethod.displayName)
                                .font(.caption)
                                .foregroundColor(currentMethod.color)
                        }
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(10)
                    }
                    
                    Spacer()
                    
                    // 网格切换按钮
                    UnifiedButton(
                        action: {
                            showGrid.toggle()
                            uiManager.resetButtonHideTimer()
                        },
                        icon: showGrid ? "grid.circle.fill" : "grid.circle",
                        backgroundColor: Color.black.opacity(0.6),
                        style: .compact
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .opacity(uiManager.showButtons ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: uiManager.showButtons)
                
                Spacer()
                
                // 简化的平滑控制滑块
                HStack {
                    Text("响应")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Slider(value: Binding(
                        get: { Double(smoothingWindowSize) },
                        set: { 
                            smoothingWindowSize = Int($0)
                            labManager.updateSmoothingWindowSize(smoothingWindowSize)
                        }
                    ), in: 0.0...50.0, step: 1.0, onEditingChanged: { editing in
                        if editing {
                            uiManager.resetButtonHideTimer()
                        }
                    })
                    .accentColor(.green)
                    
                    Text("\(smoothingWindowSize)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                        .frame(minWidth: 20)
                    
                    Text("稳定")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .opacity(uiManager.showButtons ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: uiManager.showButtons)
                
                // 距离显示组件
                EyeToScreenDistanceView(distance: labManager.currentEyeToScreenDistance)
                    .padding()
                    .opacity(uiManager.showButtons ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: uiManager.showButtons)
            }
            
            // 网格覆盖层
            if showGrid {
                GridOverlayView()
                    .allowsHitTesting(false) // 不阻挡AR视图的交互
            }
            
            // Average gaze indicator only
            if labManager.isTracking {
                GeometryReader { geometry in
                    // 直接使用gaze点坐标，无需添加safe area offset
                    // 这与原有gaze track的显示方式保持一致
                    Circle()
                        .fill(currentMethod.color.opacity(0.8))
                        .frame(width: 25, height: 25)
                        .position(x: labManager.averageGaze.x, y: labManager.averageGaze.y)
                }
            }
        }
        .onAppear {
            labManager.startTracking()
            // 设置初始窗口大小
            labManager.updateSmoothingWindowSize(smoothingWindowSize)
            // 启动UI自动隐藏计时器
            uiManager.showButtons = true
            uiManager.setupButtonHideTimer()
        }
        .onDisappear {
            labManager.stopTracking()
            uiManager.cleanup()
        }
    }
}

struct GridOverlayView: View {
    let gridLabels = [
        ["A", "B", "C", "D"],
        ["E", "F", "G", "H"],
        ["I", "J", "K", "L"],
        ["M", "N", "O", "P"],
        ["Q", "R", "S", "T"],
        ["U", "V", "W", "X"],
        ["Y", "Z", "#", "@"]
    ]
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let cellWidth = screenWidth / 4
            let cellHeight = screenHeight / 7
            
            ZStack {
                // 绘制网格线
                Path { path in
                    // 垂直线
                    for i in 1..<4 {
                        let x = CGFloat(i) * cellWidth
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: screenHeight))
                    }
                    
                    // 水平线
                    for i in 1..<7 {
                        let y = CGFloat(i) * cellHeight
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: screenWidth, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                
                // 添加标签
                ForEach(0..<7, id: \.self) { row in
                    ForEach(0..<4, id: \.self) { col in
                        let label = gridLabels[row][col]
                        let x = CGFloat(col) * cellWidth + cellWidth/2
                        let y = CGFloat(row) * cellHeight + cellHeight/2
                        
                        Text(label)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.7))
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }
}

#if DEBUG
struct GazeTrackLabView_Previews: PreviewProvider {
    static var previews: some View {
        GazeTrackLabView(currentView: .constant(.gazeTrackLab))
    }
}
#endif
