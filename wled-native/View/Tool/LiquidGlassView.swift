import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

/// A view that provides liquid glass / frosted glass effects with backwards compatibility
struct LiquidGlassView: NSViewRepresentable {
    let material: Material
    let blendingMode: BlendingMode
    let isEmphasized: Bool
    
    enum Material {
        case titlebar
        case selection
        case menu
        case popover
        case sidebar
        case headerView
        case sheet
        case windowBackground
        case hudWindow
        case fullScreenUI
        case toolTip
        case contentBackground
        case underWindowBackground
        case underPageBackground
        
        @available(macOS 10.14, *)
        var nsMaterial: NSVisualEffectView.Material {
            switch self {
            case .titlebar: return .titlebar
            case .selection: return .selection
            case .menu: return .menu
            case .popover: return .popover
            case .sidebar: return .sidebar
            case .headerView: return .headerView
            case .sheet: return .sheet
            case .windowBackground: return .windowBackground
            case .hudWindow: return .hudWindow
            case .fullScreenUI: return .fullScreenUI
            case .toolTip: return .toolTip
            case .contentBackground: return .contentBackground
            case .underWindowBackground: return .underWindowBackground
            case .underPageBackground: return .underPageBackground
            }
        }
    }
    
    enum BlendingMode {
        case behindWindow
        case withinWindow
        
        var nsBlendingMode: NSVisualEffectView.BlendingMode {
            switch self {
            case .behindWindow: return .behindWindow
            case .withinWindow: return .withinWindow
            }
        }
    }
    
    init(material: Material = .underWindowBackground, blendingMode: BlendingMode = .behindWindow, isEmphasized: Bool = false) {
        self.material = material
        self.blendingMode = blendingMode
        self.isEmphasized = isEmphasized
    }
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        
        if #available(macOS 10.14, *) {
            view.material = material.nsMaterial
        } else {
            // Fallback for older macOS versions
            view.material = .light
        }
        
        view.blendingMode = blendingMode.nsBlendingMode
        view.state = .active
        view.isEmphasized = isEmphasized
        
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        if #available(macOS 10.14, *) {
            nsView.material = material.nsMaterial
        }
        nsView.blendingMode = blendingMode.nsBlendingMode
        nsView.isEmphasized = isEmphasized
    }
}

/// SwiftUI modifier to add liquid glass background with backwards compatibility
struct LiquidGlassBackground: ViewModifier {
    let material: LiquidGlassView.Material
    let blendingMode: LiquidGlassView.BlendingMode
    let isEmphasized: Bool
    
    func body(content: Content) -> some View {
        content
            .background {
                LiquidGlassView(
                    material: material,
                    blendingMode: blendingMode,
                    isEmphasized: isEmphasized
                )
            }
    }
}

extension View {
    /// Adds a liquid glass background effect with backwards compatibility
    func liquidGlass(
        material: LiquidGlassView.Material = .underWindowBackground,
        blendingMode: LiquidGlassView.BlendingMode = .behindWindow,
        isEmphasized: Bool = false
    ) -> some View {
        modifier(LiquidGlassBackground(
            material: material,
            blendingMode: blendingMode,
            isEmphasized: isEmphasized
        ))
    }
    
    /// Adds a subtle content background glass effect
    func contentGlass() -> some View {
        liquidGlass(material: .contentBackground, blendingMode: .withinWindow)
    }
    
    /// Adds a sidebar glass effect
    func sidebarGlass() -> some View {
        liquidGlass(material: .sidebar, blendingMode: .withinWindow, isEmphasized: true)
    }
    
    /// Adds a sheet/modal glass effect
    func sheetGlass() -> some View {
        liquidGlass(material: .sheet, blendingMode: .withinWindow)
    }
}
