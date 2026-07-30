//
//  ActionCreationFlow.swift
//  Scrcpy Remote
//
//  Created by Ethan on 12/8/24.
//

import SwiftUI

// MARK: - New Action View

struct NewActionView: View {
    private var dismiss = CompatDismiss()
    @State private var actionName = ""
    @State private var selectedDevice: ScrcpySession? = nil
    @State private var currentStep = 1
    @State private var selectedVNCQuickActions: Set<VNCQuickAction> = []
    @State private var adbCommands = ""
    @State private var executionTiming: ExecutionTiming = .confirmation
    @State private var delaySeconds: Int = 3
    @State private var showingDeviceSelector = false

    // New: "Any device" mode support
    @State private var selectedDeviceType: SessionDeviceType? = nil
    @State private var useAnyDeviceMode: Bool = false

    // VNC action states
    @State private var vncInputKeysConfig = VNCInputKeysConfig()
    @State private var showingVNCKeySelector = false
    @State private var lastSelectedPCKeyCategory: PCKeyCategory = .letters

    // New ADB action states
    @State private var selectedADBActionType: ADBActionType = .homeKey
    @State private var adbInputKeysConfig = ADBInputKeysConfig()
    @State private var adbShellConfig = ADBShellConfig()
    @State private var showingKeySelector = false
    @State private var lastSelectedKeyCategory: KeyCategory = .letters

    let onSave: (ScrcpyAction) -> Void

    // Get the effective device type (from specific device or "any device" selection)
    private var effectiveDeviceType: SessionDeviceType? {
        if useAnyDeviceMode {
            return selectedDeviceType
        }
        return selectedDevice?.sessionModel.deviceType
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Step indicator
                StepIndicatorView(currentStep: currentStep, totalSteps: 3)
                    .padding()

                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        if currentStep == 1 {
                            DeviceSelectionView(
                                selectedDevice: $selectedDevice,
                                selectedDeviceType: $selectedDeviceType,
                                useAnyDeviceMode: $useAnyDeviceMode,
                                onDeviceDoubleTap: {
                                    if hasValidDeviceSelection() {
                                        handleNext()
                                    }
                                }
                            )
                        } else if currentStep == 2 {
                            Step2View(
                                deviceType: effectiveDeviceType?.rawValue ?? "vnc",
                                selectedVNCQuickActions: $selectedVNCQuickActions,
                                vncInputKeysConfig: $vncInputKeysConfig,
                                adbCommands: $adbCommands,
                                selectedADBActionType: $selectedADBActionType,
                                adbInputKeysConfig: $adbInputKeysConfig,
                                adbShellConfig: $adbShellConfig,
                                executionTiming: $executionTiming,
                                delaySeconds: $delaySeconds,
                                onVNCActionDoubleTap: {
                                    if !selectedVNCQuickActions.isEmpty {
                                        handleNext()
                                    }
                                },
                                onShowKeySelector: {
                                    showingKeySelector = true
                                },
                                onShowVNCKeySelector: {
                                    showingVNCKeySelector = true
                                }
                            )
                        } else {
                            Step3View(
                                actionName: $actionName,
                                onSave: {
                                    saveAction()
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("New Action")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: HStack {
                    if currentStep > 1 {
                        Button("Back") {
                            currentStep -= 1
                        }
                    }

                    if currentStep < 3 {
                        Button("Next") {
                            handleNext()
                        }
                        .disabled(!canProceedToNext())
                    } else {
                        Button("Save") {
                            saveAction()
                        }
                        .disabled(actionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            )
        }
        .sheet(isPresented: $showingKeySelector) {
            KeySelectorView(defaultCategory: lastSelectedKeyCategory) { keyCode in
                let keyAction = ADBKeyAction(keyCode: keyCode.rawValue, keyName: keyCode.displayName)
                adbInputKeysConfig.keys.append(keyAction)
                lastSelectedKeyCategory = keyCode.category
            }
        }
        .sheet(isPresented: $showingVNCKeySelector) {
            VNCKeySelectorView(defaultCategory: lastSelectedPCKeyCategory) { keyCode, modifiers in
                let keyAction = VNCKeyAction(keyCode: keyCode.rawValue, keyName: keyCode.displayName, modifiers: modifiers)
                vncInputKeysConfig.keys.append(keyAction)
                lastSelectedPCKeyCategory = keyCode.category
            }
        }
    }

    private func hasValidDeviceSelection() -> Bool {
        if useAnyDeviceMode {
            return selectedDeviceType != nil
        }
        return selectedDevice != nil
    }

    private func generateDefaultActionName() {
        var baseName = ""

        if useAnyDeviceMode, let deviceType = selectedDeviceType {
            // Generate name for "any device" action
            let deviceTypeName = deviceType == .vnc ? "VNC" : "ADB"
            if deviceType == .vnc {
                if selectedVNCQuickActions.isEmpty {
                    baseName = "Any \(deviceTypeName) - Connect"
                } else {
                    let actionNames = selectedVNCQuickActions.map { $0.rawValue }
                    baseName = "Any \(deviceTypeName) - \(actionNames.joined(separator: ", "))"
                }
            } else {
                switch selectedADBActionType {
                case .homeKey:
                    baseName = "Any \(deviceTypeName) - Home Key"
                case .switchKey:
                    baseName = "Any \(deviceTypeName) - Switch Key"
                case .inputKeys:
                    baseName = "Any \(deviceTypeName) - Key Input"
                case .shellCommands:
                    baseName = "Any \(deviceTypeName) - Shell Commands"
                }
            }
        } else if let device = selectedDevice {
            // Generate name for specific device action
            let deviceName = device.sessionModel.sessionName.isEmpty ? "Device" : device.sessionModel.sessionName

            if device.sessionModel.deviceType == .vnc {
                if selectedVNCQuickActions.isEmpty {
                    baseName = "Connect to \(deviceName)"
                } else {
                    let actionNames = selectedVNCQuickActions.map { $0.rawValue }
                    baseName = "\(deviceName) - \(actionNames.joined(separator: ", "))"
                }
            } else {
                switch selectedADBActionType {
                case .homeKey:
                    baseName = "\(deviceName) - Home Key"
                case .switchKey:
                    baseName = "\(deviceName) - Switch Key"
                case .inputKeys:
                    if !adbInputKeysConfig.keys.isEmpty {
                        baseName = "\(deviceName) - Key Input"
                    } else {
                        baseName = "\(deviceName) - Input Keys"
                    }
                case .shellCommands:
                    baseName = "\(deviceName) - Shell Commands"
                }
            }
        }

        actionName = generateUniqueActionName(baseName: baseName)
    }

    private func generateUniqueActionName(baseName: String) -> String {
        let existingNames = ActionManager.shared.actions.map { $0.name }

        if !existingNames.contains(baseName) {
            return baseName
        }

        var counter = 1
        var uniqueName = "\(baseName) \(counter)"

        while existingNames.contains(uniqueName) {
            counter += 1
            uniqueName = "\(baseName) \(counter)"
        }

        return uniqueName
    }

    private func saveAction() {
        guard !actionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        var action = ScrcpyAction()
        action.name = actionName
        action.executionTiming = executionTiming
        action.delaySeconds = delaySeconds

        if useAnyDeviceMode, let deviceType = selectedDeviceType {
            // "Any device" mode - no specific device, only type
            action.deviceId = nil
            action.deviceType = deviceType

            if deviceType == .vnc {
                action.vncQuickActions = Array(selectedVNCQuickActions)
                action.vncInputKeysConfig = vncInputKeysConfig
            } else {
                action.adbActionType = selectedADBActionType
                action.adbInputKeysConfig = adbInputKeysConfig
                action.adbShellConfig = adbShellConfig
                action.adbCommands = adbCommands
            }
        } else if let device = selectedDevice {
            // Specific device mode
            action.deviceId = device.sessionModel.deviceId
            action.deviceType = device.sessionModel.deviceType

            if device.sessionModel.deviceType == .vnc {
                action.vncQuickActions = Array(selectedVNCQuickActions)
                action.vncInputKeysConfig = vncInputKeysConfig
            } else {
                action.adbActionType = selectedADBActionType
                action.adbInputKeysConfig = adbInputKeysConfig
                action.adbShellConfig = adbShellConfig
                action.adbCommands = adbCommands
            }
        }

        onSave(action)
        dismiss()
    }

    private func handleNext() {
        if currentStep == 2 {
            // Only generate default name if no name has been set
            if actionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                generateDefaultActionName()
            }
        }
        if currentStep < 3 {
            currentStep += 1
        }
    }

    private func canProceedToNext() -> Bool {
        switch currentStep {
        case 1:
            return hasValidDeviceSelection()
        case 2:
            guard let deviceType = effectiveDeviceType else { return false }
            if deviceType == .vnc {
                if !selectedVNCQuickActions.isEmpty {
                    // Check specific VNC action requirements
                    if selectedVNCQuickActions.contains(.inputKeys) {
                        return !vncInputKeysConfig.keys.isEmpty
                    } else {
                        return true // Sync Clipboard doesn't need additional config
                    }
                } else {
                    return false
                }
            } else {
                // Check based on selected ADB action type
                switch selectedADBActionType {
                case .homeKey, .switchKey:
                    return true // These don't need additional configuration
                case .inputKeys:
                    return !adbInputKeysConfig.keys.isEmpty
                case .shellCommands:
                    return !adbShellConfig.commands.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            }
        case 3:
            return !actionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }

    private func resetForm() {
        actionName = ""
        selectedDevice = nil
        selectedDeviceType = nil
        useAnyDeviceMode = false
        currentStep = 1
        selectedVNCQuickActions.removeAll()
        vncInputKeysConfig = VNCInputKeysConfig()
        adbCommands = ""
        executionTiming = .confirmation
        delaySeconds = 3
    }
}

// MARK: - Edit Action View

struct EditActionView: View {
    private var dismiss = CompatDismiss()
    @State private var actionName: String
    @State private var selectedDevice: ScrcpySession? = nil
    @State private var currentStep = 1
    @State private var selectedVNCQuickActions: Set<VNCQuickAction>
    @State private var adbCommands: String
    @State private var executionTiming: ExecutionTiming = .confirmation
    @State private var delaySeconds: Int = 3
    @State private var savedSessions: [ScrcpySession] = []

    // New: "Any device" mode support
    @State private var selectedDeviceType: SessionDeviceType?
    @State private var useAnyDeviceMode: Bool

    // VNC action states
    @State private var vncInputKeysConfig: VNCInputKeysConfig
    @State private var showingVNCKeySelector = false
    @State private var lastSelectedPCKeyCategory: PCKeyCategory = .letters

    // ADB action states
    @State private var showingKeySelector = false
    @State private var lastSelectedKeyCategory: KeyCategory = .letters
    @State private var selectedADBActionType: ADBActionType
    @State private var adbInputKeysConfig: ADBInputKeysConfig
    @State private var adbShellConfig: ADBShellConfig

    let action: ScrcpyAction
    let onSave: (ScrcpyAction) -> Void

    init(action: ScrcpyAction, onSave: @escaping (ScrcpyAction) -> Void) {
        self.action = action
        self.onSave = onSave
        // Initialize state with action data
        self._actionName = State(initialValue: action.name)
        self._selectedVNCQuickActions = State(initialValue: Set(action.vncQuickActions))
        self._adbCommands = State(initialValue: action.adbCommands)
        self._executionTiming = State(initialValue: action.executionTiming)
        self._delaySeconds = State(initialValue: action.delaySeconds)
        self._vncInputKeysConfig = State(initialValue: action.vncInputKeysConfig)
        self._selectedADBActionType = State(initialValue: action.adbActionType)
        self._adbInputKeysConfig = State(initialValue: action.adbInputKeysConfig)
        self._adbShellConfig = State(initialValue: action.adbShellConfig)
        // Initialize "any device" mode based on whether the action has a specific device
        self._useAnyDeviceMode = State(initialValue: action.deviceId == nil)
        self._selectedDeviceType = State(initialValue: action.deviceId == nil ? action.deviceType : nil)
    }

    // Get the effective device type (from specific device or "any device" selection)
    private var effectiveDeviceType: SessionDeviceType? {
        if useAnyDeviceMode {
            return selectedDeviceType
        }
        return selectedDevice?.sessionModel.deviceType
    }

    private func hasValidDeviceSelection() -> Bool {
        if useAnyDeviceMode {
            return selectedDeviceType != nil
        }
        return selectedDevice != nil
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Step indicator
                StepIndicatorView(currentStep: currentStep, totalSteps: 3)
                    .padding()

                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        if currentStep == 1 {
                            DeviceSelectionView(
                                selectedDevice: $selectedDevice,
                                selectedDeviceType: $selectedDeviceType,
                                useAnyDeviceMode: $useAnyDeviceMode,
                                onDeviceDoubleTap: {
                                    if hasValidDeviceSelection() {
                                        handleNext()
                                    }
                                }
                            )
                        } else if currentStep == 2 {
                            Step2View(
                                deviceType: effectiveDeviceType?.rawValue ?? action.deviceType.rawValue,
                                selectedVNCQuickActions: $selectedVNCQuickActions,
                                vncInputKeysConfig: $vncInputKeysConfig,
                                adbCommands: $adbCommands,
                                selectedADBActionType: $selectedADBActionType,
                                adbInputKeysConfig: $adbInputKeysConfig,
                                adbShellConfig: $adbShellConfig,
                                executionTiming: $executionTiming,
                                delaySeconds: $delaySeconds,
                                onVNCActionDoubleTap: {
                                    if !selectedVNCQuickActions.isEmpty {
                                        handleNext()
                                    }
                                },
                                onShowKeySelector: {
                                    showingKeySelector = true
                                },
                                onShowVNCKeySelector: {
                                    showingVNCKeySelector = true
                                }
                            )
                        } else {
                            Step3View(
                                actionName: $actionName,
                                onSave: {
                                    saveAction()
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Action")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: HStack {
                    if currentStep > 1 {
                        Button("Back") {
                            currentStep -= 1
                        }
                    }

                    if currentStep < 3 {
                        Button("Next") {
                            handleNext()
                        }
                        .disabled(!canProceedToNext())
                    } else {
                        Button("Save") {
                            saveAction()
                        }
                        .disabled(actionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            )
        }
        .sheet(isPresented: $showingKeySelector) {
            KeySelectorView(defaultCategory: lastSelectedKeyCategory) { keyCode in
                let keyAction = ADBKeyAction(keyCode: keyCode.rawValue, keyName: keyCode.displayName)
                adbInputKeysConfig.keys.append(keyAction)
                lastSelectedKeyCategory = keyCode.category
            }
        }
        .sheet(isPresented: $showingVNCKeySelector) {
            VNCKeySelectorView(defaultCategory: lastSelectedPCKeyCategory) { keyCode, modifiers in
                let keyAction = VNCKeyAction(keyCode: keyCode.rawValue, keyName: keyCode.displayName, modifiers: modifiers)
                vncInputKeysConfig.keys.append(keyAction)
                lastSelectedPCKeyCategory = keyCode.category
            }
        }
        .onAppear {
            loadSavedSessions()
            // Find and select the associated device (if not in "any device" mode)
            if !useAnyDeviceMode, let deviceId = action.deviceId {
                selectedDevice = savedSessions.first { $0.sessionModel.deviceId == deviceId }
            }
        }
    }

    private func handleNext() {
        if currentStep == 2 {
            // Only generate default name if no name has been set
            if actionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                generateDefaultActionName()
            }
        }
        if currentStep < 3 {
            currentStep += 1
        }
    }

    private func canProceedToNext() -> Bool {
        switch currentStep {
        case 1:
            return hasValidDeviceSelection()
        case 2:
            guard let deviceType = effectiveDeviceType else { return false }
            if deviceType == .vnc {
                if !selectedVNCQuickActions.isEmpty {
                    // Check specific VNC action requirements
                    if selectedVNCQuickActions.contains(.inputKeys) {
                        return !vncInputKeysConfig.keys.isEmpty
                    } else {
                        return true // Sync Clipboard doesn't need additional config
                    }
                } else {
                    return false
                }
            } else {
                // Check based on selected ADB action type
                switch selectedADBActionType {
                case .homeKey, .switchKey:
                    return true // These don't need additional configuration
                case .inputKeys:
                    return !adbInputKeysConfig.keys.isEmpty
                case .shellCommands:
                    return !adbShellConfig.commands.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            }
        case 3:
            return !actionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }

    private func generateDefaultActionName() {
        var baseName = ""

        if useAnyDeviceMode, let deviceType = selectedDeviceType {
            // Generate name for "any device" action
            let deviceTypeName = deviceType == .vnc ? "VNC" : "ADB"
            if deviceType == .vnc {
                if selectedVNCQuickActions.isEmpty {
                    baseName = "Any \(deviceTypeName) - Connect"
                } else {
                    let actionNames = selectedVNCQuickActions.map { $0.rawValue }
                    baseName = "Any \(deviceTypeName) - \(actionNames.joined(separator: ", "))"
                }
            } else {
                switch selectedADBActionType {
                case .homeKey:
                    baseName = "Any \(deviceTypeName) - Home Key"
                case .switchKey:
                    baseName = "Any \(deviceTypeName) - Switch Key"
                case .inputKeys:
                    baseName = "Any \(deviceTypeName) - Key Input"
                case .shellCommands:
                    baseName = "Any \(deviceTypeName) - Shell Commands"
                }
            }
        } else if let device = selectedDevice {
            let deviceName = device.sessionModel.sessionName.isEmpty ? "Device" : device.sessionModel.sessionName

            if device.sessionModel.deviceType == .vnc {
                if selectedVNCQuickActions.isEmpty {
                    baseName = "Connect to \(deviceName)"
                } else {
                    let actionNames = selectedVNCQuickActions.map { $0.rawValue }
                    baseName = "\(deviceName) - \(actionNames.joined(separator: ", "))"
                }
            } else {
                switch selectedADBActionType {
                case .homeKey:
                    baseName = "\(deviceName) - Home Key"
                case .switchKey:
                    baseName = "\(deviceName) - Switch Key"
                case .inputKeys:
                    if !adbInputKeysConfig.keys.isEmpty {
                        baseName = "\(deviceName) - Key Input"
                    } else {
                        baseName = "\(deviceName) - Input Keys"
                    }
                case .shellCommands:
                    baseName = "\(deviceName) - Shell Commands"
                }
            }
        }

        let existingNames = ActionManager.shared.actions.filter { $0.id != action.id }.map { $0.name }
        actionName = generateUniqueActionName(baseName: baseName, existingNames: existingNames)
    }

    private func generateUniqueActionName(baseName: String, existingNames: [String]) -> String {
        if !existingNames.contains(baseName) {
            return baseName
        }

        var counter = 1
        var uniqueName = "\(baseName) \(counter)"

        while existingNames.contains(uniqueName) {
            counter += 1
            uniqueName = "\(baseName) \(counter)"
        }

        return uniqueName
    }

    private func saveAction() {
        guard !actionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Create a new action object with updated values
        let updatedAction = ScrcpyAction()
        updatedAction.id = action.id  // Preserve the original ID
        updatedAction.name = actionName
        updatedAction.executionTiming = executionTiming
        updatedAction.delaySeconds = delaySeconds
        updatedAction.createdAt = action.createdAt  // Preserve creation date

        if useAnyDeviceMode, let deviceType = selectedDeviceType {
            // "Any device" mode - no specific device, only type
            updatedAction.deviceId = nil
            updatedAction.deviceType = deviceType

            if deviceType == .vnc {
                updatedAction.vncQuickActions = Array(selectedVNCQuickActions)
                updatedAction.vncInputKeysConfig = vncInputKeysConfig
            } else {
                updatedAction.adbActionType = selectedADBActionType
                updatedAction.adbInputKeysConfig = adbInputKeysConfig
                updatedAction.adbShellConfig = adbShellConfig
                updatedAction.adbCommands = adbCommands
            }

            print("📝 [EditActionView] Saving edited action (any device mode): '\(updatedAction.name)' with device type: \(deviceType.rawValue)")
        } else if let device = selectedDevice {
            // Specific device mode
            updatedAction.deviceId = device.sessionModel.deviceId
            updatedAction.deviceType = device.sessionModel.deviceType

            if device.sessionModel.deviceType == .vnc {
                updatedAction.vncQuickActions = Array(selectedVNCQuickActions)
                updatedAction.vncInputKeysConfig = vncInputKeysConfig
            } else {
                updatedAction.adbActionType = selectedADBActionType
                updatedAction.adbInputKeysConfig = adbInputKeysConfig
                updatedAction.adbShellConfig = adbShellConfig
                updatedAction.adbCommands = adbCommands
            }

            print("📝 [EditActionView] Saving edited action: '\(updatedAction.name)' with device: \(device.sessionModel.sessionName) (deviceId: \(updatedAction.deviceId?.uuidString ?? "nil"))")
        } else {
            print("❌ [EditActionView] Cannot save: no device or device type selected")
            return
        }

        onSave(updatedAction)
        dismiss()
    }

    private func resetForm() {
        actionName = action.name
        selectedVNCQuickActions = Set(action.vncQuickActions)
        vncInputKeysConfig = action.vncInputKeysConfig
        adbCommands = action.adbCommands
        executionTiming = action.executionTiming
        delaySeconds = action.delaySeconds
        useAnyDeviceMode = action.deviceId == nil
        selectedDeviceType = action.deviceId == nil ? action.deviceType : nil
        currentStep = 1
    }

    private func loadSavedSessions() {
        savedSessions = SessionManager.shared.loadSessions().map {
            ScrcpySession(sessionModel: $0)
        }
    }
}
