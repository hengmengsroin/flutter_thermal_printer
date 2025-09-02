// ignore_for_file: prefer_foreach

import 'dart:async';
import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:universal_ble/universal_ble.dart';

import '../flutter_thermal_printer_platform_interface.dart';
import '../utils/printer.dart';

class OtherPrinterManager {
  OtherPrinterManager._privateConstructor();

  static OtherPrinterManager? _instance;

  static OtherPrinterManager get instance {
    _instance ??= OtherPrinterManager._privateConstructor();
    return _instance!;
  }

  final StreamController<List<Printer>> _devicesStream =
      StreamController<List<Printer>>.broadcast();

  Stream<List<Printer>> get devicesStream => _devicesStream.stream;

  StreamSubscription? _bleSubscription;
  StreamSubscription? _usbSubscription;
  StreamSubscription? _bleAvailabilitySubscription;

  static const String _channelName = 'flutter_thermal_printer/events';
  final EventChannel _eventChannel = const EventChannel(_channelName);

  final List<Printer> _devices = [];

  /// Initialize the manager and check BLE availability
  Future<void> initialize() async {
    try {
      // Check BLE availability
      final isAvailable = await UniversalBle.getBluetoothAvailabilityState();
      log('Bluetooth availability: $isAvailable');
    } catch (e) {
      log('Failed to initialize printer manager: $e');
    }
  }

  /// Optimized stop scanning with better resource cleanup
  Future<void> stopScan({
    bool stopBle = true,
    bool stopUsb = true,
  }) async {
    try {
      if (stopBle) {
        await _bleSubscription?.cancel();
        _bleSubscription = null;
        await UniversalBle.stopScan();
      }
      if (stopUsb) {
        await _usbSubscription?.cancel();
        _usbSubscription = null;
      }
    } catch (e) {
      log('Failed to stop scanning for devices: $e');
    }
  }

  /// Dispose all resources
  Future<void> dispose() async {
    await stopScan();
    await _bleAvailabilitySubscription?.cancel();
    await _devicesStream.close();
  }

  StreamSubscription? connectionStreamSubscription;
  Timer? connectionTimeoutTimer;

  /// Connect to a printer device
  Future<bool> connect(Printer device) async {
    if (device.connectionType == ConnectionType.USB) {
      return FlutterThermalPrinterPlatform.instance.connect(device);
    } else if (device.connectionType == ConnectionType.BLE) {
      try {
        final isConnected = Completer<bool>();
        if (device.address == null) {
          log('Device address is null');
          return false;
        }

        await device.connect();
        connectionStreamSubscription =
            device.connectionStream.listen((connected) {
          if (!isConnected.isCompleted) {
            isConnected.complete(connected);
          }
        });

        // Set up timeout
        connectionTimeoutTimer = Timer(const Duration(seconds: 10), () {
          if (!isConnected.isCompleted) {
            isConnected.complete(false);
          }
        });

        final result = await isConnected.future;
        await connectionStreamSubscription?.cancel();
        connectionTimeoutTimer?.cancel();
        log('Connection status: $result for device ${device.name}');
        return result;
      } catch (e) {
        log('Failed to connect to BLE device: $e');
        return false;
      }
    }
    return false;
  }

  /// Check if a device is connected
  Future<bool> isConnected(Printer device) async {
    if (device.connectionType == ConnectionType.USB) {
      return FlutterThermalPrinterPlatform.instance.isConnected(device);
    } else if (device.connectionType == ConnectionType.BLE) {
      try {
        if (device.address == null) {
          return false;
        }
        return device.isConnected ?? false;
      } catch (e) {
        log('Failed to check connection status: $e');
        return false;
      }
    }
    return false;
  }

  /// Disconnect from a printer device
  Future<void> disconnect(Printer device) async {
    if (device.connectionType == ConnectionType.BLE) {
      try {
        if (device.address != null) {
          await device.disconnect();
          log('Disconnected from device ${device.name}');
        }
      } catch (e) {
        log('Failed to disconnect device: $e');
      }
    }
  }

  List<Map<String, BleCharacteristic?>> characteristicList = [];

  /// Print data to printer device
  Future<void> printData(
    Printer printer,
    List<int> bytes, {
    bool longData = false,
  }) async {
    if (printer.connectionType == ConnectionType.USB) {
      try {
        await FlutterThermalPrinterPlatform.instance.printText(
          printer,
          Uint8List.fromList(bytes),
          path: printer.address,
        );
      } catch (e) {
        log('FlutterThermalPrinter: Unable to Print Data $e');
      }
    } else if (printer.connectionType == ConnectionType.BLE) {
      try {
        BleCharacteristic? writeCharacteristic;
        final hasCharacteristic = characteristicList.where(
          (element) => element.containsKey(printer.address),
        );
        if (hasCharacteristic.isNotEmpty) {
          writeCharacteristic = hasCharacteristic.first[printer.address];
        } else {
          final services = await printer.discoverServices();

          for (final service in services) {
            for (final characteristic in service.characteristics) {
              if (characteristic.properties.contains(
                CharacteristicProperty.write,
              )) {
                writeCharacteristic = characteristic;
                break;
              }
            }
          }
        }

        if (writeCharacteristic == null) {
          log('No write characteristic found');
          return;
        }

        const maxChunkSize = 30;
        for (var i = 0; i < bytes.length; i += maxChunkSize) {
          final chunk = bytes.sublist(
            i,
            i + maxChunkSize > bytes.length ? bytes.length : i + maxChunkSize,
          );

          await writeCharacteristic.write(
            Uint8List.fromList(chunk),
          );
        }
        return;
      } catch (e) {
        log('Failed to print data to device $e');
      }
    }
  }

  /// Get Printers from BT and USB
  Future<void> getPrinters({
    List<ConnectionType> connectionTypes = const [
      ConnectionType.BLE,
      ConnectionType.USB,
    ],
    bool androidUsesFineLocation = false,
  }) async {
    if (connectionTypes.isEmpty) {
      throw Exception('No connection type provided');
    }

    if (connectionTypes.contains(ConnectionType.USB)) {
      await _getUSBPrinters();
    }

    if (connectionTypes.contains(ConnectionType.BLE)) {
      await _getBLEPrinters(androidUsesFineLocation);
    }
  }

  /// USB printer discovery
  Future<void> _getUSBPrinters() async {
    try {
      final devices =
          await FlutterThermalPrinterPlatform.instance.startUsbScan();

      final usbPrinters = <Printer>[];
      for (final map in devices) {
        final isConnected =
            await FlutterThermalPrinterPlatform.instance.isConnected(
          Printer(
            vendorId: map['vendorId'].toString(),
            productId: map['productId'].toString(),
          ),
        );

        final printer = Printer(
          vendorId: map['vendorId'].toString(),
          productId: map['productId'].toString(),
          name: map['name'],
          connectionType: ConnectionType.USB,
          address: map['vendorId'].toString(),
          isConnected: isConnected,
        );
        usbPrinters.add(printer);
      }

      _devices.addAll(usbPrinters);
      await _usbSubscription?.cancel();
      _usbSubscription = _eventChannel.receiveBroadcastStream().listen((event) {
        final map = Map<String, dynamic>.from(event);
        _updateOrAddPrinter(
          Printer(
            vendorId: map['vendorId'].toString(),
            productId: map['productId'].toString(),
            name: map['name'],
            connectionType: ConnectionType.USB,
            address: map['vendorId'].toString(),
            isConnected: map['connected'] ?? false,
          ),
        );
      });

      sortDevices();
    } catch (e) {
      log('$e [USB Connection]');
    }
  }

  /// Universal BLE scanner implementation
  Future<void> _getBLEPrinters(bool androidUsesFineLocation) async {
    try {
      await _bleSubscription?.cancel();
      _bleSubscription = null;

      // Check bluetooth availability
      final availability = await UniversalBle.getBluetoothAvailabilityState();
      if (availability != AvailabilityState.poweredOn) {
        log('Bluetooth is not powered on. Current state: $availability');
        if (availability == AvailabilityState.poweredOff) {
          throw Exception('Bluetooth is turned off. Please enable Bluetooth.');
        }
        return;
      }

      // Stop any ongoing scan
      await UniversalBle.stopScan();

      // Start scanning
      await UniversalBle.startScan();
      log('Started BLE scan');

      sortDevices();

      // Listen to scan results using universal_ble
      _bleSubscription = UniversalBle.scanStream.listen(
        (scanResult) async {
          if (scanResult.name?.isNotEmpty ?? false) {
            _updateOrAddPrinter(
              Printer(
                address: scanResult.deviceId,
                name: scanResult.name,
                connectionType: ConnectionType.BLE,
                isConnected: await scanResult.isConnected,
              ),
            );
          }
        },
        onError: (error) {
          log('BLE scan error: $error');
        },
      );
    } catch (e) {
      log('Failed to start BLE scan: $e');
      rethrow;
    }
  }

  /// Update or add printer to the devices list
  void _updateOrAddPrinter(Printer printer) {
    final index =
        _devices.indexWhere((device) => device.address == printer.address);
    if (index == -1) {
      _devices.add(printer);
    } else {
      _devices[index] = printer;
    }
    sortDevices();
  }

  /// Sort and filter devices
  void sortDevices() {
    _devices
        .removeWhere((element) => element.name == null || element.name == '');
    // remove items having same vendorId
    final seen = <String>{};
    _devices.retainWhere((element) {
      final uniqueKey = '${element.vendorId}_${element.address}';
      if (seen.contains(uniqueKey)) {
        return false; // Remove duplicate
      } else {
        seen.add(uniqueKey); // Mark as seen
        return true; // Keep
      }
    });
    _devicesStream.add(_devices);
  }

  /// Turn on Bluetooth (universal approach)
  Future<void> turnOnBluetooth() async {
    try {
      final availability = await UniversalBle.getBluetoothAvailabilityState();
      if (availability == AvailabilityState.poweredOff) {
        await UniversalBle.enableBluetooth();
      }
    } catch (e) {
      log('Failed to turn on Bluetooth: $e');
    }
  }

  /// Stream to monitor Bluetooth state
  Stream<bool> get isBleTurnedOnStream =>
      Stream.periodic(const Duration(seconds: 5), (_) async {
        final state = await UniversalBle.getBluetoothAvailabilityState();
        return state == AvailabilityState.poweredOn;
      }).asyncMap((event) => event).distinct();
}
