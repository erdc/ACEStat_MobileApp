import 'package:flutter/cupertino.dart';

import 'CrabTest.dart';
import 'TestDefinitions.dart';

/// Holds the state of the TestForm when the current activity changes.
class TestFormState with ChangeNotifier {
  bool _enabled;
  Map<String, dynamic> _formData;
  ParameterException _inputError;
  String _selectedTest;
  Map<String, String> _presets = {};

  TestFormState() {
    this._enabled = false;
    this._formData = {};
    this._presets = Map<String, String>();
    this.selectedTest = TestDefinitions().tests.keys.first;
  }

  /// Return whether the form should be enabled or not.
  bool get enabled => this._enabled;

  /// Get available presets for the selected test.
  String get preset => this._presets[this._selectedTest];

  /// Return selected test ID.
  String get selectedTest => this._selectedTest;

  /// Validate parameter [key].
  String validate(String key) =>
      validateParameter(this._selectedTest, key, this._formData[key]);

  /// Return the available test definitions.
  Map get tests => TestDefinitions().tests;

  /// Return the definition for the selected test.
  Map get info => this.tests[this._selectedTest];

  /// Return the presets for selected test from test definitions.
  Map get presets => TestDefinitions().tests[this._selectedTest]["presets"];

  /// Return the most recent input error.
  ParameterException get inputError => this._inputError;

  /// Generate and return a CrabTest instance using the current parameters
  /// entered in the form.
  CrabTest get test {
    try {
      return CrabTest(
          this.selectedTest,
          Map.fromIterable(this._formData[this._selectedTest].entries,
              key: (e) => e.key, value: (e) => e.value));
    } on ParameterException catch (e) {
      this._inputError = e;
      notifyListeners();
      throw e;
    }
  }

  /// Return the current parameters entered in the form.
  Iterable<MapEntry<String, String>> get parameters {
    return this._formData[this._selectedTest].entries;
  }

  /// Enable or disable the form based on boolean [enable].
  set enabled(bool enable) => this._enabled = enable;

  /// Set which test type is selected using test ID [test].
  set selectedTest(String test) {
    if (!TestDefinitions().tests.containsKey(test)) {
      throw Exception("$test does not exist");
    }
    if (test != this._selectedTest) {
      _inputError = null;
    }
    this._selectedTest = test;
    this._formData.putIfAbsent(_selectedTest, () => Map());
    notifyListeners();
  }

  /// Load the preset parameters with name [preset] into the current form.
  set preset(String preset) {
    if (!this.presets.containsKey(preset)) {
      throw Exception("$preset does not exist");
    }
    this._presets[this._selectedTest] = preset;
    this.presets[preset]["parameters"].entries.forEach((entry) {
      // print("${entry.key}: ${entry.value}");
      this._formData[this._selectedTest][entry.key] = entry.value;
    });
    notifyListeners();
  }

  /// Return parameter with ID [key] from the current form.
  operator [](String key) {
    if (this._formData.containsKey(this._selectedTest) &&
        this._formData[this._selectedTest].containsKey(key)) {
      return this._formData[this._selectedTest][key];
    }
    Map param = TestDefinitions().tests[this._selectedTest]["parameters"][key];
    if (param["type"] == "select") {
      return param["options"].keys.first;
    }
  }

  /// Set parameter with ID [key] to value [value] in the current form.
  operator []=(String key, value) {
    if (_inputError != null && key == _inputError.id) _inputError = null;
    if (this.preset != null &&
        value != this.presets[this.preset]["parameters"][key])
      this._presets[this._selectedTest] = null;
    this._formData[this._selectedTest][key] = value;
    notifyListeners();
  }
}
