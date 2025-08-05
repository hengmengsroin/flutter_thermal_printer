import 'dart:async';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:win_ble/win_ble.dart';
import 'package:win_ble/win_file.dart';

import '../utils/printer.dart';
import 'print_data.dart';
import 'printers_data.dart';

/// Optimized Windows printer manager with improved resource management
class WindowPrinterManager {
  WindowPrinterManager._privateConstructor();

  static WindowPrinterManager? _instance;

  static WindowPrinterManager get instance {
    _instance ??= WindowPrinterManager._privateConstructor();
    return _instance!;
  }

  static bool _isInitialized = false;

  /// Optimized initialization with better error handling
  static Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    try {
      final serverPath = await WinServer.path();
      await WinBle.initialize(serverPath: serverPath);
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize Windows BLE: $e');
    }
  }

  final StreamController<List<Printer>> _devicesStream =
      StreamController<List<Printer>>.broadcast();

  Stream<List<Printer>> get devicesStream => _devicesStream.stream;

  StreamSubscription? _bleSubscription;
  StreamSubscription? _usbSubscription;

  /// Optimized stop scanning with proper resource cleanup
  Future<void> stopscan() async {
    if (!_isInitialized) {
      throw Exception('WindowBluetoothManager is not initialized');
    }
    WinBle.stopScanning();
    await _bleSubscription?.cancel();
    _bleSubscription = null;
  }

  /// Connect to a BLE device with improved error handling
  Future<bool> connect(Printer device) async {
    if (!_isInitialized) {
      throw Exception('WindowBluetoothManager is not initialized');
    }

    try {
      await WinBle.connect(device.address!);
      await Future.delayed(const Duration(seconds: 5));
      return await WinBle.isPaired(device.address!);
    } catch (e) {
      throw Exception('Failed to connect to device: $e');
    }
  }

  // Print data to a BLE device
  Future<void> printData(
    Printer device,
    List<int> bytes, {
    bool longData = false,
  }) async {
    if (device.connectionType == ConnectionType.USB) {
      using((alloc) {
        RawPrinter(device.name!, alloc).printEscPosWin32(bytes);
      });
      return;
    }
    if (!_isInitialized) {
      throw Exception('WindowBluetoothManager is not initialized');
    }
    final services = await WinBle.discoverServices(device.address);
    final service = services.first;
    final characteristics = await WinBle.discoverCharacteristics(
      address: device.address!,
      serviceId: service,
    );
    final characteristic = characteristics
        .firstWhere((element) => element.properties.write ?? false)
        .uuid;
    final mtusize = await WinBle.getMaxMtuSize(device.address!);
    if (longData) {
      int mtu = mtusize - 50;
      if (mtu.isNegative) {
        mtu = 20;
      }
      final numberOfTimes = bytes.length / mtu;
      final numberOfTimesInt = numberOfTimes.toInt();
      var timestoPrint = 0;
      if (numberOfTimes > numberOfTimesInt) {
        timestoPrint = numberOfTimesInt + 1;
      } else {
        timestoPrint = numberOfTimesInt;
      }
      for (var i = 0; i < timestoPrint; i++) {
        final data = bytes.sublist(
          i * mtu,
          ((i + 1) * mtu) > bytes.length ? bytes.length : ((i + 1) * mtu),
        );
        await WinBle.write(
          address: device.address!,
          service: service,
          characteristic: characteristic,
          data: Uint8List.fromList(data),
          writeWithResponse: false,
        );
      }
    } else {
      await WinBle.write(
        address: device.address!,
        service: service,
        characteristic: characteristic,
        data: Uint8List.fromList(bytes),
        writeWithResponse: false,
      );
    }
  }

  /// Get printers with optimized scanning
  Future<void> getPrinters({
    Duration refreshDuration = const Duration(seconds: 5),
    List<ConnectionType> connectionTypes = const [
      ConnectionType.BLE,
      ConnectionType.USB,
    ],
  }) async {
    final btlist = <Printer>[];
    if (connectionTypes.contains(ConnectionType.BLE)) {
      await init();
      if (!_isInitialized) {
        await init();
      }
      if (!_isInitialized) {
        throw Exception(
          'WindowBluetoothManager is not initialized. Try starting the scan again',
        );
      }
      WinBle.stopScanning();
      WinBle.startScanning();
      await _bleSubscription?.cancel();
      _bleSubscription = WinBle.scanStream.listen((device) async {
        btlist.add(
          Printer(
            address: device.address,
            name: device.name,
            connectionType: ConnectionType.BLE,
            isConnected: await WinBle.isPaired(device.address),
          ),
        );
      });
    }
    var list = <Printer>[];
    if (connectionTypes.contains(ConnectionType.USB)) {
      await _usbSubscription?.cancel();
      _usbSubscription =
          Stream.periodic(refreshDuration, (x) => x).listen((event) async {
        final devices = PrinterNames(PRINTER_ENUM_LOCAL);
        final templist = <Printer>[];
        for (final e in devices.all()) {
          final device = Printer(
            vendorId: e,
            productId: 'N/A',
            name: e,
            connectionType: ConnectionType.USB,
            address: e,
            isConnected: true,
          );
          templist.add(device);
        }
        list = templist;
      });
    }
    Stream.periodic(refreshDuration, (x) => x).listen((event) {
      _devicesStream.add(list + btlist);
    });
  }

  Future<void> turnOnBluetooth() async {
    if (!_isInitialized) {
      throw Exception('WindowBluetoothManager is not initialized');
    }
    await WinBle.updateBluetoothState(true);
  }

  Stream<bool> isBleTurnedOnStream = WinBle.bleState.map(
    (event) => event == BleState.On,
  );

  Future<bool> isBleTurnedOn() async {
    if (!_isInitialized) {
      throw Exception('WindowBluetoothManager is not initialized');
    }
    return (await WinBle.getBluetoothState()) == BleState.On;
  }
}
