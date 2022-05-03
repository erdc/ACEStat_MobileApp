import 'dart:math';

import 'package:flutter/material.dart';

import 'package:acestat/Analysis/CrabTest.dart';
import 'package:acestat/Resources/Styles.dart';
import 'package:acestat/Widgets/ResultView.dart';
import 'package:acestat/Widgets/TestHistory.dart';

/// Widget used to browse previous test results.
class ResultBrowser extends StatefulWidget {
  @override
  _ResultBrowserState createState() => _ResultBrowserState();
}

/// Contains the state of ResultBrowser.
class _ResultBrowserState extends State<ResultBrowser> {
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  CrabTest _test;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Determine what is shown in the main display.
  Widget _buildView() {
    if (this._test == null) {
      return Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("No results selected"),
          ElevatedButton(
            child: Text("Browse Results"),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
        ],
      ));
    }
    return ResultView(test: this._test);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text("Result Browser"),
      ),
      drawer: Container(
          width: min(350, MediaQuery.of(context).size.width * 0.9),
          child: Drawer(
            child: Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Column(children: <Widget>[
                  Container(
                    width: double.infinity,
                    child: DrawerHeader(
                      margin: EdgeInsets.zero,
                      padding: EdgeInsets.zero,
                      child: Image.asset("assets/images/usace_castle.png"),
                      decoration: BoxDecoration(color: usaceRed),
                    ),
                  ),
                  Expanded(child:
                      Container(child: TestHistory(onLoad: (CrabTest test) {
                    setState(() {
                      this._test = test;
                      if (_scaffoldKey.currentState.isDrawerOpen) {
                        Navigator.of(context).pop();
                      }
                    });
                  })))
                ])),
          )),
      body: this._buildView(),
    );
  }
}
