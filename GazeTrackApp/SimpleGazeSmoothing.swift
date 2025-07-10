//
//  SimpleGazeSmoothing.swift
//  GazeTrackApp
//
//  Created by Claude Code on 2025-01-10.
//

import Foundation
import CoreGraphics

/// 基于加权滑动窗口的简单凝视点平滑算法
/// 新点权重更高，减少延迟同时保持平滑性，比Kalman滤波器更轻量和直观
class SimpleGazeSmoothing {
    
    private var points: [CGPoint] = []
    private var windowSize: Int
    private var isInitialized: Bool = false
    private let useWeightedAverage: Bool
    
    init(windowSize: Int = 30, useWeightedAverage: Bool = true) {
        self.windowSize = max(1, windowSize)
        self.useWeightedAverage = useWeightedAverage
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
        
        // 返回平均位置
        return useWeightedAverage ? calculateWeightedAverage() : calculateSimpleAverage()
    }
    
    /// 计算加权平均（新点权重更高）
    private func calculateWeightedAverage() -> CGPoint {
        guard !points.isEmpty else {
            return CGPoint.zero
        }
        
        var weightedSumX: CGFloat = 0
        var weightedSumY: CGFloat = 0
        var totalWeight: CGFloat = 0
        
        // 线性权重：最新点权重最高
        for (index, point) in points.enumerated() {
            let weight = CGFloat(index + 1) // 权重从1到points.count
            weightedSumX += point.x * weight
            weightedSumY += point.y * weight
            totalWeight += weight
        }
        
        return CGPoint(
            x: weightedSumX / totalWeight,
            y: weightedSumY / totalWeight
        )
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
        return useWeightedAverage ? calculateWeightedAverage() : calculateSimpleAverage()
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