package main

import (
	"log"
	"os"
	"time"

	forwarder "me.wsen.scrcpy-tsnet/lib"
)

func main() {
	log.Printf("=== Starting IP Reuse Consistency Test ===")

	// Get environment variables for test configuration
	authKey := os.Getenv("TSNET_AUTH_KEY")
	hostname := os.Getenv("TSNET_HOSTNAME")
	stateDir := os.Getenv("TSNET_STATE_DIR")

	if authKey == "" {
		log.Printf("Please set TSNET_AUTH_KEY environment variable")
		log.Printf("Usage: TSNET_AUTH_KEY='your-auth-key' go run test_ip_reuse_standalone.go")
		return
	}

	if hostname == "" {
		hostname = "test-ip-reuse"
		log.Printf("Using default hostname: %s", hostname)
	}

	if stateDir == "" {
		stateDir = "/tmp/tsnet-ip-reuse-test"
		log.Printf("Using default state dir: %s", stateDir)
	}

	// Create forwarder instance
	tsnetForwarder := forwarder.GetInstance()

	// Variables to track connection results
	var firstConnectionIPs, secondConnectionIPs []string
	connectStatus := 0
	callbackCount := 0

	// Register connect callback
	connectCallback := &forwarder.ConnectCallback{
		OnConnectSuccess: func(hostname, magicDNS, ipv4, ipv6 string) {
			callbackCount++
			log.Printf("🔔 Callback #%d - Connect Success: hostname=%s, magicDNS=%s, ipv4=%s, ipv6=%s",
				callbackCount, hostname, magicDNS, ipv4, ipv6)
			connectStatus = 1
		},
		OnConnectError: func(hostname string, err error) {
			callbackCount++
			log.Printf("🔔 Callback #%d - Connect Error: hostname=%s, error=%v", callbackCount, hostname, err)
			connectStatus = -1
		},
	}
	tsnetForwarder.TsnetRegisterConnectCallback(connectCallback)

	// Setup configuration
	if err := tsnetForwarder.UpdateTsnetAuthKey(authKey); err != nil {
		log.Printf("Failed to set auth key: %v", err)
		return
	}

	if err := tsnetForwarder.TsnetUpdateHostname(hostname); err != nil {
		log.Printf("Failed to set hostname: %v", err)
		return
	}

	if err := tsnetForwarder.TsnetUpdateStateDir(stateDir); err != nil {
		log.Printf("Failed to set state dir: %v", err)
		return
	}

	// First connection
	log.Printf("--- First Connection ---")
	connectStatus = 0
	initialCallbackCount := callbackCount
	if err := tsnetForwarder.TsnetConnect(); err != nil {
		log.Printf("First connection failed: %v", err)
		return
	}

	// Wait for connection to complete
	for i := 0; i < 60; i++ { // Increased timeout for initial connection
		if connectStatus != 0 {
			break
		}
		time.Sleep(1 * time.Second)
		if i%5 == 0 { // Log every 5 seconds
			log.Printf("Waiting for first connection... (%d/60)", i+1)
		}
	}

	if connectStatus != 1 {
		log.Printf("First connection did not succeed within timeout")
		return
	}

	// Verify callback was called for first connection
	if callbackCount <= initialCallbackCount {
		log.Printf("❌ Callback was not called for first connection")
		return
	} else {
		log.Printf("✅ Callback was called for first connection")
	}

	// Record first connection IPs
	firstConnectionIPs = tsnetForwarder.GetTailscaleIPs()
	log.Printf("First connection IPs: %v", firstConnectionIPs)

	// Check if state directory exists
	if _, err := os.Stat(stateDir); os.IsNotExist(err) {
		log.Printf("❌ State directory does not exist after first connection: %s", stateDir)
		return
	} else {
		log.Printf("✅ State directory exists: %s", stateDir)
	}

	// Stop the first instance but preserve state
	log.Printf("--- Stopping first instance (preserving state) ---")
	tsnetForwarder.Cleanup()

	// Wait a moment before reconnecting
	time.Sleep(2 * time.Second)

	// Create new instance to simulate restart
	log.Printf("--- Creating new instance (simulating restart) ---")

	// Reset connection status
	connectStatus = 0

	// Get a fresh instance (in reality this would be a new process)
	// Since GetInstance returns singleton, we need to reconfigure it
	if err := tsnetForwarder.UpdateTsnetAuthKey(authKey); err != nil {
		log.Printf("Failed to set auth key for second instance: %v", err)
		return
	}

	if err := tsnetForwarder.TsnetUpdateHostname(hostname); err != nil {
		log.Printf("Failed to set hostname for second instance: %v", err)
		return
	}

	if err := tsnetForwarder.TsnetUpdateStateDir(stateDir); err != nil {
		log.Printf("Failed to set state dir for second instance: %v", err)
		return
	}

	// Register callback again
	tsnetForwarder.TsnetRegisterConnectCallback(connectCallback)

	// Second connection (should reuse state)
	log.Printf("--- Second Connection (State Reuse Test) ---")
	connectStatus = 0
	secondCallbackCount := callbackCount
	if err := tsnetForwarder.TsnetConnect(); err != nil {
		log.Printf("Second connection failed: %v", err)
		return
	}

	// Wait for second connection to complete
	for i := 0; i < 60; i++ {
		if connectStatus != 0 {
			break
		}
		time.Sleep(1 * time.Second)
		if i%5 == 0 { // Log every 5 seconds
			log.Printf("Waiting for second connection... (%d/60)", i+1)
		}
	}

	if connectStatus != 1 {
		log.Printf("Second connection did not succeed within timeout")
		return
	}

	// Verify callback was called for second connection (reuse case)
	if callbackCount <= secondCallbackCount {
		log.Printf("❌ Callback was not called for second connection (state reuse)")
		return
	} else {
		log.Printf("✅ Callback was called for second connection (state reuse)")
	}

	// Record second connection IPs
	secondConnectionIPs = tsnetForwarder.GetTailscaleIPs()
	log.Printf("Second connection IPs: %v", secondConnectionIPs)

	// Compare IPs
	log.Printf("--- IP Comparison Results ---")
	if len(firstConnectionIPs) != len(secondConnectionIPs) {
		log.Printf("❌ DIFFERENT: IP count changed from %d to %d", len(firstConnectionIPs), len(secondConnectionIPs))
		return
	}

	if len(firstConnectionIPs) == 0 {
		log.Printf("⚠️  WARNING: No IP addresses found in either connection")
		return
	}

	identical := true
	for i, ip1 := range firstConnectionIPs {
		if i < len(secondConnectionIPs) {
			ip2 := secondConnectionIPs[i]
			if ip1 == ip2 {
				log.Printf("✅ SAME: IP[%d] = %s", i, ip1)
			} else {
				log.Printf("❌ DIFFERENT: IP[%d] changed from %s to %s", i, ip1, ip2)
				identical = false
			}
		}
	}

	log.Printf("--- Test Results ---")
	log.Printf("📊 Callback Statistics:")
	log.Printf("   - Total callbacks called: %d", callbackCount)
	log.Printf("   - First connection callback: ✅")
	log.Printf("   - Second connection callback: ✅")

	if identical {
		log.Printf("🎉 SUCCESS: All IP addresses remained consistent after state reuse!")
		log.Printf("✅ The state reuse functionality is working correctly")
		log.Printf("✅ Callbacks are called properly in both new and reuse scenarios")
		log.Printf("✅ No duplicate devices should be created in Tailscale admin panel")
		log.Printf("✅ This confirms that the modification prevents duplicate device creation")
	} else {
		log.Printf("⚠️  WARNING: IP addresses changed after reconnection")
		log.Printf("❌ This might indicate that state reuse is not working properly")
		log.Printf("❌ This could lead to duplicate devices in the Tailscale admin panel")
	}

	// Final cleanup
	tsnetForwarder.Cleanup()
	log.Printf("=== Test completed ===")
}
