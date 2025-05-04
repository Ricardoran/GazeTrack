# GazeTrackApp
GazeTrackApp is an iOS application that uses ARKit and RealityKit to track eye gaze patterns. It records where users are looking on the screen and exports this data for analysis.

## Overview
The app utilizes the front-facing TrueDepth camera system on compatible iOS devices to track eye movements with high precision. The collected data can be valuable for research in user experience, attention studies, cognitive science, and accessibility.

## Features
- Real-time Eye Tracking : Tracks where the user is looking on the screen in real-time.
- Visualization : Displays a visual indicator showing the current gaze position.
- Video Stimuli : Can display a video while tracking eye movements, with adjustable opacity.
- Data Recording : Records eye gaze coordinates at 60Hz frequency.
- CSV Export : Exports tracking data to a CSV file with timestamps and x,y coordinates.
- Countdown Timer : Includes a 5-second countdown before recording starts to reduce initial data noise.
- Wink Detection : Detects when the user winks or raises eyebrows.
- Calibration System : Supports eye tracking calibration to improve accuracy.
- Trajectory Visualization : Provides visualization of eye movement patterns.
- Data Processing : Automatically filters and processes eye tracking data for quality.
## Architecture
GazeTrackApp uses a modular architecture with the following components:

- ARViewContainer : Handles AR session and face tracking
- TrajectoryManager : Manages recording and exporting of gaze trajectory data
- CalibrationManager : Handles eye tracking calibration
- VideoManager : Manages video playback and opacity settings
- UIManager : Handles UI state and interactions
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
3. Press "Start Calibration" to calibrate eye tracking (optional but recommended)
4. Press "Start" to begin eye tracking (a 5-second countdown will appear)
5. Look around the screen naturally
6. Press "Stop" when finished
7. Use "Show Trajectory" to view visualization of eye movements
8. Use "Export Trajectory" to save and share the data
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
## Future Development
Planned features for future releases:

- Improved calibration system for better tracking accuracy
- Heatmap visualization of gaze patterns
- Additional stimuli options (images, text, web content)
- Data analysis tools within the app
- Cloud storage for session data
- Support for more devices and iOS versions
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
- 实时眼动追踪 ：实时追踪用户在屏幕上的注视位置
- 视觉指示器 ：显示当前注视位置的可视化指示
- 视频刺激 ：可在追踪眼球运动的同时显示视频，并支持调整不透明度
- 数据记录 ：以60Hz的频率记录眼球注视坐标
- CSV导出 ：将追踪数据导出为CSV文件，包含时间戳和x,y坐标
- 倒计时功能 ：记录开始前有5秒倒计时，减少初始数据噪声
- 眨眼检测 ：检测用户眨眼或挑眉动作
- 校准系统 ：支持眼动追踪校准，提高追踪精度
- 轨迹可视化 ：提供眼动轨迹的可视化展示
- 数据处理 ：自动过滤和处理眼动数据，确保数据质量
## 架构
眼动追踪应用采用模块化架构，包含以下组件：

- AR视图容器 ：处理AR会话和面部追踪
- 轨迹管理器 ：管理眼动轨迹数据的记录和导出
- 校准管理器 ：处理眼动追踪校准
- 视频管理器 ：管理视频播放和透明度设置
- UI管理器 ：处理用户界面状态和交互
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