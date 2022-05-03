import 'dart:async' show Future;
import 'dart:collection';

import 'package:async/async.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:xml/xml.dart';

/// Constant filename for test definitions XML file.
const String FILENAME = "Tests.xml";

/// Loads and stores the CrabTest definitions used to communicate with the
/// ACEStat.
class TestDefinitions {
  Map _tests;
  String _version;
  static TestDefinitions _singleton;
  final _initTestsMemoizer = new AsyncMemoizer();

  TestDefinitions._internal();

  factory TestDefinitions() {
    if (_singleton == null) {
      _singleton = TestDefinitions._internal();
      _singleton.initTests();
    }
    return _singleton;
  }

  /// Parse a parameter tag from the test definitions xml.
  Map _parseParameter(XmlElement node) {
    Map param = new Map();
    param["id"] = node.getAttribute("id");
    param["name"] = node.getAttribute("name");
    param["type"] = node.getAttribute("type");
    if (param["type"] == "select") {
      param["options"] = LinkedHashMap.fromIterable(
          node.findAllElements("option").map((node) {
            if (node.getAttribute("value") != null)
              return [node.getAttribute("value"), node.text];
            return [node.text, node.text];
          }),
          key: (v) => v[0],
          value: (v) => v[1]);
    } else if (param["type"] == "int") {
      param["signed"] =
          (node.getAttribute("signed") ?? "").toLowerCase() == "true";
      param["min"] = int.parse(node.getAttribute("min"));
      param["max"] = int.parse(node.getAttribute("max"));
      if (node.getAttribute("lpad") != null) {
        List _lpad = node.getAttribute("lpad").split("|");
        param["lpad"] = {"char": _lpad[1], "width": int.parse(_lpad[0])};
      } else {
        param["lpad"] = null;
      }
      if (node.getAttribute("rpad") != null) {
        List _rpad = node.getAttribute("rpad").split("|");
        param["rpad"] = {"char": _rpad[1], "width": int.parse(_rpad[0])};
      } else {
        param["rpad"] = null;
      }
    }
    param["units"] = node.getAttribute("units");
    return param;
  }

  /// Parse an output tag from the test definitions xml.
  Map _parseOutput(XmlElement node) {
    Map output = new Map();
    output["id"] = node.getAttribute("id");
    output["type"] = node.getAttribute("type") ?? "field";
    switch (output["type"]) {
      case "list":
        {
          output["separator"] = node.getAttribute("separator");
        }
        break;
      case "matrix":
        {
          output["col-separator"] = node.getAttribute("col-separator");
          output["row-separator"] = node.getAttribute("row-separator");
        }
    }
    output["fields"] = LinkedHashMap.fromIterable(
        node.findElements("field").map((node) {
          return {
            "label": node.getAttribute("label"),
            "type": node.getAttribute("type"),
            "units": node.getAttribute("units")
          };
        }),
        key: (v) => v["label"],
        value: (v) => v);

    return output;
  }

  /// Parse a series tag from the test definitions xml.
  _Series _parseSeries(XmlElement node) {
    return _Series(
        node.getAttribute("name"),
        _Axis(node.getElement("x").getAttribute("output"),
            node.getElement("x").getAttribute("field")),
        _Axis(node.getElement("y").getAttribute("output"),
            node.getElement("y").getAttribute("field")));
  }

  /// Parse a plot tag from the test definitions xml.
  _Plot _parsePlot(XmlElement node) {
    return _Plot(
        node.getAttribute("title"),
        node.getAttribute("x-label"),
        node.getAttribute("y-label"),
        node.findElements("series").map((node) {
          return _parseSeries(node);
        }).toList());
  }

  /// Parse a preset tag from the test definitions xml.
  Map _parsePreset(XmlElement node) {
    Map preset = new Map();
    preset["name"] = node.getAttribute("name");
    preset["parameters"] = Map.fromIterable(
        node.findElements("parameter").map((node) {
          return [node.getAttribute("id"), node.getAttribute("value")];
        }),
        key: (v) => v[0],
        value: (v) => v[1]);
    return preset;
  }

  /// Parse a test tag from the test definitions xml.
  Map _parseTest(XmlElement node) {
    Map test = new Map();
    test['name'] = node.getAttribute("name");
    test['value'] = node.getAttribute("value");
    test['id'] = node.getAttribute("id");
    test["description"] = node.getElement("description");
    test["description"] =
        test["description"] == null ? "" : test["description"].text;
    test["timing"] = node.getElement("timing");
    test["timing"] =
        test["timing"] == null ? null : test["timing"].getAttribute("equation");
    test["parameters"] = LinkedHashMap.fromIterable(
        node
            .getElement("parameters")
            .findElements("parameter")
            .map((node) => _parseParameter(node)),
        key: (v) => v["id"],
        value: (v) => v);
    test["outputs"] = Map.fromIterable(
        node
            .getElement("outputs")
            .findElements("output")
            .map((node) => _parseOutput(node)),
        key: (v) => v["id"],
        value: (v) => v);
    test["plots"] = Map.fromIterable(
        node
            .getElement("plots")
            .findElements("plot")
            .map((node) => _parsePlot(node)),
        key: (v) => v.title,
        value: (v) => v);
    test["presets"] = LinkedHashMap.fromIterable(
        node
            .getElement("presets")
            .findElements("preset")
            .map((node) => _parsePreset(node)),
        key: (v) => v["name"],
        value: (v) => v);
    return test;
  }

  /// Recursively print Map [obj].
  void printTests(var obj) {
    if (obj is Map) {
      for (String key in obj.keys) {
        print(key);
        printTests(obj[key]);
      }
    } else if (obj is List) {
      for (var val in obj) {
        printTests(val);
      }
    } else {
      print(obj);
    }
  }

  /// Load the test defintions from the test definition XML file.
  Future<Map> _loadTests() async {
    // print("LOADING TESTS");
    Map tests = new LinkedHashMap();
    String xml = await rootBundle.loadString("assets/" + FILENAME);
    final techniques = XmlDocument.parse(xml).getElement('techniques');
    _version = techniques.getAttribute("version");
    // print("DEFINITIONS VERSION: $_version");
    techniques.findElements("technique").forEach((technique) {
      technique.findElements("test").forEach((test) {
        Map _test = _parseTest(test);
        _test["technique"] = technique.getAttribute("name");
        tests[_test["id"]] = _test;
      });
    });
    return tests;
  }

  /// Run the initial loading of test definitions.
  Future<Map> initTests() async {
    if (_tests == null) {
      _tests = await _initTestsMemoizer.runOnce(() async {
        return await _loadTests();
      });
    }
    return _tests;
  }

  /// Return the test definitions.
  Map get tests {
    if (_tests == null) {
      throw new Exception("Tests have not yet been loaded.");
    }
    return _tests;
  }

  /// Return the test definition version.
  String get version {
    return _version;
  }
}

/// Class used to describe a plot object.
class _Plot {
  final String title, xlabel, ylabel;
  final List<_Series> series;

  _Plot(this.title, this.xlabel, this.ylabel, this.series);
}

/// Class used to describe a series object.
class _Series {
  final String name;
  final _Axis x, y;

  _Series(this.name, this.x, this.y);
}

/// Class used to describe an axis object.
class _Axis {
  final String output, field;

  _Axis(this.output, this.field);
}
