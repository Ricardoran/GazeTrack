import Foundation
import CoreGraphics
import UIKit

/// 眼球追踪数据点（用于实时追踪）
struct GazeData: Codable {
    let elapsedTime: TimeInterval // 记录开始后的时间（秒）
    let x: CGFloat
    let y: CGFloat
}

/// 眼球追踪记录数据模型
struct GazeRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let duration: TimeInterval // 记录时长（秒）
    let gazePoints: [GazePoint] // 眼球追踪点数据
    let metadata: RecordMetadata // 记录元数据
    
    init(gazePoints: [GazePoint], metadata: RecordMetadata) {
        self.id = UUID()
        self.timestamp = Date()
        self.gazePoints = gazePoints
        self.metadata = metadata
        
        // 计算记录时长
        if let firstPoint = gazePoints.first, let lastPoint = gazePoints.last {
            self.duration = lastPoint.timestamp - firstPoint.timestamp
        } else {
            self.duration = 0
        }
    }
    
    /// 格式化的时间标题
    var formattedTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: timestamp)
    }
    
    /// 格式化的持续时间
    var formattedDuration: String {
        return String(format: "%.1fs", duration)
    }
    
    /// 是否是有效记录（时长大于10秒）
    var isValid: Bool {
        return duration >= 10.0 && gazePoints.count > 60 // 至少10秒且60个点（假设60fps）
    }
    
    /// 生成CSV内容
    func generateCSV() -> String {
        var csvContent = "timestamp,x,y\n"
        
        for point in gazePoints {
            csvContent += "\(point.timestamp),\(point.x),\(point.y)\n"
        }
        
        return csvContent
    }
}

/// 眼球追踪点数据
struct GazePoint: Codable {
    let timestamp: TimeInterval // 相对于记录开始的时间戳（秒）
    let x: CGFloat
    let y: CGFloat
    
    init(x: CGFloat, y: CGFloat, relativeTimestamp: TimeInterval) {
        self.x = x
        self.y = y
        self.timestamp = relativeTimestamp
    }
}

/// 记录元数据
struct RecordMetadata: Codable {
    let deviceModel: String
    let screenSize: CGSize
    let calibrationUsed: Bool
    let smoothingWindowSize: Int
    let trackingMethod: String? // 对于GazeTrackLab模式
    
    init(calibrationUsed: Bool = false, smoothingWindowSize: Int = 30, trackingMethod: String? = nil) {
        self.deviceModel = UIDevice.current.model
        self.screenSize = UIScreen.main.bounds.size
        self.calibrationUsed = calibrationUsed
        self.smoothingWindowSize = smoothingWindowSize
        self.trackingMethod = trackingMethod
    }
}