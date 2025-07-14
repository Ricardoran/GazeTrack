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
