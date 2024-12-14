import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'flutter_thermal_printer_platform_interface.dart';

class FlutterThermalPrinterPlugin extends FlutterThermalPrinterPlatform {
  static const String platformChannel = "flutter_thermal_printer";
  static late MethodChannel channel;
  bool supported = false;
  static void registerWith(Registrar registrar) {
    // Register the plugin
    channel =
        MethodChannel(platformChannel, const StandardMethodCodec(), registrar);
    final instance = FlutterThermalPrinterPlugin();
    channel.setMethodCallHandler(instance.handleMethodCall);
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    if (!supported) return;
    switch (call.method) {
      default:
        throw PlatformException(
            code: 'Unimplemented',
            details: "The flutter_tts plugin for web doesn't implement "
                "the method '${call.method}'");
    }
  }

  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_thermal_printer');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<dynamic> startUsbScan() async {
    return await methodChannel.invokeMethod('getUsbDevicesList');
  }

  @override
  Future<bool> connect(Printer device) async {
    return await methodChannel.invokeMethod('connect', {
      "vendorId": device.vendorId.toString(),
      "productId": device.productId.toString(),
    });
  }

  @override
  Future<bool> printText(Printer device, Uint8List data, {String? path}) async {
    return await methodChannel.invokeMethod('printText', {
      "vendorId": device.vendorId.toString(),
      "productId": device.productId.toString(),
      "data": List<int>.from(data),
      "path": path ?? "",
    });
  }

  @override
  Future<bool> isConnected(Printer device) async {
    return await methodChannel.invokeMethod('isConnected', {
      "vendorId": device.vendorId.toString(),
      "productId": device.productId.toString(),
    });
  }

  @override
  Future<dynamic> convertImageToGrayscale(Uint8List? value) async {
    return await methodChannel.invokeMethod('convertimage', {
      "path": List<int>.from(value!),
    });
  }

  @override
  Future<bool> disconnect(Printer device) async {
    return await methodChannel.invokeMethod('disconnect', {
      "vendorId": device.vendorId.toString(),
      "productId": device.productId.toString(),
    });
  }
}
