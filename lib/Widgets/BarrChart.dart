import 'dart:math' show Point, Rectangle, pi;

import 'package:flutter/material.dart';
import 'package:quiver/iterables.dart' show Extent, extent;

/// Default color list for plotting series, from Matlab.
const List<Color> _PLOTCOLORS = const <Color>[
  Color.fromRGBO(0, 114, 189, 1),
  Color.fromRGBO(217, 83, 25, 1),
  Color.fromRGBO(237, 177, 32, 1),
  Color.fromRGBO(126, 47, 142, 1),
  Color.fromRGBO(119, 172, 48, 1),
  Color.fromRGBO(77, 190, 238, 1),
  Color.fromRGBO(162, 20, 47, 1),
];

/// Custom chart with required features.
class BarrChart extends StatefulWidget {
  final List<CustomLineChartSeries> series;
  final String title, xAxisLabel, yAxisLabel;
  final bool showLegend, doubleTapZoom, pinchToZoom, longPressSelect;
  final num doubleTapScale;

  const BarrChart(
      {@required this.series,
      this.title,
      this.xAxisLabel,
      this.yAxisLabel,
      this.showLegend = false,
      this.doubleTapZoom = true,
      this.pinchToZoom = true,
      this.longPressSelect = true,
      this.doubleTapScale = 1.25,
      Key key})
      : super(key: key);

  // Would like to allow for custom behaviors on gestures

  @override
  State<StatefulWidget> createState() => BarrChartState();
}

/// Holds the state for BarrChart.
class BarrChartState extends State<BarrChart> {
  GlobalKey _plotKey = GlobalKey();
  Point _transformStart;
  Rectangle _dataBounds, _plotView, _startView;
  _PlotEntity _zoomRectangle, _selectedPoint;

  @override
  void initState() {
    super.initState();

    Extent xExtent = extent(widget.series
        .expand((series) => series.data)
        .toList()
        .map((point) => point.x)
        .toList());
    Extent yExtent = extent(widget.series
        .expand((series) => series.data)
        .toList()
        .map((point) => point.y)
        .toList());
    _dataBounds = Rectangle.fromPoints(
        Point(xExtent.min, yExtent.min), Point(xExtent.max, yExtent.max));
    this.resetZoom();
    // print("${_dataBounds.left} - ${_dataBounds.right}");
    // print("${_dataBounds.bottom} - ${_dataBounds.top}");
  }

  /// Reset the plots zoom back to default.
  void resetZoom() {
    num xPad = _dataBounds.width * 0.005, yPad = _dataBounds.height * 0.005;
    _plotView = Rectangle.fromPoints(
        Point(_dataBounds.left - xPad, _dataBounds.top - yPad),
        Point(_dataBounds.right + xPad, _dataBounds.bottom + yPad));
    setState(() {});
  }

  /// Return the current visible bounds of the plot.
  Rectangle get bounds {
    return this._plotView;
  }

  /// Convert pixel coordinates [x] and [y] of [context] to plot percent.
  Point _pixelsToPercent(num x, num y, BuildContext context) {
    // The canvas coordinates start in the top left
    return Point(x / context.size.width, 1.0 - (y / context.size.height));
  }

  /// Convert view percent coordinates [x] and [y] to plot coordinate.
  Point _percentToPlot(num x, num y) {
    return Point(_plotView.width * x + _plotView.left,
        _plotView.height * y + _plotView.top);
  }

  /// Convert pixel coordinates [x] and [y] to plot coordinate.
  Point _pixelsToPlot(num x, num y) {
    return Point(
        _plotView.width * (x / _plotKey.currentContext.size.width) +
            _plotView.left,
        _plotView.height * (1.0 - (y / _plotKey.currentContext.size.height)) +
            _plotView.top);
  }

  /// Manages gesture actions of the plot, such as zooming and panning.
  void _doTransform(Point start, Point end,
      {num xScale = 1.0, num yScale = 1.0, bool longPress = false}) {
    if (start == null || _startView == null) {
      return;
    }
    if (longPress) {
      return;
    }
    Point focalPoint = Point(_startView.width * start.x + _startView.left,
        _startView.height * start.y + _startView.top);
    xScale = 1.0 / xScale;
    yScale = 1.0 / yScale;
    num newWidth = _startView.width * xScale;
    num newHeight = _startView.height * yScale;

    Rectangle tmp = Rectangle(focalPoint.x - newWidth * end.x,
        focalPoint.y - newHeight * end.y, newWidth, newHeight);
    if (tmp.left < _dataBounds.right &&
        tmp.right > _dataBounds.left &&
        _dataBounds.width > tmp.width * .01) {
      _plotView =
          Rectangle(tmp.left, _plotView.top, tmp.width, _plotView.height);
    }
    if (tmp.top < _dataBounds.bottom &&
        tmp.bottom > _dataBounds.top &&
        _dataBounds.height > tmp.height * .01) {
      _plotView =
          Rectangle(_plotView.left, tmp.top, _plotView.width, tmp.height);
    }
    setState(() {});
  }

  /// Generate the x axis labels and ticks.
  Widget _xAxis() {
    return Flexible(
      flex: 0,
      child: GestureDetector(
        onDoubleTapDown: (details) {
          if (widget.doubleTapZoom) {
            setState(() {
              _transformStart = _pixelsToPercent(details.localPosition.dx,
                  details.localPosition.dy, _plotKey.currentContext);
              _startView = _plotView;
            });
          }
        },
        onDoubleTap: () {
          if (widget.doubleTapZoom) {
            _doTransform(_transformStart, _transformStart,
                xScale: widget.doubleTapScale);
          }
        },
        onScaleStart: (details) {
          setState(() {
            // Convert to percent
            _transformStart = _pixelsToPercent(
                details.localFocalPoint.dx, 0, _plotKey.currentContext);
            _startView = _plotView;
          });
        },
        onScaleUpdate: (details) {
          // Convert to percent
          Point _transformEnd = _pixelsToPercent(
              details.localFocalPoint.dx, 0, _plotKey.currentContext);
          _doTransform(_transformStart, _transformEnd,
              xScale: widget.pinchToZoom ? details.horizontalScale : 1.0);
        },
        child: LayoutBuilder(
          builder: (_, constraints) => Container(
            width: constraints.widthConstraints().maxWidth,
            height: 45,
            margin: EdgeInsets.symmetric(horizontal: 1.0),
            // Compensate for plot border
            child: ClipRect(
              child: CustomPaint(
                  painter:
                      _XAxisPainter(this._plotKey, label: widget.xAxisLabel)),
            ),
          ),
        ),
      ),
    );
  }

  /// Generate the y axis label and ticks.
  Widget _yAxis() {
    return Flexible(
      flex: 0,
      child: GestureDetector(
        onDoubleTapDown: (details) {
          if (widget.doubleTapZoom) {
            setState(() {
              _transformStart = _pixelsToPercent(details.localPosition.dx,
                  details.localPosition.dy, _plotKey.currentContext);
              _startView = _plotView;
            });
          }
        },
        onDoubleTap: () {
          if (widget.doubleTapZoom) {
            _doTransform(_transformStart, _transformStart,
                yScale: widget.doubleTapScale);
          }
        },
        onScaleStart: (details) {
          setState(() {
            // Convert to percent
            _transformStart = _pixelsToPercent(
                0, details.localFocalPoint.dy, _plotKey.currentContext);
            _startView = _plotView;
          });
        },
        onScaleUpdate: (details) {
          // Convert to percent
          Point _transformEnd = _pixelsToPercent(
              0, details.localFocalPoint.dy, _plotKey.currentContext);
          _doTransform(_transformStart, _transformEnd,
              yScale: widget.pinchToZoom ? details.verticalScale : 1.0);
        },
        child: LayoutBuilder(
          builder: (_, constraints) => Container(
            width: 95,
            height: constraints.heightConstraints().maxHeight,
            margin: EdgeInsets.symmetric(vertical: 1.0),
            // Compensate for plot border
            child: ClipRect(
              child: CustomPaint(
                  painter:
                      _YAxisPainter(this._plotKey, label: widget.yAxisLabel)),
            ),
          ),
        ),
      ),
    );
  }

  /// Generate the legend for a horizontally oriented display.
  Widget _getHorizontalLegend() {
    if (!widget.showLegend ||
        MediaQuery.of(context).orientation == Orientation.portrait) {
      return Container();
    }
    return Row(
      children: [
        SizedBox(
          width: 4,
        ),
        Wrap(
          spacing: 5.0,
          runSpacing: 12.0,
          alignment: WrapAlignment.center,
          direction: Axis.vertical,
          children: widget.series
              .asMap()
              .entries
              .map((entry) => Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "\u2014",
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: entry.value.color ??
                              _PLOTCOLORS[entry.key % _PLOTCOLORS.length],
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        entry.value.name ?? "Series ${entry.key + 1}",
                        style: TextStyle(fontSize: 14),
                      )
                    ],
                  ))
              .toList(),
        )
      ],
    );
  }

  /// Generate the legend for a vertically oriented display.
  Widget _getVerticalLegend() {
    if (!widget.showLegend ||
        MediaQuery.of(context).orientation == Orientation.landscape) {
      return Container();
    }
    return Column(
      children: [
        SizedBox(
          height: 2,
        ),
        Wrap(
            spacing: 12.0,
            runSpacing: 5.0,
            alignment: WrapAlignment.center,
            direction: Axis.horizontal,
            children: widget.series
                .asMap()
                .entries
                .map((entry) => Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "\u2014",
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: entry.value.color ??
                                _PLOTCOLORS[entry.key % _PLOTCOLORS.length],
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          entry.value.name ?? "Series ${entry.key + 1}",
                          style: TextStyle(fontSize: 14),
                        )
                      ],
                    ))
                .toList())
      ],
    );
  }


  /// Generate the plot.
  Widget _generatePlot() {
    return Expanded(
      child: GestureDetector(
        // onTapUp: (details) {
        //   print(
        //       "Local position: ${details.localPosition.dx}, ${details.localPosition.dy}");
        //   // // Point _plotPoint =
        //   print(
        //       "Size: ${_plotKey.currentContext.size.width}, ${_plotKey.currentContext.size.height}");
        //   print(
        //       "Rectangle: ${_plotView.left}, ${_plotView.top}, ${_plotView.right}, ${_plotView.bottom}");
        //   Point _tmp = _pixelsToPercent(details.localPosition.dx,
        //       details.localPosition.dy, _plotKey.currentContext);
        //   Point focalPoint = _pixelsToPlot(
        //       details.localPosition.dx, details.localPosition.dy);
        //   print("Point x: ${_tmp.x * 100}%");
        //   print("Point y: ${_tmp.y * 100}%");
        //   print("Point x: ${focalPoint.x}");
        //   print("Point y: ${focalPoint.y}");
        // },
        onLongPressStart: (details) {
          if (widget.longPressSelect) {
            setState(() {
              _transformStart = _pixelsToPlot(
                  details.localPosition.dx, details.localPosition.dy);
            });
          }
        },
        onLongPressMoveUpdate: (details) {
          if (widget.longPressSelect) {
            setState(() {
              _zoomRectangle = _PlotEntity(
                  Rectangle.fromPoints(
                      _transformStart,
                      _pixelsToPlot(
                          details.localPosition.dx, details.localPosition.dy)),
                  color: Color.fromRGBO(255, 0, 0, 0.25),
                  style: PaintingStyle.fill);
            });
          }
        },
        onLongPressEnd: (details) {
          if (widget.longPressSelect) {
            setState(() {
              _plotView = Rectangle.fromPoints(
                  _transformStart,
                  _pixelsToPlot(
                      details.localPosition.dx, details.localPosition.dy));
              _zoomRectangle = null;
            });
          }
        },
        onDoubleTapDown: (details) {
          if (widget.doubleTapZoom) {
            setState(() {
              _transformStart = _pixelsToPercent(details.localPosition.dx,
                  details.localPosition.dy, _plotKey.currentContext);
              _startView = _plotView;
            });
          }
        },
        onDoubleTap: () {
          if (widget.doubleTapZoom) {
            _doTransform(_transformStart, _transformStart,
                xScale: widget.doubleTapScale, yScale: widget.doubleTapScale);
          }
        },
        onScaleStart: (details) {
          setState(() {
            // Convert to percent
            _transformStart = _pixelsToPercent(details.localFocalPoint.dx,
                details.localFocalPoint.dy, _plotKey.currentContext);
            // print("Starting focal point: ${_transformStart.toString()}");
            _startView = _plotView;
          });
        },
        onScaleUpdate: (details) {
          // Convert to percent
          Point _transformEnd = _pixelsToPercent(details.localFocalPoint.dx,
              details.localFocalPoint.dy, _plotKey.currentContext);
          _doTransform(_transformStart, _transformEnd,
              xScale: widget.pinchToZoom ? details.horizontalScale : 1.0,
              yScale: widget.pinchToZoom ? details.verticalScale : 1.0);
        },
        // onScaleEnd: (details) {
        //   // print("Scale end");
        //   // setState(() {
        //   //   _transformStart = null;
        //   //   _startView = null;
        //   // });
        // },
        child: LayoutBuilder(
          builder: (_, constraints) => Container(
            // color: Colors.white,
            width: constraints.widthConstraints().maxWidth,
            height: constraints.heightConstraints().maxHeight,
            decoration: BoxDecoration(
                border: Border(
              left: BorderSide(width: 1.0, color: Colors.black26),
              bottom: BorderSide(width: 1.0, color: Colors.black26),
              top: BorderSide(width: 1.0, color: Colors.black26),
              right: BorderSide(width: 1.0, color: Colors.black26),
            )),
            child: ClipRect(
              child: CustomPaint(
                  key: _plotKey,
                  painter: _ChartPainter(
                      series: widget.series,
                      entities: [this._selectedPoint, this._zoomRectangle],
                      bounds: this._plotView)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Custom plot solution
    return Container(
        color: Colors.white,
        margin: EdgeInsets.all(14.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      child: Text(widget.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headline6
                              .copyWith(color: Colors.black)),
                      fit: BoxFit.contain,
                    ),
                    Expanded(
                        child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        this._yAxis(),
                        this._generatePlot(),
                      ],
                    )),
                    this._xAxis(),
                    this._getVerticalLegend()
                  ]),
            ),
            this._getHorizontalLegend()
          ],
        ));
  }
}

/// Base class for a item displayed in a plot.
class _PlotEntity {
  final dynamic data;
  final Color color;
  final num strokeWidth;
  PaintingStyle _style;
  Type _shape;

  _PlotEntity(this.data,
      {this.color = Colors.indigo,
      this.strokeWidth = 1.5,
      PaintingStyle style}) {
    if (this.data is Point) {
      this._shape = Point;
      style = style ?? PaintingStyle.fill;
    } else if (this.data is Rectangle) {
      this._shape = Rectangle;
    } else if (this.data is List<Point>) {
      this._shape = Path;
    }
    this._style = style ?? PaintingStyle.stroke;
  }

  Type get shape {
    return this._shape;
  }

  PaintingStyle get style {
    return this._style;
  }
}

class CustomLineChartSeries extends _PlotEntity {
  final String name;

  CustomLineChartSeries(
      {@required List<Point> data,
      this.name,
      Color color,
      num strokeWidth = 1.5,
      PaintingStyle style = PaintingStyle.stroke})
      : super(data, color: color, strokeWidth: strokeWidth, style: style);
}

/// A custom painter to draw a BarrChart.
class _ChartPainter extends CustomPainter {
  final List<CustomLineChartSeries> series;
  final List<_PlotEntity> entities;
  final Rectangle bounds;

  _ChartPainter(
      {@required this.series, @required this.entities, @required this.bounds});

  /// Generate and return the x axis ticks for the visible plot.
  List<num> xTicks(Size size) {
    int xSpaces = (size.width / 125).round() + 1;
    num xSpacing = this.bounds.width / xSpaces;
    return [
      for (num i = this.bounds.right - (xSpacing / 2);
          i > this.bounds.left;
          i -= xSpacing)
        i
    ];
  }

  /// Generate and return the y axis ticks for the visible plot.
  List<num> yTicks(Size size) {
    int ySpaces = (size.height / 50).round() + 1;
    num ySpacing = this.bounds.height / ySpaces;

    return [
      for (double i = (this.bounds.bottom - (ySpacing / 2));
          i > this.bounds.top;
          i -= ySpacing)
        i
    ];
  }

  /// Convert plot coordinates [coordinate] to pixel coordinates using the
  /// visible [size].
  Point plotToPixels(Point coordinate, Size size) {
    return Point(this.getXCoordinate(coordinate.x, size),
        this.getYCoordinate(coordinate.y, size));
  }

  /// Convert plot coordinate [x] to display coordinate using the visible
  /// [size].
  num getXCoordinate(num x, Size size) {
    return size.width -
        ((this.bounds.right - x) / this.bounds.width * size.width);
  }

  /// Convert plot coordinate [y] to display coordinate using the visible
  /// [size].
  num getYCoordinate(num y, Size size) {
    return (this.bounds.bottom - y) / this.bounds.height * size.height;
  }

  /// Draw a line on the plot provided list of Points [data].
  void _paintLine(Canvas canvas, Size size, List<Point> data,
      {Color color, num strokeWidth, PaintingStyle style}) {
    if (data.length == 0) return;
    final paint = Paint()
      ..style = style ?? PaintingStyle.stroke
      ..strokeWidth = strokeWidth ?? 1.5
      ..color = color ?? Colors.indigo;

    final _line = Path();
    _line.moveTo(this.getXCoordinate(data[0].x, size),
        this.getYCoordinate(data[0].y, size));
    for (var i = 1; i < data.length; i++) {
      _line.lineTo(this.getXCoordinate(data[i].x, size),
          this.getYCoordinate(data[i].y, size));
    }
    canvas.drawPath(_line, paint);
  }

  /// Draw a rectangle on the plot provided a Rectangle [rectangle].
  void _paintRectangle(Canvas canvas, Size size, Rectangle rectangle,
      {Color color, num strokeWidth, PaintingStyle style}) {
    final paint = Paint()
      ..style = style ?? PaintingStyle.stroke
      ..strokeWidth = strokeWidth ?? 1.5
      ..color = color ?? Colors.indigo;
    canvas.drawRect(
        Rect.fromLTRB(
            this.getXCoordinate(rectangle.left, size),
            this.getYCoordinate(rectangle.top, size),
            this.getXCoordinate(rectangle.right, size),
            this.getYCoordinate(rectangle.bottom, size)),
        paint);
  }

  /// Draw a point on the plot provided a Point [point].
  void _paintPoint(Canvas canvas, Size size, Point point,
      {Color color, num strokeWidth, PaintingStyle style}) {
    final paint = Paint()
      ..style = style ?? PaintingStyle.fill
      ..strokeWidth = strokeWidth ?? 1.5
      ..color = color ?? Colors.indigo;
    canvas.drawCircle(
        Offset(this.getXCoordinate(point.x, size),
            this.getYCoordinate(point.y, size)),
        5.0,
        paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.black12;
    this.xTicks(size).forEach((x) {
      num _x = this.getXCoordinate(x, size);
      canvas.drawLine(Offset(_x, 0.0), Offset(_x, size.height), paint);
    });
    this.yTicks(size).forEach((y) {
      num _y = this.getYCoordinate(y, size);
      canvas.drawLine(Offset(0, _y), Offset(size.width, _y), paint);
    });

    this.series.asMap().forEach((index, series) {
      this._paintLine(canvas, size, series.data,
          color: series.color ?? _PLOTCOLORS[index % _PLOTCOLORS.length],
          strokeWidth: series.strokeWidth,
          style: series.style);
    });

    this.entities.forEach((entity) {
      if (entity == null) {
        return;
      } else if (entity.data is Rectangle) {
        this._paintRectangle(canvas, size, entity.data,
            color: entity.color,
            strokeWidth: entity.strokeWidth,
            style: entity.style);
      } else if (entity.data is Point) {
        this._paintPoint(canvas, size, entity.data,
            color: entity.color,
            strokeWidth: entity.strokeWidth,
            style: entity.style);
      } else if (entity.data is List<Point>) {
        this._paintLine(canvas, size, entity.data,
            color: entity.color,
            strokeWidth: entity.strokeWidth,
            style: entity.style);
      }
    });
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}

/// A custom painter specifically for drawing the y axis.
class _YAxisPainter extends CustomPainter {
  final GlobalKey _plotKey;
  final String label;

  _YAxisPainter(this._plotKey, {this.label});

  void _drawLabel(Canvas canvas, Size size) {
    canvas.save();
    canvas.rotate(-90 * pi / 180);
    final textStyle = TextStyle(
      color: Colors.black,
      fontSize: 18,
    );
    final textSpan = TextSpan(
      text: this.label,
      style: textStyle,
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(
      minWidth: 0,
      maxWidth: size.height,
    );
    textPainter.paint(
        canvas, Offset(-(size.height / 2) - textPainter.width / 2, 0));
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    // canvas.translate(90.0, 90.0);
    this._drawLabel(canvas, size);

    final paint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;

    _ChartPainter plot =
        (this._plotKey.currentWidget as CustomPaint).painter as _ChartPainter;

    plot.yTicks(_plotKey.currentContext.size).forEach((i) {
      num cy = plot.getYCoordinate(i, size);
      canvas.drawLine(
          Offset(size.width - 0, cy), Offset(size.width - 5, cy), paint);
      final textStyle = TextStyle(
        color: Colors.black,
        fontSize: 14,
      );
      final textSpan = TextSpan(
        text: i.toString(),
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );
      textPainter.layout(
        minWidth: 0,
        maxWidth: 60,
      );

      final offset = Offset(
          size.width - 5 - textPainter.width, cy - (textPainter.height / 2));
      textPainter.paint(canvas, offset);
    });
  }

  @override
  bool shouldRepaint(_YAxisPainter old) => true;
}

/// A custom painter specifically for drawing the x axis.
class _XAxisPainter extends CustomPainter {
  final GlobalKey _plotKey;
  final String label;

  _XAxisPainter(this._plotKey, {this.label});

  void _drawLabel(Canvas canvas, Size size) {
    num wDiff = size.width - this._plotKey.currentContext.size.width;
    final textStyle = TextStyle(
      color: Colors.black,
      fontSize: 18,
    );
    final textSpan = TextSpan(
      text: this.label,
      style: textStyle,
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(
      minWidth: 0,
      maxWidth: this._plotKey.currentContext.size.width,
    );
    final xCenter =
        (this._plotKey.currentContext.size.width - textPainter.width) / 2 +
            wDiff;
    final yCenter = size.height - textPainter.height;
    final offset = Offset(xCenter, yCenter);
    textPainter.paint(canvas, offset);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;

    _ChartPainter plot =
        (this._plotKey.currentWidget as CustomPaint).painter as _ChartPainter;
    num wDiff = size.width - this._plotKey.currentContext.size.width;

    plot.xTicks(_plotKey.currentContext.size).forEach((i) {
      num cx = plot.getXCoordinate(i, this._plotKey.currentContext.size);
      canvas.drawLine(Offset(cx + wDiff, 0), Offset(cx + wDiff, 5), paint);
      final textStyle = TextStyle(
        color: Colors.black,
        fontSize: 14,
      );
      final textSpan = TextSpan(
        text: i.toString(),
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );
      textPainter.layout(minWidth: 0, maxWidth: 60);
      // final xCenter = (this.plot.currentContext.size.width - textPainter.width) / 2;
      // final yCenter = size.height - textPainter.height;
      final offset = Offset(cx + wDiff - (textPainter.width / 2), 5);
      textPainter.paint(canvas, offset);
    });

    this._drawLabel(canvas, size);
  }

  @override
  bool shouldRepaint(_XAxisPainter old) => true;
}
