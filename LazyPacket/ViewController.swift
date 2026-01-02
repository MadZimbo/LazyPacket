import Cocoa

import Foundation
import Network
import Darwin
import Darwin.C
import Darwin.POSIX.sys.socket
import Darwin.POSIX.netinet.`in`
import Darwin.POSIX.ifaddrs
import Darwin.POSIX.sys.time

class ViewController: NSViewController {

    @IBOutlet weak var macAddressField: NSTextField!
    @IBOutlet weak var addButton: NSButton!
    @IBOutlet weak var deleteButton: NSButton!
    @IBOutlet weak var tableView: NSTableView!
    
    var macAddresses: [(macAddress: String, deviceName: String)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        // Observing changes in the text field
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange), name: NSControl.textDidChangeNotification, object: macAddressField)
        tableView.delegate = self
        tableView.dataSource = self
        loadMacAddresses()
    }
    
    @objc func textDidChange(notification: Notification) {
        // Perform validation on text change
        let macAddress = macAddressField.stringValue
        if isValidMACAddress(macAddress) {
            macAddressField.textColor = .green // Valid MAC Address
        } else {
            macAddressField.textColor = .red // Invalid MAC Address
        }
    }
    
    @IBAction func sendWoL(_ sender: NSButton) {
        let macAddress = macAddressField.stringValue
        let normalColor = NSColor.textColor
        let errorColor = NSColor.red
        
        if isValidMACAddress(macAddress) {
            macAddressField.textColor = normalColor // Reset to normal color
            do {
                try sendMagicPacket(to: macAddress)
                showAlert(message: "Magic packet sent successfully to \(macAddress)", informativeText: "The wake-on-LAN packet was sent.")
            } catch {
                showAlert(message: "Error", informativeText: "Failed to send magic packet: \(error)")
            }
        } else {
            macAddressField.textColor = errorColor // Show error state
            showAlert(message: "Invalid MAC Address", informativeText: "Please enter a valid MAC address.")
        }
    }
    
    @IBAction func addMacAddress(_ sender: NSButton) {
        let macAddress = macAddressField.stringValue
        
        if isValidMACAddress(macAddress) {
            let newDevice = (macAddress: macAddress, deviceName: "New Device")
            macAddresses.append(newDevice)
            tableView.reloadData()
            saveMacAddresses()
            
            macAddressField.stringValue = ""
            macAddressField.textColor = .textColor
        } else {
            showAlert(message: "Invalid MAC Address", informativeText: "Please enter a valid MAC address.")
        }
    }
    
    @IBAction func deleteMacAddress(_ sender: NSButton) {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 {
            macAddresses.remove(at: selectedRow)
            tableView.reloadData()
            saveMacAddresses()
        } else {
            showAlert(message: "No Selection", informativeText: "Please select a MAC address to delete.")
        }
    }
    
    func showAlert(message: String, informativeText: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func isValidMACAddress(_ macAddress: String) -> Bool {
        let pattern = "^([0-9a-f]{1,2}[\\.:-]){5}([0-9a-f]{1,2})$"
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let nsString = macAddress as NSString
            let matches = regex.matches(in: macAddress, options: [], range: NSRange(location: 0, length: nsString.length))
            return matches.count > 0
        } catch {
            print("Regex error: \(error)")
            return false
        }
    }
    
    func sendMagicPacket(to macAddress: String) throws {
        let packet = createMagicPacket(macAddress: macAddress)
        
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
        let broadcastAddresses = getBroadcastAddresses()
        
        var lastError: Error?
        var packetSent = false
        
        // Try sending to all broadcast addresses
        for address in broadcastAddresses {
            do {
                try sendPacketToBSD(packet, socketFd: socketFd, address: address, port: 9)
                packetSent = true
                print("✅ Successfully sent packet to \(address)")
                break
            } catch {
                lastError = error
                print("❌ Failed to send to \(address) - \(error)")
            }
        }
        
        if !packetSent {
            throw lastError ?? NSError(domain: "LazyPacket", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to send magic packet"])
        }
    }
    
    private func sendPacketToBSD(_ packet: Data, socketFd: Int32, address: String, port: Int) throws {
        // Validate address
        guard inet_addr(address) != INADDR_NONE else {
            throw NSError(domain: "LazyPacket", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid address: \(address)"])
        }
        
        // Set up destination address
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
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
    }
    
    private func getBroadcastAddresses() -> [String] {
        // Simple broadcast address detection for basic ViewController
        return ["192.168.1.255", "192.168.0.255", "10.0.0.255", "172.16.255.255"]
    }
    
    func createMagicPacket(macAddress: String) -> Data {
        var data = Data(repeating: 0xFF, count: 6)
        let macBytes = macAddress.split(separator: ":").compactMap { UInt8($0, radix: 16) }
        for _ in 0..<16 {
            data.append(contentsOf: macBytes)
        }
        return data
    }
}

// MARK: - Table View Data Source and Delegate

extension ViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return macAddresses.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier: String
        let cellValue: String
        
        if tableColumn == tableView.tableColumns[0] {
            cellIdentifier = "MacAddressCell"
            cellValue = macAddresses[row].macAddress
        } else {
            cellIdentifier = "DeviceNameCell"
            cellValue = macAddresses[row].deviceName
        }
        
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = cellValue
            cell.textField?.isEditable = tableColumn == tableView.tableColumns[1] // Allow editing only for the device name
            cell.textField?.delegate = self
            
            // Ensure text is visible by setting text color and font
            cell.textField?.textColor = .white
            cell.textField?.font = NSFont.systemFont(ofSize: 12)
            
            return cell
        }
        
        return nil
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 {
            let selectedMacAddress = macAddresses[selectedRow].macAddress
            macAddressField.stringValue = selectedMacAddress
            
            // Validate the selected MAC address and update the text color
            if isValidMACAddress(selectedMacAddress) {
                macAddressField.textColor = .green // Valid MAC Address
            } else {
                macAddressField.textColor = .red // Invalid MAC Address
            }
        }
    }
}

// MARK: - Persistence

extension ViewController {
    
    func saveMacAddresses() {
        let data = macAddresses.map { ["macAddress": $0.macAddress, "deviceName": $0.deviceName] }
        UserDefaults.standard.set(data, forKey: "macAddresses")
    }
    
    func loadMacAddresses() {
        if let data = UserDefaults.standard.array(forKey: "macAddresses") as? [[String: String]] {
            macAddresses = data.compactMap { dict in
                if let macAddress = dict["macAddress"], let deviceName = dict["deviceName"] {
                    return (macAddress: macAddress, deviceName: deviceName)
                }
                return nil
            }
        }
    }
}

extension ViewController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        let row = tableView.row(for: textField)
        if row >= 0 && row < macAddresses.count {
            macAddresses[row].deviceName = textField.stringValue
            saveMacAddresses()
        }
    }
}

