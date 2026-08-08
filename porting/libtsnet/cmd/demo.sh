#!/bin/bash

# Demo script for libtsnet-forwarder C test program
# This script demonstrates how to build and test the C static library

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}     libtsnet-forwarder C Library Demo Script${NC}"
echo -e "${CYAN}=====================================================${NC}"
echo

# Check if auth key is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Tailscale auth key is required${NC}"
    echo -e "${YELLOW}Usage: $0 <tailscale-auth-key> [hostname] [state-dir]${NC}"
    echo
    echo -e "${BLUE}Examples:${NC}"
    echo -e "  $0 tskey-auth-xxxxxx"
    echo -e "  $0 tskey-auth-xxxxxx my-device"
    echo -e "  $0 tskey-auth-xxxxxx my-device /tmp/custom-tsnet"
    echo
    echo -e "${PURPLE}To get a Tailscale auth key:${NC}"
    echo -e "  1. Visit https://login.tailscale.com/admin/settings/keys"
    echo -e "  2. Generate a new auth key"
    echo -e "  3. Copy the key and use it with this script"
    exit 1
fi

AUTH_KEY="$1"
HOSTNAME="${2:-$(hostname)-c-demo}"
STATE_DIR="${3:-/tmp/tsnet-c-demo}"

echo -e "${BLUE}📋 Configuration:${NC}"
echo -e "   🔑 Auth Key: ${AUTH_KEY:0:10}...${AUTH_KEY: -4}"
echo -e "   🏷️  Hostname: $HOSTNAME"
echo -e "   📁 State Dir: $STATE_DIR"
echo

# Clean previous state
echo -e "${YELLOW}🧹 Cleaning previous state...${NC}"
if [ -d "$STATE_DIR" ]; then
    rm -rf "$STATE_DIR"
    echo -e "${GREEN}   ✅ Cleaned state directory${NC}"
fi

# Build the library and test program
echo -e "${YELLOW}🔨 Building C library and test program...${NC}"
if make build-c-test > /dev/null 2>&1; then
    echo -e "${GREEN}   ✅ Build successful${NC}"
else
    echo -e "${RED}   ❌ Build failed${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 Generated files:${NC}"
ls -lh build/libtsnet-forwarder.* build/c-test 2>/dev/null | while read line; do
    echo -e "   📄 $line"
done
echo

# Run the test
echo -e "${YELLOW}🚀 Running connection test...${NC}"
echo -e "${PURPLE}================================================${NC}"
echo

# Run the C test program
./build/c-test "$AUTH_KEY" "$HOSTNAME" "$STATE_DIR"

echo
echo -e "${PURPLE}================================================${NC}"
echo -e "${GREEN}🎉 Demo completed!${NC}"
echo

# Show additional information
echo -e "${BLUE}📖 What was tested:${NC}"
echo -e "   ✅ C static library compilation"
echo -e "   ✅ C header file generation"
echo -e "   ✅ Authentication key setting"
echo -e "   ✅ Hostname configuration"
echo -e "   ✅ State directory management"
echo -e "   ✅ Tailscale network connection"
echo -e "   ✅ Connection status monitoring"
echo -e "   ✅ MagicDNS and IP information retrieval"
echo -e "   ✅ Error handling and cleanup"
echo

echo -e "${BLUE}🔧 C API Functions tested:${NC}"
echo -e "   • update_tsnet_auth_key()"
echo -e "   • tsnet_update_hostname()"
echo -e "   • tsnet_update_state_dir()"
echo -e "   • tsnet_connect_async()"
echo -e "   • tsnet_get_connect_status()"
echo -e "   • tsnet_get_last_*() functions"
echo -e "   • tsnet_is_started()"
echo -e "   • tsnet_cleanup()"
echo

echo -e "${BLUE}📁 Files for integration:${NC}"
echo -e "   📄 build/libtsnet-forwarder.a (Static library)"
echo -e "   📄 build/libtsnet-forwarder.h (Header file)"
echo

echo -e "${YELLOW}💡 Next steps:${NC}"
echo -e "   1. Copy the .a and .h files to your C/C++ project"
echo -e "   2. Link with: -lpthread -framework CoreFoundation -framework Security -framework IOKit (macOS)"
echo -e "   3. Use the cmd/main.c as a reference for integration"
echo

echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}     Demo completed successfully! 🎊${NC}"
echo -e "${CYAN}=====================================================${NC}" 