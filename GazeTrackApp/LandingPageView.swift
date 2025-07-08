import SwiftUI

struct LandingPageView: View {
    @Binding var currentView: AppView
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Title
                Text("Gaze Track")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.top, 50)
                
                // Main buttons
                VStack(spacing: 20) {
                    // Calibration Button
                    Button(action: {
                        currentView = .calibration
                    }) {
                        HStack {
                            Image(systemName: "target")
                                .font(.title2)
                            Text("Calibration")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(15)
                    }
                    
                    // Measurement Button
                    Button(action: {
                        currentView = .measurement
                    }) {
                        HStack {
                            Image(systemName: "ruler")
                                .font(.title2)
                            Text("Measurement")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .cornerRadius(15)
                    }
                    
                    // Gaze Track Button
                    Button(action: {
                        currentView = .gazeTrack
                    }) {
                        HStack {
                            Image(systemName: "eye")
                                .font(.title2)
                            Text("Gaze Track")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(15)
                    }
                    
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Footer
                Text("Select an option to begin")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 30)
            }
        }
    }
}

enum AppView {
    case landing
    case calibration
    case measurement
    case gazeTrack
    case gazeTrackAutoStart // 新增：自动启动的gaze track模式
}

#if DEBUG
struct LandingPageView_Previews: PreviewProvider {
    static var previews: some View {
        LandingPageView(currentView: .constant(.landing))
    }
}
#endif
