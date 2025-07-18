import SwiftUI
import AVKit
import Combine

class VideoManager: ObservableObject {
    @Published var videoMode: Bool = false
    @Published var videoOpacity: Double = 1.0
    @Published var player = AVPlayer()
    
    // 初始化视频播放器
    func setupVideoPlayer() {
        // 尝试从应用包中获取视频
        if let videoURL = Bundle.main.url(forResource: "test", withExtension: "mov") {
            player = AVPlayer(url: videoURL)
        } else {
            // 如果不在包中，则回退到文件路径
            let videoPath = "/Users/ricardozhang/Desktop/AI_Agents/GazeTrackApp/GazeTrackApp/rocket.mp4"
            let videoURL = URL(fileURLWithPath: videoPath)
            player = AVPlayer(url: videoURL)
        }
        
        // 设置循环播放
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                              object: player.currentItem,
                                              queue: .main) { [weak self] _ in
            self?.player.seek(to: CMTime.zero)
            self?.player.play()
        }
    }
    
    // 切换视频模式
    func toggleVideoMode() {
        videoMode.toggle()
        if videoMode {
            player.play()
        } else {
            player.pause()
        }
    }
    
    // 清理资源
    func cleanup() {
        player.pause()
        player.replaceCurrentItem(with: nil) // 释放当前播放项
        NotificationCenter.default.removeObserver(self, 
                                                 name: .AVPlayerItemDidPlayToEndTime, 
                                                 object: nil) // 移除所有相关观察者
    }
}

// 自定义视频播放器
struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    @Binding var showButtons: Bool
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.delegate = context.coordinator
        
        // 添加自定义手势识别器
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        // 确保手势识别器不会被AVPlayerViewController的控制器拦截
        tapGesture.requiresExclusiveTouchType = false
        tapGesture.cancelsTouchesInView = false
        controller.view.addGestureRecognizer(tapGesture)
        
        // 禁用AVPlayerViewController的标准控制器，使用我们自己的控制界面
        controller.showsPlaybackControls = false
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // 更新控制器
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        let parent: CustomVideoPlayer
        
        init(_ parent: CustomVideoPlayer) {
            self.parent = parent
        }
        
        @objc func handleTap() {
            // 点击时显示按钮并发送通知重置计时器
            parent.showButtons = true
            NotificationCenter.default.post(name: .init("ResetButtonTimer"), object: nil)
        }
    }
}