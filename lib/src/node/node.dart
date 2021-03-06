import "dart:ui";
import "dart:math";
import 'package:flutter/material.dart';

import "../core/context.dart";
import "../utils/util.dart";
import '../event/event.dart';
import '../math/point.dart';
import '../math/matrix.dart';
import '../math/mathutil.dart';

class ZKNode {
  String id;
  String type = "ZKNode";

  Point anchor;
  Point position;
  Point scale;
  Point skew;

  double oriWidth = 0;
  double oriHeight = 0;

  bool visible = true;
  bool interactive = true;
  double rotation = 0;

  ZKNode parent;
  Canvas canvas;
  Paint paint;

  ZKContext context;
  dynamic expansion;
  double worldAlpha = 1;

  Matrix matrix;
  double _alpha = 1;
  bool _debug = false;
  Color _color;

  ZKNode() {
    this.id = Util.uuid();
    this.position = new Point(0.0, 0.0);
    this.anchor = new Point(0.5, 0.5);
    this.scale = new Point(1.0, 1.0);
    this.skew = new Point(0.0, 0.0);
    this.matrix = new Matrix();

    this.init();
  }

  void init() {
    this.createPaint();
  }

  void createPaint() {
    this.paint = new Paint();
    this.paint.color = Colors.blue;
    this.paint.style = PaintingStyle.fill;
  }

  ////////////////////////////////////////////////////////////
  ///
  /// Setter and Getter methods
  ///
  ////////////////////////////////////////////////////////////
  double get width {
    return this.scale.x * this.oriWidth;
  }

  set width(double w) {
    this.scale.x = w / this.oriWidth;
  }

  double get height {
    return this.scale.y * this.oriHeight;
  }

  set height(double h) {
    this.scale.y = h / this.oriHeight;
  }

  Color get color {
    return _color;
  }

  set color(Color c) {
    _color = c;
    if (this.paint != null) this.paint.color = c;
  }

  double get alpha {
    return this._alpha;
  }

  set alpha(double a) {
    if (a < 0) return;
    _alpha = max(0, min(a, 1));
    if (this.parent != null && this.parent.type != "ZKStage") {
      worldAlpha = this.parent.worldAlpha * this.alpha;
    } else {
      worldAlpha = this.alpha;
    }

    this._setPaintAlpha(worldAlpha);
  }

  bool get debug {
    return this._debug;
  }

  set debug(bool d) {
    this._debug = d;
    if (d && this.type == "ZKNode") {
      this.oriWidth = 20.0;
      this.oriHeight = 20.0;
    }
  }

  double get regX {
    return oriWidth * anchor.x;
  }

  double get regY {
    return oriHeight * anchor.y;
  }

  Offset get center {
    return Offset(regX, regY);
  }

  ////////////////////////////////////////////////////////////
  ///
  /// Update, render and other related functions
  ///
  ////////////////////////////////////////////////////////////
  void update(int time) {
    if (this.visible == false) return;
    this.updateTransform(position.x, position.y, scale.x, scale.y, rotation,
        skew.x, skew.y, regX, regY);
  }

  void updateTransform(double x, double y, double scaleX, double scaleY,
      double rotation, double skewX, double skewY, double regX, double regY) {
    this.matrix.identity();
    if (this.parent != null && this.parent.type != "ZKStage") {
      this.matrix.appendMatrix(this.parent.matrix);
    }

    this.matrix.appendTransform(
        x, y, scaleX, scaleY, rotation, skewX, skewY, regX, regY);
  }

  void draw(Canvas canvas, [Size size]) {
    if (this.debug)
      canvas.drawRect(Rect.fromLTRB(0, 0, oriWidth, oriHeight), this.paint);
  }

  void transform(Canvas canvas) {
    canvas.transform(this.matrix.toMatrix4());
  }

  void render(Canvas canvas) {
    if (this.visible == false || this.alpha == 0) return;

    this.canvas = canvas;
    canvas.save();
    this.transform(canvas);
    this.draw(canvas);
    canvas.restore();
  }

  ////////////////////////////////////////////////////////////
  ///
  /// Convenient operation method
  ///
  ////////////////////////////////////////////////////////////
  void setPosition(double x, double y) {
    this.position.x = x;
    this.position.y = y;
  }

  void setScale(double s) {
    this.scale.x = this.scale.y = s;
  }

  void remove() {
    if (this.parent != null) {
      (this.parent as IContainer).removeChild(this);
    }
  }

  void _setPaintAlpha(double a) {
    if (this.paint.color != null) {
      this.paint.color = this.paint.color.withOpacity(a);
    } else {
      this.paint.color = Colors.white.withOpacity(a);
    }
  }

  void dispose() {
    this.position.reset();
    this.anchor.reset();
    this.scale.reset();
    this.skew.reset();

    this.visible = false;
    this.canvas = null;
    //this.paint = null;
    this.parent = null;
    this.expansion = null;
    this.context = null;

    this.onTapDown = null;
    this.onTapUp = null;
    this.onTouchMove = null;
  }

  ////////////////////////////////////////////////////////////
  ///
  /// Interaction-related functions
  ///
  ////////////////////////////////////////////////////////////
  Function(ZKEvent event) onTapDown;
  Function(ZKEvent event) onTapUp;
  Function(ZKEvent event) onTouchMove;

  bool get canInteractive {
    return this.interactive == true && this.alpha != 0 && this.visible == true;
  }

  ZKNode hitTest(touchX, touchY) {
    if (this.canInteractive == false) return null;

    var a00 = matrix.a,
        a01 = matrix.c,
        a02 = matrix.tx,
        a10 = matrix.b,
        a11 = matrix.d,
        a12 = matrix.ty,
        id = 1 / (a00 * a11 + a01 * -a10);

    var x =
        a11 * id * touchX + -a01 * id * touchY + (a12 * a01 - a02 * a11) * id;
    var y =
        a00 * id * touchY + -a10 * id * touchX + (-a12 * a00 + a02 * a10) * id;

    if (MathUtil.inA2B(x, 0, oriWidth) && MathUtil.inA2B(y, 0, oriHeight)) {
      return this;
    }

    return null;
  }

  ////////////////////////////////////////////////////////////
  ///
  /// Other functions
  ///
  ////////////////////////////////////////////////////////////
  Map<String, double> toMap() {
    return {
      "x": this.position.x,
      "y": this.position.y,
      "scaleX": this.scale.x,
      "scaleY": this.scale.y,
      "rotation": this.rotation,
      "alpha": this.alpha
    };
  }

  String toString() {
    return '[ type:$type id:$id ]';
  }
}

abstract class IContainer {
  void removeChild(ZKNode child) {}
}
