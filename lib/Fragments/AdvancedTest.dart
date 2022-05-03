import 'dart:async';
import 'dart:math' show min;

import 'package:acestat/Widgets/ResultView.dart';

// import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:acestat/Analysis/CrabTest.dart';
import 'package:acestat/Resources/Styles.dart';
import 'package:acestat/Analysis/TestFormState.dart';
import 'package:acestat/Widgets/TestForm.dart';
import 'package:acestat/Analysis/TestHandler.dart';
import 'package:acestat/Widgets/TestHistory.dart';
import 'package:acestat/Comms/USBSerial.dart';

/// Manages the Advanced Test activity.
class AdvancedTest extends StatefulWidget {
  @override
  _TestState createState() => _TestState();
}

/// Contains the state of AdvancedTest.
class _TestState extends State<AdvancedTest>
    with SingleTickerProviderStateMixin {
  CrabTest _currentTest;
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<StreamSubscription> _subscriptions = [];
  TabController _drawerTabController;
  Timer _timer;
  num _remainingTime;

  @override
  void initState() {
    super.initState();

    _drawerTabController = TabController(vsync: this, length: 2);

    // _subscriptions.add(TestHandler().onResult((String key) {
    //   setState(() {
    //     // if (this._currentTest.info["plots"]) {
    //     //   _visiblePlot = key;
    //     // }
    //   });
    // }));

    _subscriptions.add(TestHandler().onError((String err) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Testing Error'),
            content: Text("$err"),
            actions: [
              TextButton(
                child: Text('Ok'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }));

    _subscriptions.add(TestHandler().onReady((bool ready) {
      if (ready && _timer != null) {
        _timer.cancel();
      }
      _remainingTime = null;
      setState(() {
        context.read<TestFormState>().enabled = ready;
      });
    }));

    _subscriptions.add(TestHandler().onTestStart((CrabTest test) {
      this._currentTest = test;
      // Initialize timer
      _remainingTime = this._currentTest.estimateRemaining;
      if (_remainingTime != null) {
        const oneSec = const Duration(seconds: 1);
        _timer = new Timer.periodic(
          oneSec,
          (Timer timer) {
            if (_remainingTime == 0) {
              setState(() {
                timer.cancel();
              });
            } else {
              setState(() {
                _remainingTime = this._currentTest.estimateRemaining;
              });
            }
          },
        );
      }
      setState(() {});
    }));

    _subscriptions.add(TestHandler().onTestEnd((CrabTest test) async {
      if (_timer != null) {
        _timer.cancel();
      }
      // var db = await DB.instance.database;
      // List result = await db.query("tests",
      //     columns: ["id"], orderBy: "timestamp ASC", limit: 1);
      // if (result.length > 0) {
      //   CrabTest tmp = await DB.loadCrabTest(result[0]["id"]);
      //   this._currentTest.results["RESULTS"].fields.forEach((field) {
      //     print(listEquals(this._currentTest.results["RESULTS"][field], tmp.results["RESULTS"][field]));
      //   });
      // }
    }));

    // Send a reset message on init, if connected
    if (USBSerial().isConnected()) {
      TestHandler().reset();
    }
    context.read<TestFormState>().enabled = TestHandler().ready;
  }

  /// Ensure that all streams are closed on disposal.
  @protected
  @mustCallSuper
  void dispose() {
    if (_timer != null) {
      _timer.cancel();
    }
    _subscriptions.forEach((subscription) {
      subscription.cancel();
    });
    super.dispose();
  }

  /// Determines what to display based on the status of the ACEStat and a
  /// running test.
  Widget _displayResults() {
    if (TestHandler().running && this._currentTest.results.isEmpty) {
      /// If a test is running and there are no results yet.
      Text label;

      /// If a remaining time is available.
      if (_remainingTime != null) {
        label = Text(
            "Test in progress.\nTime remaining: ~${_remainingTime.round()}s",
            textAlign: TextAlign.center);
      } else {
        label = Text("Test in progress.\nPlease wait...",
            textAlign: TextAlign.center);
      }
      return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            label,
            ElevatedButton(
              child: Text("Cancel"),
              onPressed: () {
                TestHandler().reset();
              },
            )
          ]);
    } else if (!TestHandler().running && !TestHandler().ready) {
      /// If no test is running, and the ACEStat is not ready. Most likely, the
      /// app has not received a ready message.
      return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("Waiting for response...", textAlign: TextAlign.center),
            ElevatedButton(
              child: Text("Retry"),
              onPressed: () {
                TestHandler().reset();
              },
            )
          ]);
    } else if (this._currentTest == null || this._currentTest.results.isEmpty) {
      /// If no test is running or the current test has no results.
      return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("No results to display.", textAlign: TextAlign.center),
            ElevatedButton(
              child: Text("New Test"),
              onPressed: () {
                _drawerTabController.index = 0;
                _scaffoldKey.currentState?.openDrawer();
              },
            )
          ]);
    } else {
      /// The current test has results available.
      return ResultView(test: this._currentTest);
    }
  }

  @override
  Widget build(BuildContext context) {
    TestFormState form = Provider.of<TestFormState>(context);
    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text("Advanced Test"),
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
                  Container(
                    padding: EdgeInsets.zero,
                    color: Colors.black12,
                    child: TabBar(
                      indicatorColor: usaceRed,
                      controller: _drawerTabController,
                      // labelColor: Colors.deepOrange,
                      unselectedLabelColor: Colors.white,
                      tabs: [
                        Tab(icon: Icon(Icons.add)),
                        Tab(icon: Icon(Icons.history)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _drawerTabController,
                      children: <Widget>[
                        Container(child: SingleChildScrollView(
                          child: TestForm(
                            onSubmit: (CrabTest test) {
                              if (test.run()) {
                                _currentTest = null;
                                if (_scaffoldKey.currentState.isDrawerOpen) {
                                  Navigator.of(context).pop();
                                }
                              }
                            },
                          ),
                        )),
                        Container(
                            child: TestHistory(
                                onCopy: (String id, Map parameters) {
                          form.selectedTest = id;
                          parameters.forEach((key, value) {
                            form[key] = value;
                          });
                          setState(() {
                            _drawerTabController.index = 0;
                          });
                        }, onLoad: (CrabTest test) {
                          setState(() {
                            this._currentTest = test;
                            if (_scaffoldKey.currentState.isDrawerOpen) {
                              Navigator.of(context).pop();
                            }
                          });
                        }))
                      ],
                    ),
                  )
                ])),
          )),
      body: Center(child: _displayResults()),
    );
  }
}
