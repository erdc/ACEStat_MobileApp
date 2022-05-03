import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:acestat/Analysis/TestDefinitions.dart';
import 'package:acestat/DBManager.dart';
import 'package:acestat/Fragments/DeviceSelect.dart';
import 'package:acestat/Resources/PackageInfo.dart';
import 'package:acestat/Resources/Styles.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  /// Initialize package info
  await PackageInfo.init();
  /// Load database
  await DB.instance.database;
  /// Load test definitions
  await TestDefinitions().initTests();
  runApp(CrabApp());
}

class CrabApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        theme: ThemeData(
          brightness: Brightness.light,
          primarySwatch: usaceRed,
          textTheme: TextTheme(
            bodyText1: TextStyle(fontSize: 20),
            bodyText2: TextStyle(fontSize: 18),
            button: TextStyle(fontSize: 18),
            caption: TextStyle(fontSize: 14),
            headline1: TextStyle(fontSize: 100),
            headline2: TextStyle(fontSize: 64),
            headline3: TextStyle(fontSize: 52),
            headline4: TextStyle(fontSize: 38),
            headline5: TextStyle(fontSize: 28),
            headline6: TextStyle(fontSize: 24),
            overline: TextStyle(fontSize: 14),
            subtitle1: TextStyle(fontSize: 18),
            subtitle2: TextStyle(fontSize: 16),
          ),
          appBarTheme: AppBarTheme(
              toolbarTextStyle: TextStyle(color: usaceText, fontSize: 18),
              titleTextStyle: TextStyle(color: usaceText, fontSize: 24)),
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: usaceRed,
          textTheme: TextTheme(
            bodyText1: TextStyle(fontSize: 20),
            bodyText2: TextStyle(fontSize: 18),
            button: TextStyle(fontSize: 18),
            caption: TextStyle(fontSize: 14),
            headline1: TextStyle(fontSize: 100),
            headline2: TextStyle(fontSize: 64),
            headline3: TextStyle(fontSize: 52),
            headline4: TextStyle(fontSize: 38),
            headline5: TextStyle(fontSize: 28),
            headline6: TextStyle(fontSize: 24),
            overline: TextStyle(fontSize: 14),
            subtitle1: TextStyle(fontSize: 18),
            subtitle2: TextStyle(fontSize: 16),
          ),
          appBarTheme: AppBarTheme(
              toolbarTextStyle: TextStyle(color: usaceText, fontSize: 18),
              titleTextStyle: TextStyle(color: usaceText, fontSize: 24)),
        ),
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: AnnotatedRegion<SystemUiOverlayStyle>(
          value: Theme.of(context).brightness == Brightness.dark
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light,
          child: new DeviceSelect(),
        ));
  }
}
