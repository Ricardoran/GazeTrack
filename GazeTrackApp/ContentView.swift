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
            // 背景层 - 在8字形测量时使用纯色背景
            if measurementManager.isTrajectoryMeasuring {
                Color.black
                    .edgesIgnoringSafeArea(.all)
            } else {
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
            }
            
            // 在8字形测量时，仍需要ARView来获取注视点数据，但设为透明
            if measurementManager.isTrajectoryMeasuring {
                ARViewContainer(
                    eyeGazeActive: $eyeGazeActive,
                    lookAtPoint: $lookAtPoint,
                    isWinking: $isWinking,
                    calibrationManager: calibrationManager,
                    measurementManager: measurementManager
                )
                .opacity(0)  // 完全透明，只用于数据收集
                .edgesIgnoringSafeArea(.all)
                .onReceive(timerPublisher) { _ in
                    if eyeGazeActive && !trajectoryManager.isCountingDown,
                       let point = lookAtPoint {
                        trajectoryManager.addTrajectoryPoint(point: point)
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
            
            // 8字形轨迹点视图（在8字形测量模式下显示动态轨迹点，亮紫色）
            if measurementManager.isTrajectoryMeasuring && measurementManager.showTrajectoryPoint {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 35, height: 35)  // 增大轨迹点
                    .position(measurementManager.currentTrajectoryPoint)
                    .shadow(color: .purple, radius: 10)  // 添加发光效果
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.1), value: measurementManager.trajectoryProgress)
                
                // 添加外圈增强可见性
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 35, height: 35)
                    .position(measurementManager.currentTrajectoryPoint)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.1), value: measurementManager.trajectoryProgress)
                
            }
            
            // 注视点视图（在测量模式下或8字形测量模式下，显示实际注视点，绿色，半透明）
            if (measurementManager.isMeasuring || measurementManager.isTrajectoryMeasuring), let lookAtPoint = lookAtPoint {
                Circle()
                    .fill(measurementManager.isTrajectoryMeasuring ? Color.green : Color.green)
                    .frame(width: measurementManager.isTrajectoryMeasuring ? 30 : 40, height: measurementManager.isTrajectoryMeasuring ? 30 : 40)
                    .position(lookAtPoint)
                    .opacity(measurementManager.isTrajectoryMeasuring ? 0.9 : 0.7)  // 8字形测量时更不透明
                    .shadow(color: .green, radius: measurementManager.isTrajectoryMeasuring ? 8 : 0)  // 8字形测量时添加发光效果
                
                // 在8字形测量时添加白色外圈
                if measurementManager.isTrajectoryMeasuring {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 30, height: 30)
                        .position(lookAtPoint)
                        .opacity(0.8)
                }
            }

            // Back button
            VStack {
                HStack {
                    Button(action: {
                        // Stop any ongoing calibration or measurement process
                        calibrationManager.stopCalibration()
                        measurementManager.stopMeasurement()
                        measurementManager.stopTrajectoryMeasurement()  // 停止8字形测量
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
                        
                        // 8字形测量按钮
                        Button("8字测量") {
                            // 启动8字形测量前先确保眼动追踪处于活跃状态
                            if !eyeGazeActive {
                                eyeGazeActive = true
                                print("自动启动眼动追踪以支持8字形测量")
                            }
                            measurementManager.startTrajectoryMeasurement()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(10)
                        .disabled(measurementManager.isMeasuring) // 静态测量时禁用
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
            
            // 8字形测量进度指示器
            if measurementManager.isTrajectoryMeasuring {
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Text("8字形轨迹测量")
                                .font(.headline)
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                            
                            Text("进度: \(Int(measurementManager.trajectoryProgress * 100))%")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            ProgressView(value: measurementManager.trajectoryProgress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                                .frame(width: 200)
                                .background(Color.white.opacity(0.3))
                                .cornerRadius(5)
                            
                            Text("请跟随紫色轨迹点移动眼球")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(15)
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }
                .zIndex(150)
            }
            
            // 8字形轨迹测量结果视图
            if measurementManager.showTrajectoryResults, let results = measurementManager.trajectoryResults {
                ZStack {
                    Color.black.opacity(0.8)
                        .edgesIgnoringSafeArea(.all)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            Text("8字形轨迹测量结果")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            // 统计信息
                            VStack(alignment: .leading, spacing: 10) {
                                Text("📊 统计数据")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                                
                                Text("平均误差: \(String(format: "%.1f", results.averageError)) pt")
                                    .foregroundColor(.white)
                                Text("最大误差: \(String(format: "%.1f", results.maxError)) pt")
                                    .foregroundColor(.white)
                                Text("最小误差: \(String(format: "%.1f", results.minError)) pt")
                                    .foregroundColor(.white)
                                Text("测量时长: \(String(format: "%.1f", results.totalDuration)) 秒")
                                    .foregroundColor(.white)
                                Text("屏幕覆盖率: \(String(format: "%.1f", results.coveragePercentage * 100))%")
                                    .foregroundColor(.white)
                                Text("数据点数量: \(results.trajectoryPoints.count) 个")
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(10)
                            
                            // 误差分布
                            VStack(alignment: .leading, spacing: 10) {
                                Text("📈 误差分析")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                                
                                let errorRanges = analyzeErrorDistribution(results.trajectoryPoints)
                                ForEach(errorRanges, id: \.range) { errorRange in
                                    Text("\(errorRange.range): \(errorRange.count) 个点 (\(String(format: "%.1f", errorRange.percentage))%)")
                                        .foregroundColor(.white)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(10)
                            
                            Button("关闭") {
                                measurementManager.showTrajectoryResults = false
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(10)
                        }
                        .padding(30)
                    }
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
                    .fill(calibrationManager.isCalibrating ? Color.yellow : 
                          (mode == .measurement ? Color.green : Color.red))
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
            measurementManager.stopTrajectoryMeasurement()  // 停止8字形测量
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

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(mode: .gazeTrack, currentView: .constant(.gazeTrack), calibrationManager: CalibrationManager(), measurementManager: MeasurementManager())
    }
}
#endif
