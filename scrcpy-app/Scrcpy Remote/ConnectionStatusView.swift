//
//  ConnectionStatusView.swift
//  Scrcpy Remote
//
//  Created by Ethan on 1/1/25.
//

import SwiftUI

struct ConnectionStatusView: View {
    let session: ScrcpySession
    let connectionStatus: ScrcpyStatus
    let statusMessage: String?
    let onCancel: () -> Void
    
    @ObservedObject private var connectionManager = SessionConnectionManager.shared
    
    @State private var animationPhase: Int = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var glowOpacity: Double = 0.3
    @State private var breathingScale: CGFloat = 1.0
    
    // 使用 State 来控制 Timer 的生命周期
    @State private var isTimerActive: Bool = true
    
    // 添加状态跟踪，用于检测状态变化
    @State private var previousConnectionStatus: ScrcpyStatus?
    
    // 新增：动画重置控制
    @State private var animationResetTrigger: Bool = false
    @State private var currentIconName: String = ""
    @State private var currentIconColor: Color = .gray
    
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient
            
            // 主要内容
            VStack(spacing: 10) {
                Spacer()

                // 顶部设备信息
                deviceInfoSection
                
                Spacer()
                
                // 连接状态动画区域
                connectionAnimationSection
                
                // 连接过程状态
                connectionProgressSection
                
                Spacer()
                Spacer()

                // 取消按钮
                cancelButton
                
                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 50)
        }
        .ignoresSafeArea()
        .onReceive(timer) { _ in
            // 只有在 Timer 激活且视图仍然需要时才更新动画
            if isTimerActive && shouldContinueAnimating {
                updateAnimations()
            }
        }
        .onAppear {
            // 视图出现时激活 Timer
            isTimerActive = true
            // 初始化动画状态
            resetAnimationState()
            previousConnectionStatus = connectionStatus
            currentIconName = connectionStatusIcon
            currentIconColor = connectionStatusColor
            print("🎭 [ConnectionStatusView] View appeared for session: \(displaySession.title)")
        }
        .onDisappear {
            // 视图消失时停止 Timer 和动画
            isTimerActive = false
            print("🎭 [ConnectionStatusView] View disappeared for session: \(displaySession.title)")
        }
        .onChange(of: connectionStatus) { newStatus in
            // 检测状态变化
            if let previousStatus = previousConnectionStatus, previousStatus != newStatus {
                print("🔄 [ConnectionStatusView] Status changed from \(previousStatus.description) to \(newStatus.description)")
                
                // 获取新的图标信息
                let newIconName = connectionStatusIcon
                let newIconColor = connectionStatusColor
                
                // 只有当图标类型真正发生变化时才重置动画
                let iconTypeChanged = currentIconName != newIconName
                
                if iconTypeChanged {
                    print("🎭 [ConnectionStatusView] Icon type changed from \(currentIconName) to \(newIconName), resetting animation")
                    
                    // 重置动画状态
                    resetAnimationState()
                    
                    // 触发动画重置
                    animationResetTrigger.toggle()
                    
                    // 短暂延迟后重新开始动画（如果需要）
                    if shouldContinueAnimating {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTimerActive = true
                        }
                    }
                } else {
                    print("🎭 [ConnectionStatusView] Icon type unchanged (\(currentIconName)), keeping animation smooth")
                }
                
                // 更新当前图标信息
                currentIconName = newIconName
                currentIconColor = newIconColor
            }
            
            // 更新前一个状态
            previousConnectionStatus = newStatus
            
            // 当连接成功时，准备停止动画
            if newStatus.isFullyConnected {
                print("✅ [ConnectionStatusView] Connection successful, preparing to stop animations")
                // 延迟停止 Timer，给用户一个短暂的视觉反馈
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTimerActive = false
                    print("⏹️ [ConnectionStatusView] Stopped animations after successful connection")
                }
            } else if newStatus == ScrcpyStatusConnectingFailed {
                // 连接失败时，保持动画一段时间让用户看到错误信息
                print("❌ [ConnectionStatusView] Connection failed, keeping animations for error visibility")
                // 延迟停止动画，给用户时间看到错误信息
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    isTimerActive = false
                    print("⏹️ [ConnectionStatusView] Stopped animations after connection failure")
                }
            }
        }
    }
    
    // MARK: - Animation Reset Function
    private func resetAnimationState() {
        withAnimation(.easeInOut(duration: 0.2)) {
            pulseScale = 1.0
            breathingScale = 1.0
            rotationAngle = 0
            glowOpacity = 0.3
        }
        animationPhase = 0
        print("🔄 [ConnectionStatusView] Animation state reset")
    }
    
    // MARK: - Computed Properties
    
    /// 获取要显示的会话信息（优先使用connectingSession，如果没有则使用传入的session）
    private var displaySession: ScrcpySession {
        if let connectingSessionModel = connectionManager.connectingSession {
            return ScrcpySession(sessionModel: connectingSessionModel)
        }
        return session
    }
    
    /// 判断是否应该继续运行动画
    private var shouldContinueAnimating: Bool {
        // 只有在连接中或连接失败时才继续动画
        // 连接失败时也继续动画，给用户时间看到错误信息
        return connectionStatus.isConnecting
    }
    
    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        ZStack {
            // 主背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color.black
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // 简化的动态光效 - 只在动画激活时显示
            if isTimerActive && shouldContinueAnimating {
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.05),
                        Color.clear
                    ]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 300
                )
                .scaleEffect(pulseScale)
                .opacity(glowOpacity)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: pulseScale)
            }
        }
    }
    
    // MARK: - Device Info Section
    private var deviceInfoSection: some View {
        VStack(spacing: 15) {
            // 设备图标
            deviceTypeIcon
            
            // 设备名称
            Text(displaySession.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Tailscale 连接指示器
            if displaySession.sessionModel.useTailscale {
                tailscaleIndicator
            }
        }
    }
    
    // MARK: - Device Type Icon
    private var deviceTypeIcon: some View {
        let iconName: String
        let iconColor: Color
        
        switch displaySession.deviceType {
        case "adb":
            iconName = "android-large"
            iconColor = .green
        case "vnc":
            iconName = "vnc-large"
            iconColor = .blue
        default:
            iconName = "questionmark.circle"
            iconColor = .gray
        }
        
        return Image(iconName)
            .resizable()
            .scaledToFit()
            .frame(width: 40, height: 40)
            .foregroundColor(.white)
            .colorMultiply(.white)
            .background(
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 60, height: 60)
            )
            .overlay(
                Circle()
                    .stroke(iconColor.opacity(0.4), lineWidth: 1)
                    .frame(width: 60, height: 60)
            )
    }
    
    // MARK: - Tailscale Indicator
    private var tailscaleIndicator: some View {
        HStack(spacing: 6) {
            // Tailscale 图标
            Image(systemName: "network")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
            
            Text("Tailscale")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Connection Animation Section
    private var connectionAnimationSection: some View {
        VStack(spacing: 10) {
            // 主连接动画 - 固定高度区域
            ZStack {
                // 外层圆环 - 只在连接中时显示
                if isTimerActive && shouldContinueAnimating && connectionStatus.isConnecting {
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 3)
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulseScale)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseScale)
                }
                
                // 内层光晕圆 - 连接中时显示
                if isTimerActive && shouldContinueAnimating && connectionStatus.isConnecting {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 60, height: 60)
                        .scaleEffect(breathingScale)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: breathingScale)
                }
                
                // 中心图标 - 连接中显示圆点，连接成功显示对勾
                if connectionStatus.isConnecting {
                    // 连接中显示柔和的圆点
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 20, height: 20)
                        .scaleEffect(breathingScale)
                        .opacity(glowOpacity)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: breathingScale)
                        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: glowOpacity)
                } else {
                    // 连接成功或失败显示对应图标
                    Image(systemName: currentIconName)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(currentIconColor)
                        .scaleEffect(connectionStatus.isFullyConnected ? 1.2 : 1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: connectionStatus.isFullyConnected)
                }
            }
            .frame(height: 100) // 固定动画区域高度
        }
    }
    
    // MARK: - Connection Progress Section
    private var connectionProgressSection: some View {
        VStack(spacing: 10) {
            // 当前状态消息 - 固定高度区域
            if let message = statusMessage, !message.isEmpty {
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .frame(minHeight: 60) // 设置最小高度
                    .frame(maxWidth: .infinity) // 确保宽度一致
                    .onAppear {
                        print("🔍 [ConnectionStatusView] Displaying specific status message: \(message)")
                    }
            } else if connectionStatus == ScrcpyStatusConnectingFailed {
                // 连接失败时，即使没有具体错误消息，也显示连接失败的提示
                Text("Connection failed. Please check your network settings and try again.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .frame(minHeight: 60) // 设置最小高度
                    .frame(maxWidth: .infinity) // 确保宽度一致
                    .onAppear {
                        print("🔍 [ConnectionStatusView] Displaying fallback error message (statusMessage is nil or empty)")
                    }
            } else {
                // 其他状态的默认状态消息 - 固定高度区域
                Text(defaultStatusMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .frame(minHeight: 60) // 设置最小高度
                    .frame(maxWidth: .infinity) // 确保宽度一致
                    .onAppear {
                        print("🔍 [ConnectionStatusView] Displaying default status message: \(defaultStatusMessage)")
                    }
            }
        }
    }
    
    // MARK: - Cancel Button
    private var cancelButton: some View {
        Button(action: onCancel) {
            HStack(spacing: 8) {
                Image(systemName: connectionStatus == ScrcpyStatusConnectingFailed ? "xmark.circle" : "xmark.circle.fill")
                    .font(.system(size: 16))
                Text(connectionStatus == ScrcpyStatusConnectingFailed ? "Dismiss" : "Cancel Connection")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.3))
            .cornerRadius(25)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Computed Properties
    private var connectionStatusIcon: String {
        switch connectionStatus {
        case ScrcpyStatusConnecting, ScrcpyStatusADBConnected:
            return "inset.filled.circle"
        case ScrcpyStatusConnected, ScrcpyStatusSDLWindowCreated, ScrcpyStatusSDLWindowAppeared:
            return "checkmark.circle.fill"
        case ScrcpyStatusConnectingFailed:
            return "xmark.circle.fill"
        default:
            return "inset.filled.circle"
        }
    }
    
    private var connectionStatusColor: Color {
        switch connectionStatus {
        case ScrcpyStatusConnecting, ScrcpyStatusADBConnected:
            return .blue
        case ScrcpyStatusConnected, ScrcpyStatusSDLWindowCreated, ScrcpyStatusSDLWindowAppeared:
            return .green
        case ScrcpyStatusConnectingFailed:
            return .red
        default:
            return .gray
        }
    }
    
    private var connectionStatusText: String {
        switch connectionStatus {
        case ScrcpyStatusConnecting:
            return "Initializing Connection"
        case ScrcpyStatusADBConnected:
            return "ADB Connected"
        case ScrcpyStatusSDLWindowCreated:
            return "Creating Display Window"
        case ScrcpyStatusConnected, ScrcpyStatusSDLWindowAppeared:
            return "Connected Successfully"
        case ScrcpyStatusConnectingFailed:
            return "Connection Failed"
        default:
            return "Preparing Connection"
        }
    }
    
    private var defaultStatusMessage: String {
        switch connectionStatus {
        case ScrcpyStatusConnecting:
            return String(format: NSLocalizedString("Establishing network connection to %@", comment: "Connecting status"),
                          "\(displaySession.sessionModel.hostReal):\(displaySession.sessionModel.port)")
        case ScrcpyStatusADBConnected:
            return NSLocalizedString("ADB protocol connection established successfully", comment: "")
        case ScrcpyStatusSDLWindowCreated:
            return NSLocalizedString("Creating display window for remote screen", comment: "")
        case ScrcpyStatusConnected, ScrcpyStatusSDLWindowAppeared:
            return NSLocalizedString("Connection established successfully", comment: "")
        case ScrcpyStatusConnectingFailed:
            return NSLocalizedString("Failed to establish connection", comment: "")
        default:
            return NSLocalizedString("Preparing connection...", comment: "")
        }
    }
    
    
    // MARK: - Animation Updates
    private func updateAnimations() {
        // 只有在 Timer 激活且需要继续动画时才更新
        guard isTimerActive && shouldContinueAnimating else { 
            // 如果不需要动画，确保状态重置
            if !shouldContinueAnimating {
                resetAnimationState()
            }
            return 
        }
        
        animationPhase = (animationPhase + 1) % 100
        
        // 更新外层脉冲环动画 - 较慢的节奏
        if animationPhase % 30 == 0 {
            withAnimation(.easeInOut(duration: 2)) {
                pulseScale = pulseScale == 1.0 ? 1.15 : 1.0
            }
        }
        
        // 更新内层呼吸灯动画 - 中等节奏
        if connectionStatus.isConnecting && animationPhase % 20 == 0 {
            withAnimation(.easeInOut(duration: 1.5)) {
                breathingScale = breathingScale == 1.0 ? 1.3 : 1.0
            }
        }
        
        // 更新中心圆点透明度 - 较快的节奏，营造柔和的呼吸效果
        if connectionStatus.isConnecting && animationPhase % 12 == 0 {
            withAnimation(.easeInOut(duration: 1.2)) {
                glowOpacity = glowOpacity == 0.3 ? 0.9 : 0.3
            }
        }
    }
}


// MARK: - Preview
struct ConnectionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionStatusView(
            session: ScrcpySession(sessionModel: ScrcpySessionModel(host: "test.example.com", port: "5555", sessionName: "Test Device")),
            connectionStatus: ScrcpyStatusConnecting,
            statusMessage: "Establishing network connection...",
            onCancel: {}
        )
    }
} 
