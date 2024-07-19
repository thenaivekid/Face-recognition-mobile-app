import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomePage({Key? key, required this.cameras}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isWorking = false;
  String result = "Ready";
  CameraController? cameraController;
  CameraDescription? currentCamera;
  late Database database;
  CameraImage? imgCamera;
  // late var interpreter;
  @override
  void initState() {
    super.initState();
    initializeDatabase();
    loadModel();
    initCamera();
  }

  Future<void> initializeDatabase() async {
    database = await openDatabase(
      join(await getDatabasesPath(), 'face_recognition.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE persons(id INTEGER PRIMARY KEY, name TEXT, embedding BLOB)',
        );
      },
      version: 1,
    );
  }

  Future<void> loadModel() async {
    try {
      final interpreter = await Interpreter.fromAsset('assets/facenet.tflite');

      print("Siamese model loaded successfully");
    } catch (e) {
      print("Failed to load model: $e");
    }
  }

  void initCamera() {
    if (widget.cameras.isEmpty) {
      print("No camera found");
      return;
    }

    currentCamera = widget.cameras.first;
    cameraController =
        CameraController(currentCamera!, ResolutionPreset.medium);
    cameraController!.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            print('User denied camera access.');
            break;
          default:
            print('Handle other errors.');
            break;
        }
      }
    });
  }

  void flipCamera() {
    if (widget.cameras.length < 2) {
      print("Only one camera available");
      return;
    }

    setState(() {
      currentCamera = (currentCamera == widget.cameras.first)
          ? widget.cameras[1]
          : widget.cameras.first;
    });
    print("switched to cam $currentCamera");

    cameraController?.dispose();
    initCamera();
  }

  Future<void> promptNewPerson(BuildContext context) async {
    final name = await _showNameInputDialog(context);

    if (name != null && name.isNotEmpty) {
      captureImage(); // Capture image and add the new person
    }
  }

  Future<void> addNewPerson(String name) async {
    if (imgCamera == null) return;

    try {
      final embedding = await computeEmbedding(imgCamera!);
      await _savePersonToDB(embedding, name);
      setState(() {
        result = "Added new person: $name";
      });
      print("Added new person: $name");
    } catch (e) {
      print("Error adding new person: $e");
      setState(() {
        result = "Error adding new person";
      });
    }
  }

  Future<String?> _showNameInputDialog(BuildContext context) async {
    String? name;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("New Person"),
          content: TextField(
            onChanged: (value) {
              name = value;
            },
            decoration: InputDecoration(hintText: "Enter name"),
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Save"),
              onPressed: () {
                Navigator.of(context).pop(name);
              },
            ),
          ],
        );
      },
    );
    return name;
  }

  Future<void> _savePersonToDB(Float32List embedding, String name) async {
    await database.insert(
      'persons',
      {
        'name': name,
        'embedding': embedding.buffer.asUint8List(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Float32List> computeEmbedding(CameraImage image) async {
    print("image format $image.Format.group");
    return Float32List.fromList([2, 3, 3]);
    // final inputBytes = Float32List(1 * 128 * 128 * 3);
    // int pixelIndex = 0;
    // for (var y = 0; y < 128; y++) {
    //   for (var x = 0; x < 128; x++) {
    //     var pixel = resizedImage.getPixel(x, y);
    //     inputBytes[pixelIndex++] = pixel.r / 255.0;
    //     inputBytes[pixelIndex++] = pixel.g / 255.0;
    //     inputBytes[pixelIndex++] = pixel.b / 255.0;
    //   }
//     }
// // https://pub.dev/documentation/tflite/latest/
//     var output = await Tflite.runModelOnBinary(
//       binary: inputBytes.buffer.asUint8List(),
//       numResults: 256,
//       threshold: 0.5,
//     );

//     if (output != null && output.isNotEmpty) {
//       List<double> outputList =
//           List<double>.from(output.map((e) => e['output']).expand((e) => e));
//       return Float32List.fromList(outputList);
//     } else {
//       throw Exception("Model output is empty");
//     }
  }

  Future<void> recognizeFace() async {
    if (!cameraController!.value.isInitialized || isWorking) return;

    try {
      // await loadModel();
      var interpreter = await Interpreter.fromAsset('assets/facenet.tflite');

      print("Siamese model loaded successfully");
      List<List<List<List<double>>>> generateRandomData(
          int n, int h, int w, int c) {
        final random = Random();
        return List.generate(
            n,
            (_) => List.generate(
                h,
                (_) => List.generate(
                    w, (_) => List.generate(c, (_) => random.nextDouble()))));
      }

      // For ex: if input tensor shape [1,5] and type is float32
      final input = generateRandomData(1, 128, 128, 3);

// if output tensor shape [1,2] and type is float32
      var output = List.filled(1 * 128, 0).reshape([1, 128]);

// inference
      interpreter.run(input, output);
      print("output");
// print the output
      print(output);
      // cameraController!.startImageStream((imageFromStream) async {
      //   cameraController!.stopImageStream();
      //   print("image from stream $imageFromStream");
      //   // List<double> preprocessedImage =
      //   //     await processCameraImage(imageFromStream);

      //   imgCamera = imageFromStream;
      //   final embedding = await computeEmbedding(imgCamera!);
      //   final recognizedPerson = await findClosestMatch(embedding);
      //   setState(() {
      //     result = recognizedPerson ?? "Unknown person";
      //   });
      // });
    } catch (e) {
      print("Error recognizing face: $e");
      setState(() {
        result = "Error recognizing face";
      });
    }
  }

  Future<String?> findClosestMatch(Float32List embedding) async {
    final List<Map<String, dynamic>> persons = await database.query('persons');
    double closestDistance = double.infinity;
    String? closestPerson;

    for (var person in persons) {
      final storedEmbedding =
          Float32List.fromList(List<double>.from(person['embedding']));
      final distance = computeDistance(embedding, storedEmbedding);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestPerson = person['name'];
      }
    }

    // You might want to set a threshold for the closest distance
    return closestDistance < 0.6 ? closestPerson : null;
  }

  double computeDistance(Float32List embedding1, Float32List embedding2) {
    double sum = 0;
    for (int i = 0; i < embedding1.length; i++) {
      sum += (embedding1[i] - embedding2[i]) * (embedding1[i] - embedding2[i]);
    }
    return sum;
  }

  Future<void> captureImage() async {
    if (!cameraController!.value.isInitialized || isWorking) return;

    try {
      cameraController!.startImageStream((imageFromStream) async {
        cameraController!.stopImageStream();
        imgCamera = imageFromStream;
        await addNewPerson("name"); // You can change "name" to the desired name
        print("Image captured from cam $currentCamera");
      });
    } catch (e) {
      print("Error capturing image: $e");
    }
  }

  @override
  void dispose() {
    cameraController?.dispose();
    Tflite.close();
    database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      return Container();
    }
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CameraPreview(cameraController!),
              ),
            ),
            Expanded(child: SizedBox()),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                result,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => promptNewPerson(context),
                  style: ElevatedButton.styleFrom(
                    shape: CircleBorder(),
                    padding: EdgeInsets.all(16),
                  ),
                  child: Icon(Icons.add, size: 52),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: recognizeFace,
                  style: ElevatedButton.styleFrom(
                    shape: CircleBorder(),
                    padding: EdgeInsets.all(16),
                  ),
                  child: Icon(Icons.camera_alt, size: 52),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: flipCamera,
                  style: ElevatedButton.styleFrom(
                    shape: CircleBorder(),
                    padding: EdgeInsets.all(16),
                  ),
                  child: Icon(Icons.flip_camera_ios, size: 52),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
