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
                    UnifiedButton(
                        action: { currentView = .calibration },
                        icon: "target",
                        text: "Calibration",
                        backgroundColor: Color.red,
                        style: .large
                    )
                    .frame(width: 280, height: 56)
                    
                    // Measurement Button
                    UnifiedButton(
                        action: { currentView = .measurement },
                        icon: "ruler",
                        text: "Measurement",
                        backgroundColor: Color.orange,
                        style: .large
                    )
                    .frame(width: 280, height: 56)
                    
                    // Gaze Track Button
                    UnifiedButton(
                        action: { currentView = .gazeTrack },
                        icon: "eye",
                        text: "Gaze Track",
                        backgroundColor: Color.blue,
                        style: .large
                    )
                    .frame(width: 280, height: 56)
                    
                    // Gaze Track Lab Button
                    UnifiedButton(
                        action: { currentView = .gazeTrackLab },
                        icon: "flask",
                        text: "Gaze Track Lab",
                        backgroundColor: Color.green,
                        style: .large
                    )
                    .frame(width: 280, height: 56)
                    
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
    case gazeTrackLab // 新增：双眼分别追踪模式（Gaze Track Lab）
}

#if DEBUG
struct LandingPageView_Previews: PreviewProvider {
    static var previews: some View {
        LandingPageView(currentView: .constant(.landing))
    }
}
#endif
