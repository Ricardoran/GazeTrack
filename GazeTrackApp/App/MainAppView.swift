import SwiftUI

struct MainAppView: View {
    @State private var currentView: AppView = .landing
    @StateObject private var sharedCalibrationManager = CalibrationManager()
    @StateObject private var sharedMeasurementManager = MeasurementManager()
    
    var body: some View {
        Group {
            switch currentView {
            case .landing:
                LandingPageView(currentView: $currentView)
                    .id("landing")
            case .calibration:
                CalibrationView(currentView: $currentView, calibrationManager: sharedCalibrationManager, measurementManager: sharedMeasurementManager)
                    .id("calibration")
            case .measurement:
                MeasurementView(currentView: $currentView, calibrationManager: sharedCalibrationManager, measurementManager: sharedMeasurementManager)
                    .id("measurement")
            case .gazeTrack:
                GazeTrackView(currentView: $currentView, calibrationManager: sharedCalibrationManager, measurementManager: sharedMeasurementManager)
                    .id("gazeTrack")
            case .gazeTrackAutoStart:
                GazeTrackAutoStartView(currentView: $currentView, calibrationManager: sharedCalibrationManager, measurementManager: sharedMeasurementManager)
                    .id("gazeTrackAutoStart")
            case .gazeTrackLab:
                GazeTrackLabView(currentView: $currentView)
                    .id("gazeTrackLab")
            case .history:
                HistoryView(currentView: $currentView)
                    .id("history")
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentView)
    }
}

struct CalibrationView: View {
    @Binding var currentView: AppView
    @ObservedObject var calibrationManager: CalibrationManager
    @ObservedObject var measurementManager: MeasurementManager
    
    var body: some View {
        ContentView(mode: .calibration, currentView: $currentView, calibrationManager: calibrationManager, measurementManager: measurementManager)
    }
}

struct MeasurementView: View {
    @Binding var currentView: AppView
    @ObservedObject var calibrationManager: CalibrationManager
    @ObservedObject var measurementManager: MeasurementManager
    
    var body: some View {
        ContentView(mode: .measurement, currentView: $currentView, calibrationManager: calibrationManager, measurementManager: measurementManager)
    }
}

struct GazeTrackView: View {
    @Binding var currentView: AppView
    @ObservedObject var calibrationManager: CalibrationManager
    @ObservedObject var measurementManager: MeasurementManager
    
    var body: some View {
        ContentView(mode: .gazeTrack, currentView: $currentView, calibrationManager: calibrationManager, measurementManager: measurementManager)
    }
}

struct GazeTrackAutoStartView: View {
    @Binding var currentView: AppView
    @ObservedObject var calibrationManager: CalibrationManager
    @ObservedObject var measurementManager: MeasurementManager
    
    var body: some View {
        ContentView(mode: .gazeTrack, currentView: $currentView, calibrationManager: calibrationManager, measurementManager: measurementManager, autoStart: true)
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