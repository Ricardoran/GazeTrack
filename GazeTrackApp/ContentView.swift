import SwiftUI
import Combine
import AVKit


struct ContentView: View {
    // 眼动追踪状态
    @State private var eyeGazeActive: Bool = false
    @State private var lookAtPoint: CGPoint?
    @State private var isWinking: Bool = false
    @State private var timerPublisher = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()
    
    // 管理器
    @StateObject private var calibrationManager = CalibrationManager()
    @StateObject private var trajectoryManager = TrajectoryManager()
    @StateObject private var videoManager = VideoManager()
    @StateObject private var uiManager = UIManager()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // AR 视图容器
            ARViewContainer(
                eyeGazeActive: $eyeGazeActive,
                lookAtPoint: $lookAtPoint,
                isWinking: $isWinking,
                calibrationManager: calibrationManager
            )
            .onReceive(timerPublisher) { _ in
                if eyeGazeActive && !trajectoryManager.isCountingDown,
                   let point = lookAtPoint {
                    trajectoryManager.addTrajectoryPoint(point: point)
                }
            }.onAppear {
                Device.printScreenSize()
            }
            
            // 视频播放器（视频模式下）
            if videoManager.videoMode {
                ZStack {
                    CustomVideoPlayer(player: videoManager.player, showButtons: $uiManager.showButtons)
                        .opacity(videoManager.videoOpacity)
                        .onAppear {
                            videoManager.setupVideoPlayer()
                        }
                        .onDisappear {
                            videoManager.player.pause()
                        }
                        // 添加额外的点击手势识别器
                        .onTapGesture {
                            uiManager.showButtons = true
                            uiManager.resetButtonHideTimer()
                        }
                }
            }

            // 校准点视图
            if calibrationManager.isCalibrating && calibrationManager.showCalibrationPoint,
               let calibrationPoint = calibrationManager.currentCalibrationPoint {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 30, height: 30)
                    .position(calibrationPoint)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: calibrationManager.currentPointIndex)
            }

            // 按钮组
            VStack(spacing: 20) {
                Group {
                    // 校准按钮
                    Button("开始校准") {
                        handleCalibration()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
                    
                    // 视频模式切换按钮
                    Button(action: {
                        videoManager.toggleVideoMode()
                        uiManager.resetButtonHideTimer()
                    }) {
                        Text(videoManager.videoMode ? "相机" : "视频")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(10)
                    }
                    
                    // 视频透明度滑块（仅在视频模式下显示）
                    if videoManager.videoMode {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("视频透明度: \(Int(videoManager.videoOpacity * 100))%")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(5)
                            
                            Slider(value: $videoManager.videoOpacity, in: 0.1...1.0, onEditingChanged: { editing in
                                if editing {
                                    uiManager.resetButtonHideTimer()
                                }
                            })
                            .padding(.horizontal)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(10)
                            .padding(.horizontal, 10)
                        }
                        .padding(.vertical, 5)
                    }
                    
                    // 开始/停止按钮
                    Button(action: {
                        handleStartStop()
                        uiManager.resetButtonHideTimer()
                    }) {
                        Text(eyeGazeActive ? "停止" : "开始")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    // 导出轨迹按钮
                    Button(action: {
                        handleExportTrajectory()
                        uiManager.resetButtonHideTimer()
                    }) {
                        Text("导出轨迹")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                            .opacity((eyeGazeActive || trajectoryManager.gazeTrajectory.isEmpty || !trajectoryManager.isValidTrajectory()) ? 0.5 : 1.0)
                    }
                    .disabled(eyeGazeActive || trajectoryManager.gazeTrajectory.isEmpty || !trajectoryManager.isValidTrajectory())
                    
                    // 显示轨迹图按钮
                    Button(action: {
                        trajectoryManager.showTrajectoryView.toggle()
                        uiManager.resetButtonHideTimer()
                    }) {
                        Text("显示轨迹")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(10)
                            .opacity((eyeGazeActive || trajectoryManager.gazeTrajectory.isEmpty || !trajectoryManager.isValidTrajectory()) ? 0.5 : 1.0)
                    }
                    .disabled(eyeGazeActive || trajectoryManager.gazeTrajectory.isEmpty || !trajectoryManager.isValidTrajectory())
                }
                .opacity(uiManager.showButtons ? 1 : 0)
            }
            .padding(.bottom, 50)
            .opacity(uiManager.showButtons ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: uiManager.showButtons)
            .alert(isPresented: $uiManager.showExportAlert) {
                Alert(title: Text("导出完成"),
                      message: Text("轨迹导出成功。"),
                      dismissButton: .default(Text("确定")))
            }

            // 轨迹可视化视图
            if trajectoryManager.showTrajectoryView && !trajectoryManager.gazeTrajectory.isEmpty {
                ZStack {
                    Color.white
                    
                    TrajectoryVisualizationView(
                        gazeTrajectory: trajectoryManager.gazeTrajectory,
                        opacity: 1.0,
                        screenSize: UIScreen.main.bounds.size
                    )
                    
                    // 关闭按钮
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                trajectoryManager.showTrajectoryView = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.black)
                                    .padding()
                            }
                        }
                        Spacer()
                    }
                }
                .zIndex(100)
            }

            // 倒计时显示
            if trajectoryManager.showCountdown {
                Text("\(trajectoryManager.countdownValue)")
                    .font(.system(size: 100, weight: .bold))
                    .foregroundColor(.white)
                    .padding(30)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)
                    .transition(.scale)
            }

            // 视线点显示
            if let lookAtPoint = lookAtPoint, eyeGazeActive {
                Circle()
                    .fill(Color.red)
                    .frame(width: isWinking ? 100 : 40, height: isWinking ? 100 : 40)
                    .position(lookAtPoint)
            }
        }
        .onTapGesture {
            // 点击屏幕时显示按钮并重置计时器
            uiManager.showButtons = true
            uiManager.resetButtonHideTimer()
        }
        .onAppear {
            // 初始化
            videoManager.setupVideoPlayer()
            uiManager.setupButtonHideTimer()
        }
        .onDisappear {
            // 清理资源
            uiManager.cleanup()
            videoManager.cleanup()
        }
    }
    
    // button functions
    
    // 处理开始/停止
    func handleStartStop() {
        if !eyeGazeActive {
            // 立即激活眼动追踪，但不立即记录
            print("开始眼动追踪...")
            trajectoryManager.resetTrajectory()
            eyeGazeActive = true
            
            // 开始倒计时
            trajectoryManager.startCountdown {
                // 倒计时结束后的回调
            }
        } else {
            // 停止追踪
            print("停止眼动追踪...")
            eyeGazeActive = false
            
            // 处理轨迹数据
            trajectoryManager.processTrajectoryData()
            
            // 如果正在倒计时，取消倒计时
            if trajectoryManager.isCountingDown {
                trajectoryManager.isCountingDown = false
                trajectoryManager.showCountdown = false
            }
        }
    }
    
    // 处理校准
    func handleCalibration() {
        calibrationManager.startCalibration()
    }
    
    // 处理导出轨迹
    func handleExportTrajectory() {
        print("导出包含 \(trajectoryManager.gazeTrajectory.count) 个数据点的轨迹...")
        trajectoryManager.exportTrajectory {
            uiManager.showExportAlert = true
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
