# ML Model Integration for GazeTrackApp

## Overview
This implementation adds ML model integration to the GazeTrackApp, allowing users to send their gaze tracking data to a Hugging Face deployed model for analysis.

## Implementation Details

### 1. MLModelService (`Core/Services/MLModelService.swift`)
- **Purpose**: Handles communication with ML models
- **Current Implementation**: Simulates ML model response with random results (1-100)
- **Features**:
  - Asynchronous data upload
  - Progress tracking
  - Error handling
  - Configurable for real Hugging Face API integration

### 2. TrajectoryManager Updates (`Core/Managers/TrajectoryManager.swift`)
- **New Properties**:
  - `showMLUploadAlert`: Controls ML upload confirmation dialog
  - `mlService`: Instance of MLModelService
- **New Methods**:
  - `uploadToMLModel()`: Sends gaze data to ML model
  - `isUploadingToML`: Returns upload status
  - `lastMLResult`: Returns last ML analysis result
  - `mlErrorMessage`: Returns error messages

### 3. UI Updates (`Features/GazeTrack/ContentView.swift`)
- **New ML Button**: Blue "ML" button next to Export button
- **Upload Progress**: Full-screen loading indicator during upload
- **Alert Dialogs**: 
  - Export choice dialog (CSV vs ML upload)
  - ML upload confirmation dialog
  - Results display dialog
- **Button States**: Proper enable/disable logic for upload button

## User Flow

1. **Record Gaze Data**: User tracks their gaze as normal
2. **Choose Export Option**: Click "Export" button to see options:
   - "CSV文件" - Traditional file export
   - "上传到ML模型" - Send to ML model
3. **ML Upload Process**:
   - Confirmation dialog appears
   - Progress indicator shows during upload
   - Results displayed in popup dialog
4. **Alternative**: Direct ML upload via "ML" button

## Current Simulation

The current implementation returns:
- **Random Result**: Integer between 1-100
- **Processing Time**: 2-second simulated delay
- **Data Summary**: Number of processed data points
- **Success Message**: "Analysis completed successfully"

## Future Hugging Face Integration

To connect to a real Hugging Face model:

1. **Update API Endpoint**: Replace mock URL with actual Hugging Face model endpoint
2. **Add Authentication**: Include real Hugging Face API token
3. **Update Request Format**: Modify request body to match model requirements
4. **Parse Real Response**: Handle actual model response format

## File Structure

```
GazeTrackApp/
├── Core/
│   ├── Services/
│   │   └── MLModelService.swift          # New ML service
│   └── Managers/
│       └── TrajectoryManager.swift       # Updated with ML integration
└── Features/
    └── GazeTrack/
        └── ContentView.swift             # Updated UI with ML options
```

## Testing

The integration is designed to be testable:
- All network calls are simulated
- Progress indicators work properly
- Error handling is implemented
- UI states are properly managed

## Benefits

1. **Non-Disruptive**: Existing CSV export functionality remains unchanged
2. **User Choice**: Users can choose between local export and ML analysis
3. **Extensible**: Easy to swap mock implementation with real API
4. **Error Handling**: Robust error handling and user feedback
5. **Progress Feedback**: Clear visual indicators during processing