import 'package:flutter/material.dart';

import 'package:acestat/Analysis/CrabTest.dart';
import 'package:acestat/Widgets/MatrixTable.dart';
import 'package:acestat/Resources/Styles.dart';

/// Widget specifically for displaying a table.
class OutputTable extends StatelessWidget {
  final Result result;

  OutputTable(this.result);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: usaceText),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text("${this.result.test.info["name"]} - ${this.result.id}"),
        ),
        body: MatrixTable(this.result));
  }
}
