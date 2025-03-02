import SwiftUI
import Combine

struct GazeData: Codable {
    let elapsedTime: TimeInterval // Time since recording started in seconds
    let x: CGFloat
    let y: CGFloat
}

struct ContentView: View {
    @State private var eyeGazeActive: Bool = false
    @State private var lookAtPoint: CGPoint?
    @State private var isWinking: Bool = false
    @State private var gazeTrajectory: [GazeData] = []
    @State private var timerPublisher = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()
    @State private var recordingStartTime: Date? // Track when recording started
    
    // State to trigger an alert after export completes
    @State private var showExportAlert: Bool = false
    // State to control whiteboard mode
    @State private var whiteboardMode: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // White board background when in whiteboard mode
            if whiteboardMode {
                Rectangle()
                    .fill(Color.white)
                    .edgesIgnoringSafeArea(.all)
            }
            
            // Reference the CustomARViewContainer from its separate file.
            CustomARViewContainer(eyeGazeActive: $eyeGazeActive,
                                  lookAtPoint: $lookAtPoint,
                                  isWinking: $isWinking)
                .opacity(whiteboardMode ? 0 : 1) // Hide camera view when in whiteboard mode
                .onReceive(timerPublisher) { _ in
                    if eyeGazeActive,
                       let point = lookAtPoint,
                       let startTime = recordingStartTime {
                        let elapsedTime = Date().timeIntervalSince(startTime)
                        let gazeData = GazeData(elapsedTime: elapsedTime, x: point.x, y: point.y)
                        gazeTrajectory.append(gazeData)
                    }
                }

            VStack(spacing: 20) {
                // Toggle for whiteboard mode
                Button(action: {
                    whiteboardMode.toggle()
                }) {
                    Text(whiteboardMode ? "Show Camera" : "Show Whiteboard")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(10)
                }
                
                // Start/Stop Button with dedicated logic.
                Button(action: handleStartStop) {
                    Text(eyeGazeActive ? "Stop" : "Start")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }

                // Export Button: now disabled if the session is active or no data exists.
                Button(action: handleExportTrajectory) {
                    Text("Export Trajectory")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                        .opacity((eyeGazeActive || gazeTrajectory.isEmpty) ? 0.5 : 1.0)
                }
                .disabled(eyeGazeActive || gazeTrajectory.isEmpty)
            }
            .padding(.bottom, 50)
            .alert(isPresented: $showExportAlert) {
                Alert(title: Text("Export Completed"),
                      message: Text("Trajectory exported successfully."),
                      dismissButton: .default(Text("OK")))
            }

            if let lookAtPoint = lookAtPoint, eyeGazeActive {
                Circle()
                    .fill(Color.blue)
                    .frame(width: isWinking ? 100 : 40, height: isWinking ? 100 : 40)
                    .position(lookAtPoint)
            }
        }
    }
    
    // MARK: - Button Actions
    
    /// Handles the start/stop logic for eye gaze tracking.
    func handleStartStop() {
        if !eyeGazeActive {
            // When starting, reset the trajectory history and begin tracking.
            print("Starting eye gaze tracking...")
            gazeTrajectory.removeAll() // Reset the trajectory data.
            recordingStartTime = Date()  // Set the recording start time.
            eyeGazeActive = true
        } else {
            // When stopping, end tracking.
            print("Stopping eye gaze tracking...")
            eyeGazeActive = false
            recordingStartTime = nil
        }
    }
    
    /// Handles the export trajectory button tap.
    func handleExportTrajectory() {
        // Log export event and perform export.
        print("Exporting trajectory with \(gazeTrajectory.count) data points...")
        exportTrajectory(trajectory: gazeTrajectory)
        // After exporting, display an alert.
        showExportAlert = true
    }
    
    /// Exports the trajectory data to a CSV file and presents a share sheet.
    func exportTrajectory(trajectory: [GazeData]) {
        var csvText = "elapsedTime(seconds),x,y\n"
        for data in trajectory {
            let formattedTime = String(format: "%.3f", data.elapsedTime)
            let formattedX = String(format: "%.2f", data.x)
            let formattedY = String(format: "%.2f", data.y)
            csvText.append("\(formattedTime),\(formattedX),\(formattedY)\n")
        }
        
        let filenameFormatter = DateFormatter()
        filenameFormatter.dateFormat = "yyyyMMdd_HH_mm_ss"
        let fileName = "gazeTrajectory_\(filenameFormatter.string(from: Date())).csv"
        
        if let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName) {
            do {
                try csvText.write(to: path, atomically: true, encoding: String.Encoding.utf8)
                let activityVC = UIActivityViewController(activityItems: [path], applicationActivities: nil)
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    activityVC.popoverPresentationController?.sourceView = rootVC.view
                    activityVC.popoverPresentationController?.sourceRect = CGRect(x: rootVC.view.bounds.midX,
                                                                                  y: rootVC.view.bounds.midY,
                                                                                  width: 0,
                                                                                  height: 0)
                    rootVC.present(activityVC, animated: true, completion: nil)
                }
            } catch {
                print("Failed to create file: \(error)")
            }
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
