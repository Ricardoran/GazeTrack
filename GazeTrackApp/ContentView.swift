import SwiftUI
import Combine
import AVKit


struct ContentView: View {
    let mode: ViewMode
    @Binding var currentView: AppView
    let autoStart: Bool
    
    // 眼动追踪状态
    @State private var eyeGazeActive: Bool = false
    @State private var lookAtPoint: CGPoint?
    @State private var isWinking: Bool = false
    @State private var timerPublisher = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()
    @State private var showCalibrationGreeting = false

    // 管理器
    @ObservedObject var calibrationManager: CalibrationManager
    @ObservedObject var measurementManager: MeasurementManager
    @StateObject private var trajectoryManager = TrajectoryManager()
    @StateObject private var videoManager = VideoManager()
    @StateObject private var uiManager = UIManager()
    
    init(mode: ViewMode, currentView: Binding<AppView>, calibrationManager: CalibrationManager, measurementManager: MeasurementManager, autoStart: Bool = false) {
        self.mode = mode
        self._currentView = currentView
        self.calibrationManager = calibrationManager
        self.measurementManager = measurementManager
        self.autoStart = autoStart
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // AR 视图容器
            ARViewContainer(
                eyeGazeActive: $eyeGazeActive,
                lookAtPoint: $lookAtPoint,
                isWinking: $isWinking,
                calibrationManager: calibrationManager,
                measurementManager: measurementManager
            )
            .onReceive(timerPublisher) { _ in
                if eyeGazeActive && !trajectoryManager.isCountingDown,
                   let point = lookAtPoint {
                    trajectoryManager.addTrajectoryPoint(point: point)
                }
            }.onAppear {
            }
            
            // 视频播放器（视频模式下，但在测量模式下禁用）
            if videoManager.videoMode && mode != .measurement {
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
            // 校准说明视图
            if showCalibrationGreeting{
                Text("请紧盯校准点，当提示：开始校准后，移动眼球，使光标至校准点")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.5), value: showCalibrationGreeting)
            }
            // 校准进度视图
            if let message = calibrationManager.temporaryMessage {
                Text(message)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .transition(.opacity)
                    .zIndex(100)
                    .padding(.top, 60)
            }

            // 校准点视图（在测量模式下或在校准模式下，显示这些已知位置的校准点，蓝色）
            if (calibrationManager.isCalibrating && calibrationManager.showCalibrationPoint) || 
               (measurementManager.isMeasuring && measurementManager.showCalibrationPoint) {
                let calibrationPoint = calibrationManager.isCalibrating ? 
                    calibrationManager.currentCalibrationPoint : 
                    measurementManager.currentMeasurementPoint
                
                if let point = calibrationPoint {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 30, height: 30)
                        .position(point)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: calibrationManager.isCalibrating ? calibrationManager.currentPointIndex : measurementManager.currentPointIndex)
                }
            }
            
            // 注视点视图（在测量模式下或在校准模式下， 显示这些已知位置的注视点，绿色，半透明）
            if measurementManager.isMeasuring, let lookAtPoint = lookAtPoint {
                Circle()
                    .fill(Color.green)
                    .frame(width: 40, height: 40)
                    .position(lookAtPoint)
                    .opacity(0.7)
            }

            // Back button
            VStack {
                HStack {
                    Button(action: {
                        // Stop any ongoing calibration or measurement process
                        calibrationManager.stopCalibration()
                        measurementManager.stopMeasurement()
                        eyeGazeActive = false
                        currentView = .landing
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                    }
                    .padding()
                    
                    Spacer()
                }
                Spacer()
            }
            .zIndex(1000)
            
            // 按钮组 - 根据模式显示不同按钮
            VStack(spacing: 20) {
                Group {
                    // 校准按钮 - 只在校准模式显示
                    if mode == .calibration {
                        Button("开始校准") {
                            if let vc = self.getRootViewController() {
                                checkCameraPermissionAndStartCalibration(presentingViewController: vc)
                            } else {
                                showCalibrationGreeting = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                    showCalibrationGreeting = false
                                    handleCalibration()
                                }
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                        
                        // 快捷跳转到Gaze Track按钮 - 只在校准完成后显示
                        if calibrationManager.calibrationCompleted {
                            Button("开始眼动追踪") {
                                currentView = .gazeTrackAutoStart
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                    }
                    
                    // 测量按钮 - 只在测量模式显示
                    if mode == .measurement {
                        Button("开始测量") {
                            measurementManager.startMeasurement()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(10)
                    }
                    
                    // 视频模式切换按钮 - 只在眼动追踪模式显示
                    if mode == .gazeTrack {
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
                    }
                    
                    // 视频透明度滑块（仅在视频模式下显示，且在眼动追踪模式）
                    if videoManager.videoMode && mode == .gazeTrack {
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
                    
                    // 开始/停止按钮 - 只在眼动追踪模式显示
                    if mode == .gazeTrack {
                        Button(action: {
                            if let vc = self.getRootViewController() {
                                self.checkCameraPermissionAndStartGazeTrack(presentingViewController: vc)
                            } else {
                                handleStartStop()
                            }
                            uiManager.resetButtonHideTimer()
                        }) {
                            Text(eyeGazeActive ? "停止" : "开始")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        
                        // Export Trajectory Button - only in gaze track mode
                        Button(action: {
                            handleExportTrajectory()
                            uiManager.resetButtonHideTimer()
                        }) {
                            Text("Export Trajectory")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(10)
                                .opacity((eyeGazeActive || trajectoryManager.gazeTrajectory.isEmpty || !trajectoryManager.isValidTrajectory()) ? 0.5 : 1.0)
                        }
                        .disabled(eyeGazeActive || trajectoryManager.gazeTrajectory.isEmpty || !trajectoryManager.isValidTrajectory())
                        
                        // Visualize Trajectory Button - only in gaze track mode
                        Button(action: {
                            trajectoryManager.showTrajectoryView.toggle()
                            uiManager.resetButtonHideTimer()
                        }) {
                            Text("Visualize Trajectory")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.orange)
                                .cornerRadius(10)
                                .opacity((eyeGazeActive || trajectoryManager.gazeTrajectory.isEmpty || !trajectoryManager.isValidTrajectory()) ? 0.5 : 1.0)
                        }
                        .disabled(eyeGazeActive || trajectoryManager.gazeTrajectory.isEmpty || !trajectoryManager.isValidTrajectory())
                    }
                    
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
            .alert(isPresented: $trajectoryManager.showExportAlert) {
                Alert(title: Text("Export Complete"),
                      message: Text("Trajectory exported successfully."),
                      dismissButton: .default(Text("OK")))
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

            // 测量结果视图 - 添加此视图
            if measurementManager.showMeasurementResults {
                ZStack {
                    Color.black.opacity(0.8)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        Text("测量结果")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("平均误差: \(String(format: "%.2f", measurementManager.averageError)) pt")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(0..<measurementManager.measurementResults.count, id: \.self) { index in
                                let result = measurementManager.measurementResults[index]
                                Text("点 \(index + 1): 误差 = \(String(format: "%.2f", result.error)) pt")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(10)
                        
                        Button("关闭") {
                            measurementManager.showMeasurementResults = false
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .padding(30)
                    .background(Color.gray.opacity(0.5))
                    .cornerRadius(20)
                }
                .zIndex(200) // 确保显示在最上层
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

            // 视线点显示 - 根据模式显示不同颜色
            if let lookAtPoint = lookAtPoint, (eyeGazeActive || calibrationManager.isCalibrating) {
                Circle()
                    .fill(calibrationManager.isCalibrating ? Color.yellow : Color.red)
                    .frame(width: isWinking ? 100 : 40, height: isWinking ? 100 : 40)
                    .position(lookAtPoint)
            }
        }
        .animation(.easeInOut, value: calibrationManager.temporaryMessage)
        .onTapGesture {
            // 点击屏幕时显示按钮并重置计时器
            uiManager.showButtons = true
            uiManager.resetButtonHideTimer()
        }
        .onAppear {
            // 初始化
            videoManager.setupVideoPlayer()
            
            // 在校准和测量模式下停止视频以减少系统警告
            if mode == .calibration || mode == .measurement {
                videoManager.videoMode = false
                videoManager.player.pause()
            }
            
            // 如果是自动启动模式，自动开始眼动追踪
            if autoStart && mode == .gazeTrack {
                print("🚀 [AUTO START] 自动启动眼动追踪模式")
                print("🚀 [AUTO START] 校准状态: \(calibrationManager.calibrationCompleted)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let vc = self.getRootViewController() {
                        self.checkCameraPermissionAndStartGazeTrack(presentingViewController: vc)
                    } else {
                        self.handleStartStop()
                    }
                }
            }
            
            uiManager.setupButtonHideTimer()
        }
        .onDisappear {
            // 清理资源
            calibrationManager.stopCalibration()
            measurementManager.stopMeasurement()
            eyeGazeActive = false
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
            calibrationManager.stopCalibration()
            
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
        eyeGazeActive = false
        calibrationManager.startCalibration()
    }
    
    // 处理测量
    func handleMeasurement() {
        measurementManager.startMeasurement()
    }
    
    // 处理导出轨迹
    func handleExportTrajectory() {
        print("导出包含 \(trajectoryManager.gazeTrajectory.count) 个数据点的轨迹...")
        trajectoryManager.exportTrajectory {
            trajectoryManager.showExportAlert = true
        }
    }
    
    func checkCameraPermissionAndStartGazeTrack(presentingViewController: UIViewController) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            handleStartStop()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        handleStartStop()
                    } else {
                        showCameraSettingsAlert(presentingViewController: presentingViewController)
                    }
                }
            }
        default:
            showCameraSettingsAlert(presentingViewController: presentingViewController)
        }
    }
    
    func checkCameraPermissionAndStartCalibration(presentingViewController: UIViewController) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            handleCalibration()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        handleCalibration()
                    } else {
                        showCameraSettingsAlert(presentingViewController: presentingViewController)
                    }
                }
            }
        default:
            showCameraSettingsAlert(presentingViewController: presentingViewController)
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(mode: .gazeTrack, currentView: .constant(.gazeTrack), calibrationManager: CalibrationManager(), measurementManager: MeasurementManager())
    }
}
#endif
