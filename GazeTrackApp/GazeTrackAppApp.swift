//  GazeTrackAppApp.swift
//  GazeTrackApp
//
//  Created by Haoran Zhang on 3/2/25.
//

import SwiftUI

@main
struct GazeTrackAppApp: App {
    init() {
        // 确保应用支持所有方向
        if #available(iOS 16.0, *) {
            // iOS 16及以上版本不需要特殊处理
        } else {
            // iOS 16以下版本需要设置支持的方向
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
