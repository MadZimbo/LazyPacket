import SwiftUI
import Foundation
import Combine
import Network

#if canImport(Darwin)
import Darwin
import Darwin.C
import Darwin.POSIX.sys.socket
import Darwin.POSIX.netinet.`in`
import Darwin.POSIX.ifaddrs
import Darwin.POSIX.sys.time
import Darwin.POSIX.netdb
#endif

// MARK: - Wake-on-LAN ViewModel
@MainActor
class WakeOnLANViewModel: ObservableObject {
    @Published var savedDevices: [SavedDevice] = []
    @Published var selectedDevice: SavedDevice?
    @Published var activityLog: [ActivityLogItem] = []
    @Published var statusMessage: String = "Ready to send Wake-on-LAN packets"
    @Published var isNetworkActive: Bool = false
    @Published var isSending: Bool = false
    @Published var isCheckingDeviceStatus: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let devicesKey = "SavedDevices"
    private let activityLogKey = "ActivityLog"
    
    // Network connectivity monitoring
    private let deviceStatusQueue = DispatchQueue(label: "device-status-check", qos: .background)
    
    init() {
        loadDevices()
        normalizeAllDeviceMACs() // Ensure all MAC addresses are in consistent uppercase format
        loadActivityLog()
        checkAllDeviceStatus() // Initial check at startup
    }
    
    // MARK: - Device Management
    func addDevice(_ device: SavedDevice) {
        // Normalize MAC address to uppercase for consistency
        let normalizedMAC = device.macAddress.uppercased()
        
        // Check for duplicates
        if savedDevices.contains(where: { $0.macAddress.uppercased() == normalizedMAC }) {
            logActivity("Device with MAC \(normalizedMAC) already exists", type: .warning)
            return
        }
        
        // Create new device with normalized MAC
        let normalizedDevice = SavedDevice(
            name: device.name,
            macAddress: normalizedMAC,
            isOnline: device.isOnline,
            deviceType: device.deviceType
        )
        
        withAnimation(.easeInOut) {
            savedDevices.append(normalizedDevice)
        }
        
        saveDevices()
        logActivity("Added device '\(normalizedDevice.name)'", type: .success)
        
        // Auto-select the newly added device
        selectDevice(normalizedDevice)
    }
    
    func deleteDevice(_ device: SavedDevice) {
        withAnimation(.easeInOut) {
            savedDevices.removeAll { $0.id == device.id }
            
            if selectedDevice?.id == device.id {
                selectedDevice = nil
            }
        }
        
        saveDevices()
        logActivity("Deleted device '\(device.name)'", type: .warning)
    }
    
    func updateDevice(_ device: SavedDevice, name: String, macAddress: String) {
        guard let index = savedDevices.firstIndex(where: { $0.id == device.id }) else { return }
        
        // Check for MAC address conflicts (excluding the current device)
        let trimmedMAC = macAddress.uppercased()
        if savedDevices.contains(where: { $0.macAddress == trimmedMAC && $0.id != device.id }) {
            logActivity("Device with MAC \(trimmedMAC) already exists", type: .warning)
            return
        }
        
        withAnimation(.easeInOut) {
            savedDevices[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            savedDevices[index].macAddress = trimmedMAC
            
            // Update selected device if it's the one being edited
            if selectedDevice?.id == device.id {
                selectedDevice = savedDevices[index]
            }
        }
        
        saveDevices()
        logActivity("Updated device '\(name)'", type: .info)
    }
    
    func selectDevice(_ device: SavedDevice) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedDevice = device
        }
    }
    
    func normalizeAllDeviceMACs() {
        print("🔧 Normalizing all device MAC addresses to uppercase...")
        var hasChanges = false
        
        for i in savedDevices.indices {
            let originalMAC = savedDevices[i].macAddress
            let normalizedMAC = originalMAC.uppercased()
            
            if originalMAC != normalizedMAC {
                print("🔧 Normalizing: '\(originalMAC)' -> '\(normalizedMAC)'")
                savedDevices[i].macAddress = normalizedMAC
                hasChanges = true
            }
        }
        
        if hasChanges {
            saveDevices()
            logActivity("Normalized MAC addresses to uppercase format", type: .info)
            print("🔧 MAC address normalization complete")
        } else {
            print("🔧 All MAC addresses already normalized")
        }
    }
    

    
    // MARK: - Wake-on-LAN Operations
    func sendWakePacket(to macAddress: String, deviceName: String? = nil) {
        guard !isSending else { return }
        
        isSending = true
        isNetworkActive = true
        
        let displayName = deviceName ?? macAddress
        
        Task {
            do {
                let packet = createMagicPacket(macAddress: macAddress)
                
                try await withThrowingTaskGroup(of: Void.self) { group in
                    // Try multiple broadcast addresses and ports for better compatibility
                    let broadcastAddresses = getBroadcastAddresses()
                    let wakePorts = [9, 7, 0] // Common Wake-on-LAN ports
                    
                    for broadcastAddr in broadcastAddresses {
                        for port in wakePorts {
                            group.addTask {
                                try await self.sendPacketWithPort(packet, to: broadcastAddr, port: port)
                            }
                        }
                    }
                    
                    // Wait for at least one to succeed
                    try await group.next()
                }
                
                await MainActor.run {
                    self.logActivity("Magic packet sent to \(displayName)", type: .success)
                    self.statusMessage = "Packet sent successfully to \(displayName)"
                    
                    // Update device online status if it's a saved device
                    if deviceName != nil,
                       let index = self.savedDevices.firstIndex(where: { $0.macAddress.lowercased() == macAddress.lowercased() }) {
                        var updatedDevice = self.savedDevices[index]
                        updatedDevice.lastWoken = Date()
                        self.savedDevices[index] = updatedDevice
                        self.saveDevices()
                    }
                }
                
            } catch {
                await MainActor.run {
                    let errorMessage = error.localizedDescription
                    
                    self.logActivity("Failed to send packet to \(displayName): \(errorMessage)", type: .error)
                    self.statusMessage = "Failed to send packet to \(displayName)"
                    
                    // Log additional debug information
                    print("Wake-on-LAN Error Details: \(error)")
                }
            }
            
            // Delay to show the loading state
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await MainActor.run {
                    self.isSending = false
                    self.isNetworkActive = false
                    
                    // Reset status message after delay
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                        await MainActor.run {
                            if self.statusMessage.contains("sent") || self.statusMessage.contains("Failed") {
                                self.statusMessage = "Ready to send Wake-on-LAN packets"
                            }
                        }
                    }
                }
            }
        }
    }
    
    func wakeDevice(_ device: SavedDevice) {
        sendWakePacket(to: device.macAddress, deviceName: device.name)
    }
    
    private func sendPacketWithPort(_ packet: Data, to address: String, port: Int) async throws {
        // Just try the standard fallback method for now, but with logging
        do {
            try await sendPacketWithFallback(packet, to: address, port: port)
        } catch {
            // Log the specific port failure but still throw
            print("Failed to send to \(address):\(port) - \(error)")
            throw error
        }
    }
    
    private func sendPacketWithFallback(_ packet: Data, to address: String, port: Int = 9) async throws {
        // Use BSD sockets only - more reliable and doesn't require special entitlements
        do {
            try await sendPacketBSD(packet, to: address, port: port)
            print("✅ Successfully sent packet via BSD sockets to \(address):\(port)")
            return
        } catch {
            print("❌ BSD socket failed for \(address):\(port): \(error)")
            throw error
        }
    }
    
    private func sendPacketBSD(_ packet: Data, to address: String, port: Int = 9) async throws {
        print("Attempting to send packet via BSD sockets to \(address):\(port)")
        
        // Create UDP socket with better error handling
        let socketFd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFd != -1 else {
            let errorCode = errno
            let errorString = String(cString: strerror(errorCode))
            print("❌ Failed to create socket: errno \(errorCode) - \(errorString)")
            throw WakeOnLANError.networkError("Failed to create socket: errno \(errorCode) - \(errorString)")
        }
        
        defer { 
            close(socketFd)
            print("Socket closed")
        }
        
        // Set socket options with better error handling
        var broadcast: Int32 = 1
        let broadcastResult = setsockopt(socketFd, SOL_SOCKET, SO_BROADCAST, &broadcast, socklen_t(MemoryLayout<Int32>.size))
        guard broadcastResult == 0 else {
            let errorCode = errno
            let errorString = String(cString: strerror(errorCode))
            print("❌ Failed to enable broadcast: errno \(errorCode) - \(errorString)")
            throw WakeOnLANError.networkError("Failed to enable broadcast: errno \(errorCode) - \(errorString)")
        }
        print("✅ Broadcast enabled successfully")
        
        // Set socket to reuse address (optional, don't fail if it doesn't work)
        var reuseAddr: Int32 = 1
        let reuseResult = setsockopt(socketFd, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))
        if reuseResult != 0 {
            print("⚠️ Warning: Could not set SO_REUSEADDR: errno \(errno)")
        }
        
        // Set socket timeout to avoid hanging
        var timeout = timeval()
        timeout.tv_sec = 5  // 5 seconds timeout
        timeout.tv_usec = 0
        
        let sendTimeoutResult = setsockopt(socketFd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        if sendTimeoutResult != 0 {
            print("⚠️ Warning: Could not set send timeout: errno \(errno)")
        }
        
        // Set up destination address with validation
        guard inet_addr(address) != INADDR_NONE else {
            throw WakeOnLANError.invalidAddress(address)
        }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr.s_addr = inet_addr(address)
        
        print("📡 Sending \(packet.count) bytes to \(address):\(port)")
        
        // Send packet with better error handling
        let sentBytes = packet.withUnsafeBytes { bytes in
            withUnsafePointer(to: addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    sendto(socketFd, bytes.bindMemory(to: UInt8.self).baseAddress, packet.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        
        guard sentBytes != -1 else {
            let errorCode = errno
            let errorString = String(cString: strerror(errorCode))
            print("❌ Failed to send packet: errno \(errorCode) - \(errorString)")
            
            // Provide more specific error messages for common issues
            let specificError: String
            switch errorCode {
            case EPERM, EACCES:
                specificError = "Permission denied. The app may not have network broadcast permissions."
            case ENETDOWN:
                specificError = "Network is down."
            case ENETUNREACH:
                specificError = "Network is unreachable."
            case EHOSTUNREACH:
                specificError = "Host is unreachable."
            case ENOBUFS:
                specificError = "No buffer space available."
            default:
                specificError = errorString
            }
            
            throw WakeOnLANError.networkError("Failed to send packet: \(specificError)")
        }
        
        guard sentBytes == packet.count else {
            throw WakeOnLANError.networkError("Partial send: only \(sentBytes) of \(packet.count) bytes sent")
        }
        
        print("✅ Successfully sent \(sentBytes) bytes via BSD socket")
    }
    

    private func createMagicPacket(macAddress: String) -> Data {
        var data = Data(repeating: 0xFF, count: 6) // Magic packet header
        
        // Parse MAC address - remove separators and convert to bytes
        let cleanMAC = macAddress.replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
        
        let macBytes = stride(from: 0, to: cleanMAC.count, by: 2).compactMap { index in
            let start = cleanMAC.index(cleanMAC.startIndex, offsetBy: index)
            let end = cleanMAC.index(start, offsetBy: 2)
            return UInt8(cleanMAC[start..<end], radix: 16)
        }
        
        guard macBytes.count == 6 else {
            logActivity("Invalid MAC address format: \(macAddress)", type: .error)
            return data
        }
        
        // Repeat MAC address 16 times
        for _ in 0..<16 {
            data.append(contentsOf: macBytes)
        }
        
        return data
    }
    
    // MARK: - Activity Log
    func logActivity(_ message: String, type: ActivityLogItem.ActivityType) {
        let activity = ActivityLogItem(message: message, type: type, timestamp: Date())
        
        withAnimation(.easeInOut) {
            activityLog.insert(activity, at: 0)
        }
        
        // Keep only last 100 items
        if activityLog.count > 100 {
            activityLog = Array(activityLog.prefix(100))
        }
        
        saveActivityLog()
    }
    
    func clearActivityLog() {
        withAnimation(.easeInOut) {
            activityLog.removeAll()
        }
        saveActivityLog()
    }
    
    // MARK: - Persistence
    func saveDevices() {
        do {
            let data = try JSONEncoder().encode(savedDevices)
            userDefaults.set(data, forKey: devicesKey)
        } catch {
            print("Failed to save devices: \(error)")
        }
    }
    
    func loadDevices() {
        guard let data = userDefaults.data(forKey: devicesKey) else { return }
        
        do {
            savedDevices = try JSONDecoder().decode([SavedDevice].self, from: data)
        } catch {
            print("Failed to load devices: \(error)")
            // Try to load legacy format
            loadLegacyDevices()
        }
    }
    
    private func loadLegacyDevices() {
        guard let data = userDefaults.array(forKey: "savedDevices") as? [[String: String]] else { return }
        
        savedDevices = data.compactMap { dict in
            guard let macAddress = dict["macAddress"],
                  let deviceName = dict["deviceName"] else { return nil }
            
            return SavedDevice(
                name: deviceName,
                macAddress: macAddress,
                isOnline: false,
                deviceType: .generic
            )
        }
        
        // Save in new format
        saveDevices()
        
        // Remove old format
        userDefaults.removeObject(forKey: "savedDevices")
    }
    
    private func saveActivityLog() {
        do {
            let recentLog = Array(activityLog.prefix(50)) // Only save recent items
            let data = try JSONEncoder().encode(recentLog)
            userDefaults.set(data, forKey: activityLogKey)
        } catch {
            print("Failed to save activity log: \(error)")
        }
    }
    
    private func loadActivityLog() {
        guard let data = userDefaults.data(forKey: activityLogKey) else { return }
        
        do {
            activityLog = try JSONDecoder().decode([ActivityLogItem].self, from: data)
        } catch {
            print("Failed to load activity log: \(error)")
        }
    }
    
    // MARK: - Network Helpers
    private func getBroadcastAddresses() -> [String] {
        // Get local network broadcast addresses only
        let localBroadcasts = getLocalNetworkBroadcasts()
        
        // If we have local broadcast addresses, use only those
        if !localBroadcasts.isEmpty {
            print("Using local network broadcast addresses: \(localBroadcasts)")
            return localBroadcasts
        }
        
        // If we can't detect local networks, calculate broadcast from current IP
        let calculatedBroadcasts = calculateBroadcastAddresses()
        if !calculatedBroadcasts.isEmpty {
            print("Using calculated broadcast addresses: \(calculatedBroadcasts)")
            return calculatedBroadcasts
        }
        
        // Last resort - use common private network broadcasts (but not global)
        let fallbackAddresses = [
            "192.168.1.255",    // Most common home network
            "192.168.0.255",    // Second most common home network  
            "10.0.0.255",       // Common business network
            "172.16.255.255"    // Corporate network
        ]
        
        print("Using fallback broadcast addresses: \(fallbackAddresses)")
        return fallbackAddresses
    }
    
    private func getLocalNetworkBroadcasts() -> [String] {
        var broadcastAddresses: [String] = []
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddr) == 0 else {
            print("Failed to get network interfaces")
            return []
        }
        
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            guard let interface = ptr?.pointee else { continue }
            
            // Skip loopback and inactive interfaces
            let flags = interface.ifa_flags
            guard (flags & UInt32(IFF_UP)) != 0,
                  (flags & UInt32(IFF_LOOPBACK)) == 0,
                  (flags & UInt32(IFF_BROADCAST)) != 0 else {
                continue
            }
            
            // Only process IPv4 addresses
            guard let addr = interface.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }
            
            // Get broadcast address if available
            if let broadAddr = interface.ifa_dstaddr {
                let broadcast = sockaddr_in_cast(broadAddr)
                let broadcastString = String(cString: inet_ntoa(broadcast.pointee.sin_addr))
                
                // Get network address for logging
                let networkAddr = sockaddr_in_cast(addr)
                let networkString = String(cString: inet_ntoa(networkAddr.pointee.sin_addr))
                
                // Get interface name
                let interfaceName = String(cString: interface.ifa_name)
                
                print("Found network interface: \(interfaceName)")
                print("  Network address: \(networkString)")
                print("  Broadcast address: \(broadcastString)")
                
                // Avoid duplicates and invalid broadcasts
                if !broadcastAddresses.contains(broadcastString) && 
                   broadcastString != "0.0.0.0" {
                    broadcastAddresses.append(broadcastString)
                }
            }
        }
        
        print("Detected local broadcast addresses: \(broadcastAddresses)")
        return broadcastAddresses
    }
    
    private func calculateBroadcastAddresses() -> [String] {
        var broadcastAddresses: [String] = []
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddr) == 0 else {
            print("Failed to get network interfaces for calculation")
            return []
        }
        
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            guard let interface = ptr?.pointee else { continue }
            
            // Skip loopback and inactive interfaces
            let flags = interface.ifa_flags
            guard (flags & UInt32(IFF_UP)) != 0,
                  (flags & UInt32(IFF_LOOPBACK)) == 0 else {
                continue
            }
            
            // Only process IPv4 addresses
            guard let addr = interface.ifa_addr,
                  let netmask = interface.ifa_netmask,
                  addr.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }
            
            let interfaceName = String(cString: interface.ifa_name)
            
            // Skip certain interfaces
            if interfaceName.hasPrefix("utun") || interfaceName.hasPrefix("ipsec") {
                continue
            }
            
            let networkAddr = sockaddr_in_cast(addr)
            let netmaskAddr = sockaddr_in_cast(netmask)
            
            let ipAddress = networkAddr.pointee.sin_addr.s_addr
            let subnetMask = netmaskAddr.pointee.sin_addr.s_addr
            
            // Calculate broadcast address: IP | (~subnet_mask)
            let broadcastAddr = ipAddress | (~subnetMask)
            
            var broadcastSockAddr = in_addr()
            broadcastSockAddr.s_addr = broadcastAddr
            
            let broadcastString = String(cString: inet_ntoa(broadcastSockAddr))
            let ipString = String(cString: inet_ntoa(networkAddr.pointee.sin_addr))
            let maskString = String(cString: inet_ntoa(netmaskAddr.pointee.sin_addr))
            
            print("Calculated broadcast for interface \(interfaceName):")
            print("  IP: \(ipString)")
            print("  Mask: \(maskString)")
            print("  Broadcast: \(broadcastString)")
            
            if !broadcastAddresses.contains(broadcastString) && 
               broadcastString != "0.0.0.0" &&
               broadcastString != "255.255.255.255" {
                broadcastAddresses.append(broadcastString)
            }
        }
        
        print("Calculated broadcast addresses: \(broadcastAddresses)")
        return broadcastAddresses
    }
    
    // Helper function to safely cast sockaddr to sockaddr_in
    private func sockaddr_in_cast(_ addr: UnsafeMutablePointer<sockaddr>) -> UnsafeMutablePointer<sockaddr_in> {
        return addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0 }
    }
    
    // MARK: - Debug Helpers
    func diagnoseNetworkIssues() {
        print("=== Network Diagnostic Information ===")
        
        // Check if we can create a socket
        let testSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        if testSocket == -1 {
            print("❌ Cannot create UDP socket: errno \(errno)")
        } else {
            print("✅ Can create UDP socket")
            
            // Test broadcast permission
            var broadcast: Int32 = 1
            let broadcastResult = setsockopt(testSocket, SOL_SOCKET, SO_BROADCAST, &broadcast, socklen_t(MemoryLayout<Int32>.size))
            if broadcastResult == 0 {
                print("✅ Can enable broadcast")
            } else {
                print("❌ Cannot enable broadcast: errno \(errno)")
            }
            
            close(testSocket)
        }
        
        // Check available network interfaces
        let broadcastAddresses = getBroadcastAddresses()
        print("📡 Available broadcast addresses: \(broadcastAddresses)")
        
        // Check if we're running on a sandboxed environment
        #if targetEnvironment(macCatalyst) || os(macOS)
        print("🖥️ Running on macOS/Catalyst")
        #elseif os(iOS)
        print("📱 Running on iOS")
        #endif
        
        print("=== End Network Diagnostic ===")
    }
    
    func testMagicPacketCreation(for macAddress: String) {
        print("=== Testing Magic Packet Creation ===")
        let packet = createMagicPacket(macAddress: macAddress)
        
        // Validate packet structure
        if packet.count == 102 {
            // Check header (first 6 bytes should be 0xFF)
            let header = packet.prefix(6)
            let isValidHeader = header.allSatisfy { $0 == 0xFF }
            print("Header valid: \(isValidHeader)")
            
            // Check if MAC is repeated 16 times
            let macSection = packet.dropFirst(6)
            let macBytes = Array(macSection.prefix(6))
            print("First MAC occurrence: \(macBytes.map { String(format: "%02X", $0) }.joined(separator: ":"))")
            
            // Verify all 16 occurrences are the same
            var isValidMAC = true
            for i in 1..<16 {
                let startIndex = i * 6
                let currentMAC = Array(macSection.dropFirst(startIndex).prefix(6))
                if currentMAC != macBytes {
                    isValidMAC = false
                    break
                }
            }
            print("MAC repetition valid: \(isValidMAC)")
            print("Total packet size: \(packet.count) bytes (expected: 102)")
        } else {
            print("INVALID PACKET SIZE: \(packet.count) bytes (expected: 102)")
        }
        print("=== End Test ===")
    }
    
    // MARK: - Device Status Monitoring
    func checkAllDeviceStatus() {
        guard !savedDevices.isEmpty else { return }
        
        Task {
            await MainActor.run {
                self.isCheckingDeviceStatus = true
            }
            
            // Simple ping-like check for each device
            for (index, device) in self.savedDevices.enumerated() {
                let isOnline = await self.pingDevice(macAddress: device.macAddress)
                
                // Update device status on main thread
                await MainActor.run {
                    if self.savedDevices.indices.contains(index) && self.savedDevices[index].id == device.id {
                        let wasOnline = self.savedDevices[index].isOnline
                        self.savedDevices[index].isOnline = isOnline
                        self.savedDevices[index].lastStatusCheck = Date()
                        
                        // Update selected device if it matches
                        if self.selectedDevice?.id == device.id {
                            self.selectedDevice = self.savedDevices[index]
                        }
                        
                        // Log status changes
                        if wasOnline != isOnline {
                            let statusText = isOnline ? "came online" : "went offline"
                            let logType: ActivityLogItem.ActivityType = isOnline ? .success : .warning
                            self.logActivity("Device '\(device.name)' \(statusText)", type: logType)
                        }
                    }
                }
            }
            
            await MainActor.run {
                self.isCheckingDeviceStatus = false
                self.saveDevices() // Persist updated status
            }
        }
    }
    
    func forceCheckDeviceStatus(_ device: SavedDevice) {
        Task {
            let isOnline = await self.pingDevice(macAddress: device.macAddress)
            
            await MainActor.run {
                if let index = self.savedDevices.firstIndex(where: { $0.id == device.id }) {
                    self.savedDevices[index].isOnline = isOnline
                    self.savedDevices[index].lastStatusCheck = Date()
                    
                    if self.selectedDevice?.id == device.id {
                        self.selectedDevice = self.savedDevices[index]
                    }
                    
                    let statusText = isOnline ? "online" : "offline"
                    let logType: ActivityLogItem.ActivityType = isOnline ? .success : .info
                    self.logActivity("Device '\(device.name)' is \(statusText)", type: logType)
                    
                    self.saveDevices()
                }
            }
        }
    }
    
    // MARK: - Device Ping (Simple and Reliable)
    private func pingDevice(macAddress: String) async -> Bool {
        // First, try to get the IP from ARP table
        if let ip = await getIPFromARP(macAddress: macAddress) {
            return await basicPing(ip: ip)
        }
        
        // If not found in ARP, device is offline
        return false
    }
    
    private func basicPing(ip: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let task = Process()
                
                // Use the most basic ping command available
                task.launchPath = "/sbin/ping"
                task.arguments = ["-c", "1", ip]
                
                // Redirect output to avoid any issues
                task.standardOutput = FileHandle.nullDevice
                task.standardError = FileHandle.nullDevice
                
                print("🏓 Basic ping to \(ip)")
                task.launch()
                task.waitUntilExit()
                
                let isOnline = task.terminationStatus == 0
                print("🏓 Ping result: \(isOnline ? "✅ ONLINE" : "❌ OFFLINE")")
                
                continuation.resume(returning: isOnline)
            }
        }
    }
    
    private func getIPFromARP(macAddress: String) async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                print("🔍 Looking up IP for MAC: \(macAddress)")
                
                let task = Process()
                task.launchPath = "/usr/sbin/arp"
                task.arguments = ["-a"]
                
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = FileHandle.nullDevice
                
                task.launch()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                print("🔍 Searching for stored MAC: '\(macAddress)'")
                
                // Normalize the saved MAC for comparison (remove separators, lowercase)
                let normalizedSavedMAC = macAddress
                    .replacingOccurrences(of: ":", with: "")
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: ".", with: "")
                    .lowercased()
                
                print("🔍 Normalized saved MAC: '\(normalizedSavedMAC)'")
                
                // Parse ARP table output
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    // Skip empty lines
                    guard !line.isEmpty else { continue }
                    
                    // Look for IP in parentheses and ANY MAC address format in the line
                    // ARP output typically looks like: hostname (192.168.1.100) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]
                    // Note: macOS ARP can show MACs with single-digit bytes like 0:11:32 instead of 00:11:32
                    if let ipMatch = line.range(of: "\\((\\d+\\.\\d+\\.\\d+\\.\\d+)\\)", options: .regularExpression) {
                        let ip = String(line[ipMatch]).replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
                        
                        // Try to find MAC address - allow 1 or 2 hex digits per byte
                        // Pattern handles both: 0:11:32:cf:b0:a3 and 00:11:32:cf:b0:a3
                        if let macMatch = line.range(of: "([0-9a-fA-F]{1,2}:[0-9a-fA-F]{1,2}:[0-9a-fA-F]{1,2}:[0-9a-fA-F]{1,2}:[0-9a-fA-F]{1,2}:[0-9a-fA-F]{1,2})", options: .regularExpression) {
                            let foundMAC = String(line[macMatch])
                            
                            // Normalize the found MAC for comparison (pad single digits with leading zero, remove separators)
                            let macComponents = foundMAC.split(separator: ":")
                            let paddedComponents = macComponents.map { component in
                                component.count == 1 ? "0\(component)" : String(component)
                            }
                            let normalizedFoundMAC = paddedComponents.joined().lowercased()
                            
                            print("🔍 Found entry - IP: \(ip), MAC: \(foundMAC) (normalized: \(normalizedFoundMAC))")
                            
                            // Compare normalized MACs (case-insensitive, separator-agnostic)
                            if normalizedSavedMAC == normalizedFoundMAC {
                                print("🔍 ✅ MATCH FOUND! IP: \(ip) for saved MAC: \(macAddress)")
                                continuation.resume(returning: ip)
                                return
                            }
                        }
                    }
                }
                
                print("🔍 ❌ No matching MAC found in ARP table")
                print("🔍 Full ARP output:")
                print(output)
                continuation.resume(returning: nil)
            }
        }
    }
    
    // MARK: - Debug Helper
    func testDevicePing(macAddress: String) {
        Task {
            print("🧪 Testing ping for device with MAC: \(macAddress)")
            let result = await pingDevice(macAddress: macAddress)
            await MainActor.run {
                let message = "Test ping for \(macAddress): \(result ? "ONLINE" : "OFFLINE")"
                print("🧪 \(message)")
                logActivity(message, type: result ? .success : .warning)
            }
        }
    }
    
    func testDirectPing(ip: String) {
        Task {
            print("🧪 Testing direct ping to IP: \(ip)")
            let result = await basicPing(ip: ip)
            await MainActor.run {
                let message = "Direct ping to \(ip): \(result ? "ONLINE" : "OFFLINE")"
                print("🧪 \(message)")
                logActivity(message, type: result ? .success : .warning)
            }
        }
    }
    
    func debugSavedDeviceMACs() {
        print("🔧 === Current Saved Device MACs ===")
        for (index, device) in savedDevices.enumerated() {
            let normalizedMAC = device.macAddress.replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: ".", with: "")
                .lowercased()
            print("🔧 Device \(index): '\(device.name)'")
            print("🔧   Stored MAC: \(device.macAddress)")
            print("🔧   Normalized: \(normalizedMAC)")
        }
        print("🔧 === End Debug ===")
    }
    
    func debugARPTable() {
        Task {
            print("🔍 === Full ARP Table Debug ===")
            
            let task = Process()
            task.launchPath = "/usr/sbin/arp"
            task.arguments = ["-a"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice
            
            task.launch()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            print("🔍 Raw ARP output:")
            print(output)
            
            let lines = output.components(separatedBy: .newlines)
            print("🔍 Parsed ARP entries:")
            
            for (index, line) in lines.enumerated() {
                guard !line.isEmpty else { continue }
                print("🔍 Line \(index): \(line)")
                
                // Try to extract IP and MAC
                if let ipMatch = line.range(of: "\\((\\d+\\.\\d+\\.\\d+\\.\\d+)\\)", options: .regularExpression) {
                    let ip = String(line[ipMatch]).replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
                    print("🔍   -> IP found: \(ip)")
                    
                    if let macMatch = line.range(of: "([0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2})", options: .regularExpression) {
                        let mac = String(line[macMatch])
                        print("🔍   -> MAC found: \(mac)")
                    } else {
                        print("🔍   -> No MAC found in this line")
                    }
                }
            }
            
            print("🔍 === End ARP Table Debug ===")
        }
    }
    
    func refreshARPTable() {
        Task {
            print("🔄 Refreshing ARP table...")
            
            // Ping broadcast addresses to populate ARP table
            let broadcastAddresses = getBroadcastAddresses()
            
            for broadcastAddr in broadcastAddresses {
                let components = broadcastAddr.components(separatedBy: ".")
                if components.count == 4, let lastOctet = Int(components[3]) {
                    let networkBase = "\(components[0]).\(components[1]).\(components[2])"
                    
                    // Ping a range of IPs to populate ARP table
                    print("🔄 Pinging range \(networkBase).1-50 to refresh ARP...")
                    
                    for i in 1...50 {
                        let targetIP = "\(networkBase).\(i)"
                        
                        // Quick ping without waiting for result
                        let task = Process()
                        task.launchPath = "/sbin/ping"
                        task.arguments = ["-c", "1", "-W", "100", targetIP] // 100ms timeout
                        task.standardOutput = FileHandle.nullDevice
                        task.standardError = FileHandle.nullDevice
                        
                        task.launch()
                        // Don't wait for completion, just fire and forget
                    }
                }
            }
            
            // Wait a bit for pings to complete
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            print("🔄 ARP table refresh complete")
            
            // Now debug the ARP table
            await debugARPTable()
        }
    }
    
    // MARK: - Validation
    static func isValidMACAddress(_ macAddress: String) -> Bool {
        // Remove any whitespace
        let trimmedMAC = macAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for common MAC address formats:
        // AA:BB:CC:DD:EE:FF (colon separated)
        // AA-BB-CC-DD-EE-FF (hyphen separated)
        // AA.BB.CC.DD.EE.FF (dot separated)
        // AABBCCDDEEFF (no separators)
        let patterns = [
            "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$",  // Colon separated
            "^([0-9A-Fa-f]{2}-){5}[0-9A-Fa-f]{2}$",  // Hyphen separated
            "^([0-9A-Fa-f]{2}\\.){5}[0-9A-Fa-f]{2}$", // Dot separated
            "^[0-9A-Fa-f]{12}$"                       // No separators
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(location: 0, length: trimmedMAC.utf16.count)
                if regex.firstMatch(in: trimmedMAC, options: [], range: range) != nil {
                    return true
                }
            } catch {
                continue
            }
        }
        
        return false
    }
    
    // MARK: - Haptic Feedback
    func triggerHaptic(_ style: HapticFeedbackType) {
        #if os(iOS)
        switch style {
        case .light:
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        case .medium:
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        case .heavy:
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        case .success:
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        case .warning:
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.warning)
        case .error:
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
        case .selection:
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
        }
        #endif
    }
}

// MARK: - Haptic Feedback Types
enum HapticFeedbackType {
    case light, medium, heavy
    case success, warning, error
    case selection
}

// MARK: - Wake-on-LAN Errors
enum WakeOnLANError: LocalizedError {
    case invalidAddress(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAddress(let address):
            return "Invalid broadcast address: \(address)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Data Models
enum DeviceType: String, CaseIterable, Codable {
    case computer = "desktopcomputer"
    case laptop = "laptopcomputer" 
    case server = "server.rack"
    case router = "airport.express"
    case printer = "printer"
    case nas = "externaldrive.connected.to.line.below"
    case iot = "sensor.tag.radiowaves.forward"
    case generic = "network"
    
    var icon: String {
        return self.rawValue
    }
    
    var displayName: String {
        switch self {
        case .computer: return "Desktop Computer"
        case .laptop: return "Laptop"
        case .server: return "Server"
        case .router: return "Router"
        case .printer: return "Printer"
        case .nas: return "NAS Storage"
        case .iot: return "IoT Device"
        case .generic: return "Network Device"
        }
    }
}

struct SavedDevice: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var macAddress: String
    var isOnline: Bool
    let deviceType: DeviceType
    var lastWoken: Date?
    var lastStatusCheck: Date?
    let createdDate: Date
    
    init(name: String, macAddress: String, isOnline: Bool, deviceType: DeviceType = .generic) {
        self.id = UUID()
        self.name = name
        self.macAddress = macAddress
        self.isOnline = isOnline
        self.deviceType = deviceType
        self.lastWoken = nil
        self.lastStatusCheck = nil
        self.createdDate = Date()
    }
    
    // Custom Codable implementation to handle UUID properly
    enum CodingKeys: String, CodingKey {
        case id, name, macAddress, isOnline, deviceType, lastWoken, lastStatusCheck, createdDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        macAddress = try container.decode(String.self, forKey: .macAddress)
        isOnline = try container.decode(Bool.self, forKey: .isOnline)
        deviceType = try container.decode(DeviceType.self, forKey: .deviceType)
        lastWoken = try container.decodeIfPresent(Date.self, forKey: .lastWoken)
        lastStatusCheck = try container.decodeIfPresent(Date.self, forKey: .lastStatusCheck)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(macAddress, forKey: .macAddress)
        try container.encode(isOnline, forKey: .isOnline)
        try container.encode(deviceType, forKey: .deviceType)
        try container.encodeIfPresent(lastWoken, forKey: .lastWoken)
        try container.encodeIfPresent(lastStatusCheck, forKey: .lastStatusCheck)
        try container.encode(createdDate, forKey: .createdDate)
    }
    
    static func == (lhs: SavedDevice, rhs: SavedDevice) -> Bool {
        lhs.id == rhs.id
    }
}

struct ActivityLogItem: Identifiable, Codable {
    let id: UUID
    let message: String
    let type: ActivityType
    let timestamp: Date
    
    init(message: String, type: ActivityType, timestamp: Date) {
        self.id = UUID()
        self.message = message
        self.type = type
        self.timestamp = timestamp
    }
    
    enum ActivityType: String, Codable {
        case success, warning, error, info
        
        var color: Color {
            switch self {
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            case .info: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    var color: Color { type.color }
    var icon: String { type.icon }
}
