import 'dart:async';
import 'package:flutter/material.dart';

import 'package:incrementally_loading_listview/incrementally_loading_listview.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:acestat/Analysis/CrabTest.dart';
import 'package:acestat/Analysis/TestDefinitions.dart';
import 'package:acestat/Analysis/TestHistoryState.dart';

import '../DBManager.dart';

final DateFormat _dateFilterFormat = DateFormat('yyyy-MM-dd hh:mm a');
final DateFormat _dateListFormat = DateFormat('yyyy-MM-dd hh:mm:ss a');

/// A widget used to sort, filter, and list test history.
class TestHistory extends StatefulWidget {
  final Function(CrabTest) onLoad;
  final Function(String, Map) onCopy;

  TestHistory({@required this.onLoad, this.onCopy});

  @override
  State<StatefulWidget> createState() => _TestHistoryState();
}

/// Contains the state for a TestHistory widget.
class _TestHistoryState extends State<TestHistory> {
  List<Map> items = [];
  bool _hasMoreItems = true;
  Future<Null> _loading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreItems();
    });
  }

  /// Refresh the list. Called when the sort/filter is changed or a result is
  /// deleted.
  void _resetList() async {
    if (this._loading != null) {
      await this._loading;
    }
    var completer = Completer<Null>();
    _loading = completer.future;
    this.items.clear();
    this._hasMoreItems = true;
    await this._loadMoreItems();
    completer.complete();
    this._loading = null;
  }

  /// Load the next set of results in the list.
  Future _loadMoreItems() async {
    TestHistoryState state =
        Provider.of<TestHistoryState>(context, listen: false);
    // print("Loading more items: ${this.items.length}");
    String _where =
        "type IN (${state.enabledTests.keys.where((key) => state.enabledTests[key]).map((e) => "\"$e\"").join(', ')})";
    List _whereArgs = [];
    if (state.filterStart != null) {
      _where = "$_where AND timestamp >= ?";
      _whereArgs.add(state.filterStart.toUtc().millisecondsSinceEpoch);
    }
    if (state.filterEnd != null) {
      _where = "$_where AND timestamp <= ?";
      _whereArgs.add(state.filterEnd.toUtc().millisecondsSinceEpoch);
    }
    return await DB.instance.database
        .then((db) => db.query("tests",
            columns: ["id", "type", "timestamp"],
            where: _where,
            whereArgs: _whereArgs,
            orderBy: "timestamp ${state.dateSort ? "ASC" : "DESC"}",
            limit: 25,
            offset: this.items.length))
        .then((value) {
      setState(() {
        items.addAll(value);
        if (value.length < 25) {
          _hasMoreItems = false;
        }
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Generate the display of the sort and filter panes.
  Widget get _testFilter {
    TestHistoryState state =
        Provider.of<TestHistoryState>(context, listen: false);
    return Column(
      children: [
        ExpansionTile(
          title: Text("Sort",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              )),
          initiallyExpanded: state.expandSort,
          onExpansionChanged: (isExpanded) {
            state.expandSort = isExpanded;
          },
          children: <Widget>[
            ListTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Date/Time',
                      style: TextStyle(
                        fontSize: 16,
                      )),
                  Icon(
                    state.dateSort
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: Theme.of(context).textTheme.subtitle1.color,
                    size: 24.0,
                  ),
                ],
              ),
              onTap: () {
                setState(() {
                  state.dateSort = !state.dateSort;
                  this.items = List.from(this.items.reversed);
                });
              },
            ),
          ],
        ),
        ExpansionTile(
          title: Text("Filter",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              )),
          initiallyExpanded: state.expandFilter,
          onExpansionChanged: (isExpanded) {
            state.expandFilter = isExpanded;
          },
          children: <Widget>[
            Column(children: [
              ...TestDefinitions()
                  .tests
                  .values
                  .toList(growable: false)
                  .map((e) => CheckboxListTile(
                        title: Text(e["name"],
                            style: TextStyle(
                              fontSize: 16,
                            )),
                        value: state.enabledTests[e["id"]],
                        onChanged: (value) {
                          state.enabledTests[e["id"]] = value;
                          this._resetList();
                        },
                      ))
                  .toList(),
              ListTile(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Time range start:',
                        style: TextStyle(
                          fontSize: 16,
                        )),
                    FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                            state.filterStart != null
                                ? _dateFilterFormat.format(state.filterStart)
                                : " ",
                            style: TextStyle(fontSize: 15))),
                  ],
                ),
                subtitle: state.filterStart != null
                    ? Text('Long press to clear',
                        style: TextStyle(
                          fontSize: 12,
                        ))
                    : null,
                onTap: () async {
                  final date = await showDatePicker(
                      context: context,
                      helpText: "Select Start Date",
                      firstDate: DateTime(1900),
                      initialDate: state.filterStart ?? DateTime.now(),
                      lastDate: DateTime(2100));
                  final time = await showTimePicker(
                    context: context,
                    helpText: "Select Start Time",
                    initialTime: TimeOfDay.fromDateTime(
                        state.filterStart ?? DateTime.now()),
                  );
                  if (time == null) return;
                  state.filterStart = DateTime(
                      date.year, date.month, date.day, time.hour, time.minute);
                  this._resetList();
                },
                onLongPress: () {
                  if (state.filterStart == null) return;
                  state.filterStart = null;
                  this._resetList();
                },
              ),
              ListTile(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Time range end:',
                        style: TextStyle(
                          fontSize: 16,
                        )),
                    FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                            state.filterEnd != null
                                ? _dateFilterFormat.format(state.filterEnd)
                                : " ",
                            style: TextStyle(fontSize: 15))),
                  ],
                ),
                subtitle: state.filterEnd != null
                    ? Text('Long press to clear',
                        style: TextStyle(
                          fontSize: 12,
                        ))
                    : null,
                onTap: () async {
                  final date = await showDatePicker(
                      context: context,
                      helpText: "Select End Date",
                      firstDate: DateTime(1900),
                      initialDate: state.filterEnd ?? DateTime.now(),
                      lastDate: DateTime(2100));
                  if (date == null) return;
                  final time = await showTimePicker(
                    context: context,
                    helpText: "Select End Time",
                    initialTime: TimeOfDay.fromDateTime(
                        state.filterEnd ?? DateTime.now()),
                  );
                  if (time == null) return;
                  state.filterEnd = DateTime(
                      date.year, date.month, date.day, time.hour, time.minute);
                  this._resetList();
                },
                onLongPress: () {
                  if (state.filterEnd == null) return;
                  state.filterEnd = null;
                  this._resetList();
                },
              ),
            ]),
          ],
        ),
      ],
    );
  }

  /// Generate the sort/filter pane container.
  Widget get _form {
    TestHistoryState state =
        Provider.of<TestHistoryState>(context, listen: false);
    return ExpansionTile(
      title: Text("Sort/Filter"),
      initiallyExpanded: state.expandSortFilter,
      onExpansionChanged: (isExpanded) {
        state.expandSortFilter = isExpanded;
      },
      children: <Widget>[
        Container(
            padding: EdgeInsets.only(top: 5.0, left: 5.0, right: 5.0),
            child: this._testFilter),
      ],
    );
  }

  /// Display dialog confirming if the user wishes to delete a result.
  Future<bool> _confirmDelete() async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm"),
          content: const Text("Are you sure you wish to delete this item?"),
          actions: <Widget>[
            ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("DELETE")),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("CANCEL"),
            ),
          ],
        );
      },
    );
  }

  /// Delete a test result at index [index].
  void _deleteResult(int index) async {
    await DB.deleteCrabTest(items[index]['id']);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${TestDefinitions().tests[items[index]["type"]]["name"]} ${_dateListFormat.format(DateTime.fromMillisecondsSinceEpoch(items[index]["timestamp"], isUtc: true).toLocal())} deleted')));
    setState(() {
      items.removeAt(index);
    });
  }

  /// Generate the buttons on an expanded result item.
  List<Widget> _prepareButtons(index) {
    List<Widget> _buttonRow = [];
    if (widget.onCopy != null) {
      _buttonRow.add(Expanded(
          child: ElevatedButton(
        child: const Text("Copy"),
        onPressed: () async {
          widget.onCopy(
              items[index]["type"], await DB.getParameters(items[index]["id"]));
        },
      )));
      _buttonRow.add(SizedBox(
        width: 5.0,
      ));
    }
    _buttonRow.add(Expanded(
        child: ElevatedButton(
      child: const Text("Load"),
      onPressed: () async {
        widget.onLoad(await DB.loadCrabTest(items[index]["id"]));
      },
    )));
    return _buttonRow;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        this._form,
        Expanded(
            child: Scrollbar(
                child: IncrementallyLoadingListView(
          padding: EdgeInsets.all(0),
          hasMore: () => _hasMoreItems,
          itemCount: () => items.length,
          loadMore: () async {
            await _loadMoreItems();
          },
          separatorBuilder: (_, __) => Divider(
            height: 1,
          ),
          loadMoreOffsetFromBottom: 2,
          itemBuilder: (context, index) {
            return Dismissible(
                key: Key(items[index]['id'].toString()),
                confirmDismiss: (DismissDirection direction) {
                  return _confirmDelete();
                },
                onDismissed: (direction) {
                  _deleteResult(index);
                },
                background: Container(color: Colors.red),
                child: ListTile(
                  title: _ResultExpansionTile(
                    result: items[index],
                    children: <Widget>[
                      ListTile(title: Row(children: _prepareButtons(index))),
                    ],
                  ),
                  onLongPress: () async {
                    if (await this._confirmDelete()) {
                      _deleteResult(index);
                    }
                  },
                ));
          },
        )))
      ],
    );
  }
}

/// Custom expansion tile that loads test parameters only on expansion.
class _ResultExpansionTile extends StatefulWidget {
  final Map result;
  final List<Widget> children;

  _ResultExpansionTile({this.result, this.children = const <Widget>[]});

  @override
  State createState() => new _ResultExpansionTileState();
}

/// Holds the state for a _ResultExpansionTile widget.
class _ResultExpansionTileState extends State<_ResultExpansionTile> {
  // PageStorageKey _key;
  Completer<Map<String, String>> _responseCompleter = new Completer();

  @override
  Widget build(BuildContext context) {
    Map def = TestDefinitions().tests;
    // _key = PageStorageKey('${widget.result["id"]}');
    return ExpansionTile(
      // key: _key,
      title: Text("${def[widget.result["type"]]["name"]}"),
      subtitle: Text(
          "${_dateListFormat.format(DateTime.fromMillisecondsSinceEpoch(widget.result["timestamp"], isUtc: true).toLocal())}"),
      onExpansionChanged: (bool isExpanding) {
        if (!_responseCompleter.isCompleted && isExpanding) {
          _responseCompleter.complete(DB.getParameters(widget.result["id"]));
        }
      },
      children: <Widget>[
        FutureBuilder(
          future: _responseCompleter.future,
          builder: (BuildContext context,
              AsyncSnapshot<Map<String, String>> response) {
            if (response.data == null) return Container();
            List<TableRow> _rows = [];
            _rows.add(TableRow(children: [
              Container(
                  alignment: Alignment.center,
                  child: Text("Parameter",
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold))),
              Container(
                  alignment: Alignment.center,
                  child: Text("Value",
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)))
            ]));
            def[widget.result["type"]]["parameters"].forEach((pKey, param) {
              Widget _input;
              if (param["type"] == "select") {
                _input = Text(param["options"][response.data[pKey]],
                    style: TextStyle(
                      fontSize: 15,
                    ));
              } else if (param["type"] == "int") {
                _input = Text(int.parse(response.data[pKey]).toString(),
                    style: TextStyle(
                      fontSize: 15,
                    ));
              }
              List<Widget> _row = [];
              _row.add(Expanded(
                  child: Container(
                alignment: Alignment.centerRight,
                padding: EdgeInsets.only(left: 10.0),
                child: _input,
              )));
              if (param["units"] != null) {
                _row.add(Text(param["units"],
                    style: TextStyle(
                      fontSize: 15,
                    )));
              }
              _rows.add(TableRow(children: [
                Container(
                    padding: EdgeInsets.symmetric(horizontal: 5.0),
                    child: Text(param["name"] + ":",
                        style: TextStyle(
                          fontSize: 15,
                        ))),
                Container(
                    padding: EdgeInsets.symmetric(horizontal: 5.0),
                    child: Row(children: _row))
              ]));
            });
            return Column(children: [
              ListTile(
                title: Table(
                    border: TableBorder.all(
                        width: 0.5,
                        color: Theme.of(context).textTheme.subtitle1.color),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: {0: IntrinsicColumnWidth()},
                    children: _rows),
              ),
              ...widget.children
            ]);
          },
        )
      ],
    );
  }
}
