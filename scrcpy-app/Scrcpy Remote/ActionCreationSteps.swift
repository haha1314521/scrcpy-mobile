//
//  ActionCreationSteps.swift
//  Scrcpy Remote
//
//  Created by Ethan on 12/8/24.
//

import SwiftUI

// MARK: - Step Indicator View

struct StepIndicatorView: View {
    let currentStep: Int
    let totalSteps: Int
    
    private let stepTitles = ["Device*", "Actions*", "Name*"]
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress bar
            HStack(spacing: 0) {
                ForEach(1...totalSteps, id: \.self) { step in
                    Rectangle()
                        .fill(
                            step <= currentStep 
                            ? LinearGradient(colors: [Color.blue, Color.compatCyan], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(height: 6)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                    
                    if step < totalSteps {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 8, height: 6)
                    }
                }
            }
            .clipShape(Capsule())
            
            // Step indicators with labels
            HStack {
                ForEach(1...totalSteps, id: \.self) { step in
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(
                                    step <= currentStep 
                                    ? LinearGradient(colors: [Color.blue, Color.compatCyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 32, height: 32)
                                .shadow(color: step <= currentStep ? Color.blue.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
                            
                            if step < currentStep {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Text("\(step)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(step == currentStep ? .white : .gray)
                            }
                        }
                        .scaleEffect(step == currentStep ? 1.1 : 1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: currentStep)
                        
                        Text(LocalizedStringKey(stepTitles[step - 1]))
                            .font(.caption)
                            .fontWeight(step == currentStep ? .semibold : .regular)
                            .foregroundColor(step <= currentStep ? .primary : .secondary)
                            .animation(.easeInOut(duration: 0.2), value: currentStep)
                    }
                    
                    if step < totalSteps {
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Device Selection Mode
enum DeviceSelectionMode {
    case specificDevice(ScrcpySession)
    case anyDeviceOfType(SessionDeviceType)

    var isAnyDevice: Bool {
        if case .anyDeviceOfType = self { return true }
        return false
    }

    var deviceType: SessionDeviceType {
        switch self {
        case .specificDevice(let session):
            return session.sessionModel.deviceType
        case .anyDeviceOfType(let type):
            return type
        }
    }

    var session: ScrcpySession? {
        if case .specificDevice(let session) = self {
            return session
        }
        return nil
    }
}

// MARK: - Step 1 View (Device Selection)

struct DeviceSelectionView: View {
    @Binding var selectedDevice: ScrcpySession?
    // New: track if user selected "Any device" mode
    @Binding var selectedDeviceType: SessionDeviceType?
    @Binding var useAnyDeviceMode: Bool

    @State private var savedSessions: [ScrcpySession] = []

    var onDeviceDoubleTap: (() -> Void)? = nil

    // Legacy initializer for backwards compatibility
    init(selectedDevice: Binding<ScrcpySession?>, onDeviceDoubleTap: (() -> Void)? = nil) {
        self._selectedDevice = selectedDevice
        self._selectedDeviceType = .constant(nil)
        self._useAnyDeviceMode = .constant(false)
        self.onDeviceDoubleTap = onDeviceDoubleTap
    }

    // New initializer with device type selection support
    init(selectedDevice: Binding<ScrcpySession?>,
         selectedDeviceType: Binding<SessionDeviceType?>,
         useAnyDeviceMode: Binding<Bool>,
         onDeviceDoubleTap: (() -> Void)? = nil) {
        self._selectedDevice = selectedDevice
        self._selectedDeviceType = selectedDeviceType
        self._useAnyDeviceMode = useAnyDeviceMode
        self.onDeviceDoubleTap = onDeviceDoubleTap
    }

    // Get available device types from saved sessions
    private var availableDeviceTypes: [SessionDeviceType] {
        let types = Set(savedSessions.map { $0.sessionModel.deviceType })
        return Array(types).sorted { $0.rawValue < $1.rawValue }
    }

    // Check if we have a valid selection (either specific device or any device type)
    private var hasValidSelection: Bool {
        if useAnyDeviceMode {
            return selectedDeviceType != nil
        }
        return selectedDevice != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Device Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Select Device")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Choose a specific device or select a device type to choose later")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if savedSessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.stack.badge.plus")
                            .font(.title)
                            .foregroundColor(.gray)
                        Text("No saved devices")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Please create a session first in the Sessions tab")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    // "Any Device" type options (only show if there are devices of that type)
                    if !availableDeviceTypes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select Later (Any Device of Type)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                                ForEach(availableDeviceTypes, id: \.self) { deviceType in
                                    AnyDeviceTypeCardView(
                                        deviceType: deviceType,
                                        isSelected: useAnyDeviceMode && selectedDeviceType == deviceType,
                                        onTap: {
                                            useAnyDeviceMode = true
                                            selectedDeviceType = deviceType
                                            selectedDevice = nil
                                        },
                                        onDoubleTap: {
                                            useAnyDeviceMode = true
                                            selectedDeviceType = deviceType
                                            selectedDevice = nil
                                            onDeviceDoubleTap?()
                                        }
                                    )
                                }
                            }
                        }

                        Divider()
                            .padding(.vertical, 8)

                        Text("Or Select Specific Device")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }

                    // Specific device selection
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        ForEach(savedSessions) { session in
                            DeviceCardView(
                                session: session,
                                isSelected: !useAnyDeviceMode && selectedDevice?.id == session.id,
                                onTap: {
                                    useAnyDeviceMode = false
                                    selectedDeviceType = nil
                                    selectedDevice = session
                                },
                                onDoubleTap: {
                                    useAnyDeviceMode = false
                                    selectedDeviceType = nil
                                    selectedDevice = session
                                    onDeviceDoubleTap?()
                                }
                            )
                        }
                    }
                }
            }

            if !hasValidSelection {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.orange)
                        Text("Please select a device or device type to continue")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            Spacer()
        }
        .onAppear {
            loadSavedSessions()
        }
    }

    private func loadSavedSessions() {
        savedSessions = SessionManager.shared.loadSessions().map {
            ScrcpySession(sessionModel: $0)
        }
    }
}

// MARK: - Any Device Type Card View

struct AnyDeviceTypeCardView: View {
    let deviceType: SessionDeviceType
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: deviceType == .vnc ? "desktopcomputer" : "iphone")
                .font(.system(size: 28))
                .foregroundColor(deviceType == .vnc ? .blue : .green)

            Text("Any \(deviceType == .vnc ? "VNC" : "ADB") Device")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)

            Text("Select at runtime")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? (deviceType == .vnc ? Color.blue.opacity(0.15) : Color.green.opacity(0.15)) : Color.gray.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? (deviceType == .vnc ? Color.blue : Color.green) : Color.clear, lineWidth: 2)
        )
        .onTapGesture(count: 2) {
            onDoubleTap()
        }
        .onTapGesture(count: 1) {
            onTap()
        }
    }
}

// MARK: - Step 2 View (Action Configuration)

struct Step2View: View {
    let deviceType: String
    @Binding var selectedVNCQuickActions: Set<VNCQuickAction>
    @Binding var vncInputKeysConfig: VNCInputKeysConfig
    @Binding var adbCommands: String
    @Binding var selectedADBActionType: ADBActionType
    @Binding var adbInputKeysConfig: ADBInputKeysConfig
    @Binding var adbShellConfig: ADBShellConfig
    @Binding var executionTiming: ExecutionTiming
    @Binding var delaySeconds: Int
    
    var onVNCActionDoubleTap: (() -> Void)? = nil
    var onShowKeySelector: (() -> Void)? = nil
    var onShowVNCKeySelector: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Configure Actions")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("*")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
            
            Text("Select at least one action to perform when executing this action")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if deviceType == "vnc" {
                // VNC Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("VNC Quick Actions")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Select actions to perform on the VNC device")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        ForEach(VNCQuickAction.allCases, id: \.self) { action in
                            QuickActionCardView(
                                action: action,
                                isSelected: selectedVNCQuickActions.contains(action),
                                onTap: {
                                    // Allow only one VNC quick action at a time
                                    if selectedVNCQuickActions.contains(action) {
                                        selectedVNCQuickActions.removeAll()
                                    } else {
                                        selectedVNCQuickActions = [action]
                                    }
                                },
                                onDoubleTap: {
                                    // Double-tap selects this action exclusively
                                    selectedVNCQuickActions = [action]
                                    onVNCActionDoubleTap?()
                                }
                            )
                        }
                    }
                    
                    // VNC Input Keys Configuration
                    if selectedVNCQuickActions.contains(.inputKeys) {
                        VNCInputKeysConfigView(
                            config: $vncInputKeysConfig,
                            onShowKeySelector: onShowVNCKeySelector
                        )
                    }
                }
            } else {
                // ADB Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("ADB Actions")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Select the type of action to perform on the Android device")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // ADB Action Type Selection
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        ForEach(ADBActionType.allCases, id: \.self) { actionType in
                            ADBActionTypeCardView(
                                actionType: actionType,
                                isSelected: selectedADBActionType == actionType,
                                onTap: {
                                    selectedADBActionType = actionType
                                }
                            )
                        }
                    }
                    
                    // Configuration based on selected action type
                    switch selectedADBActionType {
                    case .homeKey, .switchKey:
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("No additional configuration needed")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                Spacer()
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                    case .inputKeys:
                        ADBInputKeysConfigView(
                            config: $adbInputKeysConfig,
                            onShowKeySelector: onShowKeySelector
                        )
                        
                    case .shellCommands:
                        ADBShellConfigView(config: $adbShellConfig)
                    }
                }
            }
            
            // Execution Timing Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Execution Timing")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("*")
                        .font(.headline)
                        .foregroundColor(.red)
                }
                
                Text("Choose when to execute the actions after connection")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    ForEach(ExecutionTiming.allCases, id: \.self) { timing in
                        ExecutionTimingCardView(
                            timing: timing,
                            isSelected: executionTiming == timing,
                            delaySeconds: delaySeconds,
                            onTap: {
                                executionTiming = timing
                            },
                            onDelayChange: { newDelay in
                                delaySeconds = newDelay
                            }
                        )
                    }
                }
            }
            
            // Validation feedback
            if deviceType == "vnc" {
                if selectedVNCQuickActions.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Please select at least one VNC action")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                } else if selectedVNCQuickActions.contains(.inputKeys) && vncInputKeysConfig.keys.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Please configure keys for Input Keys action")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(String(
                            format: NSLocalizedString("%d action(s) selected", comment: "Count of selected actions"),
                            selectedVNCQuickActions.count
                        ))
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            } else {
                // ADB validation - only show general validation for non-shell actions
                switch selectedADBActionType {
                case .homeKey, .switchKey:
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Action configured")
                            .font(.subheadline)
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                case .inputKeys:
                    // Input keys validation is handled within ADBInputKeysConfigView
                    EmptyView()
                case .shellCommands:
                    // Shell commands validation is handled within ADBShellConfigView
                    EmptyView()
                }
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Text("Actions are required to create a meaningful automation")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("Tap Next in the top-right corner when ready")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

// MARK: - Step 3 View (Action Name)

struct Step3View: View {
    @Binding var actionName: String
    
    let onSave: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Name Your Action")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("A default name has been generated based on your selections. You can modify it if needed.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Action Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("*")
                        .font(.headline)
                        .foregroundColor(.red)
                }
                
                TextField("Enter action name", text: $actionName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.body)
                
                if actionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text("Action name is required")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Action name looks good")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Tips:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text("• Use descriptive names like 'Connect to Dev Server'")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("• Include device name for easy identification")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("• Names are automatically numbered if duplicates exist")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
            
            VStack(spacing: 16) {
                Button(action: onSave) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Save Action")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        !actionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? LinearGradient(colors: [Color.blue, Color.compatCyan], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.gray], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(12)
                    .shadow(color: !actionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.blue.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                }
                .disabled(actionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .scaleEffect(!actionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1.0 : 0.95)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: actionName.isEmpty)
                
                Text("Your action will be saved and ready to use")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
