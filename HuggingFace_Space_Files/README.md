---
title: Gaze Tracking Data Analyzer
emoji: 👁️
colorFrom: blue
colorTo: purple
sdk: gradio
sdk_version: 4.0.0
app_file: app.py
pinned: false
---

# Gaze Tracking Data Analyzer

A simple ML model for analyzing gaze tracking data and providing attention/focus scores.

## Features

- 📊 Analyzes CSV gaze tracking data
- 🎯 Calculates attention scores (1-100)
- 📈 Provides movement and stability metrics
- 🚀 REST API compatible
- 📱 Designed for mobile app integration

## Usage

### Web Interface
1. Paste your CSV data in the text box
2. Click Submit to get analysis results

### API Usage
Send POST request to `/api/predict`:

```bash
curl -X POST \
  https://YOUR_USERNAME-gaze-tracking-analyzer.hf.space/api/predict \
  -H "Content-Type: application/json" \
  -d '{
    "data": ["elapsedTime(seconds),x,y\n0.000,100.50,200.30\n0.016,101.20,201.15\n"]
  }'
```

### Expected CSV Format
```
elapsedTime(seconds),x,y
0.000,100.50,200.30
0.016,101.20,201.15
0.032,102.10,202.05
...
```

## Analysis Metrics

- **Attention Score**: Overall focus quality (1-100)
- **Duration**: Total tracking time
- **Movement Patterns**: Average and total eye movement
- **Stability**: Consistency of gaze patterns
- **Coverage Area**: Screen area covered by gaze

## Score Interpretation

- **85-100**: Excellent attention patterns
- **70-84**: Good attention stability
- **55-69**: Moderate attention focus
- **40-54**: Needs attention improvement
- **1-39**: Poor attention patterns

## Integration

This model is designed to work with the GazeTrackApp iOS application for real-time gaze tracking analysis.