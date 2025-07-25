import Foundation
import Combine
import UIKit

/// 历史记录管理器，负责管理最近5条眼球追踪记录
class HistoryManager: ObservableObject {
    @Published var records: [GazeRecord] = []
    @Published var isUploadingToML: Bool = false
    @Published var mlUploadError: String? = nil
    
    private let maxRecords = 5
    private let userDefaults = UserDefaults.standard
    private let recordsKey = "GazeTrackRecords"
    private let mlService = MLModelService()
    
    init() {
        loadRecords()
    }
    
    /// 添加新的记录
    func addRecord(_ record: GazeRecord) {
        // 只保存有效记录
        guard record.isValid else {
            return
        }
        
        // 添加到数组开头（最新的在前面）
        records.insert(record, at: 0)
        
        // 只保留最近5条记录
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }
        
        // 保存到UserDefaults
        saveRecords()
    }
    
    /// 删除指定记录
    func deleteRecord(_ record: GazeRecord) {
        records.removeAll { $0.id == record.id }
        saveRecords()
    }
    
    /// 清空所有记录
    func clearAllRecords() {
        records.removeAll()
        saveRecords()
    }
    
    /// 从UserDefaults加载记录
    private func loadRecords() {
        guard let data = userDefaults.data(forKey: recordsKey) else {
            return
        }
        
        do {
            let decodedRecords = try JSONDecoder().decode([GazeRecord].self, from: data)
            self.records = decodedRecords
        } catch {
            print("Failed to load gaze records: \(error)")
            // 如果解码失败，清空数据
            userDefaults.removeObject(forKey: recordsKey)
        }
    }
    
    /// 保存记录到UserDefaults
    private func saveRecords() {
        do {
            let data = try JSONEncoder().encode(records)
            userDefaults.set(data, forKey: recordsKey)
        } catch {
            print("Failed to save gaze records: \(error)")
        }
    }
    
    /// 获取指定ID的记录
    func getRecord(by id: UUID) -> GazeRecord? {
        return records.first { $0.id == id }
    }
    
    /// 生成记录的CSV内容
    func generateCSV(for record: GazeRecord) -> String {
        return record.generateCSV()
    }
    
    /// 创建分享活动控制器
    func createShareActivity(for record: GazeRecord) -> UIActivityViewController {
        let csvContent = generateCSV(for: record)
        let filename = "gaze_track_\(record.formattedTitle.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: " ", with: "_")).csv"
        
        // 创建临时文件
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write CSV file: \(error)")
        }
        
        let activityController = UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )
        
        return activityController
    }
    
    /// 上传记录到ML模型
    func uploadToMLModel(record: GazeRecord, completion: @escaping (MLModelResponse?) -> Void) {
        print("🚀 [HISTORY_MANAGER] Starting ML upload")
        
        // 转换GazePoint到GazeData格式（ML服务需要的格式）
        let gazeData = record.gazePoints.map { point in
            GazeData(elapsedTime: point.timestamp, x: point.x, y: point.y)
        }
        
        DispatchQueue.main.async {
            self.isUploadingToML = true
            self.mlUploadError = nil
        }
        
        mlService.sendGazeDataToModel(gazeData) { [weak self] result in
            print("🔄 [HISTORY_MANAGER] ML service callback received")
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isUploadingToML = false
                
                switch result {
                case .success(let response):
                    print("✅ [HISTORY_MANAGER] ML upload successful: \(response.result)")
                    self.mlUploadError = nil
                    completion(response)
                case .failure(let error):
                    print("❌ [HISTORY_MANAGER] ML upload failed: \(error.localizedDescription)")
                    self.mlUploadError = error.localizedDescription
                    completion(nil)
                }
            }
        }
    }
    
    /// 获取ML服务的最后结果
    var lastMLResult: MLModelResponse? {
        return mlService.lastResult
    }
    
    /// 重置ML状态
    func resetMLState() {
        mlService.resetState()
        mlUploadError = nil
    }
    
    /// 上传到ML模型的数据格式（保留用于其他目的）
    func prepareMLUploadData(for record: GazeRecord) -> [String: Any] {
        let gazeData = record.gazePoints.map { point in
            [
                "timestamp": point.timestamp,
                "x": point.x,
                "y": point.y
            ]
        }
        
        return [
            "id": record.id.uuidString,
            "timestamp": record.timestamp.timeIntervalSince1970,
            "duration": record.duration,
            "gaze_data": gazeData,
            "metadata": [
                "device_model": record.metadata.deviceModel,
                "screen_size": [
                    "width": record.metadata.screenSize.width,
                    "height": record.metadata.screenSize.height
                ],
                "calibration_used": record.metadata.calibrationUsed,
                "smoothing_window_size": record.metadata.smoothingWindowSize,
                "tracking_method": record.metadata.trackingMethod ?? "standard"
            ]
        ]
    }
}