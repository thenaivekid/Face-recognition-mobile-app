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
  late Interpreter interpreter;
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
    print("database initialized");
  }

  Future<void> loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset('assets/facenet.tflite');

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
    // clearPersonsDB();
    final name = await _showNameInputDialog(context);
    print("name input $name");
    if (name != null && name.isNotEmpty) {
      captureImage(); // Capture image and add the new person
      addNewPerson(name);
    }
  }

  Future<void> addNewPerson(String name) async {
    if (imgCamera == null) return;

    try {
      final embedding = await computeEmbedding();
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
    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  "New Person",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                TextField(
                  onChanged: (value) {
                    name = value;
                  },
                  decoration: InputDecoration(hintText: "Enter name"),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      child: Text("Cancel"),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    SizedBox(width: 8),
                    TextButton(
                      child: Text("Save"),
                      onPressed: () {
                        Navigator.of(context).pop(name);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

Future<void> _savePersonToDB(Float32List embedding, String name) async {
    String embeddingString = embedding.join(',');
    await database.insert(
      'persons',
      {
        'name': name,
        'embedding': embeddingString,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearPersonsDB() async {
    try {
      // Delete all rows in the 'persons' table
      await database.delete('persons');
      print('All data cleared from persons table');
    } catch (e) {
      print('Error clearing persons table: $e');
    }
  }

  Future<void> fetchAllPeople() async {
    // <List<Map<String, dynamic>>>
    final List<Map<String, dynamic>> people = await database.query('persons');
    people.forEach((person) {
      print('ID: ${person['id']}, Name: ${person['name']}');
    });

    // return await database.query('persons');
  }

  Future<Float32List> computeEmbedding() async {
    captureImage();

    img.Image image = convertYUV420ToImage(imgCamera!);
    final imageInput = img.copyResize(
      image!,
      width: 300,
      height: 300,
    );

    // Creating matrix representation, [300, 300, 3]
    final imageMatrix = List.generate(
      imageInput.height,
      (y) => List.generate(
        imageInput.width,
        (x) {
          final pixel = imageInput.getPixel(x, y);
          return [pixel.r, pixel.g, pixel.b];
        },
      ),
    );

    print("input $imageMatrix");
// if output tensor shape [1,2] and type is float32
    // var output = List.filled(1 * 128, 0).reshape([1, 128]);
    var output =
        List<List<double>>.generate(1, (_) => List<double>.filled(128, 0.0));
// inference
    interpreter.run([imageMatrix], output);
    print("output");
// print the output
    print(output);
    Float32List float32Output =
        Float32List.fromList(output.expand((element) => element).toList());
    return float32Output;
  }

  img.Image convertYUV420ToImage(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;

    final uvRowStride = cameraImage.planes[1].bytesPerRow;
    final uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

    final yPlane = cameraImage.planes[0].bytes;
    final uPlane = cameraImage.planes[1].bytes;
    final vPlane = cameraImage.planes[2].bytes;

    final image = img.Image(width: width, height: height);

    var uvIndex = 0;

    for (var y = 0; y < height; y++) {
      var pY = y * width;
      var pUV = uvIndex;

      for (var x = 0; x < width; x++) {
        final yValue = yPlane[pY];
        final uValue = uPlane[pUV];
        final vValue = vPlane[pUV];

        final r = yValue + 1.402 * (vValue - 128);
        final g =
            yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128);
        final b = yValue + 1.772 * (uValue - 128);

        image.setPixelRgba(x, y, r.toInt(), g.toInt(), b.toInt(), 1);

        pY++;
        if (x % 2 == 1 && uvPixelStride == 2) {
          pUV += uvPixelStride;
        } else if (x % 2 == 1 && uvPixelStride == 1) {
          pUV++;
        }
      }

      if (y % 2 == 1) {
        uvIndex += uvRowStride;
      }
    }
    return image;
  }

  Future<void> recognizeFace() async {
    print("people");
    fetchAllPeople();
    var output = await computeEmbedding();
    print("encoded");
    var recognized = findClosestMatch(output);

    // setState(() {
    //   result = "$recognized";
    // });
    return;
  }

  Future<String?> findClosestMatch(Float32List embedding) async {
    final List<Map<String, dynamic>> persons = await database.query('persons');
    double closestDistance = double.infinity;
    String? closestPerson;

    for (var person in persons) {
      String embeddingString = person["embedding"] as String;
      List<double> embeddingList = embeddingString
          .split(',')
          .map((e) => double.parse(e.trim()))
          .toList();
      Float32List storedEmbedding = Float32List.fromList(embeddingList);

      if (storedEmbedding.length != embedding.length) {
        print(
            "Warning: Stored embedding length (${storedEmbedding.length}) does not match input embedding length (${embedding.length}) for person: ${person['name']}");
        continue; // Skip this person
      }

      final distance = computeDistance(embedding, storedEmbedding);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestPerson = person['name'];
      }
    }

    print("closest person $closestPerson");
    setState(() {
      result = "$closestPerson";
    });
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
        resizeToAvoidBottomInset: false,
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
