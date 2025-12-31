# LazyPacket ⚡

A sleek and simple Wake-on-LAN utility for macOS that allows you to remotely wake up network devices with magic packets.

<p align="center">
  <img src="https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-FA7343?style=for-the-badge&logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge" alt="License">
</p>

## ✨ Features

- 🎯 **Simple & Intuitive**: Clean macOS interface for managing network devices
- ⚡ **Instant Wake**: Send Wake-on-LAN magic packets with a single click
- 📱 **Device Management**: Save and organize your network devices with custom names
- ✅ **Real-time Validation**: Live MAC address format validation
- 💾 **Persistent Storage**: Automatically saves your device list
- 🔍 **Smart Selection**: Click any saved device to auto-populate the wake field
- 🖥️ **Native macOS**: Built with AppKit for optimal performance

## 🚀 Quick Start

### Prerequisites

- macOS 10.15+ (Catalina or later)
- Xcode 12.0+ (for building from source)
- Target devices must have Wake-on-LAN enabled in BIOS/UEFI

### Installation

#### Option 1: Download Binary (Coming Soon)


#### Option 2: Build from Source
```bash
git clone https://github.com/MadZimbo/LazyPacket.git
cd LazyPacket
open LazyPacket.xcodeproj
```

Build and run in Xcode (⌘+R)

## 🎮 Usage

### Adding Devices
1. Enter the target device's MAC address (format: `AA:BB:CC:DD:EE:FF`)
2. Optionally add a friendly device name
3. Click **"Add Device"** to save it to your list

### Waking Devices
1. **Quick Wake**: Enter a MAC address and click **"Send Magic Packet"**
2. **From Saved List**: Select a saved device and click **"Send Magic Packet"**

### Managing Devices
- **Edit Names**: click device names in the list to edit
- **Remove Devices**: Select a device and click **"Delete"**


## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.


## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

