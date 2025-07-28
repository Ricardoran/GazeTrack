import SwiftUI

enum EyeTrackingMethod: CaseIterable {
    case dualEyesHitTest       // Binocular calculation + hitTest
    case lookAtPointMatrix     // lookAtPoint + matrix transform (main gaze track method)
    case lookAtPointHitTest    // lookAtPoint + hitTest
    
    var displayName: String {
        switch self {
        case .dualEyesHitTest:
            return "Binocular + HitTest"
        case .lookAtPointMatrix:
            return "LookAt + Matrix"
        case .lookAtPointHitTest:
            return "LookAt + HitTest"
        }
    }
    
    var shortName: String {
        switch self {
        case .dualEyesHitTest:
            return "D+H"
        case .lookAtPointMatrix:
            return "L+M"
        case .lookAtPointHitTest:
            return "L+H"
        }
    }
    
    var color: Color {
        switch self {
        case .dualEyesHitTest:
            return .orange
        case .lookAtPointMatrix:
            return .blue
        case .lookAtPointHitTest:
            return .purple
        }
    }
}

struct GazeTrackLabView: View {
    @Binding var currentView: AppView
    @StateObject private var labManager = GazeTrackLabManager()
    @StateObject private var uiManager = UIManager()
    @State private var smoothingWindowSize: Int = 10 // Default 10-point window
    @State private var currentMethod: EyeTrackingMethod = .lookAtPointMatrix // Current tracking method
    @State private var showGrid: Bool = false // Whether to show grid overlay
    
    var body: some View {
        ZStack {
            // AR View Container
            GazeTrackLabARViewContainer(manager: labManager, smoothingWindowSize: $smoothingWindowSize, trackingMethod: $currentMethod)
                .ignoresSafeArea()
                .onTapGesture {
                    uiManager.showButtons = true
                    uiManager.resetButtonHideTimer()
                }
            
            VStack {
                // Top controls
                HStack {
                    BackButton(action: {
                        currentView = .landing
                    })
                    
                    Spacer()
                    
                    // Method switching button (original title position)
                    Button(action: {
                        // Cycle to next method
                        let allMethods = EyeTrackingMethod.allCases
                        if let currentIndex = allMethods.firstIndex(of: currentMethod) {
                            let nextIndex = (currentIndex + 1) % allMethods.count
                            currentMethod = allMethods[nextIndex]
                        }
                        uiManager.resetButtonHideTimer()
                    }) {
                        VStack(spacing: 2) {
                            Text("Gaze Track Lab")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(currentMethod.displayName)
                                .font(.caption)
                                .foregroundColor(currentMethod.color)
                        }
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(10)
                    }
                    
                    Spacer()
                    
                    // Grid toggle button
                    UnifiedButton(
                        action: {
                            showGrid.toggle()
                            uiManager.resetButtonHideTimer()
                        },
                        icon: showGrid ? "grid.circle.fill" : "grid.circle",
                        backgroundColor: Color.black.opacity(0.6),
                        style: .large
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .opacity(uiManager.showButtons ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: uiManager.showButtons)
                
                Spacer()
                
                // Simplified smoothing control slider
                HStack {
                    Text("Response")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Slider(value: Binding(
                        get: { Double(smoothingWindowSize) },
                        set: { 
                            smoothingWindowSize = Int($0)
                            labManager.updateSmoothingWindowSize(smoothingWindowSize)
                        }
                    ), in: 0.0...50.0, step: 1.0, onEditingChanged: { editing in
                        if editing {
                            uiManager.resetButtonHideTimer()
                        }
                    })
                    .accentColor(.green)
                    
                    Text("\(smoothingWindowSize)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                        .frame(minWidth: 20)
                    
                    Text("Stability")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .opacity(uiManager.showButtons ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: uiManager.showButtons)
                
                // Distance display component
                EyeToScreenDistanceView(distance: labManager.currentEyeToScreenDistance)
                    .padding()
                    .opacity(uiManager.showButtons ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: uiManager.showButtons)
            }
            
            // Grid overlay - use conditional rendering to ensure complete cleanup
            Group {
                if showGrid {
                    GridOverlayView()
                        .allowsHitTesting(false) // Don't block AR view interactions
                        .id("grid-overlay") // Force recreation
                }
            }
            
            // Average gaze indicator only
            if labManager.isTracking {
                GeometryReader { geometry in
                    // Use gaze point coordinates directly, no need to add safe area offset
                    // This maintains consistency with original gaze track display
                    Circle()
                        .fill(currentMethod.color.opacity(0.8))
                        .frame(width: 25, height: 25)
                        .position(x: labManager.averageGaze.x, y: labManager.averageGaze.y)
                }
            }
        }
        .onAppear {
            ARSessionCoordinator.shared.requestSession(for: .gazeTrackLab, viewID: "GazeTrackLabView")
            labManager.startTracking()
            // Set initial window size
            labManager.updateSmoothingWindowSize(smoothingWindowSize)
            // Start UI auto-hide timer
            uiManager.showButtons = true
            uiManager.setupButtonHideTimer()
        }
        .onDisappear {
            // First clean up managers
            labManager.cleanup()
            uiManager.cleanup()
            
            // Reset grid state to prevent affecting other views
            showGrid = false
            
            // Delay AR session release to avoid conflicts during view switching
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                ARSessionCoordinator.shared.releaseSession(for: "GazeTrackLabView")
            }
        }
    }
}

struct GridOverlayView: View {
    let gridLabels = [
        ["A", "B", "C", "D"],
        ["E", "F", "G", "H"],
        ["I", "J", "K", "L"],
        ["M", "N", "O", "P"],
        ["Q", "R", "S", "T"],
        ["U", "V", "W", "X"],
        ["Y", "Z", "#", "@"]
    ]
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let cellWidth = screenWidth / 4
            let cellHeight = screenHeight / 7
            
            ZStack {
                // Draw grid lines
                Path { path in
                    // Vertical lines
                    for i in 1..<4 {
                        let x = CGFloat(i) * cellWidth
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: screenHeight))
                    }
                    
                    // Horizontal lines
                    for i in 1..<7 {
                        let y = CGFloat(i) * cellHeight
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: screenWidth, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                
                // Add labels
                ForEach(0..<7, id: \.self) { row in
                    ForEach(0..<4, id: \.self) { col in
                        let label = gridLabels[row][col]
                        let x = CGFloat(col) * cellWidth + cellWidth/2
                        let y = CGFloat(row) * cellHeight + cellHeight/2
                        
                        Text(label)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.7))
                            .position(x: x, y: y)
                    }
                }
            }
        }
        .allowsHitTesting(false) // Ensure GridOverlayView doesn't receive any touch events
        .contentShape(Rectangle().size(.zero)) // Explicitly set content shape to zero size
    }
}

#if DEBUG
struct GazeTrackLabView_Previews: PreviewProvider {
    static var previews: some View {
        GazeTrackLabView(currentView: .constant(.gazeTrackLab))
    }
}
#endif
