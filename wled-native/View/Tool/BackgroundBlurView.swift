import Foundation
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

/// Legacy BackgroundBlurView - now uses LiquidGlassView for better effects
struct BackgroundBlurView: View {
    let material: LiquidGlassView.Material
    let blendingMode: LiquidGlassView.BlendingMode
    
    init(
        material: LiquidGlassView.Material = .underWindowBackground,
        blendingMode: LiquidGlassView.BlendingMode = .behindWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }
    
    var body: some View {
        LiquidGlassView(material: material, blendingMode: blendingMode)
    }
}
