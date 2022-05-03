import 'package:flutter/material.dart';
import 'package:quiver/iterables.dart' show max;
import 'package:lazy_data_table/lazy_data_table.dart';

import 'package:acestat/Analysis/CrabTest.dart';

/// A widget used to display a table with many rows.
class MatrixTable extends StatefulWidget {
  final Result result;

  const MatrixTable(this.result);

  @override
  State<StatefulWidget> createState() => _MatrixTableState();
}

/// Contains the state of a MatrixTable.
class _MatrixTableState extends State<MatrixTable> {
  String title;

  @override
  void initState() {
    super.initState();

    title = "${widget.result.test.info["name"]} - ${widget.result.id}";
  }

  @override
  Widget build(BuildContext context) {
    List fields = widget.result.info["fields"].values.toList();

    /// LazyDataTable allows rendering rows only when necessary.
    return LazyDataTable(
        rows: widget.result[fields[0]["label"]].length,
        columns: widget.result.info["fields"].length,
        tableTheme: LazyDataTableTheme(
            alternateCellBorder: Border(
              left: BorderSide(width: 0.5, color: Colors.black),
              right: BorderSide(width: 0.5, color: Colors.black),
              bottom: BorderSide(width: 0.5, color: Colors.black),
            ),
            cellBorder: Border(
              left: BorderSide(width: 0.5, color: Colors.black),
              right: BorderSide(width: 0.5, color: Colors.black),
              bottom: BorderSide(width: 0.5, color: Colors.black),
            ),
            columnHeaderBorder: Border(
              bottom: BorderSide(width: 2, color: Colors.black),
              left: BorderSide(width: 1, color: Colors.black),
              right: BorderSide(width: 1, color: Colors.black),
            ),
            columnHeaderColor: Theme.of(context).bottomAppBarColor,
            cellColor: Theme.of(context).dividerColor,
            alternateCellColor: Theme.of(context).bottomAppBarColor),
        tableDimensions: LazyDataTableDimensions(
          cellHeight: 40,
          cellWidth: max([
            MediaQuery.of(context).size.width /
                widget.result.info["fields"].length,
            100
          ]),
          topHeaderHeight: 50,
        ),
        topHeaderBuilder: (i) => Center(
            child: Text(
                "${fields[i]["label"]}${fields[i]["units"] == null ? "" : " (${fields[i]["units"]})"}",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        dataCellBuilder: (i, j) => Center(
            child: Text(widget.result[fields[j]["label"]][i].toString())));
  }
}
