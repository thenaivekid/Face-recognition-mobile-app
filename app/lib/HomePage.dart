import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomePage({Key? key, required this.cameras}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isWorking = false;
  String result = "Ashok is awesome";
  CameraController? cameraController;
  CameraImage? imgCamera;
  CameraDescription? currentCamera;

  @override
  void initState() {
    super.initState();
    availableCameras().then((cameras) {
      print("Available cameras:");
      cameras.forEach((camera) {
        print('Camera name: ${camera.name}');
        print('Camera lens direction: ${camera.lensDirection}');
      });
    }).catchError((error) {
      print('Error fetching cameras: $error');
    });
    loadModel();
    initCamera();
  }

  loadModel() async {
    try {
      await Tflite.loadModel(
        model: "assets/mobilenet_v1_1.0_224.tflite",
        labels: "assets/mobilenet_v1_1.0_224.txt",
      );
      print("Model loaded successfully");
    } catch (e) {
      print("Failed to load model: $e");
    }
  }

  runModelOnFrame(CameraImage img) async {
    if (isWorking) return;
    isWorking = true;

    try {
      var recognitions = await Tflite.runModelOnFrame(
        bytesList: img.planes.map((plane) => plane.bytes).toList(),
        imageHeight: img.height,
        imageWidth: img.width,
        imageMean: 127.5,
        imageStd: 127.5,
        rotation: 90,
        numResults: 1,
        threshold: 0.1,
      );

      print("Recognitions: $recognitions");

      setState(() {
        if (recognitions != null && recognitions.isNotEmpty) {
          result =
              "${recognitions[0]['label']} - ${(recognitions[0]['confidence'] * 100).toStringAsFixed(0)}%";
        } else {
          result = "Ashok is awesome";
        }
      });

      print("Current result: $result");
    } catch (e) {
      print("Error running model: $e");
      setState(() {
        result = "Error: $e";
      });
    }

    isWorking = false;
  }

  initCamera() {
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

  captureImage() async {
    if (!cameraController!.value.isInitialized || isWorking) return;

    try {
      cameraController!.startImageStream((imageFromStream) async {
        cameraController!.stopImageStream();
        imgCamera = imageFromStream;
        runModelOnFrame(imgCamera!);
        print("image captured form cam $currentCamera");
      });
    } catch (e) {
      print("Error capturing image: $e");
    }
  }

  @override
  void dispose() {
    cameraController?.dispose();
    Tflite.close();
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
                  onPressed: captureImage,
                  style: ElevatedButton.styleFrom(
                    shape: CircleBorder(),
                    padding: EdgeInsets.all(16),
                  ),
                  child: Icon(Icons.add, size: 52),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: captureImage,
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
