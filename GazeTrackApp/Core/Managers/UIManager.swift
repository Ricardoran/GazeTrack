import SwiftUI
import Combine

class UIManager: ObservableObject {
    @Published var showButtons: Bool = true
    @Published var lastInteractionTime: Date = Date()
    @Published var interfaceOrientation: UIInterfaceOrientation = .portrait
    @Published var showExportAlert: Bool = false
    
    private var hideButtonsTimer: Timer? = nil
    
    // 设置按钮隐藏计时器
    func setupButtonHideTimer() {
        hideButtonsTimer?.invalidate()
        hideButtonsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            withAnimation(.easeOut(duration: 0.5)) {
                self?.showButtons = false
            }
        }
        
        // 添加通知监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetButtonHideTimerFromNotification),
            name: .init("ResetButtonTimer"),
            object: nil
        )
    }
    
    @objc func resetButtonHideTimerFromNotification() {
        resetButtonHideTimer()
    }
    
    // 在cleanup方法中添加移除观察者
    func cleanup() {
        hideButtonsTimer?.invalidate()
        hideButtonsTimer = nil
        NotificationCenter.default.removeObserver(self, name: .init("ResetButtonTimer"), object: nil)
    }
    
    // 重置按钮隐藏计时器
    func resetButtonHideTimer() {
        lastInteractionTime = Date()
        showButtons = true
        setupButtonHideTimer()
    }
}

// MARK: - UI Components

struct BackButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.left")
                .font(.title2)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
    }
}

struct EyeToScreenDistanceView: View {
    let distance: Float
    let title: String
    
    init(distance: Float, title: String = "眼睛到屏幕距离") {
        self.distance = distance
        self.title = title
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Text("实时距离")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            
            Text("\(String(format: "%.1f", distance)) cm")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }
}
