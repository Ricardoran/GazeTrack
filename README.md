# GazeTrackApp
GazeTrackApp is an iOS application that uses ARKit and RealityKit to track eye gaze patterns. It records where users are looking on the screen and exports this data for analysis.

## Overview
The app utilizes the front-facing TrueDepth camera system on compatible iOS devices to track eye movements with high precision. The collected data can be valuable for research in user experience, attention studies, cognitive science, and accessibility.

## Features
- **Real-time Eye Tracking**: Tracks where the user is looking on the screen with optimized smoothing
- **Gaze Track Lab**: Multi-method comparison with three different tracking approaches
- **Grid Testing**: 28-zone grid overlay (A-Z, #, @) for precision testing and accuracy assessment
- **Color-Coded Tracking**: Visual feedback with method-specific gaze point colors (orange, blue, purple)
- **Simple Smoothing Algorithm**: Lightweight sliding window averaging (0-50 points, default: 30)
- **Responsive Controls**: Real-time adjustable smoothing for different use cases
- **Enhanced Calibration**: Dual-phase calibration with auto-validation and 50pt proximity check
- **8-Figure Measurement**: Advanced trajectory following with ME (Mean Euclidean) error analysis
- **Video Stimuli**: Display videos while tracking with adjustable opacity
- **Data Recording**: Records eye gaze coordinates at 60Hz frequency
- **CSV Export**: Exports tracking data with timestamps and coordinates
- **Trajectory Visualization**: Comprehensive trajectory comparison and error analysis
- **Performance Optimized**: Minimal latency with consistent 60fps performance
## Architecture
GazeTrackApp uses a modular architecture organized into distinct layers:

### Core Components
- **ARViewContainer**: Main gaze tracking AR session and face tracking with integrated smoothing
- **GazeTrackLabARViewContainer**: Multi-method AR tracking with three different approaches
- **SimpleGazeSmoothing**: Lightweight sliding window averaging algorithm
- **GazeTrackLabManager**: Multi-method comparison and real-time method switching
- **CalibrationManager**: Enhanced dual-phase calibration with auto-validation
- **MeasurementManager**: 8-figure trajectory measurement with ME error analysis
- **TrajectoryManager**: Manages recording and exporting of gaze trajectory data
- **VideoManager**: Manages video playback and opacity settings
- **UIManager**: Handles UI state and interactions with auto-hide functionality

### Project Structure
```
GazeTrackApp/
├── App/                     # Application entry layer
├── Core/                    # Core functionality
│   ├── Managers/           # Business logic managers
│   ├── AR/                 # ARKit integration
│   ├── Algorithms/         # Processing algorithms
│   └── Utils/              # Utility functions
├── Features/               # Feature modules
│   ├── GazeTrack/         # Main tracking interface
│   ├── GazeTrackLab/    # Multi-method comparison
│   ├── Calibration/       # Calibration features
│   └── Measurement/       # Measurement tools
├── Resources/             # Assets and media
└── Supporting Files/      # Configuration
```
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

### Gaze Track Lab (Method Comparison)
1. Launch the app and select "Gaze Track Lab"
2. Toggle the grid overlay to show 28-zone reference grid (A-Z, #, @)
3. Click the method switch button to cycle between three tracking approaches:
   - **Dual Eyes + HitTest** (Orange gaze point)
   - **LookAt + Matrix Transform** (Blue gaze point) 
   - **LookAt + HitTest** (Purple gaze point)
4. Adjust smoothing window size (0-50 points) for response vs stability balance
5. Look at different grid zones to test accuracy across methods
6. Monitor real-time distance display for optimal tracking conditions

### Basic Eye Tracking
1. Launch the app and select "Gaze Track"
2. Choose whether to display a video or use the camera view
3. Adjust smoothing window size (0-50 points) using the slider
4. Press "Start Calibration" for enhanced calibration (recommended)
5. Press "Start" to begin eye tracking (5-second countdown appears)
6. Look around the screen naturally
7. Press "Stop" when finished
8. Use "Show Trajectory" to view visualization of eye movements
9. Use "Export Trajectory" to save and share the data

### Advanced Features
- **Multi-Method Comparison**: Compare three different tracking approaches in real-time
- **Grid Precision Testing**: Use 28-zone grid for quick accuracy assessment
- **Calibration**: Enhanced dual-phase calibration with auto-validation
- **8-Figure Measurement**: Test tracking accuracy with trajectory following
- **Smoothing Control**: Real-time adjustment of window size for optimal performance
- **ME Error Analysis**: View Mean Euclidean error in centimeters and detailed statistics
## Data Format
The exported CSV file contains the following columns:

- elapsedTime(seconds) : Time since recording started, in seconds
- x : X-coordinate of gaze point on screen
- y : Y-coordinate of gaze point on screen
## Limitations
- Requires good lighting conditions for optimal tracking
- Device must be held relatively stable
- Works best when user's face is fully visible to the camera
- Calibration may vary between users and devices
- Recording time needs to be at least 10 seconds to be valid
## Recent Updates

### Version 3.0 Features - Gaze Track Lab
- **Multi-Method Comparison**: Added comprehensive comparison of three tracking approaches
- **Grid Testing System**: 28-zone grid overlay (A-Z, #, @) for precision testing
- **Color-Coded Feedback**: Method-specific gaze point colors for visual identification
- **Organized Architecture**: Restructured project into logical feature modules
- **Thread Safety**: Fixed UI API thread safety warnings
- **Auto-Hide UI**: Implemented 3-second auto-hide for immersive experience
- **Distance Monitoring**: Real-time eye-to-screen distance display

### Version 2.0 Features
- **Simplified Smoothing**: Replaced complex Kalman filtering with efficient sliding window averaging
- **Enhanced Calibration**: Dual-phase calibration with auto-validation and proximity checking
- **8-Figure Measurement**: Advanced trajectory measurement with ME (Mean Euclidean) error analysis
- **Performance Optimization**: Reduced latency and improved 60fps consistency
- **UI Improvements**: Real-time smoothing controls and enhanced user feedback

## Future Development
Planned features for future releases:

- Heatmap visualization of gaze patterns
- Additional stimuli options (images, text, web content)
- Machine learning-based gaze prediction
- Multi-user session support
- Cloud storage for session data
- Advanced statistical analysis tools
## License
MIT License

Copyright (c) 2025 Haoran Zhang

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Credits
Developed by Haoran Zhang

Built with ARKit, RealityKit, and SwiftUI

# 眼动追踪应用
眼动追踪应用是一款利用ARKit和RealityKit技术追踪眼球注视模式的iOS应用。它可以记录用户在屏幕上的视线位置，并导出这些数据用于分析。

## 概述
该应用利用兼容iOS设备上的前置TrueDepth摄像头系统，以高精度追踪眼球运动。收集的数据对用户体验研究、注意力研究、认知科学和无障碍功能开发具有重要价值。

## 功能特点
- **实时眼动追踪**：优化平滑算法的实时屏幕注视位置追踪
- **眼动追踪实验室**：三种不同追踪方法的多重对比功能
- **网格测试系统**：28区域网格覆盖层（A-Z，#，@）用于精度测试和准确性评估
- **彩色编码追踪**：根据方法特定的凝视点颜色（橙色、蓝色、紫色）提供视觉反馈
- **简单平滑算法**：轻量级滑动窗口平均算法（0-50点，默认30点）
- **响应式控制**：实时可调节的平滑参数，适应不同使用场景
- **增强校准系统**：双阶段校准，带自动验证和50点邻近检查
- **8字轨迹测量**：高级轨迹跟踪，提供ME（平均欧几里得）误差分析
- **视频刺激**：追踪时显示视频，支持不透明度调整
- **数据记录**：60Hz频率记录眼球注视坐标
- **CSV导出**：导出包含时间戳和坐标的追踪数据
- **轨迹可视化**：全面的轨迹对比和误差分析
- **性能优化**：最小延迟，稳定60fps性能
## 架构
眼动追踪应用采用模块化架构，包含以下组件：

- **AR视图容器**：处理AR会话和面部追踪，集成平滑算法
- **简单凝视平滑**：轻量级滑动窗口平均算法
- **校准管理器**：增强双阶段校准，带自动验证
- **测量管理器**：8字轨迹测量，提供ME误差分析
- **轨迹管理器**：管理眼动轨迹数据的记录和导出
- **视频管理器**：管理视频播放和透明度设置
- **UI管理器**：处理用户界面状态和交互
- **轨迹对比视图**：可视化轨迹对比和误差分析
## 系统要求
- 配备Face ID的iOS设备（iPhone X或更新机型，或兼容的iPad Pro）
- iOS 16.0或更高版本
- Xcode 14.0或更高版本
## 安装方法
1. 克隆此代码库
2. 在Xcode中打开项目
3. 连接您的iOS设备
4. 在设备上构建并运行应用
## 使用方法
1. 在iOS设备上启动应用
2. 选择是否显示视频或使用相机视图
3. 点击"开始校准"进行眼动追踪校准（可选但推荐）
4. 点击"开始"开始眼动追踪（将出现5秒倒计时）
5. 自然地环顾屏幕
6. 完成后点击"停止"
7. 使用"显示轨迹"查看眼动轨迹可视化
8. 使用"导出轨迹"保存并分享数据
## 数据格式
导出的CSV文件包含以下列：

- elapsedTime(seconds) ：从记录开始后的时间（秒）
- x ：屏幕上注视点的X坐标
- y ：屏幕上注视点的Y坐标
## 局限性
- 需要良好的光线条件以获得最佳追踪效果
- 设备必须保持相对稳定
- 当用户的脸完全可见于摄像头时效果最佳
- 校准可能因用户和设备而异
- 记录时间需要至少10秒才有效
## 未来开发计划
计划在未来版本中添加的功能：

- 改进校准系统以提高追踪精度
- 注视模式的热图可视化
- 更多刺激选项（图像、文本、网页内容）
- 应用内数据分析工具
- 会话数据的云存储
- 支持更多设备和iOS版本
## 许可证
MIT License

Copyright (c) 2025 Haoran Zhang

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## 致谢
由Haoran Zhang开发

使用ARKit、RealityKit和SwiftUI构建