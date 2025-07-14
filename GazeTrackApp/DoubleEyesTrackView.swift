import SwiftUI

struct DoubleEyesTrackView: View {
    @Binding var currentView: AppView
    @StateObject private var doubleEyesManager = DoubleEyesTrackManager()
    @State private var smoothingWindowSize: Int = 10 // 默认10点窗口
    @State private var useLookAtPointMethod: Bool = false // 是否使用lookAtPoint+hitTest方法
    
    var body: some View {
        ZStack {
            // AR View Container
            DoubleEyesARViewContainer(manager: doubleEyesManager, smoothingWindowSize: $smoothingWindowSize, useLookAtPointMethod: $useLookAtPointMethod)
                .ignoresSafeArea()
            
            VStack {
                // Top controls
                HStack {
                    BackButton(action: {
                        currentView = .landing
                    })
                    
                    Spacer()
                    
                    Text("Double Eyes Track")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(10)
                    
                    Spacer()
                    
                    // 方法切换按钮
                    Button(action: {
                        useLookAtPointMethod.toggle()
                    }) {
                        Text(useLookAtPointMethod ? "L+H" : "D+H")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(useLookAtPointMethod ? Color.blue.opacity(0.8) : Color.orange.opacity(0.8))
                            .clipShape(Circle())
                    }
                    
                    Button(action: {
                        doubleEyesManager.resetTracking()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
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
                            doubleEyesManager.updateSmoothingWindowSize(smoothingWindowSize)
                        }
                    ), in: 0.0...50.0, step: 1.0)
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
                
                // Bottom info panel
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Left Eye")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text("X: \(String(format: "%.1f", doubleEyesManager.leftEyeGaze.x))")
                                .font(.caption2)
                                .foregroundColor(.white)
                            Text("Y: \(String(format: "%.1f", doubleEyesManager.leftEyeGaze.y))")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Right Eye")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("X: \(String(format: "%.1f", doubleEyesManager.rightEyeGaze.x))")
                                .font(.caption2)
                                .foregroundColor(.white)
                            Text("Y: \(String(format: "%.1f", doubleEyesManager.rightEyeGaze.y))")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                    }
                    
                    HStack {
                        Text("Average Gaze")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Spacer()
                        
                        Text("X: \(String(format: "%.1f", doubleEyesManager.averageGaze.x)), Y: \(String(format: "%.1f", doubleEyesManager.averageGaze.y))")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    
                    HStack {
                        Text("方法")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text(useLookAtPointMethod ? "lookAtPoint + hitTest" : "双眼分别 + hitTest")
                            .font(.caption2)
                            .foregroundColor(useLookAtPointMethod ? .blue : .orange)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(15)
                .padding()
            }
            
            // Average gaze indicator only
            if doubleEyesManager.isTracking {
                GeometryReader { geometry in
                    // 直接使用gaze点坐标，无需添加safe area offset
                    // 这与原有gaze track的显示方式保持一致
                    Circle()
                        .fill(Color.green.opacity(0.8))
                        .frame(width: 25, height: 25)
                        .position(x: doubleEyesManager.averageGaze.x, y: doubleEyesManager.averageGaze.y)
                }
            }
        }
        .onAppear {
            doubleEyesManager.startTracking()
            // 设置初始窗口大小
            doubleEyesManager.updateSmoothingWindowSize(smoothingWindowSize)
        }
        .onDisappear {
            doubleEyesManager.stopTracking()
        }
    }
}

#if DEBUG
struct DoubleEyesTrackView_Previews: PreviewProvider {
    static var previews: some View {
        DoubleEyesTrackView(currentView: .constant(.doubleEyesTrack))
    }
}
#endif