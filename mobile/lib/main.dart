import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'package:http_parser/http_parser.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: RotationCameraScreen(cameras: cameras),
    );
  }
}

class RotationCameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const RotationCameraScreen({super.key, required this.cameras});

  @override
  State<RotationCameraScreen> createState() => _RotationCameraScreenState();
}

class _RotationCameraScreenState extends State<RotationCameraScreen> {
  List<XFile> recordedFrames = [];
  CameraController? _cameraController;
  double? lastHeading;
  double accumulatedRotation = 0;
  bool isRecording = false;
  bool isTakingPicture = false;
  @override
  void initState() {
    super.initState();
    if (widget.cameras.isNotEmpty) {
      _cameraController =
          CameraController(widget.cameras.first, ResolutionPreset.high);
      _cameraController!.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      });
    }

    FlutterCompass.events?.listen((event) async {
      if (!isRecording || event.heading == null) return;

      final currentHeading = event.heading!;
      if (lastHeading != null) {
        double delta = currentHeading - lastHeading!;
        if (delta > 180) delta -= 360;
        if (delta < -180) delta += 360;
        accumulatedRotation += delta;

        // Каждые 15° делаем кадр
        if ((accumulatedRotation % 15).abs() < 1) {
          if (!isTakingPicture && _cameraController!.value.isInitialized) {
            isTakingPicture = true;
            try {
              final frame = await _cameraController!.takePicture();
              recordedFrames.add(frame);
              print("📸 Снято кадр: ${frame.path}");
            } catch (e) {
              print("Ошибка при снимке: $e");
            }
            isTakingPicture = false;
          }
        }
      }
      lastHeading = currentHeading;
      setState(() {});
    });
  }
  bool isUploading = false;
  double uploadProgress = 0;

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final progress = (accumulatedRotation.abs() / 360).clamp(0, 1);

    return Scaffold(
      body: Stack(
        children: [
          if (isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: uploadProgress,
                        strokeWidth: 8,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Отправка снимков на сервер…",
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${(uploadProgress * 100).toStringAsFixed(0)}%",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 📷 Камера на весь экран
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.previewSize!.height,
                height: _cameraController!.value.previewSize!.width,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),

          // 🧊 Glassmorphism панель с текстом
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GlassmorphicContainer(
                width: double.infinity,
                height: 80,
                borderRadius: 20,
                blur: 20,
                border: 1,
                linearGradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderGradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                child: Center(
                  child: Text(
                    "Нажмите и удерживайте кнопку,\nпока не обойдете машину на 360°",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 🌐 Центральный угол/прогресс
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 180), // 📍 Чуть выше кнопки
              child: Text(
                "${accumulatedRotation.abs().toStringAsFixed(0)}°",
                style: const TextStyle(
                  fontSize: 42, // немного меньше, чтобы не доминировал
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 12,
                      color: Colors.black87,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
              ),
            ),
          ),


          // 🔴 Кнопка записи снизу
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: GestureDetector(
                onLongPressStart: (_) => setState(() => isRecording = true),
                onLongPressEnd: (_) async {
                  setState(() => isRecording = false);

                  if (recordedFrames.isEmpty) return;

                  setState(() {
                    isUploading = true;
                    uploadProgress = 0;
                  });

                  print("🎯 Обход завершен. Отправляем все кадры на сервер...");

                  final uri = Uri.parse("https://drtyui.ru/car-verif");
                  var request = http.MultipartRequest('POST', uri);

                  for (var frame in recordedFrames) {
                    request.files.add(await http.MultipartFile.fromPath('files', frame.path, contentType: MediaType('image', 'jpeg')));
                  }

                  try {
                    final streamedResponse = await request.send();
                    final response = await http.Response.fromStream(streamedResponse);

                    setState(() {
                      isUploading = false;
                      uploadProgress = 1.0;
                    });

                    if (response.statusCode == 201) {
                      final data = jsonDecode(response.body);
                      print("✅ Сервер вернул результат: $data");

                      // Проверяем, есть ли машина
                      final ok = data['ok'] ?? false;
                      final photo = data['photo'];

                      if (!ok || photo == null || photo == "") {
                        // Машина не обнаружена
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              backgroundColor: Colors.black,
                              body: SafeArea(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Spacer(),
                                    const Icon(
                                      Icons.directions_car_outlined,
                                      size: 80,
                                      color: Colors.white54,
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      "Машина не обнаружена на кадрах",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 40),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white.withOpacity(0.1),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                          horizontal: 24,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text(
                                        "Назад",
                                        style: TextStyle(color: Colors.white, fontSize: 18),
                                      ),
                                    ),
                                    const Spacer(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );

                        return; // Прерываем дальнейшее выполнение
                      }

                      // Машина найдена — показываем результат
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ResultScreen(
                            photoBase64: photo,
                            detections: data['detections'] ?? [],
                          ),
                        ),
                      );
                    } else {
                      print("❌ Ошибка сервера: ${response.statusCode}");
                    }
                  } catch (e) {
                    setState(() {
                      isUploading = false;
                    });
                    print("❌ Ошибка при отправке: $e");
                  }
                },




                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: progress.toDouble(),
                        strokeWidth: 6,
                        backgroundColor: Colors.white30,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.redAccent,
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isRecording ? 90 : 80,
                      height: isRecording ? 90 : 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isRecording
                            ? Colors.redAccent
                            : Colors.white.withOpacity(0.2),
                        boxShadow: [
                          BoxShadow(
                            color:
                            Colors.redAccent.withOpacity(
                                isRecording ? 0.6 : 0.0),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fiber_manual_record,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> uploadAllFrames() async {
    if (recordedFrames.isEmpty) return;

    setState(() {
      isUploading = true;
      uploadProgress = 0;
    });

    final uri = Uri.parse("https://drtyui.ru/car-verif");
    var request = http.MultipartRequest('POST', uri);

    for (var frame in recordedFrames) {
      request.files.add(await http.MultipartFile.fromPath('files', frame.path));
    }

    var response = await request.send();
    final respStr = await response.stream.bytesToString();

    setState(() {
      isUploading = false;
      uploadProgress = 1.0;
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(respStr);

      String base64Photo = data['photo'] ?? "";
      List detections = data['detections'] ?? [];

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            photoBase64: base64Photo,
            detections: detections,
          ),
        ),
      );
    } else {
      print("Ошибка при отправке: ${response.statusCode}");
    }
  }

  Future<void> uploadFrame(XFile frame) async {
    final uri = Uri.parse("https://drtyui.ru/car-verif");
    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('files', frame.path));
    var response = await request.send();
    if (response.statusCode == 200) {
      print("Кадр ${frame.name} успешно отправлен");
    } else {
      print("Ошибка при отправке кадра ${frame.name}");
    }
  }
  }


class ResultScreen extends StatefulWidget {
  final String photoBase64;
  final List detections;

  const ResultScreen({
    super.key,
    required this.photoBase64,
    required this.detections,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  double get dirtiness {
    // Пример: считаем "грязность" как долю найденных дефектов типа 'car-dirt'
    if (widget.detections.isEmpty) return 0;
    double score = 0;
    for (var det in widget.detections) {
      if (det['class'].contains('dirt')) score += det['confidence'];
    }
    return (score / widget.detections.length).clamp(0.0, 1.0);
  }

  double get defects {
    if (widget.detections.isEmpty) return 0;
    double score = 0;
    for (var det in widget.detections) {
      if (det['class'].contains('scratch') ||
          det['class'].contains('dent')) score += det['confidence'];
    }
    return (score / widget.detections.length).clamp(0.0, 1.0);
  }

  String get recommendation {
    if (dirtiness > 0.5) return "Рекомендуется полная мойка кузова.";
    if (defects > 0.5) return "Есть повреждения, лучше посетить сервис.";
    return "Состояние хорошее, можно не беспокоиться.";
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.photoBase64.isNotEmpty
        ? Image.memory(
      base64Decode(widget.photoBase64),
      fit: BoxFit.cover,
    )
        : const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Фото автомобиля с градиентом
          Positioned.fill(
            child: Stack(
              children: [
                Positioned.fill(child: image),
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black54, Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SafeArea(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 30),
                    Text(
                      "Результаты осмотра",
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Полукруглые спидометры для грязи и дефектов
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSemiCircleMeter(
                            label: "Грязь", score: dirtiness, color: Colors.blueAccent),
                        _buildSemiCircleMeter(
                            label: "Повреждения",
                            score: defects,
                            color: Colors.redAccent),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Список дефектов
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Найденные дефекты:",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...widget.detections.map((det) => Text(
                            "${det['class']} — ${(det['confidence'] * 100).toStringAsFixed(1)}%",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          )),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Рекомендации
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          recommendation,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Кнопка назад / повторить
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 24),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.replay, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              "Сканировать снова",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemiCircleMeter({
    required String label,
    required double score,
    required Color color,
  }) {
    return Column(
      children: [
        SizedBox(
          width: 120,
          height: 60,
          child: CustomPaint(
            painter: SemiCircleMeterPainter(score: score, color: color),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class SemiCircleMeterPainter extends CustomPainter {
  final double score; // 0-1
  final Color color;

  SemiCircleMeterPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);
    final startAngle = pi;
    final sweepAngle = pi * score;

    final backgroundPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final foregroundPaint = Paint()
      ..color = color
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, pi, false, backgroundPaint);
    canvas.drawArc(rect, startAngle, sweepAngle, false, foregroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
