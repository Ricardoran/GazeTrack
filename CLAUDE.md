# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
GazeTrackApp is a native iOS application using ARKit and RealityKit for real-time eye gaze tracking. The app records gaze patterns and exports data for research in UX, attention studies, and accessibility.

## Development Commands

### Build & Run
```bash
# Open project in Xcode (primary development method)
open GazeTrackApp.xcodeproj

# Build from command line
xcodebuild -project GazeTrackApp.xcodeproj -scheme GazeTrackApp -destination 'platform=iOS,name=YOUR_DEVICE' build
```

### Important Notes
- **Physical device required**: ARKit Face Tracking requires iPhone X+ or compatible iPad Pro
- **No simulator testing**: ARKit features don't work in iOS Simulator
- **No package manager**: Uses only native iOS frameworks (no CocoaPods/SPM)
- **No formal test suite**: Testing done through manual device deployment

## Core Architecture

### Technology Stack
- **Language**: Swift 5.0 with SwiftUI
- **AR Framework**: ARKit (Face Tracking) + RealityKit
- **UI Pattern**: MVVM with ObservableObject managers
- **Target iOS**: 18.2+ (minimum 16.0)

### Key Manager Classes
All managers follow the `ObservableObject` pattern with `@Published` properties:

1. **CalibrationManager** (`CalibrationManager.swift`): 5-point calibration with gaussian-weighted correction
2. **TrajectoryManager** (`TrajectoryManager.swift`): 60Hz gaze data recording and CSV export
3. **VideoManager** (`VideoManager.swift`): Video playback with adjustable opacity during tracking
4. **UIManager** (`UIManager.swift`): UI state management and button visibility timers
5. **MeasurementManager** (`MeasurementManager.swift`): Accuracy measurement and 8-figure trajectory tracking

### Application Modes

#### Gaze Track Mode
- Primary eye tracking with real-time smoothing controls
- **Smoothing Intensity**: 0-100% adjustable via slider (default: 60%)
- **Video Overlay**: Optional video playback with opacity control
- **Export/Visualization**: CSV export and trajectory visualization tools

#### Measurement Mode  
- **Point Accuracy Measurement**: 5-point precision testing
- **8-Figure Trajectory**: Sinusoidal trajectory following for accuracy assessment
- **Distance Tracking**: Eye-to-screen distance monitoring
- **Angle Error Calculation**: Deviation analysis from expected trajectory

#### Calibration Mode
- **5-Point Calibration**: Center + 4 corners gaussian-weighted correction
- **Adaptive Collection**: 3-second data collection per point with validation
- **Correction Vectors**: Spatial interpolation for accuracy improvement

### Core Views
- **ContentView.swift**: Main UI container with all controls and overlays
- **ARViewContainer.swift**: UIViewRepresentable wrapper for CustomARView
- **CustomARView**: ARView subclass handling face tracking and coordinate transformations

### Data Flow Architecture
```
ARKit Face Tracking → ARViewContainer → Manager Classes → UI Updates
                                    ↓
                              CalibrationManager (calibration mode)
                                    ↓
                              TrajectoryManager (recording mode)
                                    ↓
                              CSV Export via ActivityViewController
```

### Coordinate System Handling
Complex transformations from face tracking coordinates to screen coordinates:
- Face anchor coordinates → World coordinates → Camera coordinates → Screen coordinates
- Device-specific screen size calculations with safe area handling

#### Coordinate Transformation Challenges
- **Non-linear mapping**: Accuracy decreases from screen center to edges/corners
- **Edge clamping effects**: Raw coordinates beyond screen bounds are clamped, causing precision loss
- **Device orientation handling**: Different transform matrices for portrait/landscape modes

### Advanced Filtering System

#### Enhanced Gaze Filter (`EnhancedGazeFilter.swift`)
Sophisticated filtering system addressing two critical challenges:

1. **Position-Adaptive Filtering**:
   - Dynamic parameter adjustment based on gaze point location
   - Higher filtering intensity near screen edges and corners
   - Compensates for non-linear coordinate mapping accuracy

2. **Head Pose Stabilization**:
   - Tracks head movement history (15-frame window)
   - Detects micro head movements vs intentional gaze shifts
   - Compensates for head pose changes to maintain gaze stability

#### Filtering Parameters
- **Center Region**: 30% of screen diagonal, highest accuracy
- **Edge Boost Factor**: 2x filtering intensity near edges
- **Corner Boost Factor**: 3x filtering intensity in corners
- **Head Stabilization Threshold**: 0.02 units for micro-movement detection

#### Blink-Aware Processing
- **Multi-level blink detection**: Partial (>0.5) and intense (>0.8) blink levels
- **Adaptive noise adjustment**: 10x measurement noise during intense blinks
- **Recovery period management**: 10-frame stabilization after blink ends
- **Anomaly rejection**: Context-aware during blink periods only

## File Structure Patterns

### Main Source Directory (`GazeTrackApp/`)
- **App entry**: `GazeTrackAppApp.swift`
- **Managers**: Individual manager classes for each major feature
- **Utils**: `Utils.swift` contains extensions and utility functions
- **Assets**: Icons and resources in `Assets.xcassets/`
- **Sample content**: `.mov` files for video testing

### Project Configuration
- **Bundle ID**: `haoranzh.GazeTrackApp`
- **Development Team**: 4JJ856G5YA
- **Required capabilities**: ARKit, Camera permissions
- **Auto-signing**: Enabled

## Development Guidelines

### State Management
- Use `@StateObject` for manager lifecycle management
- Leverage `@Published` properties for reactive UI updates
- Combine framework powers timer-based operations

### ARKit Integration
- Face tracking requires camera permissions check before initialization
- Gaze data collection runs at 60Hz frequency
- Coordinate transformations are device-specific and require careful handling

### Data Management
- CSV export automatically filters recordings <10 seconds
- Gaze trajectories include timestamps and x,y coordinates
- Built-in validation prevents export of incomplete data

## Common Issues

### Technical Challenges
- **ARKit initialization**: Always check camera permissions before starting face tracking
- **Coordinate accuracy**: Calibration is essential for accurate gaze mapping
- **Device requirements**: Features fail gracefully on unsupported devices
- **Memory management**: Long recording sessions require proper cleanup

### Gaze Tracking Robustness Issues
- **Head Movement Sensitivity**: Micro head movements cause gaze point drift even when eyes remain fixed
- **Edge/Corner Accuracy**: Gaze points near screen edges are less accurate due to non-linear coordinate mapping
- **Blink-Induced Noise**: Eye blinks cause violent gaze point fluctuations requiring specialized filtering
- **Lighting Conditions**: Poor lighting degrades face tracking quality and gaze accuracy

### Performance Considerations
- **60Hz Processing**: Real-time filtering must complete within 16ms frame budget
- **Filter Complexity**: Position-adaptive and head stabilization adds computational overhead
- **Memory Usage**: Head pose history and gaze trajectory storage for long sessions
- **Battery Impact**: Continuous ARKit face tracking is battery-intensive

### Development Best Practices
- **Filter Parameter Tuning**: Smoothing intensity must balance responsiveness vs stability
- **Debug Logging**: Comprehensive logging for filter performance and anomaly detection
- **Graceful Degradation**: Fallback modes when advanced filtering fails
- **User Feedback**: Visual indicators for tracking quality and calibration status