import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:image/image.dart' as img;
import 'package:screenshot/screenshot.dart';

import 'Others/other_printers_manager.dart';
import 'Windows/window_printer_manager.dart';
import 'utils/printer.dart';

export 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
export 'package:flutter_blue_plus/flutter_blue_plus.dart'
    show BluetoothDevice, BluetoothConnectionState;
export 'package:flutter_thermal_printer/network/network_printer.dart';

/// Main class for thermal printer operations across all platforms
///
/// This class provides a unified interface for printing operations
/// on Windows (USB/BLE) and other platforms (Android/iOS/macOS).
class FlutterThermalPrinter {
  FlutterThermalPrinter._();

  static FlutterThermalPrinter? _instance;

  /// Singleton instance with improved initialization
  static FlutterThermalPrinter get instance {
    if (_instance == null) {
      _instance = FlutterThermalPrinter._();
      _initializeLogLevel();
    }
    return _instance!;
  }

  /// Initialize log level for non-Windows platforms
  static void _initializeLogLevel() {
    if (!Platform.isWindows) {
      try {
        FlutterBluePlus.setLogLevel(LogLevel.debug);
      } catch (e) {
        // Silently handle log level initialization errors
      }
    }
  }

  Stream<List<Printer>> get devicesStream {
    if (Platform.isWindows) {
      return WindowPrinterManager.instance.devicesStream;
    } else {
      return OtherPrinterManager.instance.devicesStream;
    }
  }

  Future<bool> connect(Printer device) async {
    if (Platform.isWindows) {
      return WindowPrinterManager.instance.connect(device);
    } else {
      return OtherPrinterManager.instance.connect(device);
    }
  }

  Future<void> disconnect(Printer device) async {
    if (Platform.isWindows) {
      // await WindowBleManager.instance.disc(device);
    } else {
      await OtherPrinterManager.instance.disconnect(device);
    }
  }

  Future<void> printData(
    Printer device,
    List<int> bytes, {
    bool longData = false,
  }) async {
    if (Platform.isWindows) {
      return WindowPrinterManager.instance.printData(
        device,
        bytes,
        longData: longData,
      );
    } else {
      return OtherPrinterManager.instance.printData(
        device,
        bytes,
        longData: longData,
      );
    }
  }

  Future<void> getPrinters({
    Duration refreshDuration = const Duration(seconds: 2),
    List<ConnectionType> connectionTypes = const [
      ConnectionType.USB,
      ConnectionType.BLE,
    ],
    bool androidUsesFineLocation = false,
  }) async {
    if (Platform.isWindows) {
      await WindowPrinterManager.instance.getPrinters(
        refreshDuration: refreshDuration,
        connectionTypes: connectionTypes,
      );
    } else {
      await OtherPrinterManager.instance.getPrinters(
        connectionTypes: connectionTypes,
        androidUsesFineLocation: androidUsesFineLocation,
      );
    }
  }

  Future<void> stopScan() async {
    if (Platform.isWindows) {
      await WindowPrinterManager.instance.stopscan();
    } else {
      await OtherPrinterManager.instance.stopScan();
    }
  }

  // Turn On Bluetooth
  Future<void> turnOnBluetooth() async {
    if (Platform.isWindows) {
      await WindowPrinterManager.instance.turnOnBluetooth();
    } else {
      await OtherPrinterManager.instance.turnOnBluetooth();
    }
  }

  Stream<bool> get isBleTurnedOnStream {
    if (Platform.isWindows) {
      return WindowPrinterManager.instance.isBleTurnedOnStream;
    } else {
      return OtherPrinterManager.instance.isBleTurnedOnStream;
    }
  }

  // Get BleState
  Future<bool> isBleTurnedOn() async {
    if (Platform.isWindows) {
      return WindowPrinterManager.instance.isBleTurnedOn();
    } else {
      return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
    }
  }

  /// Optimized screen capture and conversion to printer-ready bytes
  Future<Uint8List> screenShotWidget(
    BuildContext context, {
    required Widget widget,
    Duration delay = const Duration(milliseconds: 100),
    int? customWidth,
    PaperSize paperSize = PaperSize.mm80,
    Generator? generator,
  }) async {
    final controller = ScreenshotController();

    try {
      final image = await controller.captureFromLongWidget(
        widget,
        pixelRatio: View.of(context).devicePixelRatio,
        delay: delay,
      );

      final profile = await CapabilityProfile.load();
      final generator0 = generator ?? Generator(paperSize, profile);

      var imagebytes = img.decodeImage(image);
      if (imagebytes == null) {
        throw Exception('Failed to decode captured image');
      }

      // Apply custom width if specified
      if (customWidth != null) {
        final width = _makeDivisibleBy8(customWidth);
        imagebytes = img.copyResize(imagebytes, width: width);
      }

      // Ensure image width is compatible with thermal printers
      imagebytes = _buildImageRasterAvailable(imagebytes);
      imagebytes = img.grayscale(imagebytes);

      // Process image in optimized chunks
      return _processImageInChunks(imagebytes, generator0);
    } catch (e) {
      throw Exception('Failed to capture widget screenshot: $e');
    }
  }

  /// Process image in optimized chunks for better memory management
  Uint8List _processImageInChunks(img.Image image, Generator generator) {
    const chunkHeight = 30;
    final totalHeight = image.height;
    final totalWidth = image.width;
    final chunksCount = (totalHeight / chunkHeight).ceil();

    final bytes = <int>[];

    for (var i = 0; i < chunksCount; i++) {
      final startY = i * chunkHeight;
      final endY = (startY + chunkHeight > totalHeight)
          ? totalHeight
          : startY + chunkHeight;
      final actualHeight = endY - startY;

      final croppedImage = img.copyCrop(
        image,
        x: 0,
        y: startY,
        width: totalWidth,
        height: actualHeight,
      );

      final raster = generator.imageRaster(
        croppedImage,
      );
      bytes.addAll(raster);
    }

    return Uint8List.fromList(bytes);
  }

  /// Ensure image width is compatible with thermal printers (divisible by 8)
  img.Image _buildImageRasterAvailable(img.Image image) {
    if (image.width % 8 == 0) {
      return image;
    }
    final newWidth = _makeDivisibleBy8(image.width);
    return img.copyResize(image, width: newWidth);
  }

  /// Make number divisible by 8 for printer compatibility
  int _makeDivisibleBy8(int number) {
    if (number % 8 == 0) {
      return number;
    }
    return number + (8 - (number % 8));
  }

  /// Optimized widget printing with better resource management
  Future<void> printWidget(
    BuildContext context, {
    required Printer printer,
    required Widget widget,
    Duration delay = const Duration(milliseconds: 100),
    PaperSize paperSize = PaperSize.mm80,
    CapabilityProfile? profile,
    bool printOnBle = false,
    bool cutAfterPrinted = true,
  }) async {
    final controller = ScreenshotController();

    try {
      final image = await controller.captureFromLongWidget(
        widget,
        pixelRatio: View.of(context).devicePixelRatio,
        delay: delay,
      );

      // Handle BLE printing with single raster approach
      if (printer.connectionType == ConnectionType.BLE) {
        await _printBLEWidget(image, printer, paperSize, profile);
        return;
      }

      // Handle Windows printing
      if (Platform.isWindows) {
        await printData(
          printer,
          image.toList(),
          longData: true,
        );
        return;
      }

      // Handle other platforms with chunked approach
      await _printChunkedWidget(
        image,
        printer,
        paperSize,
        profile,
        cutAfterPrinted,
      );
    } catch (e) {
      throw Exception('Failed to print widget: $e');
    }
  }

  /// Print widget on BLE devices using single raster approach
  Future<void> _printBLEWidget(
    Uint8List image,
    Printer printer,
    PaperSize paperSize,
    CapabilityProfile? profile,
  ) async {
    final profile0 = profile ?? await CapabilityProfile.load();
    final ticket = Generator(paperSize, profile0);

    var imagebytes = img.decodeImage(image);
    if (imagebytes == null) {
      throw Exception('Failed to decode image for BLE printing');
    }

    imagebytes = _buildImageRasterAvailable(imagebytes);
    final raster = ticket.imageRaster(
      imagebytes,
    );

    await printData(printer, raster, longData: true);
  }

  /// Print widget using chunked approach for better memory management
  Future<void> _printChunkedWidget(
    Uint8List image,
    Printer printer,
    PaperSize paperSize,
    CapabilityProfile? profile,
    bool cutAfterPrinted,
  ) async {
    final profile0 = profile ?? await CapabilityProfile.load();
    final ticket = Generator(paperSize, profile0);

    var imagebytes = img.decodeImage(image);
    if (imagebytes == null) {
      throw Exception('Failed to decode image for chunked printing');
    }

    imagebytes = _buildImageRasterAvailable(imagebytes);

    const chunkHeight = 30;
    final totalHeight = imagebytes.height;
    final totalWidth = imagebytes.width;
    final chunksCount = (totalHeight / chunkHeight).ceil();

    // Print image in chunks
    for (var i = 0; i < chunksCount; i++) {
      final startY = i * chunkHeight;
      final endY = (startY + chunkHeight > totalHeight)
          ? totalHeight
          : startY + chunkHeight;
      final actualHeight = endY - startY;

      final croppedImage = img.copyCrop(
        imagebytes,
        x: 0,
        y: startY,
        width: totalWidth,
        height: actualHeight,
      );

      final raster = ticket.imageRaster(
        croppedImage,
      );

      await printData(printer, raster, longData: true);
    }

    // Add cut command if requested
    if (cutAfterPrinted) {
      await printData(printer, ticket.cut(), longData: true);
    }
  }

  /// Optimized image bytes printing with validation and error handling
  Future<void> printImageBytes({
    required Uint8List imageBytes,
    required Printer printer,
    Duration delay = const Duration(milliseconds: 100),
    PaperSize paperSize = PaperSize.mm80,
    CapabilityProfile? profile,
    Generator? generator,
    bool printOnBle = false,
    int? customWidth,
  }) async {
    // Validate BLE printing settings
    if (!printOnBle && printer.connectionType == ConnectionType.BLE) {
      throw Exception(
        'Image printing on BLE Printer may be slow or fail. Still Need try? set printOnBle to true',
      );
    }

    try {
      // Handle Windows printing
      if (Platform.isWindows) {
        await printData(printer, imageBytes.toList(), longData: true);
        return;
      }

      // Handle other platforms
      await _printImageBytesOtherPlatforms(
        imageBytes,
        printer,
        paperSize,
        profile,
        generator,
        customWidth,
      );
    } catch (e) {
      throw Exception('Failed to print image bytes: $e');
    }
  }

  /// Print image bytes on non-Windows platforms
  Future<void> _printImageBytesOtherPlatforms(
    Uint8List imageBytes,
    Printer printer,
    PaperSize paperSize,
    CapabilityProfile? profile,
    Generator? generator,
    int? customWidth,
  ) async {
    final profile0 = profile ?? await CapabilityProfile.load();
    final ticket = generator ?? Generator(paperSize, profile0);

    var imagebytes = img.decodeImage(imageBytes);
    if (imagebytes == null) {
      throw Exception('Failed to decode image bytes');
    }

    // Apply custom width if specified
    if (customWidth != null) {
      final width = _makeDivisibleBy8(customWidth);
      imagebytes = img.copyResize(imagebytes, width: width);
    }

    imagebytes = _buildImageRasterAvailable(imagebytes);

    const chunkHeight = 30;
    final totalHeight = imagebytes.height;
    final totalWidth = imagebytes.width;
    final chunksCount = (totalHeight / chunkHeight).ceil();

    // Print in optimized chunks
    for (var i = 0; i < chunksCount; i++) {
      final startY = i * chunkHeight;
      final endY = (startY + chunkHeight > totalHeight)
          ? totalHeight
          : startY + chunkHeight;
      final actualHeight = endY - startY;

      final croppedImage = img.copyCrop(
        imagebytes,
        x: 0,
        y: startY,
        width: totalWidth,
        height: actualHeight,
      );

      final raster = ticket.imageRaster(
        croppedImage,
      );

      await printData(printer, raster, longData: true);
    }
  }
}
