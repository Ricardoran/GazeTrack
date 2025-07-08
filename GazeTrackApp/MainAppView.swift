import SwiftUI

struct MainAppView: View {
    @State private var currentView: AppView = .landing
    
    var body: some View {
        Group {
            switch currentView {
            case .landing:
                LandingPageView(currentView: $currentView)
            case .calibration:
                CalibrationView(currentView: $currentView)
            case .measurement:
                MeasurementView(currentView: $currentView)
            case .gazeTrack:
                GazeTrackView(currentView: $currentView)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentView)
    }
}

struct CalibrationView: View {
    @Binding var currentView: AppView
    
    var body: some View {
        ContentView(mode: .calibration, currentView: $currentView)
    }
}

struct MeasurementView: View {
    @Binding var currentView: AppView
    
    var body: some View {
        ContentView(mode: .measurement, currentView: $currentView)
    }
}

struct GazeTrackView: View {
    @Binding var currentView: AppView
    
    var body: some View {
        ContentView(mode: .gazeTrack, currentView: $currentView)
    }
}


enum ViewMode {
    case calibration
    case measurement
    case gazeTrack
}

#if DEBUG
struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        MainAppView()
    }
}
#endif