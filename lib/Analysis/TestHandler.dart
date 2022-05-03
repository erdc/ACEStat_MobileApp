import 'dart:async';
import 'dart:core';

import 'package:flutter/widgets.dart';

import 'package:acestat/Analysis/CrabTest.dart';
import 'package:acestat/DBManager.dart';
import 'package:acestat/Analysis/TestDefinitions.dart';
import 'package:acestat/Comms/USBSerial.dart';

/// A constant timeout duration when expecting a response from the ACEStat.
const ERROR_TIMEOUT = const Duration(seconds: 5);

/// A singleton class to handle all logic when running a test on the ACEStat.
class TestHandler {
  static TestHandler _singleton;
  RegExp _messageRE = new RegExp(r"([^\[\]]+|\]|\[)");

  List<StringBuffer> _msgBuffer = [];
  CrabTest _currentTest;

  ValueNotifier<bool> _ready = ValueNotifier(false);
  bool _testInProgress = false;
  StreamController<String> _resultStream, _errorStream;
  StreamController<CrabTest> _testStartStream, _testEndStream;
  StreamController<bool> _readyStream; // Use StreamController for consistency
  Timer _eTimer; // Used to trigger a timeout error

  TestHandler._internal();

  factory TestHandler() {
    if (_singleton == null) {
      _singleton = TestHandler._internal();
      _singleton._resultStream = StreamController<String>.broadcast();
      _singleton._errorStream = StreamController<String>.broadcast();
      _singleton._readyStream = StreamController<bool>.broadcast();
      _singleton._testStartStream = StreamController<CrabTest>.broadcast();
      _singleton._testEndStream = StreamController<CrabTest>.broadcast();
      _singleton._ready.addListener(
          () => _singleton._readyStream.add(_singleton._ready.value));
      USBSerial().onMessage(_singleton._routeMessage);
    }
    return _singleton;
  }

  /// Ensure streams are closed on disposal.
  @protected
  @mustCallSuper
  void dispose() {
    _errorStream.close();
    _readyStream.close();
    _resultStream.close();
    _testStartStream.close();
    _testEndStream.close();
  }

  /// Run a CrabTest [test] instance.
  bool runTest(CrabTest test) {
    if (_ready.value) {
      this._currentTest = test;
      _ready.value = false;
      USBSerial().send(test.info["value"]);
      return true;
    }
    return false;
  }

  /// Return the current CrabTest instance.
  CrabTest get currentTest {
    return this._currentTest;
  }

  /// Return whether the ACEStat is ready to run a new test or not.
  bool get ready {
    return _ready.value;
  }

  /// Return whether the ACEStat is currently running a test.
  bool get running {
    return this._testInProgress;
  }

  /// Subscribe to ready stream.
  StreamSubscription onReady(Function func) {
    return _readyStream.stream.listen(func);
  }

  /// Subscribe to result stream.
  StreamSubscription onResult(Function func) {
    return _resultStream.stream.listen(func);
  }

  /// Subscribe to error stream.
  StreamSubscription onError(Function func) {
    return _errorStream.stream.listen(func);
  }

  /// Subscribe to test start stream.
  StreamSubscription onTestStart(Function func) {
    return _testStartStream.stream.listen(func);
  }

  /// Subscribe to test end stream.
  StreamSubscription onTestEnd(Function func) {
    return _testEndStream.stream.listen(func);
  }

  /// Called when the ACEStat does not respond within the expected timeframe.
  void _inputTimeout() {
    if (this._eTimer != null) {
      this._eTimer.cancel();
      // this._eTimer = null;
      this._errorStream.add("Input timeout, please restart test.");
      // CrabTest tmp = this._currentTest;
      this.reset();
    }
  }

  /// Receive, organize, and direct data received from the ACEStat.
  void _routeMessage(String msg) {
    // print("RECEIVED: $msg");
    _messageRE.allMatches(msg).forEach((m) async {
      String match = m.group(0).toString();
      if (match == "[") {
        _msgBuffer.add(StringBuffer());
      } else if (_msgBuffer.isNotEmpty) {
        if (match == "]") {
          try {
            await _parseData(_msgBuffer.removeLast().toString());
          } catch (e) {
            // throw e;
            _errorStream.add(e.toString());
          }
        } else {
          _msgBuffer.last.write(match);
        }
      }
    });
  }

  /// Called when an input tag (starts with ":") is received from the ACEStat.
  /// Tag id is passed in as [id].
  Future _handleInput(String id) {
    if (this._eTimer != null) {
      this._eTimer.cancel();
    }
    id = id.substring(1);
    if (id.startsWith("MAIN")) {
      _testInProgress = false;
      _msgBuffer.clear();
      this._currentTest = null;
      List<String> parts = id.split(":");
      // print("FIRMWARE VERSION: ${parts.last}");
      if (parts.length < 2 || parts[1] != TestDefinitions().version) {
        _errorStream.add("Firmware version does not match definitions.");
        return null;
      }
      this._ready.value = true;
    } else if (_currentTest == null ||
        !_currentTest.parameters.info.containsKey(id)) {
      reset(); // Since we don't have the parameter, cancel the test
      _errorStream.add("Unrecognized parameter: $id.");
    } else {
      // print("$id: ${_currentTest.parameters[id].format()}");
      this._eTimer = Timer(ERROR_TIMEOUT, this._inputTimeout);
      return USBSerial().send(_currentTest.parameters[id].format());
    }
    return null;
  }

  /// Parses a data section [data] sent from _routeMessage.
  Future _parseData(String data) async {
    // print(data);
    CrabTest test = this._currentTest;
    if (data.startsWith(":")) {
      return _handleInput(data);
    } else if (data.startsWith("START")) {
      if (this._eTimer != null) {
        this._eTimer.cancel();
        // this._eTimer = null;
      }
      // Confirm this is the correct test
      if (data.substring(6) == test.id) {
        test.setStart();
        this._testInProgress = true;
        this._testStartStream.add(test);
      } else {
        _errorStream.add("Incorrect test started: ${data.substring(6)}");
        reset();
        return;
      }
    } else if (data.startsWith("ERR")) {
      _errorStream.add(data.substring(4));
    } else if (data.startsWith("END")) {
      await DB.insertCrabTest(test);
      this._testEndStream.add(test);
    } else {
      int idx = data.indexOf(":");
      List<String> parts = [
        data.substring(0, idx).trim(),
        data.substring(idx + 1).trim()
      ];
      if (test.info["outputs"].containsKey(parts.first)) {
        Map output = test.info["outputs"][parts.first];
        if (output["type"] == "field") {
          // print("${parts.first}: ${parts.last}");
          Map field = output["fields"].values.first;
          try {
            test.results.set(parts.first, {field["label"]: parts.last});
            _resultStream.add(parts.first);
          } catch (e) {
            _errorStream.add(e.toString());
          }
        } else if (output["type"] == "list") {
          // print("${parts.first}: ${parts.last}");
          List<String> fields =
              parts.last.split(RegExp(RegExp.escape(output["separator"])));
          test.results.set(
              parts.first,
              fields.asMap().map((i, value) {
                return MapEntry(
                    output["fields"].values.elementAt(i)["label"], value);
              }));
          _resultStream.add(parts.first);
        } else if (output["type"] == "matrix") {
          String rowSep = RegExp.escape(output["row-separator"]);
          String colSep = RegExp.escape(output["col-separator"]);
          parts.last = parts.last.replaceAll(RegExp(rowSep + "\$"), '');

          var rows;
          if (rowSep.length > 0) {
            rows = parts.last.split(RegExp(rowSep));
          } else {
            rows = [parts.last];
          }
          if (colSep.length > 0) {
            rows = rows.map((row) => row.split(RegExp(colSep)));
          } else {
            rows = [rows];
          }
          test.results.set(
              parts.first,
              Map.fromEntries(output["fields"]
                  .values
                  .toList()
                  .asMap()
                  .map((key, value) =>
                      MapEntry(value["label"], rows.map((row) => row[key])))
                  .entries));

          _resultStream.add(parts.first);
        } else {
          _errorStream.add("Unknown output type: ${output['type']}.");
        }
        return;
      }
    }
  }

  /// Sends a reset code to the ACEStat.
  void reset() {
    USBSerial().send(String.fromCharCodes([27]));
  }
}
