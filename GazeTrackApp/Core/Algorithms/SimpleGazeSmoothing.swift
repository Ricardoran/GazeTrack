//
//  SimpleGazeSmoothing.swift
//  GazeTrackApp
//
//  Created by Claude Code on 2025-01-10.
//

import Foundation
import CoreGraphics

/// 基于滑动窗口的简单凝视点平滑算法, 使用简单平均值
class SimpleGazeSmoothing {
    
    private var points: [CGPoint] = []
    private var windowSize: Int
    private var isInitialized: Bool = false
    
    init(windowSize: Int = 30) {
        self.windowSize = max(1, windowSize)
    }
    
    /// 动态更新窗口大小
    func updateWindowSize(_ newSize: Int) {
        self.windowSize = max(1, newSize)
        // 如果新窗口大小更小，删除多余的旧点
        if points.count > windowSize {
            points = Array(points.suffix(windowSize))
        }
    }
    
    /// 添加新的凝视点并返回平滑后的位置
    func addPoint(_ point: CGPoint) -> CGPoint {
        points.append(point)
        
        // 保持窗口大小
        if points.count > windowSize {
            points.removeFirst()
        }
        
        // 返回简单平均位置
        return calculateSimpleAverage()
    }
    
    
    /// 计算简单平均位置
    private func calculateSimpleAverage() -> CGPoint {
        guard !points.isEmpty else {
            return CGPoint.zero
        }
        
        let sumX = points.reduce(0) { $0 + $1.x }
        let sumY = points.reduce(0) { $0 + $1.y }
        let count = CGFloat(points.count)
        
        return CGPoint(x: sumX / count, y: sumY / count)
    }
    
    /// 重置平滑器状态
    func reset() {
        points.removeAll()
        isInitialized = false
    }
    
    /// 当前平滑后的位置
    var currentPosition: CGPoint {
        return calculateSimpleAverage()
    }
    
    /// 当前窗口内的点数量
    var pointCount: Int {
        return points.count
    }
    
    /// 是否已有足够的数据点进行有效平滑
    var hasEnoughData: Bool {
        return points.count >= min(10, windowSize / 2)
    }
}

// MARK: - CGPoint Extension for Array Average
extension Array where Element == CGPoint {
    /// 计算CGPoint数组的平均值
    func average() -> CGPoint {
        guard !isEmpty else { return CGPoint.zero }
        
        let sumX = reduce(0) { $0 + $1.x }
        let sumY = reduce(0) { $0 + $1.y }
        let count = CGFloat(self.count)
        
        return CGPoint(x: sumX / count, y: sumY / count)
    }
}