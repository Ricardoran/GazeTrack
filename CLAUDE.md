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
- **ARKit initialization**: Always check camera permissions before starting face tracking
- **Coordinate accuracy**: Calibration is essential for accurate gaze mapping
- **Device requirements**: Features fail gracefully on unsupported devices
- **Memory management**: Long recording sessions require proper cleanup