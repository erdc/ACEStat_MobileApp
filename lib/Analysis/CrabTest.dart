import 'dart:io';
import 'dart:async';

import 'package:csv/csv.dart';
import 'package:function_tree/function_tree.dart';
import 'package:quiver/iterables.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share/share.dart';

import 'package:acestat/Analysis/TestDefinitions.dart';
import 'package:acestat/Analysis/TestHandler.dart';

/// Set a field to it's proper type as defined in the definitions.
///
/// Throws a [FormatException] if the field [data] does not match the expected
/// format [_type]. Throws an [Exception] if the expected type [_type] is
/// unknown. Returns typed field.
dynamic _setType(String _type, dynamic data) {
  if (data == null) {
    return null;
  } else if (data is Iterable) {
    return data.map((v) {
      return _setType(_type, v);
    }).toList(growable: false);
  } else if (_type == "float") {
    try {
      return double.parse(data);
    } catch (e) {
      if (data == "inf") {
        return double.infinity;
      } else if (data == "-inf") {
        return double.negativeInfinity;
      }
      throw FormatException("Invalid float $data");
    }
  } else if (_type == "int") {
    try {
      return int.parse(data);
    } catch (e) {
      throw FormatException("Invalid integer $data");
    }
  } else if (_type == "string") {
    try {
      return data.toString();
    } catch (e) {
      throw FormatException("Invalid String $data");
    }
  } else {
    throw new Exception("Unknown field type: $_type.");
  }
}

/// A special exception used to define input parameter issues.
class ParameterException implements Exception {
  /// The name of the parameter.
  final String id;

  /// The reason why the parameter is invalid.
  final String cause;

  ParameterException(this.id, this.cause);
}

/// Checks whether the parameter input is valid.
///
/// Returns text indicating any issues with parameter [key] value [value] for
/// test method [id]. Returns null if the parameter [value] is empty or valid.
String validateParameter(String id, String key, String value) {
  if (value == null || value.isEmpty) {
    return null;
  } else if (!TestDefinitions().tests.containsKey(id)) {
    return "Unrecognized test: $id";
  } else if (!TestDefinitions().tests[id]["parameters"].containsKey(key)) {
    return "Invalid parameter: $key";
  } else {
    Map info = TestDefinitions().tests[id]["parameters"][key];
    if (info["type"] == "select") {
      if (!info["options"].containsKey(value)) return "Invalid option: $value";
    } else if (info["type"] == "int") {
      var val = int.tryParse(value);
      if (val == null) {
        return "Not a valid integer";
      } else if (val < info["min"]) {
        return "Minimum: ${info['min']}";
      } else if (val > info["max"]) return "Maximum: ${info['max']}";
    }
  }
  return null;
}

/// A container to hold all inputs and outputs for a single run of a test on the
/// ACESTat.
class CrabTest {
  final String id;
  _Parameters parameters;
  _Results results;
  DateTime _startTime;
  double _duration;
  String _version;

  /// Initialize the CrabTest instance.
  ///
  /// Throws an [Exception] if test method [id] does not exist.
  CrabTest(this.id, Map parameters, {String version}) {
    if (!TestDefinitions().tests.containsKey(id)) {
      throw new Exception("Invalid test ID: $id");
    }
    if (version == null) {
      this._version = TestDefinitions().version;
    } else {
      this._version = version;
    }

    // Get definitions for a particular version?

    this.parameters = _Parameters(this, parameters);
    this.results = _Results(this);
  }

  /// Loads a previously completed CrabTest.
  ///
  /// Returns a CrabTest instance built from a test method [id], version
  /// [version], start time [startTime], input parameters [parameters], and test
  /// results [results].
  static CrabTest loadTest(String id, String version, DateTime startTime,
      Map parameters, Map results) {
    CrabTest test = CrabTest(id, parameters, version: version);
    test._startTime = startTime;
    results.entries.forEach((r) => test.results.set(r.key, r.value));
    return test;
  }

  /// Return the definition information for a CrabTest instance.
  Map get info {
    return TestDefinitions().tests[id];
  }

  /// Provides a method to run the test for a CrabTest instance.
  bool run() {
    return TestHandler().runTest(this);
  }

  /// Returns the definition version for a CrabTest instance.
  String get version {
    return this._version;
  }

  /// Returns the start time for a CrabTest instance.
  DateTime get startTime {
    return this._startTime;
  }

  /// Set the start time for a CrabTest instance.
  void setStart() {
    this._startTime = DateTime.now().toUtc();
  }

  /// Calculate and return the estimated test duration for a CrabTest instance.
  num get duration {
    if (this._duration == null) {
      String eq = this.info["timing"];
      if (eq == null) {
        return null;
      }
      RegExp(r"\[(\w+)\]").allMatches(eq).forEach((m) {
        String match = m.group(1).toString();
        eq =
            eq.replaceAll("[$match]", "(${this.parameters[match].toString()})");
      });
      try {
        this._duration = eq.interpret();
      } catch (e) {
        return null;
      }
    }
    return this._duration;
  }

  /// Calculates and returns the estimated remaining time for a CrabTest
  /// instance.
  num get estimateRemaining {
    if (this.duration == null) return null;
    num rem = this.duration -
        (DateTime.now().toUtc().millisecondsSinceEpoch -
                this._startTime.millisecondsSinceEpoch) /
            1000.0;
    return rem > 0 ? rem : 0;
  }

  /// Writes this CrabTest instance data to a file [filename].
  Future<String> writeToFile({String filename}) async {
    if (filename == null) {
      filename = this.defaultFilename;
    }
    return Exporter.writeToFile(filename, test: this);
  }

  /// Exports this CrabTest instance data to another application, through file
  /// [filename].
  Future openWith({String filename}) async {
    if (filename == null) {
      filename = this.defaultFilename;
    }
    return Exporter.openWith(filename, test: this);
  }

  /// Shares this CrabTest instance data through another application, through
  /// file [filename].
  Future share({String filename}) async {
    if (filename == null) {
      filename = this.defaultFilename;
    }
    return Exporter.share(filename, test: this);
  }

  /// Converts this CrabTest instance data to a row/column format.
  Future<List<List<dynamic>>> toList() async {
    return await Exporter.convertToList(this);
  }

  /// Generates a filename using the start time of this CrabTest instance and
  /// name of the test method used.
  String get defaultFilename {
    // this._startTime.toIso8601String().replaceAll(":", "").replaceAll("-", "")
    return [
      this._startTime.year.toString().padLeft(4, '0'),
      this._startTime.month.toString().padLeft(2, '0'),
      this._startTime.day.toString().padLeft(2, '0'),
      "-",
      this._startTime.hour.toString().padLeft(2, '0'),
      this._startTime.minute.toString().padLeft(2, '0'),
      this._startTime.second.toString().padLeft(2, '0'),
      "_",
      this.info["name"].replaceAll(" ", "-"),
      ".csv"
    ].join();
  }
}

/// A container to manage the input parameters for a CrabTest instance.
class _Parameters {
  final CrabTest test;
  Map<String, Parameter> _parameters;

  /// Initializes the _Parameters instance.
  ///
  /// Throws [ParameterException] if a parameter is missing from [parameters]
  /// for CrabTest [test].
  _Parameters(this.test, Map parameters) {
    this._parameters = Map.fromIterable(
        this.info.keys.map<List>((key) {
          if (!parameters.containsKey(key)) {
            throw new ParameterException(key, "Missing parameter");
          }
          return [key, new Parameter(this.test, key, parameters[key])];
        }),
        key: (v) => v[0],
        value: (v) => v[1]);
  }

  /// Access _Parameters instance like a map.
  Parameter operator [](String key) => this._parameters[key];

  /// Returns a list of parameter ids for this _Parameters instance.
  Iterable<String> get keys {
    return this._parameters.keys;
  }

  /// Returns a list of parameter values for this _Parameters instance.
  Iterable<Parameter> get values {
    return this._parameters.values;
  }

  /// Returns a list of key/value entries for this _Parameters instance.
  Iterable<MapEntry<String, Parameter>> get entries {
    return this._parameters.entries;
  }

  /// Returns the definition information for this _Parameters instance.
  Map get info {
    return this.test.info["parameters"];
  }
}

/// A container to hold a single input parameter for a CrabTest instance.
class Parameter {
  final CrabTest test;
  final String id;
  final String _value;

  /// Initializes the Parameter instance.
  ///
  /// Throws [ParameterException] if [_id] is not a valid parameter for [test]
  /// or [_value] does not match the definition requirements.
  Parameter(this.test, this.id, this._value) {
    if (!test.info["parameters"].containsKey(id)) {
      throw new ParameterException(id, "Invalid parameter ID");
    } else if (this.info["type"] == "select") {
      if (!this.info["options"].containsKey(_value))
        throw new ParameterException(id, "Invalid option: $_value");
    } else if (this.info["type"] == "int") {
      var val = int.tryParse(_value);
      if (val == null)
        throw new ParameterException(id, "Expected an integer");
      else if (val < this.info["min"] || val > this.info["max"])
        throw new ParameterException(id, "Parameter outside valid range");
    }
  }

  /// Returns the definition information for this Parameter instance.
  Map get info {
    return this.test.info["parameters"][id];
  }

  /// Returns the parameter value as a string.
  String toString() {
    return this._value;
  }

  /// Returns the parameter value as a string formatted for the ACEStat syntax.
  String format() {
    var val = this._value;
    Map param = this.info;
    bool negative = false;
    if (param["signed"] == true) {
      int tmp = int.parse(val);
      negative = tmp < 0;
      val = tmp.abs().toString();
    }
    if (param["lpad"] != null) {
      val = val.padLeft(param["lpad"]["width"], param["lpad"]["char"]);
    } else if (param["rpad"] != null) {
      val = val.padRight(param["rpad"]["width"], param["rpad"]["char"]);
    }
    if (param["signed"] == true) {
      if (negative)
        val = "-" + val;
      else
        val = "+" + val;
    }
    return val;
  }
}

/// A container to manage the results for a CrabTest instance.
class _Results {
  final CrabTest test;
  Map<String, Result> _results;

  /// Initialize a _Results instance.
  _Results(this.test) {
    this._results = new Map<String, Result>();
  }

  /// Access _Results instance like a map.
  Result operator [](String key) => this._results[key];

  /// Sets a specific result [key] with value [value].
  _Results set(String key, dynamic value) {
    this._results[key] = new Result(this.test, key, value);
    return this;
  }

  /// Return whether a result [key] has been set or not for this _Results
  /// instance.
  bool containsKey(Object key) {
    return this._results.containsKey(key);
  }

  /// Return whether any results have been set or not for this _Results
  /// instance.
  bool get isEmpty {
    return this._results.isEmpty;
  }

  /// Returns a list of result keys for this _Results instance.
  Iterable<String> get keys {
    return this._results.keys;
  }

  /// Returns a list of result values for this _Results instance.
  Iterable<Result> get values {
    return this._results.values;
  }

  /// Returns a list of key/value entries for this _Results instance.
  Iterable<MapEntry<String, Result>> get entries {
    return this._results.entries;
  }

  /// Returns the definition information for this _Results instance.
  Map get info {
    return this.test.info["outputs"];
  }
}

/// A container to hold a single result for a CrabTest instance.
class Result {
  final CrabTest test;
  final String id;
  final Map<String, dynamic> _value = {};

  /// Initialize a Result instance.
  Result(this.test, this.id, dynamic values) {
    this.info["fields"].keys.forEach((f) {
      if (values.containsKey(f)) {
        this._value[f] = _setType(this.info["fields"][f]["type"], values[f]);
      }
    });
  }

  /// Access the fields of a result like a map.
  dynamic operator [](String key) => this._value[key];

  /// Return the Result value.
  Map<String, dynamic> get value {
    return this._value;
  }

  /// Returns the definition information for this Result instance.
  Map get info {
    return this.test.info["outputs"][this.id];
  }

  /// Return a list of field keys set in this Result instance.
  Iterable<String> get fields {
    return this._value.keys;
  }

  /// Return a list of field values set in this Result instance.
  Iterable<dynamic> get values {
    return this._value.values;
  }

  /// Return this Result instance formatted as a single map.
  dynamic toJSON() {
    return Map.fromEntries(this._value.map((key, value) {
      if (value is Iterable) {
        return MapEntry(key, value.map((e) => e.toString()).toList());
      }
      return MapEntry(key, value.toString());
    }).entries);
  }
}

/// Holds various tools useful for exporting a CrabTest instance.
class Exporter {
  /// Obtains the export file path for the device platform.
  static Future<String> get exportPath async {
    Directory directory;
    if (Platform.isAndroid) {
      // Android-specific code
      directory = Directory("/storage/emulated/0/CrabApp");
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
      if (!await directory.exists()) {
        await directory.create();
      }
      // directory = await getExternalStorageDirectory();
    } else {
      //if (Platform.isIOS) {
      // iOS-specific code
      directory = await getApplicationDocumentsDirectory();
    }
    return directory.path;
  }

  /// Obtains the temporary file path for the device platform.
  static Future<String> get temporaryPath async {
    Directory directory = await getTemporaryDirectory();
    return directory.path;
  }

  /// Given a CrabTest [test], return a list in row/column format of all
  /// parameters and results.
  static Future<List<List<dynamic>>> convertToList(CrabTest test) async {
    // Parameters
    List exportData = zip(<List>[
      ...test.parameters.info.entries.map<List>((entry) {
        // print("${entry.key}: ${parameters[entry.key]}");
        String label = "${entry.value["name"]}";
        if (entry.value["units"] != null) {
          label = "$label (${entry.value["units"]})";
        }
        String value = test.parameters[entry.key].toString();
        if (entry.value["type"] == "select") {
          value = entry.value["options"][value];
        }
        return [label, value];
      }).toList()
    ]).toList();

    exportData.add([]);

    test.results.info.forEach((key, value) {
      exportData.addAll(zip(<List>[
        ...value["fields"].values.map((field) {
          String label = "$key.${field["label"]}";
          if (field["units"] != null) {
            label = "$label (${field["units"]})";
          }
          if (!test.results.containsKey(key)) {
            return [label];
          } else if (test.results[key][field["label"]] is List) {
            return [label, ...test.results[key][field["label"]]];
          }
          return [label, test.results[key][field["label"]]];
        }).toList()
      ]));
      exportData.add([]);
    });
    return exportData;
  }

  /// Given a file path [path] and a CrabTest [test] or list of rows/columns
  /// [list], write the provided data to a CSV file.
  static Future<String> writeToCSV(String path,
      {CrabTest test, List list}) async {
    final file = File(path);
    try {
      if (test != null) {
        list = await Exporter.convertToList(test);
      }
      await file.writeAsString(ListToCsvConverter().convert(list));
    } on FileSystemException catch (e) {
      throw e.osError;
    } catch (e) {
      throw Exception("Failed to generate export data.");
    }
    return path;
  }

  /// Given a file path [path] and a CrabTest [test] or list of rows/columns
  /// [list], write the provided data to a file.
  static Future<String> writeToFile(String filename,
      {CrabTest test, List list}) async {
    String dir = await Exporter.exportPath;
    return Exporter.writeToCSV("$dir/$filename", test: test, list: list);
  }

  /// Given a file path [path] and a CrabTest [test] or list of rows/columns
  /// [list], write the provided data to a temporary CSV file.
  static Future<String> _saveTmp(String filename,
      {CrabTest test, List list}) async {
    String dir = await Exporter.temporaryPath;
    return writeToCSV("$dir/$filename", test: test, list: list);
  }

  /// Given a file path [path] and a CrabTest [test] or list of rows/columns
  /// [list], write the provided data to a temporary file to be opened by
  /// another application.
  static Future openWith(String filename, {CrabTest test, List list}) async {
    OpenFile.open(await Exporter._saveTmp(filename, test: test, list: list),
        type: "text/csv");
  }

  /// Given a file path [path] and a CrabTest [test] or list of rows/columns
  /// [list], write the provided data to a temporary file to be shared through
  /// another application.
  static Future share(String filename, {CrabTest test, List list}) async {
    Share.shareFiles(
        [await Exporter._saveTmp(filename, test: test, list: list)],
        subject: filename);
  }
}
