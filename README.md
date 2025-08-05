# flutter_thermal_printer

<img src="https://res.cloudinary.com/daagzbhsu/image/upload/v1735536729/vxobf0gilq0pixfsnjw1.png" />

![Visits Badge](https://badges.pufler.dev/visits/SunilDevX/flutter_thermal_printer)


## Buy Me A Coffee
If you find this project helpful and want to support its development, you can buy me a coffee:

<a href="https://www.buymeacoffee.com/SunilDevX" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

## Getting Started

This plugin is used to print data on thermal printers with ease across multiple platforms.

## Currently Supported

| Service                        | Android | iOS | macOS | Windows |
| ------------------------------ | :-----: | :-: | :---: | :-----: |
| Bluetooth                      | ✅      | ✅  | ✅    | ✅      |
| USB                            | ✅      |     | ✅    | ✅      |
| BLE                            | ✅      | ✅  | ✅    | ✅      |
| WiFi                           | ✅      | ✅  | ✅    | ✅      |

```dart
final _flutterThermalPrinterPlugin = FlutterThermalPrinter.instance;

// Enum ConnectionType
enum ConnectionType {
  BLE,
  USB,
  NETWORK,
}

// Additional Functions
// Recommended Function for getting printers
getPrinters(
  refreshDuration: Duration,
  connectionTypes: List<ConnectionType>,
) {
  // Supports WINDOWS, ANDROID for USB
  // MAC, IOS, ANDROID, WINDOWS for BLUETOOTH.
}

// Refer to Example for Complete code 
```

---

## Bluetooth Services

| Feature                        | Android | iOS | macOS | Windows |
| ------------------------------ | :-----: | :-: | :---: | :-----: |
| Start scanning                 | ✅      | ✅  | ✅    | ✅      |
| Stop scanning                  | ✅      | ✅  | ✅    | ✅      |
| Connect printer                | ✅      | ✅  | ✅    | ✅      |
| Disconnect printer             | ✅      | ✅  | ✅    | ✅      |
| Print data                     | ✅      | ✅  | ✅    | ✅      |
| Print widget                   | ✅      | ✅  | ✅    | ✅      |

---

## USB Services

| Feature                        | Android | iOS | macOS | Windows |
| ------------------------------ | :-----: | :-: | :---: | :-----: |
| Start scanning                 | ✅      |     | ✅    | ✅      |
| Stop scanning                  | ✅      |     |       | ✅      |
| Connect printer                | ✅      |     |       | ✅      |
| Print data                     | ✅      |     |       | ✅      |
| Print widget                   | ✅      |     |       | ✅      |

---

## WiFi Services

| Feature                        | Android | iOS | macOS | Windows |
| ------------------------------ | :-----: | :-: | :---: | :-----: |
| Connect printer                | ✅      | ✅  | ✅    | ✅      |
| Disconnect printer             | ✅      | ✅  | ✅    | ✅      |
| Print data                     | ✅      | ✅  | ✅    | ✅      |
| Print widget                   | ✅      | ✅  | ✅    | ✅      |

---

## Printer Model Class

```dart
String? address;
String? name;
ConnectionType? connectionType;
bool? isConnected;
String? vendorId;
String? productId;
```

---

## Additional Features

### Screenshot to Printer
Easily capture and print widgets as images using the `printWidget` method.

### Image Cropping for Long Prints
Handles long data by cropping images and printing them in chunks to ensure seamless printing on devices with limited buffer capacity.

### Connection Type Validation
- Ensures `ConnectionType` compatibility and alerts when unsupported combinations are used. 

### BLE State Monitoring
Provides real-time monitoring for Bluetooth states, ensuring proactive error handling and reconnections.

---

## Notes and Recommendations

- **Windows Users:** Make sure you have the POS-X driver installed on Windows for printer compatibility.  
  Download the driver from [POS-X Drivers](https://pos-x.com/downloads/driver/).

- **Cross-Platform Usage:** Ensure Bluetooth permissions and configurations are set correctly for Android and iOS.

---

## Contributing Guidelines

We welcome contributions to enhance the plugin's functionality!  
To contribute, please fork the repository, make changes, and submit a pull request.  
For bug reports or feature requests, feel free to open an issue.
 

---

## Contributors

![Contributors Display](https://badges.pufler.dev/contributors/SunilDevX/flutter_thermal_printer?size=50&padding=5&perRow=10&bots=true)


Feel free to contribute to this project and help make it better for everyone!

---