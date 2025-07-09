//
//  GazeKalmanFilter.swift
//  GazeTrackApp
//
//  Created by Claude Code on 2025-01-07.
//

import Foundation
import simd
import CoreGraphics
import QuartzCore
import ARKit

/// 专门针对眨眼抖动优化的Kalman滤波器
/// 使用简化但有效的2D位置跟踪模型，特别处理眨眼期间的数据不稳定性
class GazeKalmanFilter {
    
    // 状态: [x, y, vx, vy] - 位置和速度
    private var x: Float = 0
    private var y: Float = 0
    private var vx: Float = 0
    private var vy: Float = 0
    
    // 状态协方差矩阵的对角元素 (简化为对角矩阵)
    private var Pxx: Float = 1000
    private var Pyy: Float = 1000
    private var Pvx: Float = 1000
    private var Pvy: Float = 1000
    
    // 滤波器参数
    private var processNoise: Float = 0.1
    private var measurementNoise: Float = 10.0
    
    // 眨眼感知相关
    private var previousGazePoint: CGPoint?
    private var gazeHistory: [CGPoint] = []
    private var velocityHistory: [Float] = []
    private var lastBlinkLevel: Float = 0
    private var blinkRecoveryCounter: Int = 0
    
    // 配置参数
    private let historySize = 10
    private let maxRecoveryFrames = 10 // 眨眼后的恢复帧数
    private let maxAllowedVelocity: Float = 8000.0 // 合理的最大速度阈值
    
    // 统计信息
    private var updateCount: Int = 0
    private var isInitialized: Bool = false
    private var rejectedFrames: Int = 0
    
    init() {
        // 初始化完成
    }
    
    /// 更新滤波器参数
    func updateParameters(processNoise: Float, measurementNoise: Float) {
        self.processNoise = processNoise
        self.measurementNoise = measurementNoise
        
        #if DEBUG
        if updateCount % 300 == 0 && updateCount > 0 {
            print("🔧 [BLINK-AWARE KALMAN] 参数更新: processNoise=\(processNoise), measurementNoise=\(measurementNoise)")
        }
        #endif
    }
    
    /// 主要更新方法，包含眨眼感知处理
    func updateWithBlinkAwareness(measurement: CGPoint, deltaTime: Float, blinkLevel: Float) -> CGPoint {
        
        // 如果还未初始化，使用测量值初始化
        if !isInitialized {
            return initializeFilter(with: measurement)
        }
        
        updateCount += 1
        
        // 检测异常数据
        let isAnomalous = detectAnomalousData(newPoint: measurement, deltaTime: deltaTime)
        
        // 检测眨眼状态变化
        let isBlinkingIntensely = blinkLevel > 0.8
        let isBlinkingPartially = blinkLevel > 0.5
        let wasBlinking = lastBlinkLevel > 0.5
        
        // 眨眼恢复期管理
        if !isBlinkingPartially && wasBlinking {
            blinkRecoveryCounter = maxRecoveryFrames
        } else if blinkRecoveryCounter > 0 {
            blinkRecoveryCounter -= 1
        }
        
        let isInRecovery = blinkRecoveryCounter > 0
        
        var filteredPoint: CGPoint
        
        // 决策逻辑：是否使用测量值
        if isAnomalous && (isBlinkingIntensely || isInRecovery) {
            // 眨眼期间的异常数据：完全使用预测
            filteredPoint = updateWithPredictionOnly(deltaTime: deltaTime)
            rejectedFrames += 1
            
            #if DEBUG
            if arc4random_uniform(30) == 0 {
                print("🚫 [BLINK-AWARE] 眨眼异常数据被拒绝，使用纯预测")
            }
            #endif
            
        } else if isBlinkingIntensely {
            // 强烈眨眼：大幅降低对测量的信任
            let inflatedNoise = measurementNoise * 20.0
            filteredPoint = updateWithAdjustedNoise(measurement: measurement, deltaTime: deltaTime, tempMeasurementNoise: inflatedNoise)
            
            #if DEBUG
            if arc4random_uniform(60) == 0 {
                print("👁️ [BLINK-AWARE] 强烈眨眼模式，测量噪声x20")
            }
            #endif
            
        } else if isBlinkingPartially || isInRecovery {
            // 轻微眨眼或恢复期：适度降低对测量的信任
            let adjustedNoise = measurementNoise * (isInRecovery ? 8.0 : 5.0)
            filteredPoint = updateWithAdjustedNoise(measurement: measurement, deltaTime: deltaTime, tempMeasurementNoise: adjustedNoise)
            
        } else if isAnomalous {
            // 非眨眼期间的异常数据：适度增加噪声但仍使用
            let adjustedNoise = measurementNoise * 3.0
            filteredPoint = updateWithAdjustedNoise(measurement: measurement, deltaTime: deltaTime, tempMeasurementNoise: adjustedNoise)
            
        } else {
            // 正常情况
            filteredPoint = updateNormal(measurement: measurement, deltaTime: deltaTime)
        }
        
        // 更新历史记录
        updateHistory(point: filteredPoint, velocity: calculateCurrentVelocity())
        previousGazePoint = filteredPoint
        lastBlinkLevel = blinkLevel
        
        // 调试输出
        #if DEBUG
        if updateCount % 240 == 0 {
            let rejectionRate = Float(rejectedFrames) / Float(updateCount) * 100
            print("🎯 [BLINK-AWARE] 统计 - 更新:\(updateCount), 拒绝率:\(String(format: "%.1f", rejectionRate))%, 眨眼等级:\(String(format: "%.2f", blinkLevel))")
        }
        #endif
        
        return filteredPoint
    }
    
    /// 标准更新方法（向后兼容）
    func update(measurement: CGPoint, deltaTime: Float) -> CGPoint {
        return updateWithBlinkAwareness(measurement: measurement, deltaTime: deltaTime, blinkLevel: 0.0)
    }
    
    // MARK: - 私有方法
    
    private func initializeFilter(with measurement: CGPoint) -> CGPoint {
        x = Float(measurement.x)
        y = Float(measurement.y)
        vx = 0
        vy = 0
        isInitialized = true
        updateCount = 1
        previousGazePoint = measurement
        
        #if DEBUG
        print("🎯 [BLINK-AWARE KALMAN] 初始化完成: position=(\(measurement.x), \(measurement.y))")
        #endif
        
        return measurement
    }
    
    private func detectAnomalousData(newPoint: CGPoint, deltaTime: Float) -> Bool {
        guard let lastPoint = previousGazePoint, deltaTime > 0 else {
            return false
        }
        
        // 计算速度
        let distance = sqrt(pow(newPoint.x - lastPoint.x, 2) + pow(newPoint.y - lastPoint.y, 2))
        let velocity = Float(distance) / deltaTime
        
        // 速度异常检测
        if velocity > maxAllowedVelocity {
            #if DEBUG
            if arc4random_uniform(20) == 0 {
                print("⚠️ [BLINK-AWARE] 速度异常: \(String(format: "%.1f", velocity)) px/s")
            }
            #endif
            return true
        }
        
        // 位置跳跃检测（相对于屏幕尺寸）
        let screenDiagonal = sqrt(pow(Device.frameSize.width, 2) + pow(Device.frameSize.height, 2))
        let relativeJump = distance / screenDiagonal
        
        if relativeJump > 0.6 { // 超过屏幕对角线60%
            #if DEBUG
            if arc4random_uniform(20) == 0 {
                print("⚠️ [BLINK-AWARE] 位置跳跃异常: \(String(format: "%.2f", relativeJump))")
            }
            #endif
            return true
        }
        
        return false
    }
    
    private func updateWithPredictionOnly(deltaTime: Float) -> CGPoint {
        // 纯预测模式：仅基于当前状态和速度
        let predictedX = x + vx * deltaTime
        let predictedY = y + vy * deltaTime
        
        // 更新状态
        x = predictedX
        y = predictedY
        
        // 逐渐减小速度（阻尼效应）
        let damping: Float = 0.95
        vx *= damping
        vy *= damping
        
        // 增加预测不确定性
        Pxx += processNoise * 2.0
        Pyy += processNoise * 2.0
        Pvx += processNoise
        Pvy += processNoise
        
        return CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
    
    private func updateWithAdjustedNoise(measurement: CGPoint, deltaTime: Float, tempMeasurementNoise: Float) -> CGPoint {
        // 临时调整测量噪声
        let originalNoise = measurementNoise
        measurementNoise = tempMeasurementNoise
        
        let result = updateNormal(measurement: measurement, deltaTime: deltaTime)
        
        // 恢复原始噪声
        measurementNoise = originalNoise
        
        return result
    }
    
    private func updateNormal(measurement: CGPoint, deltaTime: Float) -> CGPoint {
        // 1. 预测步骤
        let x_pred = x + vx * deltaTime
        let y_pred = y + vy * deltaTime
        
        let dt2 = deltaTime * deltaTime
        let Pxx_pred = Pxx + Pvx * dt2 + processNoise
        let Pyy_pred = Pyy + Pvy * dt2 + processNoise
        let Pvx_pred = Pvx + processNoise
        let Pvy_pred = Pvy + processNoise
        
        // 2. 更新步骤
        let Kx = Pxx_pred / (Pxx_pred + measurementNoise)
        let Ky = Pyy_pred / (Pyy_pred + measurementNoise)
        
        let innovationX = Float(measurement.x) - x_pred
        let innovationY = Float(measurement.y) - y_pred
        
        // 更新状态
        x = x_pred + Kx * innovationX
        y = y_pred + Ky * innovationY
        
        // 自适应速度更新
        let velocityAlpha: Float = min(0.4, deltaTime * 8.0)
        vx = vx * (1 - velocityAlpha) + (innovationX / deltaTime) * velocityAlpha
        vy = vy * (1 - velocityAlpha) + (innovationY / deltaTime) * velocityAlpha
        
        // 速度限制（防止过大的速度导致不稳定）
        let maxVelocity: Float = 2000.0
        vx = max(-maxVelocity, min(maxVelocity, vx))
        vy = max(-maxVelocity, min(maxVelocity, vy))
        
        // 更新协方差
        Pxx = (1 - Kx) * Pxx_pred
        Pyy = (1 - Ky) * Pyy_pred
        Pvx = Pvx_pred
        Pvy = Pvy_pred
        
        return CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
    
    private func updateHistory(point: CGPoint, velocity: Float) {
        gazeHistory.append(point)
        velocityHistory.append(velocity)
        
        if gazeHistory.count > historySize {
            gazeHistory.removeFirst()
            velocityHistory.removeFirst()
        }
    }
    
    private func calculateCurrentVelocity() -> Float {
        return sqrt(vx * vx + vy * vy)
    }
    
    // MARK: - 公共接口
    
    func reset() {
        x = 0; y = 0; vx = 0; vy = 0
        Pxx = 1000; Pyy = 1000; Pvx = 1000; Pvy = 1000
        isInitialized = false
        updateCount = 0
        rejectedFrames = 0
        lastBlinkLevel = 0
        blinkRecoveryCounter = 0
        gazeHistory.removeAll()
        velocityHistory.removeAll()
        previousGazePoint = nil
        
        #if DEBUG
        print("🔄 [BLINK-AWARE KALMAN] 滤波器已重置")
        #endif
    }
    
    var currentPosition: CGPoint {
        return CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
    
    var currentVelocity: CGPoint {
        return CGPoint(x: CGFloat(vx), y: CGFloat(vy))
    }
    
    var rejectionRate: Float {
        return updateCount > 0 ? Float(rejectedFrames) / Float(updateCount) : 0
    }
}