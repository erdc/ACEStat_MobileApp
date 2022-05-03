import 'dart:convert';

import 'package:async/async.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:acestat/Analysis/CrabTest.dart';

const int DB_LIMIT = 500;

/// Accesses and manages the test history database.
class DB {
  static final DB _db = new DB._internal();

  DB._internal();

  static DB get instance => _db;
  static Database _database;
  final _initDBMemoizer = AsyncMemoizer<Database>();

  /// Return database connection.
  Future<Database> get database async {
    if (_database != null) return _database;

    _database = await _initDBMemoizer.runOnce(() async {
      return await _init();
    });

    return _database;
  }

  /// Initialise the database.
  Future<Database> _init() async {
    // await deleteDatabase(join(await getDatabasesPath(), 'crabapp.db'));
    return await openDatabase(
      join(await getDatabasesPath(), 'crabapp.db'),
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute("""
          CREATE TABLE tests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            version Text NOT NULL
          );
        """);
        await db.execute("""
          CREATE TABLE parameters (
            testid INTEGER,
            field TEXT NOT NULL,
            value TEXT NOT NULL,
            UNIQUE(testid,field) ON CONFLICT REPLACE,
            CONSTRAINT fk_tests
              FOREIGN KEY(testid)
              REFERENCES tests(id)
              ON DELETE CASCADE
          );
        """);
        await db.execute("""
          CREATE TABLE results (
            testid INTEGER,
            field TEXT NOT NULL,
            value TEXT NOT NULL,
            UNIQUE(testid,field) ON CONFLICT REPLACE,
            CONSTRAINT fk_tests
              FOREIGN KEY(testid)
              REFERENCES tests(id)
              ON DELETE CASCADE
          );
        """);
      },
      version: 1,
    );
  }

  /// Insert CarbTest [test] into the database.
  static Future<void> insertCrabTest(CrabTest test) async {
    var db = await DB.instance.database;
    int id = await db.insert(
      'tests',
      {
        "type": test.id,
        "timestamp": test.startTime.millisecondsSinceEpoch,
        "version": test.version
      },
    );
    test.parameters.entries.forEach((element) async {
      await db.insert("parameters", {
        "testid": id,
        "field": element.key,
        "value": element.value.toString()
      });
    });
    test.results.entries.forEach((element) async {
      await db.insert("results", {
        "testid": id,
        "field": element.key,
        "value": jsonEncode(element.value.toJSON())
      });
    });
    List tmp = await db.query("tests",
        columns: ["timestamp"],
        orderBy: "timestamp DESC",
        offset: DB_LIMIT,
        limit: 1);
    if (tmp.isNotEmpty) {
      await db.delete(
        'tests',
        where: 'timestamp <= ?',
        whereArgs: [tmp.first["timestamp"]],
      );
    }
  }

  /// Delete CrabTest with ID [id] from the database.
  static Future<void> deleteCrabTest(int id) async {
    var db = await DB.instance.database;
    await db.delete(
      'tests',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Load CrabTest with ID [id] from the database.
  static Future<CrabTest> loadCrabTest(int id) async {
    var db = await DB.instance.database;
    List tmp = await db.query("tests",
        columns: ["type", "timestamp", "version"],
        where: "id = ?",
        whereArgs: [id]);
    if (tmp.isEmpty) {
      throw Exception("$id not found");
    }
    var params = await db.query("parameters",
        columns: ["field", "value"], where: "testid = ?", whereArgs: [id]);
    var results = await db.query("results",
        columns: ["field", "value"], where: "testid = ?", whereArgs: [id]);
    return CrabTest.loadTest(
        tmp.first["type"],
        tmp.first["version"],
        DateTime.fromMillisecondsSinceEpoch(tmp.first["timestamp"],
            isUtc: true),
        Map.fromIterable(params,
            key: (p) => p["field"], value: (p) => p["value"]),
        Map.fromIterable(results,
            key: (r) => r["field"], value: (r) => jsonDecode(r["value"])));
  }

  /// Retrieve the parameters for test with ID [id] from the database.
  static Future<Map<String, String>> getParameters(int id) async {
    var db = await DB.instance.database;
    var params = await db.query("parameters",
        columns: ["field", "value"], where: "testid = ?", whereArgs: [id]);
    return Map.fromIterable(params,
        key: (p) => p["field"], value: (p) => p["value"]);
  }
}
