import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:quiver/iterables.dart' show zip;

import 'package:acestat/Analysis/CrabTest.dart';
import 'package:acestat/Widgets/BarrChart.dart';
import 'package:acestat/Resources/Styles.dart';

/// Widget specifically for displaying a chart.
class Chart extends StatelessWidget {
  final String plot;
  final CrabTest test;
  final GlobalKey<BarrChartState> _chartKey = GlobalKey<BarrChartState>();

  Chart({this.plot, this.test});

  /// Return a plot or message if a plot cannot be generated.
  Widget _getPlot() {
    try {
      return BarrChart(
          title: "${this.test.info["name"]} - ${this.plot}",
          xAxisLabel: this.test.info["plots"][this.plot].xlabel,
          yAxisLabel: this.test.info["plots"][this.plot].ylabel,
          series: _getSeriesList(),
          key: this._chartKey);
    } catch (e) {
      return Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("Plot not available",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              )),
          Text("Reason: ${e.message}",
              style: TextStyle(
                fontSize: 18,
              ))
        ],
      ));
    }
  }

  /// Returns a list of generated line chart series.
  List<CustomLineChartSeries> _getSeriesList() {
    var info = this.test.info["plots"][this.plot];
    return info.series.asMap().entries.map<CustomLineChartSeries>((entry) {
      var series = entry.value;
      return CustomLineChartSeries(
          data: zip([
        List<num>.from(this.test.results[series.x.output][series.x.field]),
        List<num>.from(this.test.results[series.y.output][series.y.field])
      ]).toList().map<Point>((v) {
        if (v.first.isInfinite || v.last.isInfinite) {
          throw Exception("infinite values");
        } else if (v.first.isNaN || v.last.isNaN) {
          throw Exception("NaN values");
        }
        return Point(v.first, v.last);
      }).toList());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: usaceText),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(this.plot),
          actions: <Widget>[
            Row(
              children: [
                TextButton(
                    child: Text("Reset", style: TextStyle(color: usaceText)),
                    onPressed: () {
                      this._chartKey.currentState.resetZoom();
                    }),
              ],
            )
          ],
        ),
        body: this._getPlot());
  }
}
