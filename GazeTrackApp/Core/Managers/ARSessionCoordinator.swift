import Foundation
import ARKit
import Combine

/// 集中式AR会话协调器，解决SwiftUI和ARKit的生命周期冲突
class ARSessionCoordinator: ObservableObject {
    static let shared = ARSessionCoordinator()
    
    @Published var isSessionActive: Bool = false
    @Published var currentSessionType: ARSessionType = .none
    
    private var activeSession: ARSession?
    private var activeViews: Set<String> = []
    
    enum ARSessionType {
        case none
        case gazeTrackLab
        case gazeTrack
        case calibration
        case measurement
    }
    
    private init() {}
    
    /// 请求启动AR会话
    func requestSession(for type: ARSessionType, viewID: String) {
        // 如果当前有不同类型的会话，先停止
        if currentSessionType != type && currentSessionType != .none {
            cleanupCurrentSession()
        }
        
        activeViews.insert(viewID)
        currentSessionType = type
        isSessionActive = true
    }
    
    /// 释放AR会话
    func releaseSession(for viewID: String) {
        // 在主线程上执行，避免死锁
        DispatchQueue.main.async {
            self.activeViews.remove(viewID)
            
            // 如果没有活跃的视图了，停止会话
            if self.activeViews.isEmpty {
                self.cleanupCurrentSession()
            }
        }
    }
    
    /// 设置活跃的AR会话实例
    func setActiveSession(_ session: ARSession) {
        activeSession = session
    }
    
    /// 清理当前会话
    private func cleanupCurrentSession() {
        activeSession?.pause()
        activeSession = nil
        isSessionActive = false
        currentSessionType = .none
        
        // 强制清理所有可能残留的AR视图
        DispatchQueue.main.async {
            self.forceCleanupARViews()
        }
    }
    
    /// 强制清理所有AR视图（优雅版本）
    private func forceCleanupARViews() {
        // 使用异步延迟来避免在SwiftUI view切换过程中操作UI层级
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return
            }
            
            self.cleanupARViews(in: window)
        }
    }
    
    private func cleanupARViews(in view: UIView) {
        let subviewsToCheck = view.subviews // 创建副本避免在遍历时修改数组
        
        for subview in subviewsToCheck {
            let className = String(describing: type(of: subview))
            if className.contains("ARSCN") || className.contains("SceneKit") {
                // 先尝试优雅清理
                if let arView = subview as? ARSCNView {
                    arView.session.pause()
                    arView.delegate = nil
                }
                
                // 然后移除
                subview.removeFromSuperview()
            } else {
                // 递归检查子视图
                cleanupARViews(in: subview)
            }
        }
    }
    
    /// 强制清理所有会话（应急使用）
    func forceCleanupAll() {
        activeViews.removeAll()
        cleanupCurrentSession()
    }
}