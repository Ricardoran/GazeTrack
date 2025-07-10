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
- Primary eye tracking with optimized simple smoothing
- **Simple Smoothing**: Sliding window average algorithm (0-50 points, default: 30)
- **Real-time Control**: Adjustable window size slider for response vs stability balance  
- **Video Overlay**: Optional video playback with opacity control
- **Export/Visualization**: CSV export and trajectory visualization tools

#### Measurement Mode  
- **Point Accuracy Measurement**: 5-point precision testing with simple smoothing
- **8-Figure Trajectory**: Sinusoidal trajectory following for accuracy assessment
- **Distance Tracking**: Eye-to-screen distance monitoring
- **Angle Error Calculation**: Deviation analysis from expected trajectory
- **ME (Mean Euclidean) Display**: Results shown in centimeters and visual accuracy analysis

#### Calibration Mode
- **Enhanced 5-Point Calibration**: Center + 4 corners with dual-phase collection
- **Adaptive Collection**: 3-second initial data collection + 3-second alignment verification
- **Auto-Validation**: 50pt proximity check for calibration point alignment
- **Gaussian-Weighted Correction**: Spatial interpolation using all calibration vectors

### Core Views
- **ContentView.swift**: Main UI container with all controls and overlays
- **ARViewContainer.swift**: UIViewRepresentable wrapper for CustomARView
- **CustomARView**: ARView subclass handling face tracking and coordinate transformations
- **SimpleGazeSmoothing.swift**: Lightweight sliding window smoothing algorithm
- **TrajectoryComparisonView.swift**: Visual comparison of target vs actual gaze trajectories

### Data Flow Architecture
```
ARKit Face Tracking → ARViewContainer → SimpleGazeSmoothing → Manager Classes → UI Updates
                                    ↓
                              CalibrationManager (calibration mode)
                                    ↓
                              TrajectoryManager (recording mode)
                                    ↓
                              MeasurementManager (8-figure analysis)
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

### Simple Smoothing System

#### SimpleGazeSmoothing Algorithm
Lightweight and efficient smoothing system optimized for real-time performance:

1. **Sliding Window Average**:
   - Maintains configurable window of recent gaze points (default: 30 points)
   - Weighted average with higher weight for newer points
   - Dynamic window size adjustment (0-50 points range)

2. **Performance Optimizations**:
   - Minimal computational overhead (~0.02ms per frame)
   - No complex state management or matrix operations
   - Linear memory usage proportional to window size

#### Smoothing Parameters
- **Window Size**: 0-50 points (0 = no smoothing, 50 = maximum smoothing)
- **Default Setting**: 30 points (~0.5 second delay at 60fps)
- **Response Time**: 0.08s (5 points) to 0.83s (50 points)
- **Weighted Average**: Linear weighting favoring recent points

#### Performance Characteristics
- **Low Latency**: Significantly faster than Kalman filtering
- **Predictable Behavior**: Simple algorithm with transparent results
- **User Control**: Real-time adjustable via slider for different use cases
- **Memory Efficient**: Fixed memory footprint, no growing state

## File Structure Patterns

### Main Source Directory (`GazeTrackApp/`)
- **App entry**: `GazeTrackAppApp.swift`
- **Managers**: Individual manager classes for each major feature
- **Core Components**: `SimpleGazeSmoothing.swift`, `TrajectoryComparisonView.swift`
- **Utils**: `Utils.swift` contains extensions and utility functions
- **Assets**: Icons and resources in `Assets.xcassets/`
- **Sample content**: `.mov` files for video testing

### Key Files
- `CalibrationManager.swift`: Enhanced dual-phase calibration with auto-validation
- `MeasurementManager.swift`: 8-figure trajectory measurement with ME error analysis
- `SimpleGazeSmoothing.swift`: Lightweight sliding window smoothing algorithm
- `ContentView.swift`: Main UI with simplified smoothing controls
- `ARViewContainer.swift`: Core AR functionality with integrated smoothing

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
- **60Hz Processing**: Simple smoothing completes well within 16ms frame budget
- **Minimal Overhead**: Sliding window average requires only basic arithmetic operations
- **Memory Usage**: Fixed memory footprint proportional to window size (max 50 points)
- **Battery Impact**: Reduced computational load compared to complex filtering
- **Real-time Response**: Dynamic window adjustment without performance penalty

### Development Best Practices
- **Smoothing Parameter Selection**: Window size balances response time vs stability
- **UI Responsiveness**: Real-time slider control for immediate user feedback
- **Debug Logging**: Simple distance-based smoothing effectiveness metrics
- **Graceful Performance**: Consistent behavior across all devices and conditions
- **User Control**: Direct window size control for different use case requirements

### Calibration System Enhancements
- **Dual-Phase Collection**: Initial 3s data gathering + 3s alignment verification
- **Auto-Validation**: 50pt proximity check ensures accurate calibration points
- **Enhanced Feedback**: Visual and timing cues guide user through calibration process
- **Robust Error Handling**: Automatic retry for insufficient or misaligned data