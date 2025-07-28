//
//  TrajectoryComparisonView.swift
//  GazeTrackApp
//
//  Created by Claude AI on 2025-07-08.
//

import SwiftUI

struct TrajectoryComparisonView: View {
    let trajectoryResults: TrajectoryMeasurementResult
    let screenSize: CGSize
    @State private var showLegend = true
    @Binding var showVisualization: Bool
    
    init(trajectoryResults: TrajectoryMeasurementResult, screenSize: CGSize, showVisualization: Binding<Bool>) {
        self.trajectoryResults = trajectoryResults
        self.screenSize = screenSize
        self._showVisualization = showVisualization
    }
    
    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            
            VStack {
                // Top title bar - unified horizontal layout
                HStack {
                    // Back button
                    UnifiedButton(
                        action: { showVisualization = false },
                        icon: "chevron.left",
                        text: "Back to Results",
                        backgroundColor: Color.blue.opacity(0.8),
                        style: .compact
                    )
                    
                    Spacer()
                    
                    // Legend toggle button
                    UnifiedButton(
                        action: { showLegend.toggle() },
                        icon: showLegend ? "eye.slash" : "eye",
                        text: showLegend ? "Hide Legend" : "Show Legend",
                        backgroundColor: Color.blue.opacity(0.8),
                        style: .compact
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                .padding(.bottom, 10)
                
                // Trajectory visualization area
                GeometryReader { geometry in
                    let scale = min(geometry.size.width / screenSize.width, 
                                   geometry.size.height / screenSize.height) * 0.9
                    let scaledWidth = screenSize.width * scale
                    let scaledHeight = screenSize.height * scale
                    let offsetX = (geometry.size.width - scaledWidth) / 2
                    let offsetY = (geometry.size.height - scaledHeight) / 2
                    
                    ZStack {
                        // Background frame
                        Rectangle()
                            .stroke(Color.gray, lineWidth: 2)
                            .frame(width: scaledWidth, height: scaledHeight)
                            .position(x: geometry.size.width/2, y: geometry.size.height/2)
                        
                        // Ground Truth trajectory (figure-8)
                        Path { path in
                            let groundTruthPoints = generateGroundTruthTrajectory()
                            
                            for (index, point) in groundTruthPoints.enumerated() {
                                let scaledX = offsetX + point.x * scale
                                let scaledY = offsetY + point.y * scale
                                let scaledPoint = CGPoint(x: scaledX, y: scaledY)
                                
                                if index == 0 {
                                    path.move(to: scaledPoint)
                                } else {
                                    path.addLine(to: scaledPoint)
                                }
                            }
                        }
                        .stroke(Color.red, lineWidth: 3)
                        
                        
                        // Sample point markers - bold display
                        ForEach(Array(sampleTrajectoryPoints().enumerated()), id: \.offset) { index, point in
                            Circle()
                                .fill(Color.blue.opacity(0.8))
                                .frame(width: 6, height: 6)  // Bold from 4 to 6
                                .position(x: offsetX + point.x * scale, 
                                         y: offsetY + point.y * scale)
                        }
                        
                    }
                }
                
                // Bottom legend and statistics
                if showLegend {
                    VStack(spacing: 12) {
                        // Legend description
                        HStack(spacing: 25) {
                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(Color.red)
                                    .frame(width: 24, height: 4)
                                    .cornerRadius(2)
                                Text("Target Trajectory")
                                    .font(.subheadline)
                                    .foregroundColor(.black)
                            }
                            
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.blue.opacity(0.8))
                                    .frame(width: 8, height: 8)
                                Text("Actual Trajectory")
                                    .font(.subheadline)
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(.bottom, 8)
                        
                        // Statistical data - optimized layout
                        VStack(spacing: 12) {
                            // First row: main error metrics
                            HStack(spacing: 15) {
                                StatCard(
                                    title: "Average Distance Error",
                                    value: "\(String(format: "%.3f", trajectoryResults.meanEuclideanErrorInCM)) cm",
                                    color: .red
                                )
                                
                                StatCard(
                                    title: "Average Angle Error",
                                    value: "\(String(format: "%.3f", trajectoryResults.meanEuclideanErrorInDegrees))°",
                                    color: .blue
                                )
                            }
                            
                            // Second row: auxiliary information
                            HStack(spacing: 15) {
                                StatCard(
                                    title: "Sample Points",
                                    value: "\(sampleTrajectoryPoints().count)",
                                    color: .green
                                )
                                
                                StatCard(
                                    title: "Observation Distance",
                                    value: "\(String(format: "%.1f", trajectoryResults.averageEyeToScreenDistance)) cm",
                                    color: .purple
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    // Generate Ground Truth trajectory (based on trajectory type)
    private func generateGroundTruthTrajectory() -> [CGPoint] {
        switch trajectoryResults.trajectoryType {
        case .figure8:
            return generateFigure8Trajectory()
        case .sinusoidalTrajectory:
            return generateSinusoidalTrajectory()
        }
    }
    
    // Generate figure-8 trajectory
    private func generateFigure8Trajectory() -> [CGPoint] {
        var points: [CGPoint] = []
        let centerX = screenSize.width / 2
        let centerY = screenSize.height / 2
        
        // Calculate margins and radius (consistent with MeasurementManager)
        let marginX: CGFloat = 30.0
        let marginY: CGFloat = 30.0
        let maxRadiusFromWidth = (screenSize.width - marginX * 2) / 2
        let maxRadiusFromHeight = min(centerY - marginY, screenSize.height - marginY - centerY) / 2
        let circleRadius = min(maxRadiusFromWidth, maxRadiusFromHeight)
        
        let upperCenterY = centerY - circleRadius
        let lowerCenterY = centerY + circleRadius
        
        // Generate dense enough points to draw smooth figure-8
        let totalPoints = 200
        
        for i in 0...totalPoints {
            let progress = Float(i) / Float(totalPoints)
            
            let x: CGFloat
            let y: CGFloat
            
            if progress <= 0.5 {
                // Upper circle
                let circleProgress = progress * 2
                let angle = circleProgress * 2 * Float.pi
                let adjustedAngle = Float.pi / 2 + angle
                x = centerX + circleRadius * CGFloat(cos(adjustedAngle))
                y = upperCenterY + circleRadius * CGFloat(sin(adjustedAngle))
            } else {
                // Lower circle
                let circleProgress = (progress - 0.5) * 2
                let angle = circleProgress * 2 * Float.pi
                let adjustedAngle = 3 * Float.pi / 2 - angle
                x = centerX + circleRadius * CGFloat(cos(adjustedAngle))
                y = lowerCenterY + circleRadius * CGFloat(sin(adjustedAngle))
            }
            
            let clampedX = max(marginX, min(screenSize.width - marginX, x))
            let clampedY = max(marginY, min(screenSize.height - marginY, y))
            points.append(CGPoint(x: clampedX, y: clampedY))
        }
        
        return points
    }
    
    // Generate sinusoidal trajectory
    private func generateSinusoidalTrajectory() -> [CGPoint] {
        var points: [CGPoint] = []
        let totalPoints = 200
        
        for i in 0...totalPoints {
            let progress = Float(i) / Float(totalPoints)
            points.append(generateSinusoidalTrajectoryPoint(at: progress))
        }
        
        return points
    }
    
    // Generate sine wave-based sinusoidal trajectory (with reverse propagation, consistent with MeasurementManager)
    private func generateSinusoidalTrajectoryPoint(at progress: Float) -> CGPoint {
        // Calculate safe margins (considering Dynamic Island and home indicator)
        let marginX: CGFloat = 30.0
        let marginY: CGFloat = 60.0  // Increase Y margin to avoid Dynamic Island and home indicator
        
        // Calculate available area
        let availableWidth = screenSize.width - 2 * marginX
        let availableHeight = screenSize.height - 2 * marginY
        
        // Divide entire trajectory into two phases: forward and reverse
        let phase1Duration: Float = 0.5  // First 50% of time for phase 1
        let phase2Duration: Float = 0.5  // Last 50% of time for phase 2
        
        let x: CGFloat
        let y: CGFloat
        
        if progress <= phase1Duration {
            // Phase 1: sine wave starting from top-left, from top to bottom
            let phase1Progress = progress / phase1Duration
            let waveFrequency: Float = 3.0  // 3 complete wave forms
            let amplitude = availableWidth / 2.0
            let centerX = screenSize.width / 2.0
            
            // Y coordinate from top to bottom
            y = marginY + CGFloat(phase1Progress) * availableHeight
            
            // X coordinate changes with sine wave, adjust starting phase to begin from top-left
            // Phase corresponding to top-left: sin(phase) = -1, i.e., phase = 3π/2
            let startPhase: Float = 3.0 * Float.pi / 2.0  // Start from top-left
            let wavePhase = startPhase + phase1Progress * waveFrequency * 2.0 * Float.pi
            let waveOffset = amplitude * CGFloat(sin(wavePhase))
            x = centerX + waveOffset
            
        } else {
            // Phase 2: sine wave from bottom to top (reverse propagation, change frequency to reduce overlap)
            let phase2Progress = (progress - phase1Duration) / phase2Duration
            let waveFrequency: Float = 2.5  // Change frequency to 2.5 wave forms, reduce overlap
            let amplitude = availableWidth / 2.0
            let centerX = screenSize.width / 2.0
            
            // Y coordinate from bottom to top (reverse)
            y = marginY + availableHeight - CGFloat(phase2Progress) * availableHeight
            
            // X coordinate changes with sine wave, but add phase offset to ensure continuity
            // Calculate X position at end of phase 1, ensure phase 2 starts from this position
            let phase1StartPhase: Float = 3.0 * Float.pi / 2.0  // Phase 1 starting phase
            let phase1EndPhase = phase1StartPhase + 1.0 * 3.0 * 2.0 * Float.pi  // Phase at end of phase 1
            let phase1EndX = centerX + amplitude * CGFloat(sin(phase1EndPhase))
            
            // Phase 2 starting phase, ensure starting from phase 1 end position
            let phase2StartPhase = asin(Float((phase1EndX - centerX) / amplitude))
            let wavePhase = phase2StartPhase + phase2Progress * waveFrequency * 2.0 * Float.pi
            let waveOffset = amplitude * CGFloat(sin(wavePhase))
            x = centerX + waveOffset
        }
        
        // Ensure coordinates are within screen boundaries
        let clampedX = max(marginX, min(screenSize.width - marginX, x))
        let clampedY = max(marginY, min(screenSize.height - marginY, y))
        
        return CGPoint(x: clampedX, y: clampedY)
    }
    
    // Helper function: linear interpolation between two points
    private func interpolatePoints(from start: CGPoint, to end: CGPoint, t: CGFloat) -> CGPoint {
        let x = start.x + (end.x - start.x) * t
        let y = start.y + (end.y - start.y) * t
        return CGPoint(x: x, y: y)
    }
    
    // Appropriately sample trajectory data
    private func sampleTrajectoryPoints() -> [CGPoint] {
        let allPoints = trajectoryResults.trajectoryPoints
        guard !allPoints.isEmpty else { return [] }
        
        // Sample one point every 10 points, maintain reasonable density
        let sampleRate = 10
        var sampledPoints: [CGPoint] = []
        
        for i in stride(from: 0, to: allPoints.count, by: sampleRate) {
            sampledPoints.append(allPoints[i].actualPosition)
        }
        
        // Ensure the last point is included
        if let lastPoint = allPoints.last {
            sampledPoints.append(lastPoint.actualPosition)
        }
        
        return sampledPoints
    }
}

// Statistics card component
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }
}

#if DEBUG
struct TrajectoryComparisonView_Previews: PreviewProvider {
    static var previews: some View {
        let samplePoints = [
            TrajectoryMeasurementPoint(
                targetPosition: CGPoint(x: 200, y: 400),
                actualPosition: CGPoint(x: 195, y: 405),
                timestamp: 0.0,
                error: 7.0,
                eyeToScreenDistance: 30.0
            )
        ]
        
        let sampleResult = TrajectoryMeasurementResult(
            trajectoryPoints: samplePoints,
            averageError: 50.0,
            maxError: 120.0,
            minError: 10.0,
            totalDuration: 30.0,
            coveragePercentage: 0.8,
            trajectoryType: .figure8
        )
        
        TrajectoryComparisonView(
            trajectoryResults: sampleResult,
            screenSize: CGSize(width: 400, height: 800),
            showVisualization: .constant(true)
        )
    }
}
#endif