import SwiftUI
import Combine
import AVKit

struct GazeData: Codable {
    let elapsedTime: TimeInterval // Time since recording started in seconds
    let x: CGFloat
    let y: CGFloat
}

struct ContentView: View {
    @State private var eyeGazeActive: Bool = false
    @State private var lookAtPoint: CGPoint?
    @State private var isWinking: Bool = false
    @State private var gazeTrajectory: [GazeData] = []
    @State private var timerPublisher = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()
    @State private var recordingStartTime: Date? // Track when recording started
    
    // 添加倒计时相关状态
    @State private var isCountingDown: Bool = false
    @State private var countdownValue: Int = 5
    @State private var showCountdown: Bool = false
    
    // State to trigger an alert after export completes
    @State private var showExportAlert: Bool = false
    // State to control video mode
    @State private var videoMode: Bool = false
    // State to control video opacity
    @State private var videoOpacity: Double = 1.0
    // Video player
    @State private var player = AVPlayer()
    
    // 添加界面方向状态
    @State private var interfaceOrientation: UIInterfaceOrientation = .portrait
    
    // 添加按钮显示控制状态
    @State private var showButtons: Bool = true
    @State private var lastInteractionTime: Date = Date()
    @State private var hideButtonsTimer: Timer? = nil
    
    // 添加眼动轨迹图相关状态
    @State private var showTrajectoryView: Bool = false
    
    @StateObject private var calibrationManager = CalibrationManager()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(
                eyeGazeActive: $eyeGazeActive,
                lookAtPoint: $lookAtPoint,
                isWinking: $isWinking,
                calibrationManager: calibrationManager
            )
                .onReceive(timerPublisher) { _ in
                    if eyeGazeActive && !isCountingDown,
                        let point = lookAtPoint,
                        let startTime = recordingStartTime {
                        let elapsedTime = Date().timeIntervalSince(startTime)
                        let gazeData = GazeData(elapsedTime: elapsedTime, x: point.x, y: point.y)
                        gazeTrajectory.append(gazeData)
                    }
                }.onAppear {
                    Device.printScreenSize()
                }
                // .edgesIgnoringSafeArea(.all)
            
            // Video player when in video mode
            if videoMode {
                ZStack {
                    CustomVideoPlayer(player: player, showButtons: $showButtons)
                        .opacity(videoOpacity)
                        // .edgesIgnoringSafeArea(.all)
                        .onAppear {
                            setupVideoPlayer()
                        }
                        .onDisappear {
                            player.pause()
                        }
                }
            }

            // 添加校准点视图
            if calibrationManager.isCalibrating && calibrationManager.showCalibrationPoint,
               let calibrationPoint = calibrationManager.currentCalibrationPoint {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 30, height: 30)
                    .position(calibrationPoint)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: calibrationManager.currentPointIndex)
            }

            VStack(spacing: 20) {
                // 使用opacity来控制按钮的显示和隐藏
                Group {
                    // Start Calibration Button
                    Button("Start Calibration") {
                        handleCalibration()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
                    .opacity(showButtons ? 1 : 0)
                    // Toggle for video mode
                    Button(action: {
                        videoMode.toggle()
                        if videoMode {
                            player.play()
                        } else {
                            player.pause()
                        }
                        resetButtonHideTimer() // 重置隐藏计时器
                    }) {
                        Text(videoMode ? "Camera" : "Video")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(10)
                    }
                    // Opacity slider (only visible when video is active)
                    if videoMode {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Video Opacity: \(Int(videoOpacity * 100))%")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(5)
                            
                            Slider(value: $videoOpacity, in: 0.1...1.0, onEditingChanged: { editing in
                                if editing {
                                    resetButtonHideTimer() // 滑动时重置计时器
                                }
                            })
                                .padding(.horizontal)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(10)
                                .padding(.horizontal, 10)
                        }
                        .padding(.vertical, 5)
                    }
                    
                    // Start/Stop Button with dedicated logic.
                    Button(action: {
                        handleStartStop()
                        resetButtonHideTimer() // 重置隐藏计时器
                    }) {
                        Text(eyeGazeActive ? "Stop" : "Start")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    // Export Button: now disabled if the session is active or no data exists.
                    Button(action: {
                        handleExportTrajectory()
                        resetButtonHideTimer() // 重置隐藏计时器
                    }) {
                        Text("Export Trajectory")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                            .opacity((eyeGazeActive || gazeTrajectory.isEmpty || !isValidTrajectory()) ? 0.5 : 1.0)
                    }
                    .disabled(eyeGazeActive || gazeTrajectory.isEmpty || !isValidTrajectory())
                    
                    // 添加显示轨迹图按钮
                    Button(action: {
                        showTrajectoryView.toggle()
                        resetButtonHideTimer() // 重置隐藏计时器
                    }) {
                        Text("Show Trajectory")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(10)
                            .opacity((eyeGazeActive || gazeTrajectory.isEmpty || !isValidTrajectory()) ? 0.5 : 1.0)
                    }
                    .disabled(eyeGazeActive || gazeTrajectory.isEmpty || !isValidTrajectory())
                }
                .opacity(showButtons ? 1 : 0) // 控制整个按钮组的透明度
            }
            .padding(.bottom, 50)
            .opacity(showButtons ? 1 : 0) // 控制按钮组透明度
            .animation(.easeInOut(duration: 0.3), value: showButtons) // 添加动画效果
            .alert(isPresented: $showExportAlert) {
                Alert(title: Text("Export Completed"),
                      message: Text("Trajectory exported successfully."),
                      dismissButton: .default(Text("OK")))
            }

            // 添加轨迹可视化视图
            if showTrajectoryView && !gazeTrajectory.isEmpty {
                ZStack {
                    // 白色背景
                    // Color.white.edgesIgnoringSafeArea(.all)
                    Color.white
                    
                    // 轨迹可视化
                    TrajectoryVisualizationView(
                        gazeTrajectory: gazeTrajectory,
                        opacity: 1.0, // 固定不透明度为1.0，不再使用可变的透明度
                        screenSize: UIScreen.main.bounds.size
                    )
                    
                    // 关闭按钮
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                showTrajectoryView = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.black)
                                    .padding()
                            }
                        }
                        Spacer()
                    }
                    
                    // 移除透明度控制滑块
                }
                .zIndex(100) // 确保显示在最上层
            }

            // 添加倒计时显示
            if showCountdown {
                Text("\(countdownValue)")
                    .font(.system(size: 100, weight: .bold))
                    .foregroundColor(.white)
                    .padding(30)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)
                    .transition(.scale)
            }

            if let lookAtPoint = lookAtPoint, eyeGazeActive {
                Circle()
                    .fill(Color.red)
                    .frame(width: isWinking ? 100 : 40, height: isWinking ? 100 : 40)
                    .position(lookAtPoint)
            }
        }
        .onTapGesture {
            // 点击屏幕时显示按钮并重置计时器
            showButtons = true
            resetButtonHideTimer()
        }
        .onAppear {
            // 初始化视频播放器
            setupVideoPlayer()
            
            // 添加方向变化通知监听
            NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification,
                                                  object: nil,
                                                  queue: .main) { _ in
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    self.interfaceOrientation = windowScene.interfaceOrientation
                }
            }
            
            // 设置初始隐藏计时器
            setupButtonHideTimer()
        }
        .onDisappear {
            // 移除方向变化通知监听
            NotificationCenter.default.removeObserver(self,
                                                     name: UIDevice.orientationDidChangeNotification,
                                                     object: nil)
            
            // 清除计时器
            hideButtonsTimer?.invalidate()
            hideButtonsTimer = nil
        }
    }
    
    // MARK: - Video Setup
    
    /// Sets up the video player with the rocket video
    private func setupVideoPlayer() {
        // Try to get the video from the app bundle first
        if let videoURL = Bundle.main.url(forResource: "test", withExtension: "mov") {
            player = AVPlayer(url: videoURL)
        } else {
            // Fallback to the file path if not in bundle
            // fall back video is not available to be used at this time, I think we might want to use a while board as placeholder
            let videoPath = "/Users/ricardozhang/Desktop/AI_Agents/GazeTrackApp/GazeTrackApp/rocket.mp4"
            let videoURL = URL(fileURLWithPath: videoPath)
            player = AVPlayer(url: videoURL)
        }
        
        // Set up looping
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                              object: player.currentItem,
                                              queue: .main) { _ in
            player.seek(to: CMTime.zero)
            player.play()
        }
    }
    
    // MARK: - Button Actions
    
    /// Handles the start/stop logic for eye gaze tracking.
    func handleStartStop() {
        if !eyeGazeActive {
            // 立即激活眼动追踪，但不立即记录
            print("Starting eye gaze tracking...")
            gazeTrajectory.removeAll() // Reset the trajectory data.
            eyeGazeActive = true
            
            // 开始倒计时
            startCountdown()
        } else {
            // When stopping, end tracking.
            print("Stopping eye gaze tracking...")
            eyeGazeActive = false
            
            // 处理轨迹数据，删除最后3秒的数据
            processTrajectoryData()
            
            recordingStartTime = nil
            
            // 如果正在倒计时，取消倒计时
            if isCountingDown {
                isCountingDown = false
                showCountdown = false
            }
        }
    }
    
    // 添加处理轨迹数据的函数
    private func processTrajectoryData() {
        // 检查是否有轨迹数据
        guard !gazeTrajectory.isEmpty else { return }
        
        // 获取最后一个数据点的时间，即总记录时长
        if let lastDataPoint = gazeTrajectory.last {
            let totalDuration = lastDataPoint.elapsedTime
            
            // 如果总时长小于3秒，删除整个轨迹
            if totalDuration < 3.0 {
                print("Recording too short (< 3s), discarding all data...")
                gazeTrajectory.removeAll()
                return
            }
            
            // 如果总时长小于10秒，删除整个轨迹
            if totalDuration < 10.0 {
                print("Recording too short (< 10s), discarding all data...")
                gazeTrajectory.removeAll()
                return
            }
            
            // 删除最后3秒的数据
            let cutoffTime = totalDuration - 3.0
            gazeTrajectory = gazeTrajectory.filter { $0.elapsedTime <= cutoffTime }
            
            print("Removed last 3 seconds of trajectory data. Remaining data points: \(gazeTrajectory.count)")
        }
    }
    
    func handleCalibration() {
        calibrationManager.startCalibration()
    }
    
    /// Handles the export trajectory button tap.
    func handleExportTrajectory() {
        // Log export event and perform export.
        print("Exporting trajectory with \(gazeTrajectory.count) data points...")
        exportTrajectory(trajectory: gazeTrajectory)
        // After exporting, display an alert.
        showExportAlert = true
    }
    
    // 添加倒计时函数
    private func startCountdown() {
        isCountingDown = true
        showCountdown = true
        countdownValue = 5
        
        // 创建倒计时定时器
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if self.countdownValue > 1 {
                self.countdownValue -= 1
            } else {
                // 倒计时结束，开始记录
                self.showCountdown = false
                self.isCountingDown = false
                self.recordingStartTime = Date()  // 设置记录开始时间
                timer.invalidate()
            }
        }
        
        // 确保定时器在主线程运行
        RunLoop.current.add(timer, forMode: .common)
    }
    
    // 添加检查轨迹是否有效的辅助函数
    private func isValidTrajectory() -> Bool {
        guard !gazeTrajectory.isEmpty, let lastPoint = gazeTrajectory.last else {
            return false
        }
        
        // 检查总时长是否至少为10秒
        return lastPoint.elapsedTime >= 10.0
    }
    
    /// Exports the trajectory data to a CSV file and presents a share sheet.
    func exportTrajectory(trajectory: [GazeData]) {
        var csvText = "elapsedTime(seconds),x,y\n"
        for data in trajectory {
            let formattedTime = String(format: "%.3f", data.elapsedTime)
            let formattedX = String(format: "%.2f", data.x)
            let formattedY = String(format: "%.2f", data.y)
            csvText.append("\(formattedTime),\(formattedX),\(formattedY)\n")
        }
        
        let filenameFormatter = DateFormatter()
        filenameFormatter.dateFormat = "yyyyMMdd_HH_mm_ss"
        let fileName = "gazeTrajectory_\(filenameFormatter.string(from: Date())).csv"
        
        if let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName) {
            do {
                try csvText.write(to: path, atomically: true, encoding: String.Encoding.utf8)
                let activityVC = UIActivityViewController(activityItems: [path], applicationActivities: nil)
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    activityVC.popoverPresentationController?.sourceView = rootVC.view
                    activityVC.popoverPresentationController?.sourceRect = CGRect(x: rootVC.view.bounds.midX,
                                                                                  y: rootVC.view.bounds.midY,
                                                                                  width: 0,
                                                                                  height: 0)
                    rootVC.present(activityVC, animated: true, completion: nil)
                }
            } catch {
                print("Failed to create file: \(error)")
            }
        }
    }
    
    // MARK: - Button Visibility Management

    /// 设置按钮隐藏计时器
    private func setupButtonHideTimer() {
        hideButtonsTimer?.invalidate()
        hideButtonsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.5)) {
                self.showButtons = false
                // 如果在视频模式下，触发系统视频控制器的自动隐藏
                if self.videoMode {
                    self.player.play()
                    self.player.pause()
                    self.player.play()
                }
            }
        }
    }

    /// 重置按钮隐藏计时器
    private func resetButtonHideTimer() {
        lastInteractionTime = Date()
        showButtons = true
        setupButtonHideTimer()
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif

// 在文件底部修改 CustomVideoPlayer 的实现
struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    @Binding var showButtons: Bool
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.delegate = context.coordinator
        
        // 添加自定义手势识别器
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.delegate = context.coordinator
        controller.view.addGestureRecognizer(tapGesture)
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, AVPlayerViewControllerDelegate, UIGestureRecognizerDelegate {
        let parent: CustomVideoPlayer
        
        init(_ parent: CustomVideoPlayer) {
            self.parent = parent
            super.init()
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            let view = gesture.view!
            
            // 检查点击位置是否在底部控制区域
            let bottomControlHeight = view.bounds.height * 0.15
            let isInControlArea = location.y > (view.bounds.height - bottomControlHeight)
            
            if !isInControlArea {
                DispatchQueue.main.async {
                    self.parent.showButtons = true
                    NotificationCenter.default.post(
                        name: .init("ResetButtonTimer"),
                        object: nil
                    )
                }
            }
        }
        
        // 允许手势识别器与系统手势共存
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}
