# Makefile for libtsnet

.PHONY: all clean build-go build-c-archive build-c-shared test

# Default target
all: build-go build-c-archive

# Build Go library
build-go:
	@echo "Building Go library..."
	go build -o bin/libtsnet-forwarder ./lib

# Build C archive file (static library)
build-c-archive:
	@echo "Building C archive (static library)..."
	@mkdir -p build
	go build -buildmode=c-archive -o build/libtsnet-forwarder.a ./cmd/c-binding
	@echo "Static library built: build/libtsnet-forwarder.a"
	@echo "Header file built: build/libtsnet-forwarder.h"

# Build C shared library (.so file)
build-c-shared:
	@echo "Building C shared library..."
	@mkdir -p build
	go build -buildmode=c-shared -o build/libtsnet-forwarder.so ./cmd/c-binding
	@echo "Shared library built: build/libtsnet-forwarder.so"
	@echo "Header file built: build/libtsnet-forwarder.h"

# iOS device static library build (ARM64)
build-iphoneos-arm64:
	@echo "Building iOS device ARM64 static library..."
	@mkdir -p build/iphoneos/arm64 build/include
	CGO_ENABLED=1 GOOS=ios GOARCH=arm64 CC="$(shell xcrun --sdk iphoneos --find clang)" \
	CGO_CFLAGS="-arch arm64 -isysroot $(shell xcrun --sdk iphoneos --show-sdk-path) -mios-version-min=12.0" \
	CGO_LDFLAGS="-arch arm64 -isysroot $(shell xcrun --sdk iphoneos --show-sdk-path)" \
	go build -tags ios -buildmode=c-archive -o build/iphoneos/arm64/libtsnet-forwarder.a ./cmd/c-binding
	@cp build/iphoneos/arm64/libtsnet-forwarder.h build/include/
	@echo "iOS device ARM64 library built: build/iphoneos/arm64/libtsnet-forwarder.a"
	@echo "Header file copied to: build/include/libtsnet-forwarder.h"

# iOS simulator static library build (x86_64)
build-iphonesimulator-x86_64:
	@echo "Building iOS Simulator x86_64 static library..."
	@mkdir -p build/iphonesimulator/x86_64 build/include
	CGO_ENABLED=1 GOOS=ios GOARCH=amd64 CC="$(shell xcrun --sdk iphonesimulator --find clang)" \
	CGO_CFLAGS="-arch x86_64 -isysroot $(shell xcrun --sdk iphonesimulator --show-sdk-path) -mios-simulator-version-min=12.0" \
	CGO_LDFLAGS="-arch x86_64 -isysroot $(shell xcrun --sdk iphonesimulator --show-sdk-path)" \
	go build -tags ios -buildmode=c-archive -o build/iphonesimulator/x86_64/libtsnet-forwarder.a ./cmd/c-binding
	@cp build/iphonesimulator/x86_64/libtsnet-forwarder.h build/include/
	@echo "iOS Simulator x86_64 library built: build/iphonesimulator/x86_64/libtsnet-forwarder.a"
	@echo "Header file copied to: build/include/libtsnet-forwarder.h"

# iOS simulator static library build (ARM64) for M1/M2 Macs
build-iphonesimulator-arm64:
	@echo "Building iOS Simulator ARM64 static library..."
	@mkdir -p build/iphonesimulator/arm64 build/include
	CGO_ENABLED=1 GOOS=ios GOARCH=arm64 CC="$(shell xcrun --sdk iphonesimulator --find clang)" \
	CGO_CFLAGS="-arch arm64 -isysroot $(shell xcrun --sdk iphonesimulator --show-sdk-path) -mios-simulator-version-min=12.0" \
	CGO_LDFLAGS="-arch arm64 -isysroot $(shell xcrun --sdk iphonesimulator --show-sdk-path)" \
	go build -tags ios -buildmode=c-archive -o build/iphonesimulator/arm64/libtsnet-forwarder.a ./cmd/c-binding
	@cp build/iphonesimulator/arm64/libtsnet-forwarder.h build/include/
	@echo "iOS Simulator ARM64 library built: build/iphonesimulator/arm64/libtsnet-forwarder.a"
	@echo "Header file copied to: build/include/libtsnet-forwarder.h"

# Compatibility targets (maintain backward compatibility)
build-ios-arm64: build-iphoneos-arm64
	@echo "Legacy target: use build-iphoneos-arm64 instead"

build-ios-simulator: build-iphonesimulator-x86_64
	@echo "Legacy target: use build-iphonesimulator-x86_64 instead"

# Build all iOS architectures
build-ios-all: build-iphoneos-arm64 build-iphonesimulator-x86_64 build-iphonesimulator-arm64
	@echo "All iOS architectures built successfully"

# Create universal iOS simulator library (x86_64 + ARM64)
build-iphonesimulator-universal: build-iphonesimulator-x86_64 build-iphonesimulator-arm64
	@echo "Creating universal iOS Simulator library..."
	@mkdir -p build/iphonesimulator/universal
	lipo -create build/iphonesimulator/x86_64/libtsnet-forwarder.a build/iphonesimulator/arm64/libtsnet-forwarder.a -output build/iphonesimulator/universal/libtsnet-forwarder.a
	@echo "Universal iOS Simulator library built: build/iphonesimulator/universal/libtsnet-forwarder.a"

# Create complete universal iOS library (device + simulator)
build-ios-universal: build-iphoneos-arm64 build-iphonesimulator-universal
	@echo "Creating complete universal iOS library..."
	@mkdir -p build/ios/universal
	lipo -create build/iphoneos/arm64/libtsnet-forwarder.a build/iphonesimulator/universal/libtsnet-forwarder.a -output build/ios/universal/libtsnet-forwarder.a
	@echo "Complete universal iOS library built: build/ios/universal/libtsnet-forwarder.a"

# Test Go library
test:
	@echo "Running Go tests..."
	go test ./lib

# Run example program
run-example:
	@echo "Running example program..."
	go run ./cmd/main

# Build C test program
build-c-test: build-c-archive
	@echo "Building C test program..."
	@mkdir -p build
	@if [ "$(shell uname)" = "Darwin" ]; then \
		gcc -o build/c-test cmd/main.c build/libtsnet-forwarder.a -lpthread -framework CoreFoundation -framework Security -framework IOKit; \
	else \
		gcc -o build/c-test cmd/main.c build/libtsnet-forwarder.a -lpthread; \
	fi
	@echo "C test program built: build/c-test"

# Run C test program
run-c-test: build-c-test
	@echo "Running C test program..."
	@if [ -z "$(TS_AUTHKEY)" ]; then \
		echo "Error: TS_AUTHKEY environment variable is not set"; \
		echo "Usage: TS_AUTHKEY=your-auth-key make run-c-test"; \
		exit 1; \
	fi
	@./build/c-test "$(TS_AUTHKEY)" "$(shell hostname)-c-test" "/tmp/tsnet-c-test"

# Clean build files
clean:
	@echo "Cleaning build files..."
	rm -rf build/
	rm -rf bin/
	go clean

# Install dependencies
deps:
	@echo "Installing dependencies..."
	go mod tidy
	go mod download

# Show help
help:
	@echo "Available targets:"
	@echo "  all                          - Build Go library and C static library"
	@echo "  build-go                     - Build Go library only"
	@echo "  build-c-archive              - Build C static library (.a file)"
	@echo "  build-c-shared               - Build C shared library (.so file)"
	@echo "  build-c-test                 - Build C test program"
	@echo ""
	@echo "iOS specific targets:"
	@echo "  build-iphoneos-arm64         - Build iOS device ARM64 static library"
	@echo "  build-iphonesimulator-x86_64 - Build iOS Simulator x86_64 static library"
	@echo "  build-iphonesimulator-arm64  - Build iOS Simulator ARM64 static library (M1/M2 Macs)"
	@echo "  build-ios-all                - Build all iOS architectures"
	@echo "  build-iphonesimulator-universal - Build universal iOS Simulator library (x86_64+ARM64)"
	@echo "  build-ios-universal          - Build complete universal iOS library (device+simulator)"
	@echo ""
	@echo "Legacy targets (deprecated):"
	@echo "  build-ios-arm64              - Use build-iphoneos-arm64 instead"
	@echo "  build-ios-simulator          - Use build-iphonesimulator-x86_64 instead"
	@echo ""
	@echo "Test and run targets:"
	@echo "  test                         - Run Go tests"
	@echo "  run-example                  - Run example program"
	@echo "  run-c-test                   - Run C test program (requires TS_AUTHKEY)"
	@echo ""
	@echo "Other targets:"
	@echo "  clean                        - Clean build files"
	@echo "  deps                         - Install/update dependencies"
	@echo "  help                         - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  TS_AUTHKEY=tskey-auth-xxxxx make run-c-test"
	@echo "  make build-c-test && ./build/c-test tskey-auth-xxxxx my-hostname /tmp/tsnet"
