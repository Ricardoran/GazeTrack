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
    @State private var smoothingWindowSize: Int = 10 // 简单平滑窗口大小，默认10点
    @State private var arView: CustomARView?
    @State private var currentMLResult: MLModelResponse? // ML分析结果

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
    
    var backgroundARView: some View {
        ARViewContainer(
            eyeGazeActive: $eyeGazeActive,
            lookAtPoint: $lookAtPoint,
            isWinking: $isWinking,
            calibrationManager: calibrationManager,
            measurementManager: measurementManager,
            smoothingWindowSize: $smoothingWindowSize,
            arView: $arView
        )
        .onReceive(timerPublisher) { _ in
            if eyeGazeActive && !trajectoryManager.isCountingDown,
               let point = lookAtPoint {
                trajectoryManager.addTrajectoryPoint(point: point)
            }
        }
    }
    
    var backgroundLayer: some View {
        Group {
            if measurementManager.isTrajectoryMeasuring || measurementManager.isTrajectoryCountingDown {
                Color.black.edgesIgnoringSafeArea(.all)
            } else {
                backgroundARView
            }
        }
    }
    
    var videoPlayerLayer: some View {
        Group {
            if videoManager.videoMode && mode != .measurement {
                CustomVideoPlayer(player: videoManager.player, showButtons: $uiManager.showButtons)
                    .opacity(videoManager.videoOpacity)
                    .onAppear { videoManager.setupVideoPlayer() }
                    .onDisappear { videoManager.player.pause() }
                    .onTapGesture {
                        uiManager.showButtons = true
                        uiManager.resetButtonHideTimer()
                    }
            }
        }
    }
    
    var measurementARView: some View {
        Group {
            if measurementManager.isTrajectoryMeasuring || measurementManager.isTrajectoryCountingDown {
                ARViewContainer(
                    eyeGazeActive: $eyeGazeActive,
                    lookAtPoint: $lookAtPoint,
                    isWinking: $isWinking,
                    calibrationManager: calibrationManager,
                    measurementManager: measurementManager,
                    smoothingWindowSize: $smoothingWindowSize,
                    arView: $arView
                )
                .opacity(0)
                .edgesIgnoringSafeArea(.all)
                .onReceive(timerPublisher) { _ in
                    if eyeGazeActive && !trajectoryManager.isCountingDown,
                       let point = lookAtPoint {
                        trajectoryManager.addTrajectoryPoint(point: point)
                    }
                }
            }
        }
    }
    
    var calibrationInstructionView: some View {
        Group {
            if showCalibrationGreeting {
                Text("Please focus on the calibration point. When prompted to start calibration, move your eyes to align the cursor with the calibration point")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.5), value: showCalibrationGreeting)
            }
        }
    }
    
    var calibrationProgressView: some View {
        Group {
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
        }
    }
    
    var gridOverlayView: some View {
        Group {
            if calibrationManager.isCalibrating {
                GridOverlayView()
                    .allowsHitTesting(false)
            }
        }
    }
    
    var calibrationPointView: some View {
        Group {
            if calibrationManager.isCalibrating && calibrationManager.showCalibrationPoint {
                let calibrationPoint = calibrationManager.currentCalibrationPoint
                
                if let point = calibrationPoint {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 30, height: 30)
                        .position(point)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: calibrationManager.currentPointIndex)
                }
            }
        }
    }
    
    var trajectoryPointView: some View {
        Group {
            if measurementManager.isTrajectoryMeasuring && measurementManager.showTrajectoryPoint {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 35, height: 35)
                    .position(measurementManager.currentTrajectoryPoint)
                    .shadow(color: .purple, radius: 10)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.1), value: measurementManager.trajectoryProgress)
                
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 35, height: 35)
                    .position(measurementManager.currentTrajectoryPoint)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.1), value: measurementManager.trajectoryProgress)
            }
        }
    }
    
    var gazePointView: some View {
        Group {
            if let lookAtPoint = lookAtPoint, eyeGazeActive {
                let isTrajectoryMode = measurementManager.isTrajectoryMeasuring || measurementManager.isTrajectoryCountingDown
                
                ZStack {
                    // 主要的 gaze point - 根据模式选择颜色
                    let gazeColor = isTrajectoryMode ? Color.green : Color.red
                    
                    Circle()
                        .fill(gazeColor)
                        .frame(width: isTrajectoryMode ? 30 : 40, 
                               height: isTrajectoryMode ? 30 : 40)
                        .position(lookAtPoint)
                        .opacity(isTrajectoryMode ? 0.9 : 0.8)
                        .shadow(color: gazeColor, radius: isTrajectoryMode ? 8 : 6)
                        .allowsHitTesting(false)
                    
                    // 轨迹模式的白色边框
                    if isTrajectoryMode {
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 30, height: 30)
                            .position(lookAtPoint)
                            .opacity(0.9)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    }
    
    var headerView: some View {
        VStack {
            HStack {
                BackButton(action: {
                    calibrationManager.stopCalibration()
                    measurementManager.stopTrajectoryMeasurement()
                    eyeGazeActive = false
                    currentView = .landing
                })
                
                Spacer()
                
                if mode == .gazeTrack {
                    headerButtons
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 15)
            
            Spacer()
        }
    }
    
    var headerButtons: some View {
        HStack(spacing: 8) {
            // Video/Camera toggle button
            UnifiedButton(
                action: {
                    videoManager.toggleVideoMode()
                    uiManager.resetButtonHideTimer()
                },
                icon: videoManager.videoMode ? "camera" : "video",
                backgroundColor: Color.purple.opacity(0.8),
                style: .compact
            )
            
            // Export trajectory button
            UnifiedButton(
                action: {
                    trajectoryManager.showExportAlert = true
                    uiManager.resetButtonHideTimer()
                },
                icon: "square.and.arrow.up",
                backgroundColor: Color.green.opacity(0.8),
                style: .compact,
                isDisabled: eyeGazeActive || trajectoryManager.gazeTrajectory.isEmpty || !trajectoryManager.isValidTrajectory()
            )
            
            // Visualize trajectory button
            UnifiedButton(
                action: {
                    trajectoryManager.showTrajectoryView.toggle()
                    uiManager.resetButtonHideTimer()
                },
                icon: "chart.line.uptrend.xyaxis",
                backgroundColor: Color.orange.opacity(0.8),
                style: .compact,
                isDisabled: eyeGazeActive || trajectoryManager.gazeTrajectory.isEmpty || !trajectoryManager.isValidTrajectory()
            )
        }
    }
    
    var centralButtonArea: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                Group {
                    // 校准按钮 - 只在校准模式显示
                    if mode == .calibration {
                        Button("Start Calibration") {
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
                        .disabled(true)
                        .opacity(0.5)
                        .cornerRadius(10)
                        
                        // 快捷跳转到Gaze Track按钮 - 只在校准完成后显示
                        if calibrationManager.calibrationCompleted {
                            Button("Start Gaze Tracking") {
                                currentView = .gazeTrackAutoStart
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                    }
                    
                }
            }
            
            Spacer()
            Spacer()
        }
        .opacity(uiManager.showButtons ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: uiManager.showButtons)
    }
    
    var bottomControlsArea: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 8) {
                // 测量模式：8字形和正弦函数轨迹测量按钮
                if mode == .measurement {
                    HStack(spacing: 12) {
                        // 8字形测量按钮
                        Button("Figure-8 Measurement") {
                            if !eyeGazeActive {
                                eyeGazeActive = true
                                print("自动启动眼动追踪以支持8字形测量")
                            }
                            measurementManager.startTrajectoryMeasurement()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.purple)
                        .cornerRadius(10)
                        .disabled(measurementManager.isTrajectoryMeasuring || measurementManager.isTrajectoryCountingDown)
                        
                        // 正弦函数轨迹测量按钮
                        Button("Sinusoidal Trajectory Measurement") {
                            if !eyeGazeActive {
                                eyeGazeActive = true
                                print("自动启动眼动追踪以支持正弦函数轨迹测量")
                            }
                            measurementManager.startSinusoidalTrajectoryMeasurement()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .cornerRadius(10)
                        .disabled(measurementManager.isTrajectoryMeasuring || measurementManager.isTrajectoryCountingDown)
                    }
                    .padding(.bottom, 12)
                }
                
                // 视频透明度滑块（仅在视频模式下显示，且在眼动追踪模式）
                if videoManager.videoMode && mode == .gazeTrack {
                    videoOpacitySlider
                }
                
                // 简化的平滑控制滑块
                if mode == .gazeTrack || mode == .measurement {
                    smoothingControlSlider
                }
                
                // iPhone风格圆环开始/停止按钮 - 只在眼动追踪模式显示
                if mode == .gazeTrack {
                    circularStartStopButton
                }
            }
            .padding(.bottom, 20)
            .opacity(uiManager.showButtons ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: uiManager.showButtons)
        }
    }
    
    var videoOpacitySlider: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Video Opacity: \(Int(videoManager.videoOpacity * 100))%")
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
    
    var smoothingControlSlider: some View {
        HStack {
            Text("Response")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
            
            Slider(value: Binding(
                get: { Double(smoothingWindowSize) },
                set: {
                    smoothingWindowSize = Int($0)
                    arView?.resetSmoothingFilter()
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
            
            Text("Stability")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }
    
    var circularStartStopButton: some View {
        HStack {
            Spacer()
            
            Button(action: {
                if let vc = self.getRootViewController() {
                    self.checkCameraPermissionAndStartGazeTrack(presentingViewController: vc)
                } else {
                    handleStartStop()
                }
                uiManager.resetButtonHideTimer()
            }) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        .fill(eyeGazeActive ? Color.red : Color.white)
                        .frame(width: eyeGazeActive ? 40 : 60, height: eyeGazeActive ? 40 : 60)
                    
                    if eyeGazeActive {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                    }
                }
                .scaleEffect(eyeGazeActive ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: eyeGazeActive)
            }
            
            Spacer()
        }
        .padding(.top, 15)
    }
    
    var mlUploadProgressView: some View {
        Group {
            if trajectoryManager.isUploadingToML {
                ZStack {
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(1.5)
                        
                        Text("Uploading to ML model...")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Analyzing data, please wait")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(40)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                }
                .zIndex(1000)
            }
        }
    }
    
    var trajectoryVisualizationOverlay: some View {
        Group {
            if trajectoryManager.showTrajectoryView && !trajectoryManager.gazeTrajectory.isEmpty {
                ZStack {
                    Color.white.edgesIgnoringSafeArea(.all)
                    
                    TrajectoryVisualizationView(
                        gazeTrajectory: trajectoryManager.gazeTrajectory,
                        opacity: 1.0,
                        screenSize: UIScreen.main.bounds.size
                    )
                    
                    trajectoryOverlayControls
                }
                .zIndex(1000)
            }
        }
    }
    
    var trajectoryOverlayControls: some View {
        VStack {
            // 顶部按钮区域
            HStack {
                UnifiedButton(
                    action: { trajectoryManager.showTrajectoryView = false },
                    icon: "chevron.left",
                    backgroundColor: Color.black.opacity(0.7)
                )
                
                Spacer()
                
                HStack(spacing: 12) {
                    UnifiedButton(
                        action: { trajectoryManager.exportTrajectory {} },
                        icon: "square.and.arrow.up",
                        backgroundColor: Color.green.opacity(0.8)
                    )
                    
                    UnifiedButton(
                        action: { trajectoryManager.showTrajectoryView = false },
                        icon: "xmark",
                        backgroundColor: Color.red.opacity(0.8)
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer()
            
            // 底部信息区域
            VStack(spacing: 12) {
                Text("Trajectory Visualization")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                HStack(spacing: 20) {
                    VStack {
                        Text("Data Points")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(trajectoryManager.gazeTrajectory.count)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    VStack {
                        Text("Duration")
                            .font(.caption)
                            .foregroundColor(.gray)
                        if let duration = trajectoryManager.recordingDuration {
                            Text("\(String(format: "%.1f", duration))s")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    
    var trajectoryProgressIndicator: some View {
        Group {
            if measurementManager.isTrajectoryMeasuring && !measurementManager.isTrajectoryCountingDown {
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Text(measurementManager.currentTrajectoryType == .figure8 ? "Figure-8 Measurement" : "Sinusoidal Trajectory Measurement")
                                .font(.headline)
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                            
                            Text("Progress: \(Int(measurementManager.trajectoryProgress * 100))%")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            ProgressView(value: measurementManager.trajectoryProgress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                                .frame(width: 200)
                                .background(Color.white.opacity(0.3))
                                .cornerRadius(5)
                            
                            Text("Please follow the purple trajectory point with your eyes")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(15)
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }
                .zIndex(150)
            }
        }
    }
    
    var trajectoryResultsOverlay: some View {
        Group {
            if measurementManager.showTrajectoryResults, let results = measurementManager.trajectoryResults {
                TrajectoryComparisonView(
                    trajectoryResults: results,
                    screenSize: UIScreen.main.bounds.size,
                    showVisualization: $measurementManager.showTrajectoryResults
                )
                .zIndex(160)
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundLayer
            videoPlayerLayer
            measurementARView
            calibrationInstructionView
            calibrationProgressView
            gridOverlayView
            calibrationPointView
            trajectoryPointView
            
            headerView
                .opacity(uiManager.showButtons ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: uiManager.showButtons)
                .zIndex(1000)
            
            centralButtonArea
            bottomControlsArea
            mlUploadProgressView
            trajectoryVisualizationOverlay
            trajectoryProgressIndicator
            trajectoryResultsOverlay
            
            // 最后渲染 gaze point，确保在所有其他元素之上
            gazePointView
                .zIndex(2000)
        }
        .animation(.easeInOut, value: calibrationManager.temporaryMessage)
        .onTapGesture {
            uiManager.showButtons = true
            uiManager.resetButtonHideTimer()
        }
        .onAppear {
            setupView()
        }
        .onDisappear {
            cleanupView()
        }
        .alert(isPresented: $uiManager.showExportAlert) {
            Alert(title: Text("Export Complete"),
                  message: Text("Trajectory exported successfully."),
                  dismissButton: .default(Text("OK")))
        }
        .alert("Select Export Method", isPresented: $trajectoryManager.showExportAlert) {
            Button("CSV File") {
                handleExportTrajectory()
            }
            Button("Upload to ML Model") {
                handleMLUpload()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please select a method to export trajectory data")
        }
        .alert("ML Model Analysis", isPresented: $trajectoryManager.showMLUploadAlert) {
            Button("Upload for Analysis") {
                handleMLUpload()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Send trajectory data to ML model for analysis?")
        }
        .sheet(item: $currentMLResult, onDismiss: {
            print("📱 [CONTENT VIEW] ML result sheet dismissed")
        }) { result in
            MLResultView(result: result, onDismiss: {
                currentMLResult = nil
            })
            .onAppear {
                print("📱 [CONTENT VIEW] Presenting ML result sheet with score: \(result.result)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupView() {
        videoManager.setupVideoPlayer()
        
        if mode == .calibration || mode == .measurement {
            videoManager.videoMode = false
            videoManager.player.pause()
            
            // 在measurement mode下确保按钮显示
            if mode == .measurement {
                uiManager.showButtons = true
            }
        }
        
        measurementManager.onMeasurementCompleted = {
            DispatchQueue.main.async {
                print("📱 测量完成，自动关闭eye gaze tracking以节省能耗")
                eyeGazeActive = false
            }
        }
        
        if autoStart && mode == .gazeTrack {
            print("🚀 [AUTO START] 自动启动眼动追踪模式")
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
    
    private func cleanupView() {
        calibrationManager.stopCalibration()
        measurementManager.stopTrajectoryMeasurement()
        eyeGazeActive = false
        uiManager.cleanup()
        videoManager.cleanup()
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
    
    
    // 处理导出轨迹
    func handleExportTrajectory() {
        print("导出包含 \(trajectoryManager.gazeTrajectory.count) 个数据点的轨迹...")
        trajectoryManager.exportTrajectory {
            // Export completed
        }
    }
    
    // 处理ML模型上传
    func handleMLUpload() {
        print("上传包含 \(trajectoryManager.gazeTrajectory.count) 个数据点的轨迹到ML模型...")
        trajectoryManager.uploadToMLModel { result in
            DispatchQueue.main.async {
                if let result = result {
                    // 显示成功结果
                    showMLResult(result)
                } else {
                    // 显示错误
                    showMLError()
                }
            }
        }
    }
    
    // 显示ML结果
    func showMLResult(_ result: MLModelResponse) {
        print("📊 [CONTENT VIEW] Setting ML result and showing sheet")
        print("📊 [CONTENT VIEW] Result score: \(result.result), message: \(result.message)")
        
        // 设置结果数据，sheet会自动显示
        self.currentMLResult = result
    }
    
    // 显示ML错误
    func showMLError() {
        let alert = UIAlertController(
            title: "Upload Failed",
            message: trajectoryManager.mlErrorMessage ?? "Unknown error",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    
    
    
    // 分析误差分布
    func analyzeErrorDistribution(_ points: [TrajectoryMeasurementPoint]) -> [(range: String, count: Int, percentage: Float)] {
        let totalPoints = points.count
        guard totalPoints > 0 else { return [] }
        
        let ranges = [
            ("0-20pt", 0.0...20.0),
            ("20-40pt", 20.0...40.0),
            ("40-60pt", 40.0...60.0),
            ("60-80pt", 60.0...80.0),
            (">80pt", 80.0...Double.infinity)
        ]
        
        return ranges.map { (rangeName, range) in
            let count = points.filter { range.contains(Double($0.error)) }.count
            let percentage = Float(count) / Float(totalPoints) * 100
            return (range: rangeName, count: count, percentage: percentage)
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


// GridOverlayView is imported from GazeTrackLabView

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(mode: .gazeTrack, currentView: .constant(.gazeTrack), calibrationManager: CalibrationManager(), measurementManager: MeasurementManager())
    }
}
#endif
