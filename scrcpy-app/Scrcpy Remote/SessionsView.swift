//
//  SessionsView.swift
//  Scrcpy Remote
//
//  Created by Ethan on 12/8/24.
//

import SwiftUI
import Network

// MARK: - iOS 14 local network activation primer
// On iOS 14, raw BSD sockets to LAN addresses fail with EHOSTUNREACH until the
// local-network permission is "activated" for this process by a high-level
// networking API (Network.framework / CFNetwork). The latency testers use raw
// sockets, so prime the activation once per launch before the first test.
enum LocalNetworkPrimer {
    private static var primed = false

    static func prime(host: String, port: UInt16, completion: @escaping () -> Void) {
        guard !primed else { completion(); return }
        let connection = NWConnection(host: NWEndpoint.Host(host),
                                      port: NWEndpoint.Port(rawValue: port) ?? 5555,
                                      using: .tcp)
        var finished = false
        let finish: () -> Void = {
            guard !finished else { return }
            finished = true
            primed = true
            connection.cancel()
            DispatchQueue.main.async { completion() }
        }
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready, .failed:
                finish()
            default:
                break
            }
        }
        connection.start(queue: .global())
        // Never block testing for long even if the connection hangs
        DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { finish() }
    }
}

struct ScrcpySession: Codable, Identifiable {
    var id: UUID {
        sessionModel.id
    }
    var title: String {
        if !sessionModel.sessionName.isEmpty {
            return sessionModel.sessionName
        } else {
            return "\(sessionModel.hostReal):\(sessionModel.port)"
        }
    }
    var imageName: String = ""
    var deviceType: String {
        sessionModel.deviceType.rawValue
    }
    
    // 根据设备类型获取背景图片名称
    var deviceBackgroundImageName: String {
        return "\(deviceType)-background"
    }
    
    var backgroundColor: LinearGradient {
        // Background color based on UUID to randomize colors
        let colors: [Color] = [.blue, .compatCyan, .orange, .pink, .purple, .red, .yellow]
        // Convert title to fixed int
        let titleNumber = title.unicodeScalars.map { code in
            Int(code.value)
        }.reduce(0, +)
        let index = titleNumber % colors.count
        let color = colors[abs(index)]
        // Gradient for background
        return LinearGradient(gradient: Gradient(colors: [color.opacity(0.9), color.opacity(0.7)]), startPoint: .top, endPoint: .bottom)
    }
    
    // 根据背景颜色计算 Y 轴偏移
    var backgroundImageOffset: CGFloat {
        let colors: [Color] = [.blue, .green, .orange, .pink, .purple, .red, .yellow]
        let titleNumber = title.unicodeScalars.map { code in
            Int(code.value)
        }.reduce(0, +)
        let index = titleNumber % colors.count
        let colorIndex = abs(index)
        
        // 根据颜色索引返回不同的 Y 轴偏移值
        switch colorIndex {
        case 0: return -30  // blue
        case 1: return -50  // cyan
        case 2: return -40    // orange
        case 3: return 10   // pink
        case 4: return 20   // purple
        case 5: return -15  // red
        case 6: return 40   // yellow
        default: return 0
        }
    }
    
    var sessionModel: ScrcpySessionModel = ScrcpySessionModel()
    
    init() {}
    
    init(sessionModel: ScrcpySessionModel) {
        self.sessionModel = sessionModel
    }
}

struct SessionsView: View {
    @Binding var savedSessions: [ScrcpySession]
    var onDeleteSession: ((UUID) -> Void)?
    var onConnectSession: ((ScrcpySession) -> Void)?
    var onEditSession: ((ScrcpySession) -> Void)?
    var onDuplicateSession: ((ScrcpySession) -> Void)?
    
    @State private var testingLatencySessionId: UUID? = nil
    @State private var latencyResults: [UUID: Double] = [:]
    @State private var latencyErrors: [UUID: String] = [:]
    @State private var isRefreshing: Bool = false
    @State private var showingDeleteAlert = false
    @State private var sessionToDelete: ScrcpySession? = nil
    @State private var showingCopyConfirmation = false
    @State private var copiedURLScheme = ""
    
    // 新增状态管理变量
    @State private var hasInitialized: Bool = false
    @State private var lastSessionsHash: Int = 0
    @State private var autoTestEnabled: Bool = true

    var body: some View {
        Group {
            if savedSessions.isEmpty {
                VStack {
                    Image(systemName: "rectangle.on.rectangle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.gray)
                    Text("No Scrcpy Sessions")
                        .font(.title2)
                        .bold()
                        .padding(2)
                    Text("Start a new scrcpy session by tapping the + button.\nSessions will be saved here for quick access.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.init(top: 1, leading: 20, bottom: 1, trailing: 20))
                        .multilineTextAlignment(.center)
                }
            } else {
                List(savedSessions) { session in
                    ZStack {
                        // 背景图片和渐变色的组合
                        ZStack {
                            // 渐变背景色覆盖
                            session.backgroundColor
                                .frame(height: 110)
                            
                            // 设备背景图片
                            Image(session.deviceBackgroundImageName)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 110)
                                .offset(y: session.backgroundImageOffset)
                                .opacity(0.08)
                                .clipped()
                                .compatForegroundStyle(.clear)
                        }
                        .background(Color.clear)
                        .cornerRadius(10)
                        .overlay(
                            // Left top corner: device type icon + title
                            HStack(spacing: 4) {
                                deviceTypeIcon(for: session)
                                Text(session.title)
                                    .font(.headline)
                                    .bold()
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(),
                            alignment: .topLeading
                        )
                        .overlay(
                            // Right bottom corner: device type text + latency test  
                            HStack(spacing: 2) {
                                latencyTestView(for: session)
                            }
                            .padding(),
                            alignment: .topTrailing
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.3), lineWidth: 0)
                        )
                    }
                    .listRowInsets(EdgeInsets())
                    .padding(8)
                    .compatListRowSeparatorHidden()
                    .contextMenu {
                        Button(action: {
                            onConnectSession?(session)
                        }) {
                            Label("Connect Session", systemImage: "play")
                        }
                        Button(action: {
                            onEditSession?(session)
                        }) {
                            Label("Edit Session", systemImage: "pencil")
                        }
                        Button(action: {
                            onDuplicateSession?(createDuplicateSession(from: session))
                        }) {
                            Label("Duplicate Session", systemImage: "doc.on.doc.fill")
                        }
                        Button(action: {
                            // Copy URL scheme to clipboard
                            let urlScheme = "scrcpy2://\(session.sessionModel.id.uuidString)"
                            UIPasteboard.general.string = urlScheme
                            
                            // Show confirmation feedback
                            copiedURLScheme = urlScheme
                            showingCopyConfirmation = true
                        }) {
                            Label("Copy URL Scheme", systemImage: "doc.on.doc")
                        }
                        Button(action: {
                            sessionToDelete = session
                            showingDeleteAlert = true
                        }) {
                            Label("Delete Session", systemImage: "trash")
                        }
                    }
                    .onTapGesture {
                        onConnectSession?(session)
                    }
                }
                .listStyle(.plain)
                .padding(.horizontal, 8)
                .compatSafeAreaInset(edge: .top) {
                    Color.clear.frame(height: 2)
                }
                .compatSafeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 2)
                }
                .ignoresSafeArea(.container, edges: [.leading, .trailing])
                .compatRefreshable {
                    // 手动刷新：重置状态并重新测试所有会话
                    await performManualRefresh()
                }
                .onAppear {
                    // 智能延迟测试：只在首次加载或会话列表发生变化时进行测试
                    let currentSessionsHash = savedSessions.map { $0.id }.hashValue
                    
                    // 检查是否需要触发自动测试
                    let shouldTest = shouldTriggerAutoTest(
                        currentHash: currentSessionsHash,
                        hasInitialized: hasInitialized,
                        autoTestEnabled: autoTestEnabled
                    )
                    
                    if shouldTest {
                        // 执行延迟测试
                        performAutoLatencyTest()
                        
                        // 更新状态
                        hasInitialized = true
                        lastSessionsHash = currentSessionsHash
                    }
                }
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Session"),
                message: Text("Are you sure you want to delete '\(sessionToDelete?.title ?? "")'?\n\nThis action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    if let session = sessionToDelete {
                        // Remove from UI immediately for responsive feedback
                        savedSessions.removeAll { $0.id == session.id }
                        
                        // Then perform the backend deletion
                        onDeleteSession?(session.id)
                        sessionToDelete = nil
                    }
                },
                secondaryButton: .cancel {
                    sessionToDelete = nil
                }
            )
        }
        .compatAlert("URL Scheme Copied", isPresented: $showingCopyConfirmation,
                     message: "URL scheme has been copied to clipboard:\n\n\(copiedURLScheme)",
                     primaryLabel: "OK")
    }
    
    // Create a duplicate session with a new UUID and numbered suffix
    private func createDuplicateSession(from originalSession: ScrcpySession) -> ScrcpySession {
        // Create a new session model based on the original
        var newSessionModel = originalSession.sessionModel
        newSessionModel.id = UUID() // Generate new UUID
        
        // Determine the base name for duplicate detection
        let baseName: String
        if !originalSession.sessionModel.sessionName.isEmpty {
            // Use existing sessionName as base
            baseName = originalSession.sessionModel.sessionName
        } else {
            // Use host:port combination as base name
            baseName = "\(originalSession.sessionModel.hostReal):\(originalSession.sessionModel.port)"
        }
        
        // Find the next available number suffix
        var nextNumber = 2
        
        // Check existing sessions to find the highest number suffix for this base name
        let existingSessions = savedSessions
        
        for session in existingSessions {
            let sessionName = session.sessionModel.sessionName
            let compareBaseName: String
            
            if !sessionName.isEmpty {
                compareBaseName = sessionName
            } else {
                compareBaseName = "\(session.sessionModel.hostReal):\(session.sessionModel.port)"
            }
            
            // Check if this session name starts with our base name
            if compareBaseName.hasPrefix(baseName) {
                // Extract potential number suffix
                if let numberSuffix = extractNumberSuffix(from: compareBaseName, withBase: baseName) {
                    nextNumber = max(nextNumber, numberSuffix + 1)
                }
            }
        }
        
        // Set the new sessionName with number suffix
        if extractNumberSuffix(from: baseName, withBase: baseName) != nil {
            // If the base name already has a number, replace it
            let nameWithoutSuffix = removeNumberSuffix(from: baseName)
            newSessionModel.sessionName = "\(nameWithoutSuffix) \(nextNumber)"
        } else {
            // Add new number suffix to the base name
            newSessionModel.sessionName = "\(baseName) \(nextNumber)"
        }
        
        return ScrcpySession(sessionModel: newSessionModel)
    }
    
    // Extract number suffix from name string, considering the base name
    private func extractNumberSuffix(from name: String, withBase baseName: String) -> Int? {
        // Remove the base name and check what's left
        if name.hasPrefix(baseName) {
            let remainder = String(name.dropFirst(baseName.count)).trimmingCharacters(in: .whitespaces)
            if let number = Int(remainder) {
                return number
            }
        }
        
        // Fallback to the original logic
        let components = name.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
        if let lastComponent = components.last,
           let number = Int(lastComponent),
           components.count > 1 {
            return number
        }
        return nil
    }
    
    // Remove number suffix from name string (e.g., "host 2" returns "host")
    private func removeNumberSuffix(from name: String) -> String {
        let components = name.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
        if components.count > 1,
           let lastComponent = components.last,
           Int(lastComponent) != nil {
            return components.dropLast().joined(separator: " ")
        }
        return name
    }
    
    // Test sessions one by one with a delay between each test
    private func testSessionsSequentially(sessions: [ScrcpySession], index: Int = 0) {
        guard index < sessions.count else { return }
        
        // Check if any latency test is already in progress
        if testingLatencySessionId != nil {
            // Try again after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                testSessionsSequentially(sessions: sessions, index: index)
            }
            return
        }
        
        let session = sessions[index]
        
        // Skip auto-testing for Tailscale sessions
        if !session.sessionModel.useTailscale {
            testLatency(for: session)
        }
        
        // Schedule next test with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            testSessionsSequentially(sessions: sessions, index: index + 1)
        }
    }
    
    @ViewBuilder
    private func latencyTestView(for session: ScrcpySession) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "wifi")
                .foregroundColor(.white)
                .font(.system(size: 12))
            if testingLatencySessionId == session.id {
                // Replace spinner with dots animation
                DotLoadingView()
                    .frame(width: 24, height: 12)
            } else if let latency = latencyResults[session.id] {
                // Show latency result with color and icon based on value
                HStack(spacing: 2) {
                    Text("\(Int(latency))ms")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(latencyColor(for: latency))

                    Image(systemName: latencyIcon(for: latency))
                        .font(.system(size: 8))
                        .foregroundColor(latencyColor(for: latency))
                }
            } else if latencyErrors[session.id] != nil {
                // Show error icon
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.yellow)
                    .font(.system(size: 12))
            } else if session.sessionModel.useTailscale {
                // Show "~" for Tailscale sessions that haven't been tested
                Text("Tailscale")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(5)
        .padding(.horizontal, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(15)
        .padding(.horizontal, 0)
        .frame(height: 30)
        .contentShape(Rectangle())
        .onTapGesture {
            guard testingLatencySessionId == nil else { return }
            testLatency(for: session)
        }
    }
    
    private func testLatency(for session: ScrcpySession) {
        // Clear previous results for this session
        latencyResults[session.id] = nil
        latencyErrors[session.id] = nil

        // Set testing state
        testingLatencySessionId = session.id

        // Activate local-network permission for this process before using the
        // raw-socket testers (no-op after the first time per launch)
        LocalNetworkPrimer.prime(host: session.sessionModel.hostReal,
                                 port: UInt16(session.sessionModel.port) ?? 5555) {
            startLatencyTest(for: session)
        }
    }

    private func startLatencyTest(for session: ScrcpySession) {
        // For Tailscale sessions, get connection info first
        if session.sessionModel.useTailscale {
            // Check if Tailscale configuration is valid
            guard TailscaleManager.shared.isConfigurationValid() else {
                latencyErrors[session.id] = "Tailscale not configured. Please set Auth Key in Settings."
                testingLatencySessionId = nil
                return
            }
            
            Task {
                guard let connectionInfo = await SessionNetworking.shared.getConnectionInfo(for: session.sessionModel) else {
                    await MainActor.run {
                        // Provide more specific error message based on Tailscale status
                        let manager = TailscaleManager.shared
                        if !manager.isConfigurationValid() {
                            latencyErrors[session.id] = "Tailscale configuration invalid"
                        } else if let lastError = manager.getLastError() {
                            latencyErrors[session.id] = "Tailscale error: \(lastError)"
                        } else {
                            latencyErrors[session.id] = "Failed to setup Tailscale connection"
                        }
                        testingLatencySessionId = nil
                    }
                    return
                }
                
                // Test latency using the proxied connection
                await testLatencyWithConnectionInfo(for: session, connectionInfo: connectionInfo)
            }
        } else {
            // Direct connection - use original logic
            testLatencyDirect(for: session)
        }
    }
    
    private func testLatencyDirect(for session: ScrcpySession) {
        // Get host and port for direct connection
        let host = session.sessionModel.hostReal
        let port = session.sessionModel.port
        
        // Use the common latency test logic
        performLatencyTest(for: session, host: host, port: port)
    }
    
    @MainActor
    private func testLatencyWithConnectionInfo(for session: ScrcpySession, connectionInfo: NetworkConnectionInfo) async {
        // Use the proxied host and port from connection info
        let host = connectionInfo.host
        let port = connectionInfo.port
        
        // Always use TCP latency tester for proxied connections (force VNC type for consistency)
        await withCheckedContinuation { continuation in
            performLatencyTest(for: session, host: host, port: port) {
                continuation.resume()
            }
        }
    }
    
    /// Common latency test logic that can be used for both direct and proxied connections
    /// - Parameters:
    ///   - session: The session to test
    ///   - host: The host to connect to
    ///   - port: The port to connect to
    ///   - deviceType: The device type to determine which tester to use
    ///   - completion: Optional completion handler
    private func performLatencyTest(for session: ScrcpySession, host: String, port: String, attempt: Int = 0, completion: (() -> Void)? = nil) {
        // First LAN socket right after cold launch often fails transiently (local
        // network privacy readiness race, worst on iOS 14) - retry once before
        // reporting an error.
        let resultHandler: (NSNumber?, Error?) -> Void = { latency, error in
            DispatchQueue.main.async {
                if error != nil && attempt < 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        performLatencyTest(for: session, host: host, port: port, attempt: attempt + 1, completion: completion)
                    }
                    return
                }
                self.handleLatencyTestResult(for: session, latency: latency, error: error)
                completion?()
            }
        }

        // Choose the appropriate latency tester based on device type
        switch session.sessionModel.deviceType {
        case .adb:
            // Use ADBLatencyTester for ADB devices
            let tester = ADBLatencyTester(session: session.sessionModel.toDict())

            // Run latency test with 1 iteration for a quick result
            tester.testAverageLatency(withCount: 1, completion: resultHandler)

        case .vnc:
            // Use TCPLatencyTester for VNC devices or proxied connections
            let tester = TCPLatencyTester(host: host, port: port)

            // Run latency test with 1 iteration for a quick result
            tester.testAverageLatency(withCount: 1, completion: resultHandler)
        }
    }
    
    /// Handle the result of latency test (success or error)
    /// - Parameters:
    ///   - session: The session that was tested
    ///   - latency: The latency result (if successful)
    ///   - error: The error (if failed)
    private func handleLatencyTestResult(for session: ScrcpySession, latency: NSNumber?, error: Error?) {
        if let latency = latency?.doubleValue {
            latencyResults[session.id] = latency
        } else if let error = error {
            latencyErrors[session.id] = error.localizedDescription
        }
        
        // Reset testing state
        testingLatencySessionId = nil
    }
    
    // Helper function to determine color based on latency value
    private func latencyColor(for latency: Double) -> Color {
        switch latency {
        case ..<60:
            return .green       // Excellent latency
        case 60..<150:
            return .yellow      // Good latency
        default:
            return .red         // Poor latency
        }
    }
    
    // Helper function to determine icon based on latency value
    private func latencyIcon(for latency: Double) -> String {
        switch latency {
        case ..<60:
            return "bolt.fill"        // Fast/lightning icon for excellent latency
        case 60..<150:
            return "checkmark.circle"  // Checkmark for good latency
        default:
            return "exclamationmark.triangle"  // Warning for poor latency
        }
    }
    
    // Add merged icon and text in one elliptical background
    private func deviceTypeIcon(for session: ScrcpySession) -> some View {
        let deviceType = session.deviceType
        let iconName: String
        
        switch deviceType {
        case "adb":
            iconName = "android"  // Use android icon from Assets
        case "vnc":
            iconName = "vnc"      // Use vnc icon from Assets
        default:
            iconName = "questionmark.circle"
        }
        
        return Image(iconName)
            .resizable()
            .scaledToFit()
            .frame(width: 16, height: 16)
            .padding(4)
            .foregroundColor(.white)
            .colorMultiply(.white)
            .background(Color.black.opacity(0.6))
            .clipShape(Circle())
    }
    
    // Device type text only with matching style
    private func deviceTypeTextOnly(for session: ScrcpySession) -> some View {
        let deviceType = session.deviceType
        
        return Text(deviceType)
            .frame(width: 50, height: 24)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .background(Color.black.opacity(0.6))
            .cornerRadius(20)
    }
    
    // MARK: - 优化的刷新逻辑辅助方法
    
    /// 判断是否应该触发自动延迟测试
    /// - Parameters:
    ///   - currentHash: 当前会话列表的哈希值
    ///   - hasInitialized: 是否已经初始化过
    ///   - autoTestEnabled: 是否启用自动测试
    /// - Returns: 是否应该触发测试
    private func shouldTriggerAutoTest(
        currentHash: Int,
        hasInitialized: Bool,
        autoTestEnabled: Bool
    ) -> Bool {
        // 如果自动测试被禁用，不触发
        guard autoTestEnabled else { return false }
        
        // 如果会话列表为空，不触发
        guard !savedSessions.isEmpty else { return false }
        
        // 如果正在测试中，不触发
        guard testingLatencySessionId == nil else { return false }
        
        // 首次加载时触发
        if !hasInitialized {
            return true
        }
        
        // 会话列表发生变化时触发
        if currentHash != lastSessionsHash {
            return true
        }
        
        // 其他情况不触发
        return false
    }
    
    /// 执行自动延迟测试
    private func performAutoLatencyTest() {
        // 重置测试状态
        latencyResults = [:]
        latencyErrors = [:]
        
        // 开始顺序测试
        testSessionsSequentially(sessions: savedSessions)
    }
    
    /// 执行手动刷新
    @MainActor
    private func performManualRefresh() async {
        // 设置刷新状态
        isRefreshing = true
        
        // 重置所有延迟测试结果
        latencyResults = [:]
        latencyErrors = [:]
        
        // 等待当前测试完成（如果有的话）
        while testingLatencySessionId != nil {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        }
        
        // 开始测试所有会话
        testSessionsSequentially(sessions: savedSessions)
        
        // 等待测试完成
        while testingLatencySessionId != nil {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        }
        
        // 标记刷新完成
        isRefreshing = false
    }
    
    /// 启用或禁用自动延迟测试
    /// - Parameter enabled: 是否启用
    func setAutoTestEnabled(_ enabled: Bool) {
        autoTestEnabled = enabled
    }
    
    /// 手动触发延迟测试（用于外部调用）
    func triggerLatencyTest() {
        guard autoTestEnabled && !savedSessions.isEmpty else { return }
        performAutoLatencyTest()
    }
    
    /// 清除所有延迟测试结果
    func clearLatencyResults() {
        latencyResults = [:]
        latencyErrors = [:]
        testingLatencySessionId = nil
    }
}

// Add a dot loading animation view
struct DotLoadingView: View {
    @State private var animationStep = 0
    
    let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
                    .opacity(self.animationStep == index ? 1 : 0.3)
            }
        }
        .onReceive(timer) { _ in
            self.animationStep = (self.animationStep + 1) % 3
        }
    }
}

struct SessionsView_Previews: PreviewProvider {
    @State static private var previewSessions = [
        ScrcpySession(sessionModel: ScrcpySessionModel(host: "test.example.com", port: "5091", sessionName: "My Test Device")),
        ScrcpySession(sessionModel: ScrcpySessionModel(host: "scrcpy.link", port: "5555")),
        ScrcpySession(sessionModel: ScrcpySessionModel(host: "adb://myphone.link", port: "15680", sessionName: "My Phone"))
    ]
    
    static var previews: some View {
        SessionsView(
            savedSessions: $previewSessions,
            onDuplicateSession: { _ in }
        )
    }
}
