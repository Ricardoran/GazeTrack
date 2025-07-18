import Foundation
import SwiftUI

struct MLModelResponse: Codable {
    let result: Int
    let message: String
    let processedDataPoints: Int
}

struct HuggingFaceResponse: Codable {
    let data: [String]?
    let error: String?
}

struct GradioEventResponse: Codable {
    let event_id: String
}

struct GazeAnalysisResult: Codable {
    let score: Int
    let analysis: AnalysisDetails
    let message: String
}

struct AnalysisDetails: Codable {
    let total_points: Int
    let duration_seconds: Double
    let average_movement: Double
    let total_movement: Double
    let stability_score: Double
    let coverage_area: Double
}

class MLModelService: ObservableObject {
    @Published var isUploading: Bool = false
    @Published var lastResult: MLModelResponse? = nil
    @Published var errorMessage: String? = nil
    
    // Hugging Face Gradio API配置
    private let huggingFaceAPIURL = "https://ricardo15222024-gaze-track-analyzer.hf.space/gradio_api/call/predict" // 工作正常的Gradio API端点
    
    // 发送CSV数据到ML模型进行分析
    func sendGazeDataToModel(_ gazeData: [GazeData], completion: @escaping (Result<MLModelResponse, Error>) -> Void) {
        isUploading = true
        errorMessage = nil
        
        // 创建CSV格式的数据
        var csvText = "elapsedTime(seconds),x,y\n"
        for data in gazeData {
            let formattedTime = String(format: "%.3f", data.elapsedTime)
            let formattedX = String(format: "%.2f", data.x)
            let formattedY = String(format: "%.2f", data.y)
            csvText.append("\(formattedTime),\(formattedX),\(formattedY)\n")
        }
        
        // 调用Hugging Face API
        sendToHuggingFaceAPI(csvText, completion: completion)
    }
    
    
    
    // 重置状态
    func resetState() {
        lastResult = nil
        errorMessage = nil
        isUploading = false
    }
    
    
    // Hugging Face API调用
    func sendToHuggingFaceAPI(_ csvData: String, completion: @escaping (Result<MLModelResponse, Error>) -> Void) {
        guard let url = URL(string: huggingFaceAPIURL) else {
            DispatchQueue.main.async {
                self.isUploading = false
                self.errorMessage = "Invalid Hugging Face API URL"
                completion(.failure(URLError(.badURL)))
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Gradio API格式 - 基于你的Python客户端代码
        let requestBody = [
            "data": [csvData]
        ] as [String: Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            DispatchQueue.main.async {
                self.isUploading = false
                self.errorMessage = "Failed to encode request: \(error.localizedDescription)"
                completion(.failure(error))
            }
            return
        }
        
        print("🚀 Sending request to Hugging Face API...")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isUploading = false
                
                if let error = error {
                    print("❌ Network error: \(error.localizedDescription)")
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid response")
                    self?.errorMessage = "Invalid response"
                    completion(.failure(URLError(.badServerResponse)))
                    return
                }
                
                print("📡 HTTP Status: \(httpResponse.statusCode)")
                
                guard let data = data else {
                    print("❌ No data received")
                    self?.errorMessage = "No data received"
                    completion(.failure(URLError(.dataNotAllowed)))
                    return
                }
                
                // 打印原始响应用于调试
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Gradio API Response: \(responseString)")
                }
                
                do {
                    // 尝试解析Gradio event_id响应
                    let eventResponse = try JSONDecoder().decode(GradioEventResponse.self, from: data)
                    print("✅ Got event_id: \(eventResponse.event_id)")
                    
                    // 现在使用event_id获取结果
                    self?.fetchGradioQueueResult(eventId: eventResponse.event_id, csvData: csvData, completion: completion)
                    
                } catch {
                    print("❌ JSON parsing error: \(error.localizedDescription)")
                    self?.errorMessage = "Failed to parse analysis result: \(error.localizedDescription)"
                    
                    // Fallback - API解析失败时的默认结果
                    let fallbackResponse = MLModelResponse(
                        result: 0, // 固定分数：API解析失败
                        message: "API调用成功，但结果解析失败",
                        processedDataPoints: csvData.components(separatedBy: "\n").count - 1
                    )
                    
                    self?.lastResult = fallbackResponse
                    completion(.success(fallbackResponse))
                }
            }
        }.resume()
    }
    
    // 获取Gradio队列结果
    private func fetchGradioQueueResult(eventId: String, csvData: String, completion: @escaping (Result<MLModelResponse, Error>) -> Void) {
        guard let url = URL(string: "https://ricardo15222024-gaze-track-analyzer.hf.space/gradio_api/call/predict/\(eventId)") else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid result URL"
                completion(.failure(URLError(.badURL)))
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("🔄 Fetching result for event_id: \(eventId)")
        
        // 添加延迟以等待处理完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ Result fetch error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.errorMessage = "Result fetch error: \(error.localizedDescription)"
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response")
                DispatchQueue.main.async {
                    self?.errorMessage = "Invalid response"
                    completion(.failure(URLError(.badServerResponse)))
                }
                return
            }
            
            print("📡 Result HTTP Status: \(httpResponse.statusCode)")
            
            guard let data = data else {
                print("❌ No result data received")
                DispatchQueue.main.async {
                    self?.errorMessage = "No result data received"
                    completion(.failure(URLError(.dataNotAllowed)))
                }
                return
            }
            
            // 打印原始响应用于调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Gradio Result Response: \(responseString)")
            }
            
            do {
                // 解析SSE格式的响应
                let responseString = String(data: data, encoding: .utf8) ?? ""
                
                // 查找 "data: [" 行
                let lines = responseString.components(separatedBy: .newlines)
                var dataLine: String?
                
                for line in lines {
                    if line.hasPrefix("data: [") {
                        dataLine = line
                        break
                    }
                }
                
                guard let dataLine = dataLine else {
                    throw NSError(domain: "MLModelService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data line found in SSE response"])
                }
                
                // 提取JSON数据部分
                let jsonStart = dataLine.index(dataLine.startIndex, offsetBy: 6) // "data: ".count
                let jsonString = String(dataLine[jsonStart...])
                
                // 解析为JSON数组
                let jsonData = jsonString.data(using: .utf8)!
                let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as! [String]
                
                guard let analysisResultString = jsonArray.first else {
                    throw NSError(domain: "MLModelService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No analysis result in data array"])
                }
                
                // 解析分析结果JSON
                let analysisData = analysisResultString.data(using: .utf8)!
                let analysisResult = try JSONDecoder().decode(GazeAnalysisResult.self, from: analysisData)
                
                // 转换为MLModelResponse格式
                let response = MLModelResponse(
                    result: analysisResult.score,
                    message: analysisResult.message,
                    processedDataPoints: analysisResult.analysis.total_points
                )
                
                print("✅ Gradio SSE Analysis completed with score: \(analysisResult.score)")
                print("📊 Analysis details: Duration=\(analysisResult.analysis.duration_seconds)s, Stability=\(analysisResult.analysis.stability_score)")
                
                DispatchQueue.main.async {
                    self?.lastResult = response
                    completion(.success(response))
                }
                
            } catch {
                print("❌ Result parsing error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to parse analysis result: \(error.localizedDescription)"
                    
                    // Fallback - API解析失败时的默认结果
                    let fallbackResponse = MLModelResponse(
                        result: 0, // 固定分数：API解析失败
                        message: "API调用成功，但结果解析失败",
                        processedDataPoints: csvData.components(separatedBy: "\n").count - 1
                    )
                    
                    self?.lastResult = fallbackResponse
                    completion(.success(fallbackResponse))
                }
            }
        }.resume()
        }
    }
}