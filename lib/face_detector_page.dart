import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'camera_view.dart';
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:fluttertoast/fluttertoast.dart';
class FaceDetectorPage extends StatefulWidget {
  const FaceDetectorPage({super.key});

  @override
  State<FaceDetectorPage> createState() => _FaceDetectorPageState();
}

class _FaceDetectorPageState extends State<FaceDetectorPage> {
  @override
  void initState() {
    super.initState();

    _initializeNotifications();
  }
  //create face detector object
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
    ),
  );
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;

//Var for check processing image
  bool _isProcessing = false;
  //Setup face detector
  final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
    enableContours: true,
    enableClassification: true,
    enableTracking: true,
    enableLandmarks: true,
  ));
  //Var for detected face
  bool isFaceDetected = false;
  //Var for timer value
  int _start = DETECTION_TIME;
  Timer? _timer;
  //Var for check if timer is running
  bool _isRunning = false;
  //Var for check if timer is paused
  bool _isPaused = false;
  //Var for notification
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isDetectionSession = true;
  @override
  void dispose() {
    _canProcess = false;
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraView(
          title: 'Face Detector',
          customPaint: _customPaint,
          text: _text,
          onImage: (inputImage) {
            processImage(inputImage);
          },
          initialDirection: CameraLensDirection.front,
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_isRunning) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(20),
                    ),
                  ),
                  child: Text(
                    isFaceDetected ? 'Detection Time' : 'Rest Time',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      decoration: TextDecoration.none,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 60),
              ],
              Text(
                _formatTime(_start),
                style: const TextStyle(
                  fontSize: 36,
                  decoration: TextDecoration.none,
                  color: Color.fromARGB(255, 255, 255, 255)
                ),
              ),
              const SizedBox(height: 40),
    
              if (!_isRunning) ...[
                ElevatedButton(
                  onPressed: () async {
                    //Check face status
                    if (!isFaceDetected) {
                      //showFailedStartNotification();
                      return;
                    }
    
                    //Start background service
                    const androidConfig = FlutterBackgroundAndroidConfig(
                      notificationTitle: "Eye Detector",
                      notificationText: "Eye Detector running in background",
                      notificationImportance: AndroidNotificationImportance.Max,
                    );
                    await FlutterBackground.initialize(
                        androidConfig: androidConfig);
                    await FlutterBackground.enableBackgroundExecution();
    
                    //Start detection
                    showSuccessStartNotification();
                    _startTimer();
                  },
                  child: const Text('Start Timer'),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: () async {
                    //Stop background service
                    final enabled =
                        FlutterBackground.isBackgroundExecutionEnabled;
                    if (enabled) {
                      await FlutterBackground.disableBackgroundExecution();
                    }
    
                    //Reset timer
                    _resetTimer();
                  },
                  child: const Text('Reset Timer'),
                ),
              ],
            ],
          ),
        ),
      ]
    );
  }

  Future<void> processImage(final InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = "";
    });
    final faces = await _faceDetector.processImage(inputImage);
    isFaceDetected = faces.isNotEmpty;

    if (isFaceDetected) {
      if (_isDetectionSession) {
        if (_isRunning && _isPaused) {
          _resumeTimer();
        }
      } else {
        if (_isRunning && !_isPaused) {
          _pauseTimer();
        }
      }

      final face = faces[0];
      if (face.leftEyeOpenProbability != null &&
        face.rightEyeOpenProbability != null) {
        //Check if user blink
        if (face.leftEyeOpenProbability! < 0.7 ||
          face.rightEyeOpenProbability! < 0.7) {
          if (_isRunning) {
            print('BLINKING');
          }
        }
      }
    } else {
        //Determine timer state
        if (_isRunning) {
          if (_isDetectionSession) {
            if (!_isPaused) {
              _pauseTimer();
            }
          } else {
            if (_isPaused) _restartTimer();
          }
        }
      }

    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> showFailedStartNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      '1',
      '1',
      channelDescription: '1',
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'ticker',
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      1,
      'Failed to start timer',
      'Your face/eye is not detected in camera',
      platformChannelSpecifics,
    );
  }

  Future<void> showSuccessStartNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      '2',
      '2',
      channelDescription: '2',
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'ticker',
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      2,
      'Eye Detector',
      "Eye Detector running in background",
      platformChannelSpecifics,
    );
  }

  Future<void> showPausedNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      '3',
      '3',
      channelDescription: '3',
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'ticker',
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      3,
      _isDetectionSession ? 'Eye Detector is paused' : 'Rest time is paused',
      _isDetectionSession
          ? "Your face/eye is not detected in camera"
          : "Your face/eye is detected in camera",
      platformChannelSpecifics,
    );
  }

  Future<void> showTimerDoneNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      '4',
      '4',
      channelDescription: '4',
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'ticker',
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      4,
      'Eye Detector',
      "20 minutes timer is done. You can rest for 20 seconds",
      platformChannelSpecifics,
    );
  }

  Future<void> showResumedNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      '5',
      '5',
      channelDescription: '5',
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'ticker',
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      5,
      'Eye Detector',
      "Eye Detector is resumed",
      platformChannelSpecifics,
    );
  }
  //Format time to readable timer text
  String _formatTime(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  //Function to start timer
  void _startTimer() {
    setState(() {
      _isRunning = true;
    });

    //Timer every seconds
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      //Timer done
      if (_start == 0) {
        setState(() {
          //set up timer restart time based on session
          _start = _isDetectionSession ? REST_TIME : DETECTION_TIME;

          if (_isDetectionSession) {
            showTimerDoneNotification();
          }

          //Reset session status
          _isDetectionSession = !_isDetectionSession;
        });
      } else {
        //Timer running
        setState(() {
          _start--;
        });
      }
    });
  }

  //Function for reset timer
  void _resetTimer() {
    Fluttertoast.showToast(msg: "Eye Detector is stopped");
    setState(() {
      _timer?.cancel();
      _isRunning = false;
      _start = DETECTION_TIME;
      _isDetectionSession = true;
    });
  }

  //Function for pause timer
  void _pauseTimer() {
    _timer?.cancel();
    _isPaused = true;
    showPausedNotification();
    setState(() {});
  }

  //Function for resume timer
  void _resumeTimer() {
    _startTimer();
    _isPaused = false;
    showResumedNotification();
    setState(() {});
  }

  //Function for restart timer
  void _restartTimer() {
    _start = REST_TIME;
    _isPaused = false;
    setState(() {});
    _startTimer();
  }
}
