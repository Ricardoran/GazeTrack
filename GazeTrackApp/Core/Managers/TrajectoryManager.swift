import SwiftUI
import Combine

struct GazeData: Codable {
    let elapsedTime: TimeInterval // 记录开始后的时间（秒）
    let x: CGFloat
    let y: CGFloat
}

class TrajectoryManager: ObservableObject {
    @Published var gazeTrajectory: [GazeData] = []
    @Published var recordingStartTime: Date? = nil
    @Published var isCountingDown: Bool = false
    @Published var countdownValue: Int = 5
    @Published var showCountdown: Bool = false
    @Published var showTrajectoryView: Bool = false
    @Published var showExportAlert: Bool = false
    
    // 添加新的轨迹点
    func addTrajectoryPoint(point: CGPoint) {
        guard let startTime = recordingStartTime, !isCountingDown else { return }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let gazeData = GazeData(elapsedTime: elapsedTime, x: point.x, y: point.y)
        gazeTrajectory.append(gazeData)
    }
    
    // 开始倒计时
    func startCountdown(completion: @escaping () -> Void) {
        isCountingDown = true
        showCountdown = true
        countdownValue = 5
        
        // 创建倒计时定时器
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { 
                timer.invalidate()
                return 
            }
            
            if self.countdownValue > 1 {
                self.countdownValue -= 1
            } else {
                // 倒计时结束，开始记录
                self.showCountdown = false
                self.isCountingDown = false
                self.recordingStartTime = Date()  // 设置记录开始时间
                timer.invalidate()
                completion()
            }
        }
        
        // 确保定时器在主线程运行
        RunLoop.current.add(timer, forMode: .common)
    }
    
    // 处理轨迹数据
    func processTrajectoryData() {
        // 检查是否有轨迹数据
        guard !gazeTrajectory.isEmpty else { return }
        
        // 获取最后一个数据点的时间，即总记录时长
        if let lastDataPoint = gazeTrajectory.last {
            let totalDuration = lastDataPoint.elapsedTime
            
            // 如果总时长小于3秒，删除整个轨迹
            if totalDuration < 3.0 {
                print("记录时间太短（< 3秒），丢弃所有数据...")
                gazeTrajectory.removeAll()
                return
            }
            
            // 如果总时长小于10秒，删除整个轨迹
            if totalDuration < 10.0 {
                print("记录时间太短（< 10秒），丢弃所有数据...")
                gazeTrajectory.removeAll()
                return
            }
            
            // 删除最后3秒的数据
            let cutoffTime = totalDuration - 3.0
            gazeTrajectory = gazeTrajectory.filter { $0.elapsedTime <= cutoffTime }
            
            print("已删除轨迹数据的最后3秒。剩余数据点：\(gazeTrajectory.count)")
        }
    }
    
    // 检查轨迹是否有效
    func isValidTrajectory() -> Bool {
        guard !gazeTrajectory.isEmpty, let lastPoint = gazeTrajectory.last else {
            return false
        }
        
        // 检查总时长是否至少为10秒
        return lastPoint.elapsedTime >= 10.0
    }
    
    // 导出轨迹数据
    func exportTrajectory(completion: @escaping () -> Void) {
        var csvText = "elapsedTime(seconds),x,y\n"
        for data in gazeTrajectory {
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
                    rootVC.present(activityVC, animated: true) {
                        completion()
                    }
                } else {
                    completion()
                }
            } catch {
                print("创建文件失败：\(error)")
                completion()
            }
        } else {
            completion()
        }
    }
    
    // 重置轨迹数据
    func resetTrajectory() {
        gazeTrajectory.removeAll()
        recordingStartTime = nil
    }
}

// 轨迹可视化视图
struct TrajectoryVisualizationView: View {
    let gazeTrajectory: [GazeData]
    let opacity: Double
    let screenSize: CGSize
    
    var body: some View {
        ZStack {
            // 绘制轨迹
            Path { path in
                guard !gazeTrajectory.isEmpty else { return }
                
                // 移动到第一个点
                if let firstPoint = gazeTrajectory.first {
                    path.move(to: CGPoint(x: firstPoint.x, y: firstPoint.y))
                }
                
                // 连接所有点
                for point in gazeTrajectory.dropFirst() {
                    path.addLine(to: CGPoint(x: point.x, y: point.y))
                }
            }
            .stroke(Color.red, lineWidth: 2)
            .opacity(opacity)
            
            // 绘制起点和终点标记
            if let firstPoint = gazeTrajectory.first {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                    .position(CGPoint(x: firstPoint.x, y: firstPoint.y))
            }
            
            if let lastPoint = gazeTrajectory.last {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
                    .position(CGPoint(x: lastPoint.x, y: lastPoint.y))
            }
        }
    }
}