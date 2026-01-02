import Cocoa
import Foundation
import Network
import Darwin

class ModernViewController: NSViewController {
    
    // MARK: - Modern Color Palette
    private struct Colors {
        static let primary = NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0) // Modern blue
        static let secondary = NSColor(red: 0.17, green: 0.24, blue: 0.31, alpha: 1.0) // Dark slate
        static let success = NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0) // Green
        static let warning = NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0) // Orange
        static let danger = NSColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0) // Red
        static let background = NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0) // Dark background
        static let surface = NSColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1.0) // Card background
        static let text = NSColor(red: 0.92, green: 0.92, blue: 0.96, alpha: 1.0) // Light text
        static let textSecondary = NSColor(red: 0.68, green: 0.68, blue: 0.73, alpha: 1.0) // Secondary text
    }
    
    @IBOutlet weak var macAddressField: NSTextField!
    @IBOutlet weak var deviceNameField: NSTextField!
    @IBOutlet weak var addButton: NSButton!
    @IBOutlet weak var wakeButton: NSButton!
    @IBOutlet weak var deleteButton: NSButton!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var mainContentView: NSView!
    @IBOutlet weak var controlsContainer: NSView!
    @IBOutlet weak var statusLabel: NSTextField!
    
    var devices: [(macAddress: String, deviceName: String)] = []
    private var isValidMacFormat = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupModernUI()
        setupObservers()
        setupTableView()
        loadDevices()
        updateButtonStates()
    }
    
    // MARK: - Modern UI Setup
    private func setupModernUI() {
        // Main window styling
        view.wantsLayer = true
        view.layer?.backgroundColor = Colors.background.cgColor
        
        // Setup modern card-like containers
        setupContainer(controlsContainer, cornerRadius: 16)
        
        // Style text fields with modern appearance
        styleTextField(macAddressField, placeholder: "Enter MAC Address (AA:BB:CC:DD:EE:FF)")
        styleTextField(deviceNameField, placeholder: "Device Name (Optional)")
        
        // Style buttons with modern design
        styleButton(addButton, type: .secondary, icon: "plus.circle.fill")
        styleButton(wakeButton, type: .primary, icon: "bolt.fill")
        styleButton(deleteButton, type: .danger, icon: "trash.fill")
        
        // Style table view
        styleTableView()
        
        // Setup status label
        statusLabel.textColor = Colors.textSecondary
        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.stringValue = "Ready to send Wake-on-LAN packets"
    }
    
    private func setupContainer(_ container: NSView, cornerRadius: CGFloat = 12) {
        container.wantsLayer = true
        container.layer?.backgroundColor = Colors.surface.cgColor
        container.layer?.cornerRadius = cornerRadius
        container.layer?.borderWidth = 1
        container.layer?.borderColor = Colors.secondary.cgColor
        
        // Add subtle shadow
        container.shadow = NSShadow()
        container.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.1)
        container.shadow?.shadowOffset = NSSize(width: 0, height: -2)
        container.shadow?.shadowBlurRadius = 8
    }
    
    private func styleTextField(_ textField: NSTextField, placeholder: String) {
        textField.placeholderString = placeholder
        textField.textColor = Colors.text
        textField.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        textField.backgroundColor = Colors.background
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.focusRingType = .none
        
        // Custom border styling
        textField.wantsLayer = true
        textField.layer?.cornerRadius = 8
        textField.layer?.borderWidth = 1
        textField.layer?.borderColor = Colors.secondary.cgColor
    }
    
    private enum ButtonType {
        case primary, secondary, danger
    }
    
    private func styleButton(_ button: NSButton, type: ButtonType, icon: String? = nil) {
        button.wantsLayer = true
        button.layer?.cornerRadius = 8
        button.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        button.bezelStyle = .rounded
        
        // Set button colors based on type
        switch type {
        case .primary:
            button.layer?.backgroundColor = Colors.primary.cgColor
            button.contentTintColor = .white
        case .secondary:
            button.layer?.backgroundColor = Colors.secondary.cgColor
            button.contentTintColor = Colors.text
        case .danger:
            button.layer?.backgroundColor = Colors.danger.cgColor
            button.contentTintColor = .white
        }
        
        // Add icon if provided
        if let iconName = icon {
            if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
                button.image = image
                button.imagePosition = .imageLeading
                button.imageHugsTitle = true
            }
        }
        
        // Add hover effect
        button.addTrackingArea(NSTrackingArea(
            rect: button.bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self
        ))
    }
    
    private func styleTableView() {
        tableView.backgroundColor = Colors.surface
        tableView.gridColor = Colors.secondary
        tableView.headerView?.wantsLayer = true
        tableView.headerView?.layer?.backgroundColor = Colors.background.cgColor
        
        // Style scroll view
        if let scrollView = tableView.enclosingScrollView {
            scrollView.wantsLayer = true
            scrollView.layer?.cornerRadius = 12
            scrollView.layer?.borderWidth = 1
            scrollView.layer?.borderColor = Colors.secondary.cgColor
            scrollView.backgroundColor = Colors.surface
        }
    }
    
    // MARK: - Observers and Validation
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(macAddressDidChange),
            name: NSControl.textDidChangeNotification,
            object: macAddressField
        )
    }
    
    @objc private func macAddressDidChange() {
        let macAddress = macAddressField.stringValue
        isValidMacFormat = isValidMACAddress(macAddress)
        
        // Visual feedback with smooth transitions
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            if isValidMacFormat && !macAddress.isEmpty {
                macAddressField.layer?.borderColor = Colors.success.cgColor
                macAddressField.layer?.borderWidth = 2
            } else if !macAddress.isEmpty {
                macAddressField.layer?.borderColor = Colors.danger.cgColor
                macAddressField.layer?.borderWidth = 2
            } else {
                macAddressField.layer?.borderColor = Colors.secondary.cgColor
                macAddressField.layer?.borderWidth = 1
            }
        }
        
        updateButtonStates()
    }
    
    private func updateButtonStates() {
        let hasValidMac = isValidMacFormat && !macAddressField.stringValue.isEmpty
        let hasSelection = tableView.selectedRow >= 0
        
        wakeButton.isEnabled = hasValidMac
        addButton.isEnabled = hasValidMac
        deleteButton.isEnabled = hasSelection
        
        // Update button opacity based on state
        wakeButton.alphaValue = hasValidMac ? 1.0 : 0.6
        addButton.alphaValue = hasValidMac ? 1.0 : 0.6
        deleteButton.alphaValue = hasSelection ? 1.0 : 0.6
    }
    
    // MARK: - Actions with Modern Feedback
    @IBAction func sendWakeOnLAN(_ sender: NSButton) {
        let macAddress = macAddressField.stringValue
        
        guard isValidMACAddress(macAddress) else {
            showModernAlert(title: "Invalid MAC Address", 
                          message: "Please enter a valid MAC address format.",
                          type: .warning)
            return
        }
        
        // Show loading state
        showLoadingState(for: sender)
        
        // Use async operation to avoid blocking UI
        Task {
            do {
                try await sendMagicPacketAsync(to: macAddress)
                
                await MainActor.run {
                    self.hideLoadingState(for: sender)
                    self.showSuccessFeedback()
                    self.updateStatus("Magic packet sent successfully to \(macAddress)", type: .success)
                }
                
            } catch {
                await MainActor.run {
                    self.hideLoadingState(for: sender)
                    self.showModernAlert(title: "Network Error", 
                                      message: "Failed to send magic packet: \(error.localizedDescription)",
                                      type: .danger)
                }
            }
        }
    }
    
    private func sendMagicPacketAsync(to macAddress: String) async throws {
        let packet = Self.createMagicPacketStatic(macAddress: macAddress)
        
        // Try Network framework first (modern approach)
        do {
            try await sendPacketWithNetworkFrameworkAsync(packet: packet)
            print("✅ Successfully sent packet using Network framework")
            return
        } catch {
            print("❌ Network framework failed: \(error)")
            // Fall back to BSD sockets on background thread
        }
        
        // Fallback: BSD sockets approach on background thread
        try await Task.detached {
            try Self.sendPacketWithBSDSocketsStatic(packet: packet)
        }.value
    }
    
    private func sendPacketWithNetworkFrameworkAsync(packet: Data) async throws {
        let broadcastAddresses = getBroadcastAddresses()
        let wakePorts = [9, 7, 0]
        
        return try await withThrowingTaskGroup(of: Void.self) { group in
            var hasSucceeded = false
            var errors: [Error] = []
            
            for address in broadcastAddresses {
                for port in wakePorts {
                    group.addTask {
                        try await self.sendToEndpoint(packet: packet, address: address, port: port)
                    }
                }
            }
            
            // Collect results from all tasks
            while let result = await group.nextResult() {
                switch result {
                case .success:
                    hasSucceeded = true
                    group.cancelAll()
                    break
                case .failure(let error):
                    errors.append(error)
                }
            }
            
            if !hasSucceeded {
                // If we have errors, throw the first one; otherwise throw a generic error
                if let firstError = errors.first {
                    throw firstError
                } else {
                    throw NSError(domain: "LazyPacket", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to send magic packet to any address"])
                }
            }
        }
    }
    
    private func sendToEndpoint(packet: Data, address: String, port: Int) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(address),
                port: NWEndpoint.Port(integerLiteral: UInt16(port))
            )
            
            let connection = NWConnection(to: endpoint, using: .udp)
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: packet, completion: .contentProcessed { error in
                        connection.cancel()
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            print("✅ Successfully sent packet to \(address):\(port)")
                            continuation.resume()
                        }
                    })
                case .failed(let error):
                    continuation.resume(throwing: error)
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
        }
    }
    
    @IBAction func addDevice(_ sender: NSButton) {
        let macAddress = macAddressField.stringValue
        let deviceName = deviceNameField.stringValue.isEmpty ? "Unnamed Device" : deviceNameField.stringValue
        
        guard isValidMACAddress(macAddress) else {
            showModernAlert(title: "Invalid MAC Address", 
                          message: "Please enter a valid MAC address.",
                          type: .warning)
            return
        }
        
        // Check for duplicates
        if devices.contains(where: { $0.macAddress == macAddress }) {
            showModernAlert(title: "Device Already Exists", 
                          message: "A device with this MAC address is already in your list.",
                          type: .warning)
            return
        }
        
        // Add with animation
        let newDevice = (macAddress: macAddress, deviceName: deviceName)
        devices.append(newDevice)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            tableView.insertRows(at: IndexSet(integer: devices.count - 1), withAnimation: .slideDown)
        }
        
        saveDevices()
        clearInputFields()
        updateStatus("Device '\(deviceName)' added successfully", type: .success)
    }
    
    @IBAction func deleteDevice(_ sender: NSButton) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 else {
            showModernAlert(title: "No Selection", 
                          message: "Please select a device to delete.",
                          type: .warning)
            return
        }
        
        let deviceName = devices[selectedRow].deviceName
        devices.remove(at: selectedRow)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            tableView.removeRows(at: IndexSet(integer: selectedRow), withAnimation: .slideUp)
        }
        
        saveDevices()
        updateButtonStates()
        updateStatus("Device '\(deviceName)' deleted", type: .warning)
    }
    
    // MARK: - Modern UI Feedback
    private func showLoadingState(for button: NSButton) {
        button.isEnabled = false
        let progressIndicator = NSProgressIndicator()
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.startAnimation(nil)
        
        let originalTitle = button.title
        button.title = ""
        button.addSubview(progressIndicator)
        
        // Center the progress indicator within the button
        let size: CGFloat = 16 // Size of small spinning indicator
        progressIndicator.frame = CGRect(
            x: (button.bounds.width - size) / 2,
            y: (button.bounds.height - size) / 2,
            width: size,
            height: size
        )
        
        button.layer?.setValue(originalTitle, forKey: "originalTitle")
        button.layer?.setValue(progressIndicator, forKey: "progressIndicator")
    }
    
    private func hideLoadingState(for button: NSButton) {
        button.isEnabled = true
        
        if let progressIndicator = button.layer?.value(forKey: "progressIndicator") as? NSProgressIndicator {
            progressIndicator.removeFromSuperview()
        }
        
        if let originalTitle = button.layer?.value(forKey: "originalTitle") as? String {
            button.title = originalTitle
        }
    }
    
    private func showSuccessFeedback() {
        // Briefly flash the wake button with success color
        let originalColor = wakeButton.layer?.backgroundColor
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            wakeButton.layer?.backgroundColor = Colors.success.cgColor
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                self.wakeButton.layer?.backgroundColor = originalColor
            }
        }
    }
    
    private enum AlertType {
        case success, warning, danger
        
        var color: NSColor {
            switch self {
            case .success: return Colors.success
            case .warning: return Colors.warning  
            case .danger: return Colors.danger
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .danger: return "xmark.circle.fill"
            }
        }
    }
    
    private func updateStatus(_ message: String, type: AlertType) {
        statusLabel.stringValue = message
        statusLabel.textColor = type.color
        
        // Auto-clear after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.statusLabel.stringValue == message {
                self.statusLabel.stringValue = "Ready to send Wake-on-LAN packets"
                self.statusLabel.textColor = Colors.textSecondary
            }
        }
    }
    
    private func showModernAlert(title: String, message: String, type: AlertType) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = type == .danger ? .critical : .informational
        
        if let image = NSImage(systemSymbolName: type.icon, accessibilityDescription: nil) {
            alert.icon = image
        }
        
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func clearInputFields() {
        macAddressField.stringValue = ""
        deviceNameField.stringValue = ""
        macAddressField.layer?.borderColor = Colors.secondary.cgColor
        macAddressField.layer?.borderWidth = 1
        updateButtonStates()
    }
    
    // MARK: - Table View Setup
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    // MARK: - Core Functionality (Enhanced)
    func isValidMACAddress(_ macAddress: String) -> Bool {
        let pattern = "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$"
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: macAddress.utf16.count)
            return regex.firstMatch(in: macAddress, options: [], range: range) != nil
        } catch {
            return false
        }
    }
    
    func sendMagicPacket(to macAddress: String) throws {
        let packet = Self.createMagicPacketStatic(macAddress: macAddress)
        
        // Try Network framework first (modern approach)
        do {
            try sendPacketWithNetworkFramework(packet: packet)
            print("✅ Successfully sent packet using Network framework")
            return
        } catch {
            print("❌ Network framework failed: \(error)")
            // Fall back to BSD sockets
        }
        
        // Fallback: BSD sockets approach
        try sendPacketWithBSDSockets(packet: packet)
    }
    

    private func sendPacketWithBSDSockets(packet: Data) throws {
        try Self.sendPacketWithBSDSocketsStatic(packet: packet)
    }
    
    nonisolated private static func sendPacketWithBSDSocketsStatic(packet: Data) throws {
        // Create UDP socket
        let socketFd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFd != -1 else {
            let errorCode = errno
            let errorString = String(cString: strerror(errorCode))
            throw NSError(domain: "LazyPacket", code: Int(errorCode), userInfo: [NSLocalizedDescriptionKey: "Failed to create socket: \(errorString)"])
        }
        
        defer {
            close(socketFd)
        }
        
        // Enable broadcast
        var broadcast: Int32 = 1
        let broadcastResult = setsockopt(socketFd, SOL_SOCKET, SO_BROADCAST, &broadcast, socklen_t(MemoryLayout<Int32>.size))
        guard broadcastResult == 0 else {
            let errorCode = errno
            let errorString = String(cString: strerror(errorCode))
            throw NSError(domain: "LazyPacket", code: Int(errorCode), userInfo: [NSLocalizedDescriptionKey: "Failed to enable broadcast: \(errorString)"])
        }
        
        // Set socket timeout
        var timeout = timeval()
        timeout.tv_sec = 5
        timeout.tv_usec = 0
        setsockopt(socketFd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        
        // Get dynamic broadcast addresses
        let broadcastAddresses = Self.getBroadcastAddressesStatic()
        let wakePorts = [9, 7, 0]
        
        var lastError: Error?
        var packetSent = false
        
        // Try sending to all broadcast addresses and ports
        for address in broadcastAddresses {
            for port in wakePorts {
                do {
                    try Self.sendPacketToBSDStatic(packet, socketFd: socketFd, address: address, port: port)
                    packetSent = true
                    print("✅ Successfully sent packet to \(address):\(port)")
                    break // Success, exit inner loop
                } catch {
                    lastError = error
                    print("❌ Failed to send to \(address):\(port) - \(error)")
                }
            }
            if packetSent { break } // Success, exit outer loop
        }
        
        if !packetSent {
            throw lastError ?? NSError(domain: "LazyPacket", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to send magic packet"])
        }
    }
    
    private func sendPacketWithNetworkFramework(packet: Data) throws {
        // This is a synchronous wrapper that shouldn't be used for new code
        // but exists for compatibility with the existing synchronous method
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<Void, Error>?
        
        Task {
            do {
                try await sendPacketWithNetworkFrameworkAsync(packet: packet)
                result = .success(())
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        switch result {
        case .success():
            return
        case .failure(let error):
            throw error
        case .none:
            throw NSError(domain: "LazyPacket", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network operation failed"])
        }
    }
    
    private func sendPacketToBSD(_ packet: Data, socketFd: Int32, address: String, port: Int) throws {
        try Self.sendPacketToBSDStatic(packet, socketFd: socketFd, address: address, port: port)
    }
    
    nonisolated private static func sendPacketToBSDStatic(_ packet: Data, socketFd: Int32, address: String, port: Int) throws {
        // Validate address
        guard inet_addr(address) != INADDR_NONE else {
            throw NSError(domain: "LazyPacket", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid address: \(address)"])
        }
        
        // Set up destination address
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(UInt16(port).bigEndian)
        addr.sin_addr.s_addr = inet_addr(address)
        
        // Send packet
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
            throw NSError(domain: "LazyPacket", code: Int(errorCode), userInfo: [NSLocalizedDescriptionKey: "Failed to send packet: \(errorString)"])
        }
        
        guard sentBytes == packet.count else {
            throw NSError(domain: "LazyPacket", code: 3, userInfo: [NSLocalizedDescriptionKey: "Partial send: \(sentBytes)/\(packet.count) bytes"])
        }
    }
    
    private func getBroadcastAddresses() -> [String] {
        return Self.getBroadcastAddressesStatic()
    }
    
    nonisolated private static func getBroadcastAddressesStatic() -> [String] {
        // Use same logic as WakeOnLANViewModel
        let calculatedBroadcasts = Self.calculateBroadcastAddressesStatic()
        if !calculatedBroadcasts.isEmpty {
            print("Using calculated broadcast addresses: \(calculatedBroadcasts)")
            return calculatedBroadcasts
        }
        
        // Fallback addresses
        let fallbackAddresses = [
            "192.168.1.255",
            "192.168.0.255",
            "10.0.0.255",
            "172.16.255.255"
        ]
        
        print("Using fallback broadcast addresses: \(fallbackAddresses)")
        return fallbackAddresses
    }
    
    private func calculateBroadcastAddresses() -> [String] {
        return Self.calculateBroadcastAddressesStatic()
    }
    
    nonisolated private static func calculateBroadcastAddressesStatic() -> [String] {
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
            
            // Skip VPN interfaces
            if interfaceName.hasPrefix("utun") || interfaceName.hasPrefix("ipsec") {
                continue
            }
            
            let networkAddr = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0 }
            let netmaskAddr = netmask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0 }
            
            let ipAddress = networkAddr.pointee.sin_addr.s_addr
            let subnetMask = netmaskAddr.pointee.sin_addr.s_addr
            
            // Calculate broadcast address: IP | (~subnet_mask)
            let broadcastAddr = ipAddress | (~subnetMask)
            
            var broadcastSockAddr = in_addr()
            broadcastSockAddr.s_addr = broadcastAddr
            
            let broadcastString = String(cString: inet_ntoa(broadcastSockAddr))
            
            if !broadcastAddresses.contains(broadcastString) && 
               broadcastString != "0.0.0.0" &&
               broadcastString != "255.255.255.255" {
                broadcastAddresses.append(broadcastString)
            }
        }
        
        print("Calculated broadcast addresses: \(broadcastAddresses)")
        return broadcastAddresses
    }
    
    func createMagicPacket(macAddress: String) -> Data {
        return Self.createMagicPacketStatic(macAddress: macAddress)
    }
    
    nonisolated static func createMagicPacketStatic(macAddress: String) -> Data {
        var data = Data(repeating: 0xFF, count: 6) // Magic packet header
        
        // Parse MAC address
        let macComponents = macAddress.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "")
        let macBytes = stride(from: 0, to: macComponents.count, by: 2).compactMap { index in
            let start = macComponents.index(macComponents.startIndex, offsetBy: index)
            let end = macComponents.index(start, offsetBy: 2)
            return UInt8(macComponents[start..<end], radix: 16)
        }
        
        // Repeat MAC address 16 times
        for _ in 0..<16 {
            data.append(contentsOf: macBytes)
        }
        
        return data
    }
    
    // MARK: - Persistence
    private func saveDevices() {
        let data = devices.map { ["macAddress": $0.macAddress, "deviceName": $0.deviceName] }
        UserDefaults.standard.set(data, forKey: "savedDevices")
    }
    
    private func loadDevices() {
        if let data = UserDefaults.standard.array(forKey: "savedDevices") as? [[String: String]] {
            devices = data.compactMap { dict in
                guard let macAddress = dict["macAddress"],
                      let deviceName = dict["deviceName"] else { return nil }
                return (macAddress: macAddress, deviceName: deviceName)
            }
            tableView.reloadData()
        }
    }
}

// MARK: - Table View Data Source & Delegate
extension ModernViewController: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return devices.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let device = devices[row]
        let cellIdentifier: String
        let cellValue: String
        let isEditable: Bool
        
        if tableColumn == tableView.tableColumns[0] {
            cellIdentifier = "MacAddressCell"
            cellValue = device.macAddress
            isEditable = false
        } else {
            cellIdentifier = "DeviceNameCell"
            cellValue = device.deviceName
            isEditable = true
        }
        
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(cellIdentifier), owner: nil) as? NSTableCellView {
            
            cell.textField?.stringValue = cellValue
            cell.textField?.isEditable = isEditable
            cell.textField?.textColor = Colors.text
            cell.textField?.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            cell.textField?.delegate = self
            
            // Style the cell
            if tableColumn == tableView.tableColumns[0] {
                cell.textField?.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
                cell.textField?.textColor = Colors.primary
            }
            
            return cell
        }
        
        return nil
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 {
            let device = devices[selectedRow]
            macAddressField.stringValue = device.macAddress
            deviceNameField.stringValue = device.deviceName
            
            // Trigger validation
            macAddressDidChange()
            
            // Subtle selection feedback
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                macAddressField.layer?.backgroundColor = Colors.primary.withAlphaComponent(0.1).cgColor
            } completionHandler: {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3
                    self.macAddressField.layer?.backgroundColor = Colors.background.cgColor
                }
            }
        }
        
        updateButtonStates()
    }
}

// MARK: - Text Field Delegate
extension ModernViewController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        let row = tableView.row(for: textField)
        
        if row >= 0 && row < devices.count {
            devices[row].deviceName = textField.stringValue.isEmpty ? "Unnamed Device" : textField.stringValue
            saveDevices()
            updateStatus("Device name updated", type: .success)
        }
    }
}

// MARK: - Mouse Tracking for Button Hover Effects
extension ModernViewController {
    override func mouseEntered(with event: NSEvent) {
        if let button = event.trackingArea?.owner as? NSButton {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                button.layer?.transform = CATransform3DMakeScale(1.02, 1.02, 1.0)
                button.alphaValue = 0.9
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if let button = event.trackingArea?.owner as? NSButton {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                button.layer?.transform = CATransform3DIdentity
                button.alphaValue = button.isEnabled ? 1.0 : 0.6
            }
        }
    }
}