import 'package:flutter/cupertino.dart';

import 'package:acestat/Analysis/TestDefinitions.dart';

/// Holds the state of the TestHistory form when the current activity changes.
class TestHistoryState with ChangeNotifier {
  bool _sortDateAsc = false,
      _sortFilterExpand = false,
      _sortExpand = false,
      _filterExpand = false;
  DateTime _filterStart, _filterEnd;
  Map<String, bool> _enabledTests;

  TestHistoryState() {
    this._enabledTests = Map.fromEntries(TestDefinitions()
        .tests
        .values
        .toList(growable: false)
        .map((e) => MapEntry(e["id"], true)));
  }

  /// Return whether the date is sorted by ascending or not.
  bool get dateSort => this._sortDateAsc;

  /// Set whether the date is sorted by ascending or not to [sort].
  set dateSort(bool sort) => this._sortDateAsc = sort;

  /// Return whether the sort/filter pane is expanded or not.
  bool get expandSortFilter => this._sortFilterExpand;

  /// Set whether the sort/filter pane is expanded or not to [expand].
  set expandSortFilter(bool expand) => this._sortFilterExpand = expand;

  /// Return whether the sort pane is expanded or not.
  bool get expandSort => this._sortExpand;

  /// Set whether the sort pane is expanded or not to [expand].
  set expandSort(bool expand) => this._sortExpand = expand;

  /// Return whether the filter pane is expaneded or not.
  bool get expandFilter => this._filterExpand;

  /// Set whether the filter pane is expanded or not to [expand].
  set expandFilter(bool expand) => this._filterExpand = expand;

  /// Get the filter start time.
  DateTime get filterStart => this._filterStart;

  /// Get the filter end time.
  DateTime get filterEnd => this._filterEnd;

  /// Set the filter start time to [start].
  set filterStart(DateTime start) => this._filterStart = start;

  /// Set the filter end time to [end].
  set filterEnd(DateTime end) => this._filterEnd = end;

  /// Return a Map of test types and whether they will be included in the search
  /// results or not.
  Map<String, bool> get enabledTests => this._enabledTests;

  /// Set a Map of test types and whether they should be included in the search
  /// results or not.
  set enabledTests(Map<String, bool> tests) => this._enabledTests = tests;
}
