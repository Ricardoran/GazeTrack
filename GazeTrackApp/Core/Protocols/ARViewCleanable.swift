import Foundation
import SwiftUI
import ARKit
import SceneKit

/// AR视图清理协议，确保所有AR相关视图都有统一的清理机制
protocol ARViewCleanable {
    /// 视图的唯一标识符
    var viewID: String { get }
    
    /// 执行清理操作
    func performCleanup()
    
    /// 检查是否已经清理完成
    var isCleanedUp: Bool { get }
}

/// UIViewRepresentable的AR视图基类
protocol SwiftUIARViewRepresentable: ARViewCleanable {
    associatedtype UIViewType: UIView
    
    /// SwiftUI的dismantleUIView调用
    static func dismantleUIView(_ uiView: UIViewType, coordinator: ())
}

/// ARSCNView的清理扩展
extension ARSCNView {
    /// 优雅地清理ARSCNView
    func cleanupGracefully() {
        // 1. 停止会话（在主线程执行避免死锁）
        if Thread.isMainThread {
            session.pause()
            performCleanupSteps()
        } else {
            DispatchQueue.main.async {
                self.session.pause()
                self.performCleanupSteps()
            }
        }
    }
    
    private func performCleanupSteps() {
        // 2. 清理delegate
        delegate = nil
        
        // 3. 清理场景节点
        scene.rootNode.childNodes.forEach { node in
            node.removeFromParentNode()
        }
        
        // 清理pointOfView的子节点
        pointOfView?.childNodes.forEach { node in
            node.removeFromParentNode()
        }
        
        // 从父视图移除
        removeFromSuperview()
    }
}

/// SwiftUI ViewModifier for AR view lifecycle management
struct ARViewLifecycleModifier: ViewModifier {
    let sessionType: ARSessionCoordinator.ARSessionType
    let viewID: String
    
    @StateObject private var coordinator = ARSessionCoordinator.shared
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                coordinator.requestSession(for: sessionType, viewID: viewID)
            }
            .onDisappear {
                coordinator.releaseSession(for: viewID)
            }
    }
}

extension View {
    /// 为AR视图添加生命周期管理
    func managedARSession(type: ARSessionCoordinator.ARSessionType, viewID: String) -> some View {
        self.modifier(ARViewLifecycleModifier(sessionType: type, viewID: viewID))
    }
}