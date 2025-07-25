import SwiftUI

struct HistoryView: View {
    @Binding var currentView: AppView
    @StateObject private var historyManager = HistoryManager()
    @State private var selectedRecord: GazeRecord?
    @State private var showingActionSheet = false
    @State private var showingShareSheet = false
    @State private var showingTrajectoryView = false
    @State private var activityViewController: UIActivityViewController?
    @State private var currentMLResult: MLModelResponse?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack {
                    // Header
                    HStack {
                        BackButton(action: {
                            currentView = .landing
                        })
                        
                        Spacer()
                        
                        Text("History")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Clear all button
                        Button(action: {
                            historyManager.clearAllRecords()
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.red)
                                .frame(width: 44, height: 44)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .disabled(historyManager.records.isEmpty)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    if historyManager.records.isEmpty {
                        // Empty state
                        VStack(spacing: 20) {
                            Spacer()
                            
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("No Records Yet")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Complete a gaze tracking session to see your records here")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            Spacer()
                        }
                    } else {
                        // Records list
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(historyManager.records) { record in
                                    RecordCard(record: record) {
                                        selectedRecord = record
                                        showingActionSheet = true
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Select Action"),
                message: Text("What would you like to do with this record?"),
                buttons: [
                    .default(Text("View Trajectory")) {
                        showingTrajectoryView = true
                    },
                    .default(Text("Export as CSV")) {
                        exportCSV()
                    },
                    .default(Text(historyManager.isUploadingToML ? "Uploading..." : "Upload to ML Model")) {
                        if !historyManager.isUploadingToML {
                            uploadToMLModel()
                        }
                    },
                    .destructive(Text("Delete")) {
                        if let record = selectedRecord {
                            historyManager.deleteRecord(record)
                        }
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            if let activityVC = activityViewController {
                ActivityViewController(activityViewController: activityVC)
            }
        }
        .sheet(isPresented: $showingTrajectoryView) {
            if let record = selectedRecord {
                TrajectoryDetailView(record: record)
            }
        }
        .sheet(item: $currentMLResult, onDismiss: {
            print("📱 [HISTORY] ML result sheet dismissed")
        }) { result in
            MLResultView(result: result, onDismiss: {
                currentMLResult = nil
            })
            .onAppear {
                print("📱 [HISTORY] Presenting ML result sheet with score: \(result.result)")
            }
        }
        .alert("ML Upload Error", isPresented: .constant(historyManager.mlUploadError != nil)) {
            Button("OK") {
                historyManager.mlUploadError = nil
            }
        } message: {
            Text(historyManager.mlUploadError ?? "")
        }
    }
    
    private func exportCSV() {
        guard let record = selectedRecord else { return }
        
        activityViewController = historyManager.createShareActivity(for: record)
        showingShareSheet = true
    }
    
    private func uploadToMLModel() {
        guard let record = selectedRecord else { return }
        
        print("🚀 [HISTORY] Starting ML upload for record: \(record.formattedTitle)")
        
        historyManager.uploadToMLModel(record: record) { result in
            print("🔄 [HISTORY] ML upload completed, result: \(result != nil ? "success" : "failed")")
            
            DispatchQueue.main.async {
                if let result = result {
                    print("✅ [HISTORY] Setting currentMLResult and showing sheet")
                    print("📊 [HISTORY] Result score: \(result.result), message: \(result.message)")
                    
                    // 设置结果数据，sheet会自动显示
                    self.currentMLResult = result
                    print("🐛 [HISTORY] Just set currentMLResult: \(self.currentMLResult?.result ?? -1)")
                } else {
                    print("❌ [HISTORY] ML upload failed, error: \(self.historyManager.mlUploadError ?? "unknown")")
                }
            }
        }
    }
}

struct RecordCard: View {
    let record: GazeRecord
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    // Title (时间)
                    Text(record.formattedTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Metadata
                    HStack {
                        Label(record.formattedDuration, systemImage: "clock")
                        
                        Spacer()
                        
                        Label("\(record.gazePoints.count) points", systemImage: "eye")
                        
                        if let method = record.metadata.trackingMethod {
                            Spacer()
                            Text(method)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.white.opacity(0.8))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// UIActivityViewController wrapper for SwiftUI
struct ActivityViewController: UIViewControllerRepresentable {
    let activityViewController: UIActivityViewController
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#if DEBUG
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView(currentView: .constant(.history))
    }
}
#endif