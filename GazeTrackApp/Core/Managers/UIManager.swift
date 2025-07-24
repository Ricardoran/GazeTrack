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
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
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

// MARK: - Unified Button Component

struct UnifiedButton: View {
    enum Style {
        case compact  // 主界面紧凑样式
        case large    // 轨迹视图大按钮样式
    }
    
    let action: () -> Void
    let icon: String
    let text: String?
    let backgroundColor: Color
    let style: Style
    let isDisabled: Bool
    let disabledOpacity: Double
    
    init(action: @escaping () -> Void, 
         icon: String, 
         text: String? = nil, 
         backgroundColor: Color, 
         style: Style = .large,
         isDisabled: Bool = false,
         disabledOpacity: Double = 0.5) {
        self.action = action
        self.icon = icon
        self.text = text
        self.backgroundColor = backgroundColor
        self.style = style
        self.isDisabled = isDisabled
        self.disabledOpacity = disabledOpacity
    }
    
    var body: some View {
        Button(action: action) {
            if let text = text {
                HStack(spacing: style == .compact ? 6 : 8) {
                    Image(systemName: icon)
                    Text(text)
                }
                .font(style == .compact ? .caption : .system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, style == .compact ? 12 : 16)
                .padding(.vertical, style == .compact ? 8 : 12)
                .background(backgroundColor)
                .cornerRadius(style == .compact ? 8 : 12)
            } else {
                Image(systemName: icon)
                    .font(style == .compact ? .caption : .system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: style == .compact ? 36 : 44, height: style == .compact ? 36 : 44)
                    .background(backgroundColor)
                    .cornerRadius(style == .compact ? 8 : 12)
            }
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? disabledOpacity : 1.0)
    }
}
