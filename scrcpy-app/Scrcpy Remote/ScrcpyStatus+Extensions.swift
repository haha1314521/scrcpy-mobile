//
//  ScrcpyStatus+Extensions.swift
//  Scrcpy Remote
//
//  Created by Ethan on 1/1/25.
//

import Foundation

// MARK: - ScrcpyStatus Extensions
extension ScrcpyStatus {
    
    /// 检查连接状态是否为活跃状态
    /// 活跃状态包括：正在连接、已连接、以及其他非断开状态
    var isActive: Bool {
        switch self {
        case ScrcpyStatusDisconnected:
            return false
        case ScrcpyStatusConnectingFailed:
            return false
        default:
            return true
        }
    }
    
    /// 检查连接状态是否为完全连接状态
    var isFullyConnected: Bool {
        switch self {
        case ScrcpyStatusSDLWindowCreated:
            return true
        case ScrcpyStatusSDLWindowAppeared:
            return true
        case ScrcpyStatusConnected:
            return true
        default:
            return false
        }
    }
    
    /// 检查连接状态是否正在连接中
    var isConnecting: Bool {
        switch self {
        case ScrcpyStatusConnecting:
            return true
        case ScrcpyStatusADBConnected:
            return true
        case ScrcpyStatusSDLWindowCreated:
            return true
        default:
            return false
        }
    }
    
    /// 获取状态的描述文本
    var description: String {
        switch self {
        case ScrcpyStatusDisconnected:
            return NSLocalizedString("Disconnected", comment: "")
        case ScrcpyStatusConnecting:
            return NSLocalizedString("Connecting", comment: "")
        case ScrcpyStatusADBConnected:
            return NSLocalizedString("ADB Connected", comment: "")
        case ScrcpyStatusConnected:
            return NSLocalizedString("Connected", comment: "")
        case ScrcpyStatusSDLWindowCreated:
            return NSLocalizedString("Window Created", comment: "")
        case ScrcpyStatusSDLWindowAppeared:
            return NSLocalizedString("Connected", comment: "")
        case ScrcpyStatusConnectingFailed:
            return NSLocalizedString("Connection Failed", comment: "")
        default:
            return "Unknown (\(self.rawValue))"
        }
    }
}

// MARK: - iOS 14 compatibility shims
// The UI below was written against iOS 15 SwiftUI APIs; these wrappers keep the
// original behavior on iOS 15+ and degrade gracefully on iOS 14.

import SwiftUI

enum CompatVerticalEdge {
    case top, bottom
}

enum CompatControlSize {
    case mini, small, regular, large

    @available(iOS 15.0, *)
    var native: ControlSize {
        switch self {
        case .mini: return .mini
        case .small: return .small
        case .regular: return .regular
        case .large: return .large
        }
    }
}

extension View {
    @ViewBuilder func compatTextSelection() -> some View {
        if #available(iOS 15.0, *) { self.textSelection(.enabled) } else { self }
    }

    @ViewBuilder func compatButtonStyleBorderedProminent() -> some View {
        if #available(iOS 15.0, *) { self.buttonStyle(.borderedProminent) } else { self }
    }

    @ViewBuilder func compatButtonStyleBordered() -> some View {
        if #available(iOS 15.0, *) { self.buttonStyle(.bordered) } else { self }
    }

    @ViewBuilder func compatControlSize(_ size: CompatControlSize) -> some View {
        if #available(iOS 15.0, *) { self.controlSize(size.native) } else { self }
    }

    @ViewBuilder func compatRefreshable(action: @escaping () async -> Void) -> some View {
        if #available(iOS 15.0, *) {
            self.refreshable { await action() }
        } else { self }
    }

    @ViewBuilder func compatListRowSeparatorHidden() -> some View {
        if #available(iOS 15.0, *) { self.listRowSeparator(.hidden) } else { self }
    }

    @ViewBuilder func compatForegroundStyle(_ color: Color) -> some View {
        self.foregroundColor(color)
    }

    @ViewBuilder func compatSafeAreaInset<C: View>(edge: CompatVerticalEdge, @ViewBuilder content: @escaping () -> C) -> some View {
        if #available(iOS 15.0, *) {
            self.safeAreaInset(edge: edge == .top ? VerticalEdge.top : VerticalEdge.bottom,
                               alignment: .center, spacing: nil) { content() }
        } else if edge == .top {
            self.overlay(VStack(spacing: 0) { content(); Spacer() })
        } else {
            self.overlay(VStack(spacing: 0) { Spacer(); content() })
        }
    }

    /// iOS 15 style `.alert(_:isPresented:actions:message:)` replacement built on
    /// the iOS 14 `Alert` API. Supports one or two buttons.
    @ViewBuilder func compatAlert(_ title: String,
                                  isPresented: Binding<Bool>,
                                  message: String? = nil,
                                  primaryLabel: String = "OK",
                                  primaryIsDestructive: Bool = false,
                                  primaryAction: (() -> Void)? = nil,
                                  cancelLabel: String? = nil,
                                  cancelAction: (() -> Void)? = nil) -> some View {
        self.alert(isPresented: isPresented) {
            // Text(String) 那个重载不做本地化, 必须包成 LocalizedStringKey,
            // 否则标题和按钮永远是英文(实测: 弹窗标题一直显示 Validation Error)。
            let messageText = message.map { Text(LocalizedStringKey($0)) }

            // iOS 14 下 sheet 里的 .alert(isPresented:) 有时点了按钮不会把绑定置回 false,
            // 表现就是"弹窗关不掉"。这里在每个按钮里显式关一次。
            let dismiss = { isPresented.wrappedValue = false }

            let primary: Alert.Button = primaryIsDestructive
                ? .destructive(Text(LocalizedStringKey(primaryLabel))) { dismiss(); primaryAction?() }
                : .default(Text(LocalizedStringKey(primaryLabel))) { dismiss(); primaryAction?() }

            if let cancelLabel = cancelLabel {
                return Alert(title: Text(LocalizedStringKey(title)), message: messageText,
                             primaryButton: primary,
                             secondaryButton: .cancel(Text(LocalizedStringKey(cancelLabel))) { dismiss(); cancelAction?() })
            }
            return Alert(title: Text(LocalizedStringKey(title)), message: messageText, dismissButton: primary)
        }
    }
}

/// iOS 15 `Button(_:role:action:)` replacement.
func CompatButton(_ title: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
    Group {
        if #available(iOS 15.0, *) {
            Button(title, role: destructive ? .destructive : nil, action: action)
        } else {
            Button(action: action) {
                Text(title).foregroundColor(destructive ? .red : nil)
            }
        }
    }
}

extension Color {
    /// `Color.cyan` requires iOS 15; same RGB value on all systems.
    static var compatCyan: Color { Color(red: 0.333, green: 0.784, blue: 0.980) }
}

/// `@Environment(\.dismiss)` replacement usable from iOS 14.
struct CompatDismiss: DynamicProperty {
    @Environment(\.presentationMode) private var presentationMode

    func callAsFunction() {
        presentationMode.wrappedValue.dismiss()
    }
}
