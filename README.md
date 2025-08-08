# WLED-Native-macOS

A native macOS app for discovering and controlling your WLED devices with a beautiful desktop interface! This is a complete macOS conversion of the original iOS app, redesigned specifically for desktop use with modern macOS features.

## ✨ What's New in macOS Version

This macOS version is a complete rewrite of the original iOS app with significant enhancements:

- **🖥️ Desktop-Native Interface**: Built specifically for macOS with proper window management and desktop layouts
- **✨ Liquid Glass Effects**: Modern translucent visual effects using NSVisualEffectView throughout the interface
- **📱➡️💻 Platform Conversion**: Complete migration from iOS UIKit to macOS AppKit APIs
- **🗂️ Split-View Navigation**: Desktop-optimized NavigationSplitView perfect for larger screens  
- **🌍 Expanded Localization**: Now supports 8 languages (up from 2 in original iOS version)
- **⚙️ Native Settings Panel**: macOS-style preferences accessible via ⌘, shortcut
- **⌨️ Keyboard Shortcuts**: Full keyboard navigation and shortcuts (⌘⇧D for device discovery)
- **🪟 Proper Window Management**: Resizable windows with sensible defaults (1200x800)

## 🚀 Features

- **🔍 Automatic Device Detection**: Seamless mDNS/Bonjour discovery of WLED devices on your network
- **📱 Device Management**: Custom names, hide/delete devices, organize your lighting setup  
- **📋 Unified Device List**: All your WLED lights accessible from one convenient sidebar
- **🌐 Full WLED Control**: Access complete WLED web interface for each device
- **🎨 Modern UI**: Beautiful liquid glass effects and native macOS design patterns
- **🌍 Multi-Language Support**: Available in 8 languages with automatic system language detection
- **⚡ Performance**: Built with SwiftUI and native macOS frameworks for optimal performance

## 🛠️ Getting Started

### Requirements
- macOS 13.0 or later
- Xcode 15.0 or later (for building from source)
- WLED devices on your local network

### Building from Source
```bash
git clone https://github.com/Moustachauve/WLED-Native-iOS.git
cd WLED-Native-iOS
xcodebuild -project wled-native.xcodeproj -scheme wled-native -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
```

The built app will be available in the Xcode DerivedData directory. For distribution, you'll need to configure proper code signing.

## 📱 Using the App

**🔍 Device Discovery**: The app automatically scans your network for WLED devices using mDNS/Bonjour. Discovered devices appear in the sidebar.

**🎛️ Device Control**: Click any device in the sidebar to view its web interface in the main panel. All WLED features are accessible through the embedded web view.

**⚙️ Device Management**: Right-click devices to rename, hide, or remove them from your list.

**🔧 Settings**: Access preferences via the menu bar (WLED Native → Settings) or press ⌘, to configure app behavior.

**⌨️ Keyboard Shortcuts**: 
- `⌘⇧D` - Trigger device discovery
- `⌘,` - Open Settings

## 🌍 Localization

The app is fully localized in 8 languages:
- **English** (en) - Default
- **French** (fr) - Universal French
- **Dutch** (nl) - Netherlands Dutch
- **German** (de) - Standard German
- **Chinese Simplified** (zh-Hans) - Mainland China
- **Chinese Traditional** (zh-Hant) - Taiwan/Hong Kong
- **Spanish** (es) - International Spanish
- **Portuguese** (pt) - International Portuguese

The app automatically uses your system language if supported, or falls back to English.

## 🔧 Technical Details

### Architecture
- **Framework**: SwiftUI with AppKit integration for macOS-specific features
- **Platform APIs**: Native macOS APIs (NSViewRepresentable, NSAlert, NSWorkspace, NSVisualEffectView)
- **Networking**: URLSession for HTTP requests, WebKit for device interfaces, Network framework for mDNS discovery
- **Data Persistence**: Core Data for device storage and user preferences
- **Visual Effects**: NSVisualEffectView for liquid glass effects with backwards compatibility

### Key Components Converted from iOS
- **WebView**: `UIViewRepresentable` → `NSViewRepresentable` 
- **Alerts**: `UIAlert` → `NSAlert`
- **Images**: `UIImage` → `NSImage`
- **Navigation**: Mobile navigation → `NavigationSplitView` for desktop
- **Modals**: `fullScreenCover` → `sheet` for proper macOS presentation

## 💻 About WLED

This application is made to connect and control devices using [WLED](https://github.com/Aircoookie/WLED).  
Read the full documentation of [WLED here!](https://kno.wled.ge/)

## 🙏 Credits

This macOS app is based on the excellent [WLED-Native-iOS](https://github.com/Moustachauve/WLED-Native-iOS) app created by **Christophe Gagnier (@Moustachauve)**. 

### What We Built Upon
- ✅ **Core Architecture**: Device discovery, Core Data models, and basic SwiftUI structure
- ✅ **WLED Integration**: HTTP API communication and WebKit integration
- ✅ **Foundation**: Solid codebase that made this macOS conversion possible

### What We Added for macOS
- 🆕 **Complete Platform Migration**: iOS UIKit → macOS AppKit
- 🆕 **Desktop UI Patterns**: NavigationSplitView, proper window management, Settings panel
- 🆕 **Liquid Glass Effects**: Modern NSVisualEffectView integration throughout
- 🆕 **Expanded Internationalization**: 8 languages (up from 2)
- 🆕 **macOS-Specific Features**: Keyboard shortcuts, native alerts, system integration

**Huge thanks** to Christophe for creating such a solid foundation and for open-sourcing the project. This macOS version builds upon his excellent work while adding significant desktop-specific enhancements and modern macOS design patterns.
