import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:usb_serial/usb_serial.dart';

/// A singleton class used to communicate with the ACEStat.
class USBSerial {
  static const int defaultBaud = 9600;
  static const List<int> _supportedBaudRates = [
    300,
    600,
    1200,
    2400,
    4800,
    9600,
    19200,
    38400,
    57600,
    115200,
    230400,
    460800,
    921600
  ];
  UsbPort _port;
  int _deviceId;
  StreamController<String> _messageStream;

  final ValueNotifier<bool> _isConnected = ValueNotifier(false);

  static USBSerial _singleton;

  USBSerial._internal();

  factory USBSerial() {
    if (_singleton == null) {
      _singleton = USBSerial._internal();

      _singleton._messageStream = StreamController<String>.broadcast();

      _singleton.onUsbEvent((var event) async {
        // print(event);
        List ports = await _singleton.PORTS;
        ports = ports.map((port) {
          return port.deviceId;
        }).toList();
        if (!ports.contains(_singleton._deviceId)) {
          await _singleton.disconnect();
        }
      });
    }

    return _singleton;
  }

  /// Connect to a [device] using a specified [baud] rate.
  Future<bool> connect(UsbDevice device, int baud) async {
    if (device != null && _isConnected.value && _deviceId == device.deviceId) {
      return true;
    }

    // Ensure blank slate
    await disconnect();

    if (device == null) {
      return true;
    }

    // print(device.deviceId);

    _port = await device.create();
    if (!await _port.open()) {
      _isConnected.value = false;
      return false;
    }

    _deviceId = device.deviceId;
    await _port.setDTR(true);
    await _port.setRTS(true);
    await _port.setPortParameters(
        baud, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    _port.inputStream.listen((msg) {
      _messageStream.add(String.fromCharCodes(msg));
    });
    _isConnected.value = true;
    return true;
  }

  /// Disconnect from the connected device.
  Future<bool> disconnect() async {
    if (_port != null) {
      try {
        await _port.close();
      } catch (err) {
        print("ERROR $err");
      }
    }

    _port = null;
    _deviceId = null;
    _isConnected.value = false;
    return true;
  }

  /// Send a message [msg] to the connected device.
  Future send(String msg) async {
    if (_port == null || !_isConnected.value) {
      return;
    }
    return await _port.write(Uint8List.fromList(msg.codeUnits));
  }

  /// Return whether a serial connection is established.
  bool isConnected() {
    return _isConnected.value;
  }

  /// Subscribe to message event stream.
  StreamSubscription onMessage(Function func) {
    return _messageStream.stream.listen(func);
  }

  /// Subscribe to USB event stream.
  StreamSubscription<UsbEvent> onUsbEvent(Function func) {
    return UsbSerial.usbEventStream.listen(func);
  }

  /// Called when the connection status changes.
  void onConnectChange(Function func) {
    _isConnected.addListener(func);
  }

  /// Returns the device ID of the connected device.
  int getConnectedDeviceId() {
    return _deviceId;
  }

  /// Returns a list of available devices to connect to.
  Future get PORTS async {
    return await UsbSerial.listDevices();
  }

  /// Returns a list of supported baud rates.
  List<int> get BAUD {
    return _supportedBaudRates;
  }
}
