
import 'dart:async';
import 'dart:core';
import 'dart:typed_data';
import 'dart:typed_data' as prefix0;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';


import 'package:flutter/services.dart';
import 'package:leosplugin/leosplugin.dart';
import 'package:image/image.dart' as img;



const String _IMAGE_PATH = 'assets/google.png';
const String _IMAGE_PATH2 = 'assets/2.png';
const int _IMAGE_SIZE = 256;



void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {


  String _mdlStats = 'load model first';
  Uint8List _prediction, _beforePred;

  @override
  void initState() {
    super.initState();
  }

  ///lädt das model
  Future<void> loadModel() async {
    String mdlStats;
    mdlStats = await Leosplugin.loadModel(
      model: "assets/neu3.tflite",
      name: "model"
    );

    setState(() {
      _mdlStats = mdlStats;
    });
  }

  ///Über diese Methode wird das übergebene Bild predicted
  Future<void> run() async {
    var bytes_source_pic = (await rootBundle.load(_IMAGE_PATH)).buffer;
    img.Image source_pic = img.decodePng(bytes_source_pic.asUint8List());
    img.Image resizedImage = img.copyResize(source_pic, width: _IMAGE_SIZE, height: _IMAGE_SIZE);

    Float64List input = imageToFloatList(resizedImage, _IMAGE_SIZE);
    Uint8List beforePred = imageToByteListWithAlpha(resizedImage, _IMAGE_SIZE, 255);


    Uint8List result;
      result = Uint8List.fromList( await Leosplugin.run(name: "model", floats: input));

    Uint8List image = addAlphaToImage(result, 255);

    setState(() {
      _beforePred = beforePred;
      _prediction = image;
    });
  }



  ///Gibt eine Float-Liste der Farbwerte(/255) zurück.
  ///[x,y,Farbe]
  ///[0,0,r],[0,0,g],[0,0,b],[1,0,r],....
  ///
  Float64List imageToFloatList(img.Image image, int inputSize) {
    Float64List res = new Float64List(inputSize * inputSize * 3);
    var buffer = Float64List.view(res.buffer);
    int idx = buffer.offsetInBytes;
    for(int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        var pixel = image.getPixel(x, y);
        buffer[idx++] =  img.getRed(pixel) / 255;
        buffer[idx++] =  img.getGreen(pixel) / 255;
        buffer[idx++] =  img.getBlue(pixel) / 255;
      }
    }
    return res;
  }

  Uint8List imageToByteListWithAlpha(img.Image image, int inputSize, alpha) {
  Uint8List res = new Uint8List(inputSize * inputSize * 4);
  var buffer = Uint8List.view(res.buffer);
  int idx = buffer.offsetInBytes;
  for(int y = 0; y < inputSize; y++) {
    for (int x = 0; x < inputSize; x++) {
      var pixel = image.getPixel(x, y);
      buffer[idx++] = img.getRed(pixel);
      buffer[idx++] = img.getGreen(pixel);
      buffer[idx++] = img.getBlue(pixel);
      buffer[idx++] = alpha;
    }
  }
  return res;
  }


  ///Macht aus einer Uint8Liste ohne Alpha-Werte, eine List mit Alpha-Werte.
  Uint8List addAlphaToImage(Uint8List noalpha, int alpha) {
    Uint8List result = new Uint8List(_IMAGE_SIZE * _IMAGE_SIZE * 4);
    int idx = 0;
    for (int i = 0; i < noalpha.length; i += 3) {
      result[idx++] = noalpha[i];
      result[idx++] = noalpha[i + 1];
      result[idx++] = noalpha[i + 2];
      result[idx++] = alpha;
    }

    return result;
  }

  Future<ui.Image> makeImage(Uint8List pred) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pred,
      _IMAGE_SIZE,
      _IMAGE_SIZE,
      ui.PixelFormat.rgba8888,
      c.complete,
    );
    return c.future;
  }


  Future<img.Image> predict(img.Image im1, img.Image im2) async {
    if (im2 == null) {
      return im1;
    }
    List<int> x = new List<int>();

    x.addAll(im1.getBytes(format: img.Format.rgb));
    x.addAll(im2.getBytes(format: img.Format.rgb));
    var bytes = Uint8List.fromList(x);
    Float64List floats = Float64List.fromList(bytes.map((x) => x/1).toList());
    print(floats.length);
    print(floats);
    Uint8List output = Uint8List.fromList(await Leosplugin.run(name: "model", floats: floats));
    img.Image result = img.Image.fromBytes(im1.width, im1.height, output,
        format: img.Format.rgb);

    setState(() {
      _beforePred = im1.getBytes();
      _prediction = result.getBytes();
    });
    return result;
  }






  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            children: <Widget> [
              Text('Model loaded: $_mdlStats\n'),
              _prediction == null ?
              new Text("Kein Bild") :
              new FutureBuilder<ui.Image>(
                future: makeImage(_beforePred),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return RawImage(
                      image: snapshot.data,
                    );
                  } else {
                    return Center(child: CircularProgressIndicator());
                  }
                },
              ),
              _prediction == null ?
              new Text("Kein Bild") :
              new FutureBuilder<ui.Image>(
                future: makeImage(_prediction),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return RawImage(
                      image: snapshot.data,
                    );
                  } else {
                    return Center(child: CircularProgressIndicator());
                  }
                },
              ),
            ]
          ),
        ),
          bottomSheet: BottomAppBar(
            color: Color.fromARGB(255, 40, 40, 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                FlatButton(
                  child: Text("Load", style: TextStyle(color: Colors.amber)),
                  onPressed: () {loadModel();},
                ),
                FlatButton(
                  child: Text("Predict", style: TextStyle(color: Colors.amber)),
                  onPressed: () async {
                    var bytes_source_pic = (await rootBundle.load(_IMAGE_PATH)).buffer;
                    var bytes_makeup_pic = (await rootBundle.load(_IMAGE_PATH2)).buffer;
                    img.Image source_pic = img.decodePng(bytes_source_pic.asUint8List());
                    img.Image makeup_pic = img.decodePng(bytes_makeup_pic.asUint8List());


                    img.Image resizedImage = img.copyResize(source_pic, width: _IMAGE_SIZE, height: _IMAGE_SIZE);
                    img.Image resizedImage2 = img.copyResize(makeup_pic, width: _IMAGE_SIZE, height: _IMAGE_SIZE);
                    predict(resizedImage, resizedImage2);},
                )
              ],
            ),
          )
      ),
    );
  }
}
/*
Old Methods

  ///Macht aus einem Image eine Uint8List, die verarbeitet werden kann
  Uint8List imageToByteList(img.Image image, int inputSize) {

    Uint8List res = new Uint8List(inputSize * inputSize * 3);
    var buffer = Uint8List.view(res.buffer);
    int idx = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        var pixel = image.getPixel(x, y);
        buffer[idx++] = img.getRed(pixel);
        buffer[idx++] = img.getGreen(pixel);
        buffer[idx++] = img.getBlue(pixel);
      }
    }

    return res;
  }

 */
