// ignore_for_file: prefer_foreach

import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../flutter_thermal_printer_platform_interface.dart';
import '../utils/printer.dart';

/// Optimized printer manager for non-Windows platforms
/// Handles BLE and USB printer discovery and operations
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

  static const String _channelName = 'flutter_thermal_printer/events';
  final EventChannel _eventChannel = const EventChannel(_channelName);

  bool get _isApplePlatform => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  final List<Printer> _devices = [];

  /// Optimized stop scanning with better resource cleanup
  Future<void> stopScan({
    bool stopBle = true,
    bool stopUsb = true,
  }) async {
    try {
      if (stopBle) {
        await _bleSubscription?.cancel();
        _bleSubscription = null;
        await FlutterBluePlus.stopScan();
      }
      if (stopUsb) {
        await _usbSubscription?.cancel();
        _usbSubscription = null;
      }
    } catch (e) {
      log('Failed to stop scanning for devices: $e');
    }
  }

  Future<bool> connect(Printer device) async {
    if (device.connectionType == ConnectionType.USB) {
      return FlutterThermalPrinterPlatform.instance.connect(device);
    } else {
      try {
        var isConnected = false;
        final bt = BluetoothDevice.fromId(device.address!);
        await bt.connect();
        final stream = bt.connectionState.listen((event) {
          if (event == BluetoothConnectionState.connected) {
            isConnected = true;
          }
        });
        await Future.delayed(const Duration(seconds: 3));
        await stream.cancel();
        return isConnected;
      } catch (e) {
        return false;
      }
    }
  }

  Future<bool> isConnected(Printer device) async {
    if (device.connectionType == ConnectionType.USB) {
      return FlutterThermalPrinterPlatform.instance.isConnected(device);
    } else {
      try {
        final bt = BluetoothDevice.fromId(device.address!);
        return bt.isConnected;
      } catch (e) {
        return false;
      }
    }
  }

  Future<void> disconnect(Printer device) async {
    if (device.connectionType == ConnectionType.BLE) {
      try {
        final bt = BluetoothDevice.fromId(device.address!);
        await bt.disconnect();
      } catch (e) {
        log('Failed to disconnect device');
      }
    }
  }

  // Print data to BLE device
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
    } else {
      try {
        final device = BluetoothDevice.fromId(printer.address!);
        if (!device.isConnected) {
          log('Device is not connected');
          return;
        }

        final services = (await device.discoverServices()).skipWhile(
          (value) => value.characteristics
              .where((element) => element.properties.write)
              .isEmpty,
        );

        BluetoothCharacteristic? writeCharacteristic;
        for (final service in services) {
          for (final characteristic in service.characteristics) {
            if (characteristic.properties.write) {
              writeCharacteristic = characteristic;
              break;
            }
          }
        }

        if (writeCharacteristic == null) {
          log('No write characteristic found');
          return;
        }

        const maxChunkSize = 512;
        for (var i = 0; i < bytes.length; i += maxChunkSize) {
          final chunk = bytes.sublist(
            i,
            i + maxChunkSize > bytes.length ? bytes.length : i + maxChunkSize,
          );

          await writeCharacteristic.write(
            Uint8List.fromList(chunk),
            withoutResponse: !longData,
            allowLongWrite: longData,
          );
        }

        return;
      } catch (e) {
        log('Failed to print data to device $e');
      }
    }
  }

  // Get Printers from BT and USB
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

  Future<void> _getBLEPrinters(bool androidUsesFineLocation) async {
    try {
      await _bleSubscription?.cancel();
      _bleSubscription = null;
      if (!_isApplePlatform) {
        if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
          await FlutterBluePlus.turnOn();
        }
      } else {
        final state = await FlutterBluePlus.adapterState.first;
        if (state == BluetoothAdapterState.off) {
          log('Bluetooth is off, turning on.');
          return;
        }
      }

      await FlutterBluePlus.stopScan();
      await FlutterBluePlus.startScan(
        androidUsesFineLocation: androidUsesFineLocation,
      );

      // Get system devices
      final systemDevices = await _getBLESystemDevices();
      _devices.addAll(systemDevices);

      // Get bonded devices (Android only)
      if (Platform.isAndroid) {
        final bondedDevices = await _getBLEBondedDevices();
        _devices.addAll(bondedDevices);
      }

      sortDevices();

      // Listen to scan results
      _bleSubscription = FlutterBluePlus.scanResults.listen((result) {
        final devices = result
            .map(
              (e) => Printer(
                address: e.device.remoteId.str,
                name: e.device.platformName,
                connectionType: ConnectionType.BLE,
                isConnected: e.device.isConnected,
              ),
            )
            .where((device) => device.name?.isNotEmpty ?? false)
            .toList();

        for (final device in devices) {
          _updateOrAddPrinter(device);
        }
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Printer>> _getBLESystemDevices() async =>
      (await FlutterBluePlus.systemDevices([]))
          .map(
            (device) => Printer(
              address: device.remoteId.str,
              name: device.platformName,
              connectionType: ConnectionType.BLE,
              isConnected: device.isConnected,
            ),
          )
          .toList();

  Future<List<Printer>> _getBLEBondedDevices() async =>
      (await FlutterBluePlus.bondedDevices)
          .map(
            (device) => Printer(
              address: device.remoteId.str,
              name: device.platformName,
              connectionType: ConnectionType.BLE,
              isConnected: device.isConnected,
            ),
          )
          .toList();

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

  Future<void> turnOnBluetooth() async {
    await FlutterBluePlus.turnOn();
  }

  Stream<bool> get isBleTurnedOnStream => FlutterBluePlus.adapterState.map(
        (event) => event == BluetoothAdapterState.on,
      );
}
