import 'dart:async';

import 'dart:typed_data';
import 'dart:ui' show Color;
import 'package:meta/meta.dart';

import 'package:flutter/services.dart';

class Leosplugin {
  static const MethodChannel _channel = const MethodChannel('leosplugin');

  static Future<String> loadModel({
    @required name,
    @required String model,
    String labels = "",
    int numThreads = 4,
  }) async {
    return await _channel.invokeMethod(
      'loadModel',
      {
        "name": name,
        "model": model,
        "labels": labels,
        "numThreads": numThreads
      },
    );
  }

  ///Als Output gibt es das Bild nach der Prediction
  static Future<Uint8List> run({
    @required String name,
    @required Float64List floats,
  }) async {
    final Uint8List y =
        await _channel.invokeMethod('run', {"name": name, "floats": floats});
    return y;
  }

  ///Gibt den Shape eines geladenen Models zurück.
  static Future<Int32List> shape({
    @required String name,
  }) async {
    final Int32List shape =
        await _channel.invokeMethod('shape', {"name": name});
    return shape;
  }

  ///Schließt alle Interpreter.
  static Future<String> dispose() async {
    final String result =
        await _channel.invokeMethod('dispose');
    return result;
  }
}
