import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:acestat/Analysis/CrabTest.dart';
import 'package:acestat/Fragments/OutputChart.dart';
import 'package:acestat/Fragments/OutputTable.dart';
import 'package:acestat/Transitions/Slide.dart';
import 'package:acestat/Analysis/TestDefinitions.dart';
import 'package:acestat/Analysis/TestHandler.dart';

class ResultView extends StatefulWidget {
  final CrabTest test;

  ResultView({@required this.test});

  @override
  _ResultViewState createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView> {
  String _export;

  void _showAlert(String title, String msg) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(msg),
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
  }

  void _saveResults() async {
    try {
      _export = await widget.test.writeToFile();
      setState(() {});
      Clipboard.setData(ClipboardData(text: _export));
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Results saved. Path copied to clipboard.")));
    } catch (e) {
      this._showAlert("Export Error", e.message);
    }
  }

  void _shareResults() async {
    try {
      await widget.test.share();
    } catch (e) {
      this._showAlert("Export Error", e.message);
    }
  }

  void _openResultsWith() async {
    try {
      await widget.test.openWith();
    } catch (e) {
      this._showAlert("Export Error", e.message);
    }
  }

  Widget _buildView() {
    if (widget.test == null) {
      return Center(
        child: Text("No results selected"),
      );
    }
    String id = widget.test.id;
    Map outputs = widget.test.info["outputs"];

    List<Widget> tmp = [
      SizedBox(height: 15),
      Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
                child: Text("Parameters",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ))),
          ]),
      SizedBox(height: 15),
      Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
                child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              defaultColumnWidth: IntrinsicColumnWidth(),
              children: TestDefinitions()
                  .tests[id]["parameters"]
                  .entries
                  .map<TableRow>((entry) {
                // print("${entry.key}: ${params[entry.key]}");
                String value = widget.test.parameters[entry.key].toString();
                if (entry.value.containsKey("options")) {
                  value = entry.value["options"][value];
                }
                if (entry.value["units"] != null) {
                  value += entry.value["units"];
                }
                // print("${entry.value["name"]}: $value");
                return TableRow(children: [
                  Container(
                      padding: EdgeInsets.only(
                          left: 2.0, top: 2.0, right: 18.0, bottom: 2.0),
                      child: Text("${entry.value["name"]}:",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ))),
                  Container(
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.all(2.0),
                      child: Text(value,
                          style: TextStyle(
                            fontSize: 16,
                          )))
                ]);
              }).toList(),
            )),
          ]),
      SizedBox(height: 45),
      Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
                child: Text("Results",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ))),
          ]),
      SizedBox(height: 15),
      Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
                child: Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    defaultColumnWidth: IntrinsicColumnWidth(),
                    children: <TableRow>[
                  ...[
                    ...outputs.entries.map((output) {
                      if (!widget.test.results.containsKey(output.key)) {
                        return [
                          TableRow(children: [
                            Container(
                                padding: EdgeInsets.only(
                                    left: 2.0,
                                    top: 2.0,
                                    right: 18.0,
                                    bottom: 2.0),
                                child: Text("${output.key}",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ))),
                            Container()
                          ])
                        ];
                      } else if (output.value["type"] == "matrix") {
                        return [
                          TableRow(children: [
                            Container(
                                padding: EdgeInsets.only(
                                    left: 2.0,
                                    top: 2.0,
                                    right: 18.0,
                                    bottom: 2.0),
                                child: Text("${output.key}",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ))),
                            Row(
                              children: [
                                Container(
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.all(2.0),
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.push(
                                          context,
                                          SlideLeftRoute(
                                              page: new OutputTable(widget
                                                  .test.results[output.key]))),
                                      child: Text('Show Table'),
                                    ))
                              ],
                            )
                          ])
                        ];
                      } else {
                        return output.value["fields"].values
                            .map((field) => TableRow(children: [
                                  Container(
                                      padding: EdgeInsets.only(
                                          left: 2.0,
                                          top: 2.0,
                                          right: 18.0,
                                          bottom: 2.0),
                                      child: Text(
                                          "${output.key} ${field['label']}",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ))),
                                  Container(
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.all(2.0),
                                    child: Text(
                                        "${widget.test.results[output.key][field['label']]}${field["units"] ?? ''}",
                                        style: TextStyle(
                                          fontSize: 16,
                                        )),
                                  )
                                ]))
                            .toList();
                      }
                    })
                  ].expand((r) => r).toList()
                ])),
          ]),
      SizedBox(height: 15)
    ];
    if (TestHandler().running) {
      tmp.add(Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            Text("Processing...", textAlign: TextAlign.center),
            ElevatedButton(
              child: Text("Cancel"),
              onPressed: () {
                TestHandler().reset();
              },
            )
          ]));
    } else {
      if (widget.test.info["plots"].isNotEmpty) {
        tmp.addAll([
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                    child: Text("Plots",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ))),
              ]),
          SizedBox(height: 15),
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                    child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  defaultColumnWidth: IntrinsicColumnWidth(),
                  children: widget.test.info["plots"].entries
                      .map<TableRow>((entry) => TableRow(children: [
                            Container(
                                padding: EdgeInsets.only(
                                    left: 2.0,
                                    top: 2.0,
                                    right: 18.0,
                                    bottom: 2.0),
                                child: Text("${entry.key}",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ))),
                            Container(
                              alignment: Alignment.centerRight,
                              padding: EdgeInsets.all(2.0),
                              child: ElevatedButton(
                                onPressed: () => Navigator.push(
                                    context,
                                    SlideLeftRoute(
                                        page: new Chart(
                                            plot: entry.key,
                                            test: widget.test))),
                                child: Text('Show'),
                              ),
                            )
                          ]))
                      .toList(),
                ))
              ])
        ]);
      }
      tmp.add(Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.save),
            tooltip: _export == null
                ? 'Save results to local device'
                : "File saved to: $_export",
            onPressed: _export == null ? _saveResults : null,
          ),
          IconButton(
            icon: Icon(Icons.open_in_new),
            tooltip: 'Open results in another application',
            onPressed: _openResultsWith,
          ),
          IconButton(
            icon: Icon(Icons.share),
            tooltip: 'Share file',
            onPressed: _shareResults,
          ),
        ],
      ));
      tmp.add(Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
              child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(horizontal: 10.0),
                  child: SelectableText(
                    _export ?? "",
                    textAlign: TextAlign.center,
                    onTap: _export != null
                        ? () {
                            Clipboard.setData(ClipboardData(text: _export));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text("Copied to clipboard.")));
                          }
                        : null,
                  )))
        ],
      ));
    }
    return ListView(
      children: tmp,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(padding: EdgeInsets.zero, child: this._buildView());
  }
}
