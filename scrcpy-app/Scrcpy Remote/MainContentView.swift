//
//  ContentView.swift
//  Scrcpy Remote
//
//  Created by Ethan on 12/5/24.
//

import SwiftUI

struct MainContentView: View {
    @StateObject private var connectionManager = SessionConnectionManager.shared
    
    @State private var selectedTab = 0
    @State private var isSettingsPresented = false
    @State private var isSessionCreatePresented = false
    @State private var isNewActionPresented = false
    @State private var editingSession: ScrcpySession? = nil
    @State private var savedSessions: [ScrcpySession] = []
    @State private var currentStatusMessage: String?
    @State private var isNavigationBarHidden: Bool = false
    @State private var shouldShowNavigationBarAfterDismiss: Bool = false
    @State private var userDismissedConnection: Bool = false
    @State private var showMigrationAlert: Bool = false
    @State private var legacyDeviceInfo: (host: String, port: String)?
    @EnvironmentObject var appSettings: AppSettings
    
    init(sessions: [ScrcpySession] = []) {
        self._savedSessions = State(initialValue: sessions)
        
        // Configure navigation bar and tab bar appearance for iOS 14+
        if #available(iOS 14.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            appearance.shadowColor = UIColor.separator  // Add subtle shadow/border below navigation bar
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithDefaultBackground()
            tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            UITabBar.appearance().standardAppearance = tabBarAppearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            }
        }
    }
    
    func reloadSessions() {
        savedSessions = SessionManager.shared.loadSessions().map {
            ScrcpySession(sessionModel: $0)
        }
        print("Reloaded sessions:", savedSessions.count)
    }
    
    /// 回到前台时设备已掉线,由 SessionConnectionManager 发通知过来,这里走一遍正常连接流程
    private func handleAutoReconnectRequest(_ note: Notification) {
        guard let sessionId = note.userInfo?["sessionId"] as? UUID else { return }
        guard let session = savedSessions.first(where: { $0.id == sessionId }) else {
            print("🔁 [MainContentView] AutoReconnect: session \(sessionId) not found in list")
            return
        }
        print("🔁 [MainContentView] AutoReconnect: reconnecting to \(session.title)")
        connectToSession(session)
    }

    /// 连接到指定会话
    private func connectToSession(_ session: ScrcpySession) {
        print("Connecting to session:", session.title)
        
        // 重置用户关闭标志，允许显示新的连接状态
        userDismissedConnection = false
        
        // 使用 SessionConnectionManager 进行连接
        SessionConnectionManager.shared.connectToSession(
            session.sessionModel,
            statusCallback: { status, message, isConnecting in
                // 状态更新由 @ObservedObject 自动处理
                DispatchQueue.main.async {
                    print("📝 [MainContentView] Status callback received - Status: \(status.description), Message: \(message ?? "nil"), IsConnecting: \(isConnecting)")
                    self.currentStatusMessage = message
                    if let msg = message {
                        print("📝 [MainContentView] Setting currentStatusMessage to: \(msg)")
                    } else {
                        print("📝 [MainContentView] Setting currentStatusMessage to nil")
                    }
                }
                
                switch status {
                case ScrcpyStatusSDLWindowAppeared:
                    print("✅ Connected to session:", session.title)
                    
                case ScrcpyStatusConnectingFailed:
                    print("❌ Failed to connect to session:", session.title)
                    
                default:
                    print("🔄 Connection status update:", status.description)
                    if let msg = message {
                        print("📝 Status message:", msg)
                    }
                }
            },
            errorCallback: { title, message in
                // 错误信息现在通过 ConnectionStatusView 展示，不再显示 alert
                print("❌ [MainContentView] Connection error: \(title) - \(message)")
                // 错误信息会通过 statusCallback 传递到 ConnectionStatusView
            }
        )
    }

    // MARK: - Computed Properties
    
    // MARK: - Migration Methods
    
    private func checkForMigration() {
        DispatchQueue.main.async {
            if SessionManager.shared.shouldShowMigrationPrompt() {
                self.legacyDeviceInfo = SessionManager.shared.getLegacyDeviceInfo()
                self.showMigrationAlert = true
            }
        }
    }
    
    private func performMigration() {
        SessionManager.shared.performUserRequestedMigration()
        reloadSessions()
        showMigrationAlert = false
    }
    
    private func declineMigration() {
        SessionManager.shared.declineMigration()
        showMigrationAlert = false
    }

    // MARK: - Extracted subviews / handlers (keeps `body` small enough to type-check)

    private var sessionsTabView: some View {
        SessionsView(savedSessions: $savedSessions, onDeleteSession: { id in
            print("Deleting session:", id)
            SessionManager.shared.deleteSession(id: id)
            reloadSessions()
        }, onConnectSession: { session in
            connectToSession(session)
        }, onEditSession: { session in
            print("Editing session:", session.title)
            editingSession = session
        }, onDuplicateSession: { duplicatedSession in
            print("Duplicating session:", duplicatedSession.title)
            SessionManager.shared.saveSession(duplicatedSession.sessionModel)
            reloadSessions()
        })
    }

    @ViewBuilder private var connectionOverlay: some View {
        if shouldShowConnectionStatusView {
            ConnectionStatusView(
                session: ScrcpySession(sessionModel: connectionManager.currentSession ?? ScrcpySessionModel()),
                connectionStatus: connectionManager.connectionStatus,
                statusMessage: currentStatusMessage,
                onCancel: { handleConnectionCancel() }
            )
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.3), value: shouldShowConnectionStatusView)
                .onDisappear {
                    // 兜底: 连接界面消失后, 导航栏必须回来
                    if isNavigationBarHidden {
                        print("🧭 [MainContentView] 连接界面已关闭, 恢复导航栏")
                        isNavigationBarHidden = false
                    }
                }
        }
    }

    private func handleConnectionCancel() {
        print("🚫 [MainContentView] User dismissed connection, restoring navigation bar")

        // 立即设置用户关闭标志，强制隐藏连接状态视图
        userDismissedConnection = true

        withAnimation(.easeInOut(duration: 0.3)) {
            isNavigationBarHidden = false
        }
        currentStatusMessage = nil

        // 断开连接并清理会话状态
        SessionConnectionManager.shared.disconnectCurrent()

        // 对于连接失败的情况，需要手动清理会话状态
        if connectionManager.connectionStatus == ScrcpyStatusConnectingFailed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                SessionConnectionManager.shared.clearCurrentSession()
            }
        }
    }

    private func handleSchemeConnection(_ notification: Notification) {
        guard let session = notification.userInfo?["session"] as? ScrcpySessionModel else {
            print("❌ [MainContentView] No session found in scheme connection notification")
            return
        }

        print("🔗 [MainContentView] Received scheme connection request for: \(session.host):\(session.port)")

        let scrcpySession = ScrcpySession(sessionModel: session)
        connectToSession(scrcpySession)

        selectedTab = 0
    }

    private func handleConnectingChange(_ isConnecting: Bool) {
        // 用户已经关掉连接界面后, 迟到的状态回调不应该再把导航栏藏起来,
        // 否则会话列表顶部的设置/新建按钮会一直消失, 直到下次进入会话才恢复。
        if isConnecting && !userDismissedConnection {
            isNavigationBarHidden = true
        }

        if !isConnecting && connectionManager.connectionStatus != ScrcpyStatusConnectingFailed {
            print("🧹 [MainContentView] Auto-clearing currentStatusMessage (not in failure state)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                currentStatusMessage = nil
                print("🧹 [MainContentView] currentStatusMessage cleared")
            }
        } else if !isConnecting && connectionManager.connectionStatus == ScrcpyStatusConnectingFailed {
            print("⚠️ [MainContentView] Not auto-clearing currentStatusMessage (in failure state)")
        }
    }

    private func handleStatusChange(_ newStatus: ScrcpyStatus) {
        print("🔄 [MainContentView] Connection status changed to: \(newStatus.description)")
        print("🔄 [MainContentView] Current currentStatusMessage: \(currentStatusMessage ?? "nil")")

        switch newStatus {
        case ScrcpyStatusSDLWindowAppeared:
            print("✅ [MainContentView] SDL Window appeared, restoring navigation bar and hiding status view")
            isNavigationBarHidden = false
            userDismissedConnection = false // 重置用户关闭标志
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                currentStatusMessage = nil
                print("🧹 [MainContentView] currentStatusMessage cleared after SDL window appeared")
            }

        case ScrcpyStatusConnected:
            print("✅ [MainContentView] Connection successful, preparing to hide status view")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                currentStatusMessage = nil
                print("🧹 [MainContentView] currentStatusMessage cleared after connection success")
            }

        case ScrcpyStatusConnectingFailed:
            print("❌ [MainContentView] Connection failed, waiting for user to dismiss")
            print("❌ [MainContentView] Current currentStatusMessage: \(currentStatusMessage ?? "nil")")
            // 仅在失败提示还要显示时才隐藏导航栏; 用户已主动关闭的话保持显示
            isNavigationBarHidden = !userDismissedConnection

            // 不自动清除状态消息，等待用户点击 dismiss 按钮

        case ScrcpyStatusDisconnected:
            print("🔌 [MainContentView] Connection disconnected, restoring navigation bar and cleaning up")
            isNavigationBarHidden = false
            // 注意: 这里不再重置 userDismissedConnection。
            // 用户主动取消后, 底层会先报"已断开"再补一条"连接失败";
            // 若此处把标记清掉, 那条迟到的失败状态就会让连接界面重新出现、
            // 导航栏再次被隐藏(表现为顶部按钮消失, 要再进一次会话才恢复)。
            // 该标记统一在发起新连接时(connectToSession)重置。
            currentStatusMessage = nil
            print("🧹 [MainContentView] currentStatusMessage cleared after disconnect")

        default:
            break
        }
    }
    
    // MARK: - Computed Properties
    
    /// 判断是否应该显示连接状态视图
    private var shouldShowConnectionStatusView: Bool {
        // 如果用户主动关闭了连接状态视图，立即隐藏
        guard !userDismissedConnection else {
            return false
        }
        
        // 只有在以下情况下才显示 ConnectionStatusView：
        // 1. 正在连接中
        // 2. 连接失败（等待用户主动点击 dismiss 按钮）
        // 3. 有当前会话且状态处于连接过程中（不包括连接失败）
        return connectionManager.isConnecting || 
               (connectionManager.connectionStatus == ScrcpyStatusConnectingFailed && currentStatusMessage != nil) ||
               (connectionManager.currentSession != nil && 
                connectionManager.connectionStatus != ScrcpyStatusDisconnected &&
                connectionManager.connectionStatus != ScrcpyStatusConnectingFailed &&
                connectionManager.connectionStatus.rawValue < ScrcpyStatusSDLWindowAppeared.rawValue)
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                TabView(selection: $selectedTab) {
                    sessionsTabView
                        .tabItem {
                            Image(systemName: "rectangle.stack")
                            Text("Sessions")
                        }
                        .tag(0)
                    ActionsView()
                        .tabItem {
                            Image(systemName: "play.square.stack.fill")
                            Text("Actions")
                        }
                        .tag(1)
                }
                .navigationTitle(
                    selectedTab == 0 ? "Scrcpy Sessions" : "Scrcpy Actions"
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            isSettingsPresented.toggle()
                        }) {
                            Image(systemName: "gear")
                        }
                        .disabled(connectionManager.isConnecting)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            if selectedTab == 0 {
                                isSessionCreatePresented.toggle()
                            } else if selectedTab == 1 {
                                isNewActionPresented.toggle()
                            }
                        }) {
                            Image(systemName: "plus")
                        }
                        .disabled(connectionManager.isConnecting)
                    }
                }
                .navigationBarHidden(shouldShowConnectionStatusView)   // 由状态推导, 避免手动开关产生的竞态
                .sheet(isPresented: $isSettingsPresented) {
                    SettingsView()
                        .environmentObject(appSettings)
                }
                .sheet(isPresented: $isSessionCreatePresented, onDismiss: {
                    editingSession = nil
                    reloadSessions()
                }) {
                    SessionCreateView()
                        .environmentObject(appSettings)
                }
                .sheet(isPresented: $isNewActionPresented) {
                    NewActionView { action in
                        ActionManager.shared.saveAction(action)
                    }
                }
                .sheet(item: $editingSession, onDismiss: {
                    editingSession = nil
                    reloadSessions()
                }) { item in
                    SessionCreateView(sessionModel: item.sessionModel)
                        .environmentObject(appSettings)
                }
                .overlay(connectionOverlay)
                .onReceive(NotificationCenter.default.publisher(for: .startSchemeConnection)) { handleSchemeConnection($0) }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScrcpyAutoReconnectRequest"))) { handleAutoReconnectRequest($0) }
                .onAppear {
                    if savedSessions.isEmpty {
                        reloadSessions()
                    }
                    checkForMigration()
                    // 冷启动: 进程可能是在后台被系统杀掉的, 检查有没有待恢复的会话
                    connectionManager.checkAutoReconnectOnLaunch()
                }
                .onChange(of: connectionManager.isConnecting) { handleConnectingChange($0) }
                .onChange(of: connectionManager.connectionStatus) { handleStatusChange($0) }
                // Migration prompt
                .compatAlert("Legacy Data Found", isPresented: $showMigrationAlert,
                             message: legacyDeviceInfo.map {
                                 "We found device settings from the previous versions:\n\n📱 Device: \($0.host):\($0.port)\n\nWould you like to migrate this device to the new app? A new ADB device will be created with your previous settings."
                             } ?? "We found settings from the previous versions. Would you like to migrate them to the new version?",
                             primaryLabel: "Migrate",
                             primaryAction: { performMigration() },
                             cancelLabel: "Skip",
                             cancelAction: { declineMigration() })
            }
        } else {
            NavigationView {
                TabView(selection: $selectedTab) {
                    sessionsTabView
                        .tabItem {
                            Image(systemName: "rectangle.stack")
                            Text("Sessions")
                        }
                        .tag(0)
                    ActionsView()
                        .tabItem {
                            Image(systemName: "play.rectangle.fill")
                            Text("Actions")
                        }
                        .tag(1)
                }
                .navigationBarTitle(
                    selectedTab == 0 ? "Scrcpy Sessions" : "Scrcpy Actions",
                    displayMode: .inline
                )
                .navigationBarItems(leading: Button(action: {
                    isSettingsPresented.toggle()
                }) {
                    Image(systemName: "gear")
                }.disabled(connectionManager.isConnecting), trailing: Button(action: {
                    if selectedTab == 0 {
                        isSessionCreatePresented.toggle()
                    } else if selectedTab == 1 {
                        isNewActionPresented.toggle()
                    }
                }) {
                    Image(systemName: "plus")
                }.disabled(connectionManager.isConnecting))
                .navigationBarHidden(shouldShowConnectionStatusView)   // 由状态推导, 避免手动开关产生的竞态
                .sheet(isPresented: $isSettingsPresented) {
                    SettingsView()
                        .environmentObject(appSettings)
                }
                .sheet(isPresented: $isSessionCreatePresented, onDismiss: {
                    editingSession = nil
                    reloadSessions()
                }) {
                    SessionCreateView()
                        .environmentObject(appSettings)
                }
                .sheet(isPresented: $isNewActionPresented) {
                    NewActionView { action in
                        ActionManager.shared.saveAction(action)
                    }
                }
                .sheet(item: $editingSession, onDismiss: {
                    editingSession = nil
                    reloadSessions()
                }) { item in
                    SessionCreateView(sessionModel: item.sessionModel)
                        .environmentObject(appSettings)
                }
                .overlay(connectionOverlay)
                .onReceive(NotificationCenter.default.publisher(for: .startSchemeConnection)) { handleSchemeConnection($0) }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScrcpyAutoReconnectRequest"))) { handleAutoReconnectRequest($0) }
                .onAppear {
                    if savedSessions.isEmpty {
                        reloadSessions()
                    }
                    checkForMigration()
                    // 冷启动: 进程可能是在后台被系统杀掉的, 检查有没有待恢复的会话
                    connectionManager.checkAutoReconnectOnLaunch()
                }
                .onChange(of: connectionManager.isConnecting) { handleConnectingChange($0) }
                .onChange(of: connectionManager.connectionStatus) { handleStatusChange($0) }
                // Migration prompt
                .alert(isPresented: $showMigrationAlert) {
                    let title = "Legacy Data Found"
                    let message: String
                    if let deviceInfo = legacyDeviceInfo {
                        message = "We found device settings from the previous scrcpy-ios app:\n\n📱 Device: \(deviceInfo.host):\(deviceInfo.port)\n\nWould you like to migrate this device to the new app? A new ADB device will be created with your previous settings."
                    } else {
                        message = "We found settings from the previous scrcpy-ios app. Would you like to migrate them to the new version?"
                    }
                    
                    return Alert(
                        title: Text(title),
                        message: Text(message),
                        primaryButton: .default(Text("Migrate")) {
                            performMigration()
                        },
                        secondaryButton: .cancel(Text("Skip")) {
                            declineMigration()
                        }
                    )
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}

#Preview {
    MainContentView(sessions: [
        ScrcpySession(sessionModel: ScrcpySessionModel(host: "test.abc.com", port: "5555", sessionName: "Test Server")),
        ScrcpySession(sessionModel: ScrcpySessionModel(host: "vnc://myvnc.com", port: "5901", sessionName: "My VNC")),
        ScrcpySession(sessionModel: ScrcpySessionModel(host: "adb://test.example.com", port: "1555")),
        ScrcpySession(sessionModel: ScrcpySessionModel(host: "10.1.1.1", port: "8080", sessionName: "Local Device")),
        ScrcpySession(sessionModel: ScrcpySessionModel(host: "test2.examle.com", port: "5555"))
    ])
}
