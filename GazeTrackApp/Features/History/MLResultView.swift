import SwiftUI

struct MLResultView: View {
    let result: MLModelResponse
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("ML Analysis Result")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Gaze Pattern Analysis Complete")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    
                    // Result Score Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Analysis Score")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Text("\(result.result)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(scoreColor(result.result))
                            
                            VStack(alignment: .leading) {
                                Text("out of 100")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(scoreDescription(result.result))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(scoreColor(result.result))
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(scoreColor(result.result).opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Message Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Analysis Summary")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(result.message)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Technical Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Technical Details")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Label("Data Points Processed", systemImage: "dot.scope")
                            Spacer()
                            Text("\(result.processedDataPoints)")
                                .fontWeight(.medium)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            // TODO: Share result functionality
                            shareResult()
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Result")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            // TODO: Save to device functionality
                            saveResult()
                        }) {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                Text("Save Analysis")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100:
            return .green
        case 60...79:
            return .blue
        case 40...59:
            return .orange
        default:
            return .red
        }
    }
    
    private func scoreDescription(_ score: Int) -> String {
        switch score {
        case 80...100:
            return "Excellent"
        case 60...79:
            return "Good"
        case 40...59:
            return "Fair"
        default:
            return "Needs Improvement"
        }
    }
    
    private func shareResult() {
        // Create shareable text
        let shareText = """
        Gaze Track Analysis Result
        
        Score: \(result.result)/100 (\(scoreDescription(result.result)))
        Data Points: \(result.processedDataPoints)
        
        Summary: \(result.message)
        
        Generated by Gaze Track App
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(
                x: rootVC.view.bounds.midX,
                y: rootVC.view.bounds.midY,
                width: 0,
                height: 0
            )
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func saveResult() {
        // TODO: Implement save to Photos or Files
        // For now, just copy to clipboard
        let resultText = """
        Gaze Analysis: \(result.result)/100
        Message: \(result.message)
        Data Points: \(result.processedDataPoints)
        """
        
        UIPasteboard.general.string = resultText
        
        // Show feedback (you could add a toast or alert here)
        print("Result copied to clipboard")
    }
}

#if DEBUG
struct MLResultView_Previews: PreviewProvider {
    static var previews: some View {
        MLResultView(
            result: MLModelResponse(
                result: 85,
                message: "Your gaze pattern shows excellent focus and attention stability. The tracking data indicates smooth and controlled eye movements with minimal scatter.",
                processedDataPoints: 1250
            ),
            onDismiss: {}
        )
    }
}
#endif