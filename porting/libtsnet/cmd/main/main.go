package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	forwarder "me.wsen.scrcpy-tsnet/lib"
)

func main() {
	// Get forwarder instance
	f := forwarder.GetInstance()

	// Set authentication key (from environment variable or command line argument)
	authKey := os.Getenv("TS_AUTHKEY")
	if authKey == "" {
		log.Println("Warning: TS_AUTHKEY environment variable not set, will use interactive authentication")
	} else {
		if err := f.UpdateTsnetAuthKey(authKey); err != nil {
			log.Fatalf("Failed to set authentication key: %v", err)
		}
		log.Println("✅ Authentication key set successfully")
	}

	// Register callback functions
	callback := &forwarder.ForwardCallback{
		OnForwardSuccess: func(remoteAddr string, remotePort int, localPort int) {
			log.Printf("✅ Forward started successfully: %s:%d -> localhost:%d", remoteAddr, remotePort, localPort)
		},
		OnForwardClosed: func(remoteAddr string, remotePort int, localPort int) {
			log.Printf("🔴 Forward closed: %s:%d -> localhost:%d", remoteAddr, remotePort, localPort)
		},
		OnForwardError: func(remoteAddr string, remotePort int, localPort int, err error) {
			log.Printf("❌ Forward error: %s:%d -> localhost:%d, error: %v", remoteAddr, remotePort, localPort, err)
		},
	}
	f.TsnetRegisterCallback(callback)

	// Wait a few seconds for the server to start
	log.Println("⏳ Waiting for Tailscale server to start...")
	time.Sleep(3 * time.Second)

	// Start port forwarding example
	// Please modify these parameters according to your actual network environment
	remoteAddr := "100.78.206.85" // Device IP in Tailscale network
	remotePort := 8000            // Remote service port
	localPort := 8080             // Local listening port

	log.Printf("🚀 Starting port forward: %s:%d -> localhost:%d", remoteAddr, remotePort, localPort)
	if err := f.TsnetStartForward(remoteAddr, remotePort, localPort); err != nil {
		log.Fatalf("❌ Failed to start forwarding: %v", err)
	}

	// Show server status
	if f.IsStarted() {
		ips := f.GetTailscaleIPs()
		if len(ips) > 0 {
			log.Printf("📡 Tailscale IPs: %v", ips)
		}
	}

	log.Printf("🎉 Forwarding started! You can access the remote service via:")
	log.Printf("   Browser: http://localhost:%d", localPort)
	log.Printf("   curl: curl http://localhost:%d", localPort)
	log.Println("Press Ctrl+C to stop forwarding...")

	// Setup signal handling
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)

	// Wait for interrupt signal
	<-c

	log.Println("\n🛑 Received stop signal, cleaning up resources...")

	// Cleanup all forwards
	count := f.Cleanup()
	log.Printf("✅ Cleaned up %d forward connections", count)

	log.Println("👋 Program exited")
}
