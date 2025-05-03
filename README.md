# GazeTrackApp

GazeTrackApp is an iOS application that uses ARKit and RealityKit to track eye gaze patterns. It records where users are looking on the screen and exports this data for analysis.

## Overview

The app utilizes the front-facing TrueDepth camera system on compatible iOS devices to track eye movements with high precision. The collected data can be valuable for research in user experience, attention studies, cognitive science, and accessibility.

## Features

- **Real-time Eye Tracking**: Tracks where the user is looking on the screen in real-time.
- **Visualization**: Displays a visual indicator showing the current gaze position.
- **Video Stimuli**: Can display a video while tracking eye movements, with adjustable opacity.
- **Data Recording**: Records eye gaze coordinates at 60Hz frequency.
- **CSV Export**: Exports tracking data to a CSV file with timestamps and x,y coordinates.
- **Countdown Timer**: Includes a 5-second countdown before recording starts to reduce initial data noise.
- **Wink Detection**: Detects when the user winks or raises eyebrows.

## Requirements

- iOS device with Face ID (iPhone X or newer, or compatible iPad Pro)
- iOS 16.0 or later
- Xcode 14.0 or later

## Installation

1. Clone this repository
2. Open the project in Xcode
3. Connect your iOS device
4. Build and run the app on your device

## Usage

1. Launch the app on your iOS device
2. Choose whether to display a video or use the camera view
3. Press "Start" to begin eye tracking (a 3-second countdown will appear)
4. Look around the screen naturally
5. Press "Stop" when finished
6. Use "Export Trajectory" to save and share the data

## Data Format

The exported CSV file contains the following columns:
- `elapsedTime(seconds)`: Time since recording started, in seconds
- `x`: X-coordinate of gaze point on screen
- `y`: Y-coordinate of gaze point on screen

## Limitations

- Requires good lighting conditions for optimal tracking
- Device must be held relatively stable
- Works best when user's face is fully visible to the camera
- Calibration may vary between users and devices

## Future Development

Planned features for future releases:
- Calibration system to improve tracking accuracy
- Heatmap visualization of gaze patterns
- Additional stimuli options (images, text, web content)
- Data analysis tools within the app
- Cloud storage for session data

## License

[Include your license information here]

## Credits

Developed by Haoran Zhang

Built with ARKit, RealityKit, and SwiftUI