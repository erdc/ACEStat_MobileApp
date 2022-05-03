import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock/wakelock.dart';

import 'package:acestat/Resources/PackageInfo.dart';
import 'package:acestat/Fragments/SerialActivitySelection.dart';
import 'package:acestat/Transitions/Slide.dart';
import 'package:acestat/Fragments/StartDrawer.dart';
import 'package:acestat/Resources/Styles.dart';
import 'package:acestat/Comms/USBSerial.dart';

/// Manages the serial device select activity.
class DeviceSelect extends StatefulWidget {
  @override
  _DeviceListState createState() => _DeviceListState();
}

/// Contains the state of DeviceSelect.
class _DeviceListState extends State<DeviceSelect> {
  List<Widget> _ports;
  int _currentBaud;

  /// Called when the user selects a [device] to connect to.
  Future<bool> _connectTo(device) async {
    if (!await USBSerial().connect(device, this._currentBaud)) {
      // Bring up alert
      return false;
    }
    return true;
  }

  /// Loads a list of available serial devices.
  void _getDeviceMenuItems() async {
    this._ports = (await USBSerial().PORTS)
        .map<ListTile>((device) => ListTile(
            leading: Icon(Icons.usb),
            title: Text(device.productName),
            subtitle: Text(device.manufacturerName),
            trailing: ElevatedButton(
              child: Text("Connect"),
              onPressed: () {
                _connectTo(device);
              },
            )))
        .toList();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    this._currentBaud = USBSerial.defaultBaud;
    this._ports = [];

    USBSerial().onUsbEvent((var event) {
      _getDeviceMenuItems();
    });

    USBSerial().onConnectChange(() {
      if (USBSerial().isConnected()) {
        Wakelock.enable();
        // Transition to test fragment
        Navigator.push(
                context, SlideLeftRoute(page: new SerialActivitySelect()))
            .then((context) => USBSerial().disconnect());
      } else {
        // Return to home fragment
        Navigator.popUntil(context, ModalRoute.withName('/'));
        Wakelock.disable();
      }
    });

    _getDeviceMenuItems();
  }

  /// Ensures an established serial connection is closed on disposal.
  @override
  void dispose() {
    super.dispose();
    USBSerial().disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(PackageInfo.appName),
          actions: <Widget>[
            Row(
              children: [
                Text("Baud: "),
                DropdownButton(
                  value: this._currentBaud,
                  onChanged: (int selectedBaud) {
                    setState(() {
                      this._currentBaud = selectedBaud;
                    });
                  },
                  // style: TextStyle(color: Colors.black),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: usaceText,
                  ),
                  selectedItemBuilder: (BuildContext context) {
                    return USBSerial().BAUD.map((int value) {
                      return Align(
                          alignment: Alignment.center,
                          child: Text(
                            this._currentBaud.toString(),
                            style: TextStyle(color: usaceText, fontSize: 18),
                          ));
                    }).toList();
                  },
                  items:
                      USBSerial().BAUD.map<DropdownMenuItem<int>>((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text(value.toString(),
                          style: TextStyle(fontSize: 18)),
                    );
                  }).toList(),
                ),
              ],
            )
          ],
        ),
        drawer: StartDrawer(),
        body: Center(
          child: Column(children: <Widget>[
            Text(
                this._ports.length > 0
                    ? "Available Serial Ports"
                    : "No serial devices available",
                style: Theme.of(context).textTheme.headline6),
            ...this._ports,
          ]),
        ));
  }
}
