# libtsnet-forwarder - Tailscale Network Forwarding Library

<div align="center">

[![Go Version](https://img.shields.io/badge/Go-1.19+-blue.svg)](https://golang.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20iOS-green.svg)](#supported-platforms)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/Build-Passing-brightgreen.svg)](#build-instructions)

*A powerful Tailscale network proxy forwarding library supporting cross-platform deployment and iOS static library integration*

</div>

---

## 📖 Table of Contents

- [Project Overview](#-project-overview)
- [Features](#-features)
- [Quick Start](#-quick-start)
- [API Reference](#-api-reference)
- [Build Instructions](#-build-instructions)
- [iOS Integration](#-ios-integration)
- [Example Code](#-example-code)
- [Supported Platforms](#-supported-platforms)
- [FAQ](#-faq)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🚀 Project Overview

**libtsnet** is a Tailscale network forwarding library developed in Go, designed to simplify local port proxying for Tailscale subnet devices. The library provides complete C/Go API interfaces and supports building as a static library, especially suitable for iOS application integration.

### 🎯 Core Advantages

- **Zero Configuration Deployment** - Simple API calls enable network forwarding
- **Cross-Platform Support** - Supports macOS, Linux, iOS and other platforms
- **Static Library Integration** - Can be packaged as iOS static library with no runtime dependencies
- **Real-time Callbacks** - Provides detailed forwarding status monitoring and error handling
- **High Performance** - Based on Go's high-concurrency network processing capabilities

---

## ✨ Features

| Feature | Description | Status |
|---------|-------------|--------|
| 🔐 **Authentication Management** | Supports Tailscale AuthKey authentication | ✅ |
| 🔄 **Port Forwarding** | Transparent proxy from Tailscale devices to local ports | ✅ |
| 🎛️ **Forward Management** | Dynamic start/stop of individual or batch forwards | ✅ |
| 📞 **Status Callbacks** | Real-time monitoring of forwarding status and exceptions | ✅ |
| 📱 **iOS Support** | Static library integration, supports ARM64/x86_64 | ✅ |
| 🌐 **Multi-Platform** | Full platform support for macOS, Linux, iOS | ✅ |

---

## 🚀 Quick Start

### Prerequisites

- Go 1.19 or higher
- Valid Tailscale account and AuthKey
- Target device already joined to Tailscale network

### Install Dependencies

```bash
# Clone the project
git clone https://github.com/your-org/libtsnet.git
cd libtsnet

# Install dependencies
make deps
```

### Basic Usage

```go
package main

import (
    "log"
    "time"
    forwarder "me.wsen.scrcpy-tsnet/lib"
)

func main() {
    // 1. Get forwarder instance
    f := forwarder.GetInstance()
    
    // 2. Set Tailscale authentication key
    err := f.UpdateTsnetAuthKey("tskey-auth-xxxxxx")
    if err != nil {
        log.Fatalf("Authentication failed: %v", err)
    }
    
    // 3. Start port forwarding: forward 100.78.206.85:8000 to local :8080
    err = f.TsnetStartForward("100.78.206.85", 8000, 8080)
    if err != nil {
        log.Fatalf("Failed to start forwarding: %v", err)
    }
    
    log.Println("🎉 Forwarding started! Visit http://localhost:8080")
    
    // 4. Keep program running
    time.Sleep(30 * time.Second)
    
    // 5. Cleanup resources
    f.Cleanup()
}
```

---

## 📚 API Reference

### Go API

#### 🔧 Basic Operations

```go
// Get global instance
forwarder := libtsnet_forwarder.GetInstance()

// Authentication setup
err := forwarder.UpdateTsnetAuthKey("your-auth-key")

// Start forwarding
err := forwarder.TsnetStartForward("100.78.206.85", 8000, 8080)

// Stop specific forwarding
count := forwarder.TsnetStopForward("100.78.206.85", 8000, 8080)

// Stop all forwarding
count := forwarder.TsnetStopAllForwards()

// Cleanup resources
count := forwarder.Cleanup()
```

#### 📞 Callback Handling

```go
callback := &libtsnet_forwarder.ForwardCallback{
    OnForwardSuccess: func(remoteAddr string, remotePort int, localPort int) {
        log.Printf("✅ Forward successful: %s:%d -> :%d", remoteAddr, remotePort, localPort)
    },
    OnForwardClosed: func(remoteAddr string, remotePort int, localPort int) {
        log.Printf("🔴 Forward closed: %s:%d -> :%d", remoteAddr, remotePort, localPort)
    },
    OnForwardError: func(remoteAddr string, remotePort int, localPort int, err error) {
        log.Printf("❌ Forward error: %s:%d -> :%d, error: %v", remoteAddr, remotePort, localPort, err)
    },
}
forwarder.TsnetRegisterCallback(callback)
```

### C API

#### 🔧 Basic Operations

```c
#include "libtsnet-forwarder.h"

// Set authentication key
int result = update_tsnet_auth_key("your-auth-key");

// Start port forwarding
int result = tsnet_start_forward("100.78.206.85", 8000, 8080);

// Stop port forwarding
int count = tsnet_stop_forward("100.78.206.85", 8000, 8080);

// Stop all forwarding
int count = tsnet_stop_all_forwards();

// Check service status
int is_started = tsnet_is_started();

// Get Tailscale IP
char* ip = tsnet_get_tailscale_ips();

// Cleanup resources
int count = tsnet_cleanup();
```

#### 🔗 Connection Testing

```c
#include "libtsnet-forwarder.h"

// Set configuration
update_tsnet_auth_key("your-auth-key");
tsnet_update_hostname("my-device");
tsnet_update_state_dir("/tmp/tsnet-state");

// Connect to Tailscale (async)
tsnet_connect_async();

// Monitor connection status
int status = tsnet_get_connect_status();
if (status == 1) {
    // Connection successful - get information
    char* hostname = tsnet_get_last_hostname();
    char* magic_dns = tsnet_get_last_magic_dns();
    char* ipv4 = tsnet_get_last_ipv4();
    char* ipv6 = tsnet_get_last_ipv6();
    
    printf("Connected: %s (%s)\n", hostname, magic_dns);
    printf("IPv4: %s, IPv6: %s\n", ipv4, ipv6);
    
    // Remember to free allocated strings
    free(hostname); free(magic_dns); free(ipv4); free(ipv6);
}
```

---

## 🔨 Build Instructions

### Available Build Targets

| Command | Description | Output |
|---------|-------------|--------|
| `make deps` | Install project dependencies | - |
| `make build-go` | Build Go library | `build/` |
| `make build-c-archive` | Build C static library | `build/libtsnet-forwarder.a` |
| `make build-c-shared` | Build C shared library | `build/libtsnet.so` |
| `make build-c-test` | Build C test program | `build/c-test` |
| `make build-ios-arm64` | Build iOS ARM64 static library | `build/ios/` |
| `make build-ios-simulator` | Build iOS simulator library | `build/ios/` |
| `make build-ios-universal` | Build iOS universal library | `build/ios/libtsnet-forwarder.a` |
| `make test` | Run test suite | - |
| `make run-example` | Run example program | - |
| `make run-c-test` | Run C test program | - |

### C Test Program

The project includes a comprehensive C test program that demonstrates all library features:

```bash
# Quick test with environment variable
TS_AUTHKEY="your-tailscale-auth-key" make run-c-test

# Manual build and run
make build-c-test
./build/c-test "tskey-auth-xxxxxx" "my-hostname" "/tmp/tsnet-test"

# Interactive demo script
./cmd/demo.sh "tskey-auth-xxxxxx"
```

The C test program features:
- ✅ **Complete API Testing** - Tests all C API functions
- ✅ **Connection Monitoring** - Real-time connection status tracking
- ✅ **Information Display** - Shows MagicDNS, IPv4, and IPv6 addresses
- ✅ **Error Handling** - Comprehensive error reporting and timeout management
- ✅ **Memory Management** - Proper cleanup of allocated resources
- ✅ **Colorized Output** - User-friendly interface with color-coded messages

See `cmd/README-C-TEST.md` for detailed usage instructions.

### Build Steps

```bash
# 1. Install dependencies
make deps

# 2. Build required targets
make build-go               # Go library
make build-c-archive        # C static library
make build-ios-universal    # iOS universal library

# 3. Run tests
make test

# 4. Run example
export TS_AUTHKEY="your-tailscale-auth-key"
make run-example
```

---

## 📱 iOS Integration

### Quick Integration Steps

#### 1️⃣ Build iOS Library

```bash
# Build universal static library (supports device and simulator)
make build-ios-universal
```

#### 2️⃣ Add to iOS Project

Add the following files to your iOS project:

```
build/ios/
├── libtsnet-forwarder.a    # Static library file
└── libtsnet-forwarder.h    # C header file
```

#### 3️⃣ Project Configuration

Configure in Xcode:

1. **Link Binary With Libraries** - Add `libtsnet-forwarder.a`
2. **Header Search Paths** - Add header file path
3. **Build Settings** - Ensure support for C++/Objective-C++

#### 4️⃣ Code Usage

```objc
#include "libtsnet-forwarder.h"

// Use in your iOS code
- (void)startForwarding {
    // Set authentication
    int result = update_tsnet_auth_key("your-auth-key");
    
    // Start forwarding
    result = tsnet_start_forward("100.78.206.85", 8000, 8080);
    
    if (result == 0) {
        NSLog(@"✅ Forwarding started successfully");
    }
}
```

### Architecture Support

| Architecture | Support Status | Usage |
|--------------|----------------|-------|
| `arm64` | ✅ | iPhone/iPad devices |
| `x86_64` | ✅ | iOS Simulator |
| `armv7` | ❌ | Not supported (deprecated) |

---

## 📋 Example Code

### Complete Example Program

The project includes a complete example program located at `cmd/main/main.go`:

```bash
# Set environment variable
export TS_AUTHKEY="your-tailscale-auth-key"

# Run example
make run-example
```

### Advanced Usage Example

```go
package main

import (
    "context"
    "log"
    "os"
    "os/signal"
    "syscall"
    "time"
    
    forwarder "me.wsen.scrcpy-tsnet/lib"
)

func main() {
    // Create context for graceful shutdown
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()
    
    // Signal handling
    sigChan := make(chan os.Signal, 1)
    signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
    
    // Initialize forwarder
    f := forwarder.GetInstance()
    
    // Set detailed callback handling
    callback := &forwarder.ForwardCallback{
        OnForwardSuccess: func(remoteAddr string, remotePort int, localPort int) {
            log.Printf("🟢 [SUCCESS] %s:%d ➜ localhost:%d", remoteAddr, remotePort, localPort)
        },
        OnForwardClosed: func(remoteAddr string, remotePort int, localPort int) {
            log.Printf("🔴 [CLOSED] %s:%d ➜ localhost:%d", remoteAddr, remotePort, localPort)
        },
        OnForwardError: func(remoteAddr string, remotePort int, localPort int, err error) {
            log.Printf("❌ [ERROR] %s:%d ➜ localhost:%d | %v", remoteAddr, remotePort, localPort, err)
        },
    }
    f.TsnetRegisterCallback(callback)
    
    // Authentication
    authKey := os.Getenv("TS_AUTHKEY")
    if authKey == "" {
        log.Fatal("❌ Please set TS_AUTHKEY environment variable")
    }
    
    if err := f.UpdateTsnetAuthKey(authKey); err != nil {
        log.Fatalf("❌ Authentication failed: %v", err)
    }
    
    // Start multiple forwards
    forwards := []struct {
        addr string
        remote, local int
    }{
        {"100.78.206.85", 8000, 8080},
        {"100.78.206.85", 22, 2222},
        {"100.78.206.85", 3389, 3389},
    }
    
    for _, fw := range forwards {
        if err := f.TsnetStartForward(fw.addr, fw.remote, fw.local); err != nil {
            log.Printf("❌ Failed to start forward %s:%d->:%d: %v", fw.addr, fw.remote, fw.local, err)
        } else {
            log.Printf("🚀 Started forward: %s:%d ➜ localhost:%d", fw.addr, fw.remote, fw.local)
        }
    }
    
    log.Println("🎉 All forwards started, press Ctrl+C to exit")
    
    // Wait for exit signal
    select {
    case <-sigChan:
        log.Println("🛑 Received exit signal, cleaning up...")
    case <-ctx.Done():
        log.Println("🛑 Context cancelled, cleaning up...")
    }
    
    // Graceful shutdown
    count := f.Cleanup()
    log.Printf("✅ Cleaned up %d forward connections", count)
}
```

---

## 💻 Supported Platforms

| Platform | Architecture | Status | Notes |
|----------|--------------|--------|-------|
| **macOS** | amd64, arm64 | ✅ | Full support |
| **Linux** | amd64, arm64 | ✅ | Full support |
| **iOS** | arm64 | ✅ | Static library integration |
| **iOS Simulator** | x86_64 | ✅ | Development debugging |
| **Windows** | amd64 | 🔄 | Planned support |
| **Android** | arm64 | 🔄 | Planned support |

---

## ❓ FAQ

### Q: How to get Tailscale AuthKey?

**A:** Log in to [Tailscale Console](https://login.tailscale.com/admin/settings/keys), generate a new Auth Key in Settings > Keys page.

### Q: What to do when forwarding fails to start?

**A:** Please check:
1. Whether the target device is in the Tailscale network
2. Whether the AuthKey is valid
3. Whether the local port is occupied
4. Whether firewall settings allow it

### Q: Compilation errors during iOS integration?

**A:** Ensure:
1. Using the correct architecture version (arm64/x86_64)
2. Project settings support C++/Objective-C++
3. Header file paths are configured correctly

### Q: How to debug network connection issues?

**A:** Enable verbose logging:
```go
// Set callbacks to monitor all events
f.TsnetRegisterCallback(callback)

// Check Tailscale connection status
ip := tsnet_get_tailscale_ips()
log.Printf("Tailscale IP: %s", ip)
```

---

## 🤝 Contributing

We welcome community contributions! Please follow these steps:

### Development Environment Setup

```bash
# 1. Fork the project and clone
git clone https://github.com/your-username/libtsnet.git
cd libtsnet

# 2. Install dependencies
make deps

# 3. Run tests
make test

# 4. Create feature branch
git checkout -b feature/your-feature-name
```

### Commit Conventions

- 🐛 `fix:` Bug fixes
- ✨ `feat:` New features
- 📚 `docs:` Documentation updates
- 🔧 `refactor:` Code refactoring
- ✅ `test:` Test related

### Pull Request Process

1. Ensure all tests pass
2. Update relevant documentation
3. Create Pull Request
4. Wait for code review

---

## 📄 License

This project is open sourced under the [MIT License](LICENSE).

```
MIT License

Copyright (c) 2024 libtsnet

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction...
```

---

## 🔗 Related Links

- [Tailscale Official Documentation](https://tailscale.com/kb/)
- [Go Official Website](https://golang.org/)
- [Project Issues](https://github.com/your-org/libtsnet/issues)
- [Project Wiki](https://github.com/your-org/libtsnet/wiki)

---

<div align="center">

*Made with ❤️ by the libtsnet team*

</div>
