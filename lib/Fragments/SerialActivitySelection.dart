import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:acestat/Fragments/AdvancedTest.dart';
import 'package:acestat/Transitions/Slide.dart';
import 'package:acestat/Analysis/TestFormState.dart';
import 'package:acestat/Analysis/TestHistoryState.dart';

/// Allow the user to select which activity they would like to start.
class SerialActivitySelect extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text("Activity Selection"),
      ),
      body: Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ElevatedButton(
            child: Text("Advanced Test"),
            onPressed: () {
              Navigator.push(
                  context,
                  SlideLeftRoute(
                      page: MultiProvider(providers: [
                    ChangeNotifierProvider(create: (_) => TestFormState()),
                    ChangeNotifierProvider(create: (_) => TestHistoryState())
                  ], child: new AdvancedTest())));
            },
          )
        ],
      )),
    );
  }
}
