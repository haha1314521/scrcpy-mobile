//
//  ActionCreationComponents.swift
//  Scrcpy Remote
//
//  Created by Ethan on 12/8/24.
//

import SwiftUI

// MARK: - Device Card View

struct DeviceCardView: View {
    let session: ScrcpySession
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Device Icon
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(session.deviceType == "vnc" ? "vnc" : "android")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            
            // Device Info
            VStack(spacing: 4) {
                Text(session.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .frame(height: 16)
                
                Text("\(session.sessionModel.hostReal):\(session.sessionModel.port)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        // Fill the grid cell width to maintain equal outer margins
        .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
        .onTapGesture(count: 2) {
            onDoubleTap()
        }
        .onTapGesture(count: 1) {
            onTap()
        }
    }
}

// MARK: - Quick Action Card View

struct QuickActionCardView: View {
    let action: VNCQuickAction
    let isSelected: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: action.icon)
                .font(.title2)
                .foregroundColor(isSelected ? .white : .blue)
            
            Text(NSLocalizedString(action.rawValue, comment: "VNC quick action title"))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .multilineTextAlignment(.center)

            Text(NSLocalizedString(action.description, comment: "VNC quick action description"))
                .font(.caption2)
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding()
        // Keep all quick-action cards the same height for visual consistency
        .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
        .onTapGesture(count: 2) {
            onDoubleTap()
        }
        .onTapGesture(count: 1) {
            onTap()
        }
    }
}

// MARK: - ADB Action Type Card View

struct ADBActionTypeCardView: View {
    let actionType: ADBActionType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: actionType.icon)
                .font(.title2)
                .foregroundColor(isSelected ? .white : .blue)
                .frame(height: 24)
            
            Text(NSLocalizedString(actionType.rawValue, comment: "ADB action type title"))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .frame(height: 16)

            Text(NSLocalizedString(actionType.description, comment: "ADB action type description"))
                .font(.caption2)
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 24)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Execution Timing Card View

struct ExecutionTimingCardView: View {
    let timing: ExecutionTiming
    let isSelected: Bool
    let delaySeconds: Int
    let onTap: () -> Void
    let onDelayChange: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: timing.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(timing.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(timing.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .blue : .gray.opacity(0.5))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .onTapGesture {
                onTap()
            }
            
            // Delay time picker for delayed execution
            if timing == .delayed && isSelected {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Delay Time")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    HStack {
                        Text("Wait")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Delay", selection: Binding(
                            get: { delaySeconds },
                            set: { onDelayChange($0) }
                        )) {
                            ForEach([1, 2, 3, 5, 10, 15, 30], id: \.self) { seconds in
                                Text("\(seconds)")
                                    .tag(seconds)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        Text("seconds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.05))
                )
            }
        }
    }
}

// MARK: - Add Key Button View

struct AddKeyButtonView: View {
    var body: some View {
        Text("+")
            .font(.title2)
            .fontWeight(.medium)
            .foregroundColor(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - ADB Input Keys Config View

struct ADBInputKeysConfigView: View {
    @Binding var config: ADBInputKeysConfig
    let onShowKeySelector: (() -> Void)?
    @State private var lastSelectedCategory: KeyCategory = .control
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Input Keys Configuration")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Configure a sequence of keys to send to the device")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Keys list with drag and drop support
            VStack(alignment: .leading, spacing: 8) {
                if !config.keys.isEmpty {
                    HStack {
                        Text("Selected Keys:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("Drag to reorder")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Draggable keys grid with full 2D support
                DraggableKeysGrid(
                    keys: $config.keys,
                    onShowKeySelector: onShowKeySelector
                )
            }
            
            // Interval setting
            HStack {
                Text("Key interval:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Button("-") {
                        if config.intervalMs > 50 {
                            config.intervalMs -= 50
                        }
                    }
                    .disabled(config.intervalMs <= 50)
                    
                    Text("\(config.intervalMs)ms")
                        .font(.caption)
                        .frame(width: 60)
                    
                    Button("+") {
                        if config.intervalMs < 5000 {
                            config.intervalMs += 50
                        }
                    }
                    .disabled(config.intervalMs >= 5000)
                }
                .compatButtonStyleBorderedProminent()
                .compatControlSize(.mini)
                
                Spacer()
            }

            // Validation feedback
            if config.keys.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Please configure at least one key")
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
                .frame(maxWidth: .infinity)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(config.keys.count) key(s) configured")
                        .font(.caption)
                        .foregroundColor(.green)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func moveKey(from source: Int, to destination: Int) {
        guard source >= 0 && source < config.keys.count &&
              destination >= 0 && destination < config.keys.count else {
            return
        }
        
        let movedKey = config.keys.remove(at: source)
        config.keys.insert(movedKey, at: destination)
    }
    
    private func moveKeys(from source: IndexSet, to destination: Int) {
        config.keys.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - Draggable Keys Grid

struct DraggableKeysGrid: View {
    @Binding var keys: [ADBKeyAction]
    let onShowKeySelector: (() -> Void)?
    
    @State private var draggedKey: ADBKeyAction?
    @State private var dragOffset = CGSize.zero
    @State private var draggedIndex: Int?
    
    private let columns = 3
    private let spacing: CGFloat = 8
    
    var body: some View {
        let totalItems = keys.count + 1 // +1 for add button
        let rows = (totalItems + columns - 1) / columns
        
        VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        
                        if index < keys.count {
                            DraggableKeyItemView(
                                keyAction: keys[index],
                                index: index,
                                isDragged: draggedIndex == index,
                                onDragStarted: { key in
                                    draggedKey = key
                                    draggedIndex = index
                                },
                                onDragChanged: { offset in
                                    dragOffset = offset
                                },
                                onDragEnded: { translation in
                                    handleDragEnd(from: index, translation: translation)
                                },
                                onDelete: {
                                    withAnimation(.spring()) {
                                        keys.removeAll { $0.id == keys[index].id }
                                    }
                                }
                            )
                        } else if index == keys.count {
                            // Add button
                            Button {
                                onShowKeySelector?()
                            } label: {
                                AddKeyButtonView()
                            }
                        } else {
                            // Empty space
                            Spacer()
                                .frame(height: 56)
                        }
                    }
                }
            }
        }
    }
    
    private func handleDragEnd(from sourceIndex: Int, translation: CGSize) {
        let targetIndex = calculateTargetIndex(from: sourceIndex, translation: translation)
        
        if targetIndex != sourceIndex && targetIndex >= 0 && targetIndex < keys.count {
            withAnimation(.spring()) {
                let movedKey = keys.remove(at: sourceIndex)
                keys.insert(movedKey, at: targetIndex)
            }
        }
        
        // Reset drag state
        draggedKey = nil
        draggedIndex = nil
        dragOffset = .zero
    }
    
    private func calculateTargetIndex(from sourceIndex: Int, translation: CGSize) -> Int {
        // Estimate grid cell size (this is approximate)
        let cellWidth: CGFloat = 100 // Approximate width
        let cellHeight: CGFloat = 64 // Approximate height including spacing
        
        // Calculate how many cells to move horizontally and vertically
        let horizontalMove = Int(translation.width / cellWidth)
        let verticalMove = Int(translation.height / cellHeight)
        
        // Calculate source position in grid
        let sourceRow = sourceIndex / columns
        let sourceColumn = sourceIndex % columns
        
        // Calculate target position
        let targetRow = max(0, sourceRow + verticalMove)
        let targetColumn = max(0, min(columns - 1, sourceColumn + horizontalMove))
        
        // Convert back to index
        let targetIndex = targetRow * columns + targetColumn
        
        // Clamp to valid range
        return max(0, min(keys.count - 1, targetIndex))
    }
}

// MARK: - Draggable Key Item View

struct DraggableKeyItemView: View {
    let keyAction: ADBKeyAction
    let index: Int
    let isDragged: Bool
    let onDragStarted: (ADBKeyAction) -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void
    let onDelete: () -> Void
    
    @State private var dragOffset = CGSize.zero
    @State private var showingControls = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 4) {
                // Key name and code
                VStack(spacing: 2) {
                    Text(keyAction.keyName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    Text("\(keyAction.keyCode)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Position indicator when showing controls
                if showingControls {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.point.up.left")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        
                        Text("Position \(index + 1)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(isDragged ? Color.blue.opacity(0.2) : (showingControls ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05)))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isDragged ? Color.blue : (showingControls ? Color.blue : Color.gray.opacity(0.3)), 
                           lineWidth: isDragged ? 3 : (showingControls ? 2 : 1))
            )
            .scaleEffect(isDragged ? 1.1 : 1.0)
            .shadow(color: isDragged ? Color.black.opacity(0.3) : Color.clear, radius: isDragged ? 12 : 0)
            .offset(dragOffset)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingControls)
            .animation(.spring(response: 0.2, dampingFraction: 0.9), value: isDragged)
            .onTapGesture {
                showingControls.toggle()
            }
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        if dragOffset == .zero {
                            onDragStarted(keyAction)
                            showingControls = false
                        }
                        dragOffset = value.translation
                        onDragChanged(value.translation)
                    }
                    .onEnded { value in
                        onDragEnded(value.translation)
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
            )
            
            // Delete button
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
            }
            .offset(x: 8, y: -8)
            .opacity(isDragged ? 0.3 : 1.0)
        }
    }
}

// MARK: - ADB Shell Config View

struct ADBShellConfigView: View {
    @Binding var config: ADBShellConfig
    @State private var showingExamples = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Shell Commands Configuration")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Enter shell commands to execute on the Android device")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Interval setting with improved alignment
            VStack(alignment: .leading, spacing: 8) {
                Text("Command interval:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                HStack {
                    Button("-") {
                        if config.intervalMs > 0 {
                            config.intervalMs -= 100
                        }
                    }
                    .disabled(config.intervalMs <= 0)
                    
                    Text("\(config.intervalMs)ms")
                        .font(.caption)
                        .frame(width: 60)
                        .multilineTextAlignment(.center)
                    
                    Button("+") {
                        if config.intervalMs < 10000 {
                            config.intervalMs += 100
                        }
                    }
                    .disabled(config.intervalMs >= 10000)
                    
                    Spacer()
                    
                    Button {
                        showingExamples.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb")
                                .font(.caption)
                            Text("Examples")
                                .font(.caption)
                        }
                    }
                    .compatButtonStyleBordered()
                    .compatControlSize(.mini)
                }
                .compatButtonStyleBorderedProminent()
                .compatControlSize(.mini)
            }
            .padding(.vertical, 4)
            
            // Examples section
            if showingExamples {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Common ADB Shell Examples")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button {
                            showingExamples = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
                        ExampleCommandView(
                            title: "Open WeChat",
                            command: "am start -n com.tencent.mm/.ui.LauncherUI",
                            description: "Launch WeChat app"
                        ) {
                            addExampleCommand("am start -n com.tencent.mm/.ui.LauncherUI")
                        }
                        
                        ExampleCommandView(
                            title: "Open QQ",
                            command: "am start -n com.tencent.mobileqq/.activity.SplashActivity",
                            description: "Launch QQ app"
                        ) {
                            addExampleCommand("am start -n com.tencent.mobileqq/.activity.SplashActivity")
                        }
                        
                        ExampleCommandView(
                            title: "Open Settings",
                            command: "am start -a android.settings.SETTINGS",
                            description: "Open Android Settings"
                        ) {
                            addExampleCommand("am start -a android.settings.SETTINGS")
                        }
                        
                        ExampleCommandView(
                            title: "Input Text",
                            command: "input text \"Hello World\"",
                            description: "Type text on screen"
                        ) {
                            addExampleCommand("input text \"Hello World\"")
                        }
                        
                        ExampleCommandView(
                            title: "Take Screenshot",
                            command: "screencap -p /sdcard/screenshot.png",
                            description: "Capture screen to file"
                        ) {
                            addExampleCommand("screencap -p /sdcard/screenshot.png")
                        }
                        
                        ExampleCommandView(
                            title: "Send Key Event",
                            command: "input keyevent KEYCODE_HOME",
                            description: "Send Home key press"
                        ) {
                            addExampleCommand("input keyevent KEYCODE_HOME")
                        }
                        
                        ExampleCommandView(
                            title: "Get Device Info",
                            command: "getprop ro.product.model",
                            description: "Get device model info"
                        ) {
                            addExampleCommand("getprop ro.product.model")
                        }
                        
                        ExampleCommandView(
                            title: "Wait Command",
                            command: "sleep 2",
                            description: "Wait 2 seconds"
                        ) {
                            addExampleCommand("sleep 2")
                        }
                    }
                }
                .padding(12)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
            }
            
            // Commands input area
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Commands:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("One command per line")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                TextEditor(text: $config.commands)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .font(.system(.caption, design: .monospaced))
            }
            
            // Validation feedback
            if config.commands.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Please enter at least one shell command")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
                .frame(maxWidth: .infinity)
            } else {
                let commandCount = config.commands.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .count
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(commandCount) command(s) configured")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func addExampleCommand(_ command: String) {
        if config.commands.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            config.commands = command
        } else {
            config.commands += "\n" + command
        }
    }
}

// MARK: - Example Command View

struct ExampleCommandView: View {
    let title: String
    let command: String
    let description: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "plus.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                
                Text(command)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - VNC Input Keys Config View

struct VNCInputKeysConfigView: View {
    @Binding var config: VNCInputKeysConfig
    let onShowKeySelector: (() -> Void)?
    @State private var lastSelectedCategory: PCKeyCategory = .control
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VNC Input Keys Configuration")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Configure a sequence of keys to send to the VNC device")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Keys list with drag and drop support
            VStack(alignment: .leading, spacing: 8) {
                if !config.keys.isEmpty {
                    HStack {
                        Text("Selected Keys:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("Drag to reorder")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Draggable keys grid for VNC
                DraggableVNCKeysGrid(
                    keys: $config.keys,
                    onShowKeySelector: onShowKeySelector
                )
            }
            
            // Interval setting
            HStack {
                Text("Key interval:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Button("-") {
                        if config.intervalMs > 50 {
                            config.intervalMs -= 50
                        }
                    }
                    .disabled(config.intervalMs <= 50)
                    
                    Text("\(config.intervalMs)ms")
                        .font(.caption)
                        .frame(width: 60)
                    
                    Button("+") {
                        if config.intervalMs < 5000 {
                            config.intervalMs += 50
                        }
                    }
                    .disabled(config.intervalMs >= 5000)
                }
                .compatButtonStyleBorderedProminent()
                .compatControlSize(.mini)
                
                Spacer()
            }

            // Validation feedback
            if config.keys.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Please configure at least one key")
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
                .frame(maxWidth: .infinity)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(config.keys.count) key(s) configured")
                        .font(.caption)
                        .foregroundColor(.green)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Draggable VNC Keys Grid

struct DraggableVNCKeysGrid: View {
    @Binding var keys: [VNCKeyAction]
    let onShowKeySelector: (() -> Void)?
    
    @State private var draggedKey: VNCKeyAction?
    @State private var dragOffset = CGSize.zero
    @State private var draggedIndex: Int?
    
    private let columns = 3
    private let spacing: CGFloat = 8
    
    var body: some View {
        let totalItems = keys.count + 1 // +1 for add button
        let rows = (totalItems + columns - 1) / columns
        
        VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        
                        if index < keys.count {
                            DraggableVNCKeyItemView(
                                keyAction: keys[index],
                                index: index,
                                isDragged: draggedIndex == index,
                                onDragStarted: { key in
                                    draggedKey = key
                                    draggedIndex = index
                                },
                                onDragChanged: { offset in
                                    dragOffset = offset
                                },
                                onDragEnded: { translation in
                                    handleDragEnd(from: index, translation: translation)
                                },
                                onDelete: {
                                    withAnimation(.spring()) {
                                        keys.removeAll { $0.id == keys[index].id }
                                    }
                                }
                            )
                        } else if index == keys.count {
                            // Add button
                            Button {
                                onShowKeySelector?()
                            } label: {
                                AddKeyButtonView()
                            }
                        } else {
                            // Empty space
                            Spacer()
                                .frame(height: 56)
                        }
                    }
                }
            }
        }
    }
    
    private func handleDragEnd(from sourceIndex: Int, translation: CGSize) {
        let targetIndex = calculateTargetIndex(from: sourceIndex, translation: translation)
        
        if targetIndex != sourceIndex && targetIndex >= 0 && targetIndex < keys.count {
            withAnimation(.spring()) {
                let movedKey = keys.remove(at: sourceIndex)
                keys.insert(movedKey, at: targetIndex)
            }
        }
        
        // Reset drag state
        draggedKey = nil
        draggedIndex = nil
        dragOffset = .zero
    }
    
    private func calculateTargetIndex(from sourceIndex: Int, translation: CGSize) -> Int {
        // Estimate grid cell size (this is approximate)
        let cellWidth: CGFloat = 100 // Approximate width
        let cellHeight: CGFloat = 64 // Approximate height including spacing
        
        // Calculate how many cells to move horizontally and vertically
        let horizontalMove = Int(translation.width / cellWidth)
        let verticalMove = Int(translation.height / cellHeight)
        
        // Calculate source position in grid
        let sourceRow = sourceIndex / columns
        let sourceColumn = sourceIndex % columns
        
        // Calculate target position
        let targetRow = max(0, sourceRow + verticalMove)
        let targetColumn = max(0, min(columns - 1, sourceColumn + horizontalMove))
        
        // Convert back to index
        let targetIndex = targetRow * columns + targetColumn
        
        // Clamp to valid range
        return max(0, min(keys.count - 1, targetIndex))
    }
}

// MARK: - Draggable VNC Key Item View

struct DraggableVNCKeyItemView: View {
    let keyAction: VNCKeyAction
    let index: Int
    let isDragged: Bool
    let onDragStarted: (VNCKeyAction) -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void
    let onDelete: () -> Void
    
    @State private var dragOffset = CGSize.zero
    @State private var showingControls = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 4) {
                // Key name and code with modifiers
                VStack(spacing: 2) {
                    Text(keyAction.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                    
                    Text("\(keyAction.keyCode)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Position indicator when showing controls
                if showingControls {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.point.up.left")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        
                        Text("Position \(index + 1)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(isDragged ? Color.blue.opacity(0.2) : (showingControls ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05)))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isDragged ? Color.blue : (showingControls ? Color.blue : Color.gray.opacity(0.3)), 
                           lineWidth: isDragged ? 3 : (showingControls ? 2 : 1))
            )
            .scaleEffect(isDragged ? 1.1 : 1.0)
            .shadow(color: isDragged ? Color.black.opacity(0.3) : Color.clear, radius: isDragged ? 12 : 0)
            .offset(dragOffset)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingControls)
            .animation(.spring(response: 0.2, dampingFraction: 0.9), value: isDragged)
            .onTapGesture {
                showingControls.toggle()
            }
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        if dragOffset == .zero {
                            onDragStarted(keyAction)
                            showingControls = false
                        }
                        dragOffset = value.translation
                        onDragChanged(value.translation)
                    }
                    .onEnded { value in
                        onDragEnded(value.translation)
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
            )
            
            // Delete button
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
            }
            .offset(x: 8, y: -8)
            .opacity(isDragged ? 0.3 : 1.0)
        }
    }
}

// MARK: - VNC Key Selector View

struct VNCKeySelectorView: View {
    var dismiss = CompatDismiss()
    let onKeySelected: (PCKeyCode, [VNCKeyModifier]) -> Void
    let defaultCategory: PCKeyCategory?
    
    @State private var selectedCategory: PCKeyCategory = .letters
    @State private var selectedModifiers: Set<VNCKeyModifier> = []
    @State private var searchText = ""
    
    init(defaultCategory: PCKeyCategory? = nil, onKeySelected: @escaping (PCKeyCode, [VNCKeyModifier]) -> Void) {
        self.defaultCategory = defaultCategory
        self.onKeySelected = onKeySelected
    }
    
    var filteredKeys: [PCKeyCode] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return PCKeyCode.allCases.filter { $0.category == selectedCategory }
        } else {
            // Search across all keys regardless of selected category
            return PCKeyCode.allCases.filter { $0.displayName.localizedCaseInsensitiveContains(trimmed) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                VStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search keys...", text: $searchText)
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
                
                // Modifier selector
                VStack(alignment: .leading) {
                    Text("Modifiers (Optional)")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(VNCKeyModifier.allCases, id: \.self) { modifier in
                                Button {
                                    if selectedModifiers.contains(modifier) {
                                        selectedModifiers.remove(modifier)
                                    } else {
                                        selectedModifiers.insert(modifier)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: modifier.icon)
                                            .font(.caption)
                                    Text(LocalizedStringKey(modifier.rawValue))
                                        .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        selectedModifiers.contains(modifier) ? Color.blue : Color.gray.opacity(0.1)
                                    )
                                    .foregroundColor(
                                        selectedModifiers.contains(modifier) ? .white : .primary
                                    )
                                    .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Category selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(PCKeyCategory.allCases, id: \.self) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: category.icon)
                                        .font(.caption)
                                    Text(LocalizedStringKey(category.rawValue))
                                        .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    selectedCategory == category ? Color.green : Color.gray.opacity(0.1)
                                )
                                .foregroundColor(
                                    selectedCategory == category ? .white : .primary
                                )
                                .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
                
                // Keys grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(filteredKeys, id: \.self) { keyCode in
                            Button {
                                onKeySelected(keyCode, Array(selectedModifiers))
                                dismiss()
                            } label: {
                                VStack(spacing: 4) {
                                    Text(keyCode.displayName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                    
                                    Text("\(keyCode.rawValue)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(NSLocalizedString("Select PC Key", comment: "Select PC key title"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button(NSLocalizedString("Cancel", comment: "Cancel")) {
                    dismiss()
                }
            )
            .onAppear {
                if let defaultCategory = defaultCategory {
                    selectedCategory = defaultCategory
                }
            }
        }
    }
}

// MARK: - Key Selector View

struct KeySelectorView: View {
    var dismiss = CompatDismiss()
    let onKeySelected: (AndroidKeyCode) -> Void
    let defaultCategory: KeyCategory?
    
    @State private var selectedCategory: KeyCategory = .letters
    @State private var searchText = ""
    
    init(defaultCategory: KeyCategory? = nil, onKeySelected: @escaping (AndroidKeyCode) -> Void) {
        self.defaultCategory = defaultCategory
        self.onKeySelected = onKeySelected
    }
    
    var filteredKeys: [AndroidKeyCode] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return AndroidKeyCode.allCases.filter { $0.category == selectedCategory }
        } else {
            // Search across all keys regardless of selected category
            return AndroidKeyCode.allCases.filter { $0.displayName.localizedCaseInsensitiveContains(trimmed) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                VStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search keys...", text: $searchText)
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
                
                // Category selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(KeyCategory.allCases, id: \.self) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: category.icon)
                                        .font(.caption)
                                    Text(LocalizedStringKey(category.rawValue))
                                        .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    selectedCategory == category ? Color.blue : Color.gray.opacity(0.1)
                                )
                                .foregroundColor(
                                    selectedCategory == category ? .white : .primary
                                )
                                .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Keys grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(filteredKeys, id: \.self) { keyCode in
                            Button {
                                onKeySelected(keyCode)
                                dismiss()
                            } label: {
                                VStack(spacing: 4) {
                                    Text(keyCode.displayName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                    
                                    Text("\(keyCode.rawValue)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Select Key")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    dismiss()
                }
            )
            .onAppear {
                if let defaultCategory = defaultCategory {
                    selectedCategory = defaultCategory
                }
            }
        }
    }
}
