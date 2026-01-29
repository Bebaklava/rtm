import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(const SimonGameApp());
}

class SimonGameApp extends StatelessWidget {
  const SimonGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Повтори Мелодию',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF222222),
        useMaterial3: true,
      ),
      home: const SimonGamePage(),
    );
  }
}

class SimonGamePage extends StatefulWidget {
  const SimonGamePage({super.key});

  @override
  State<SimonGamePage> createState() => _SimonGamePageState();
}

class _SimonGamePageState extends State<SimonGamePage> {
  final List<int> _sequence = [];
  final List<int> _userSequence = [];
  final Random _random = Random();
  final AudioPlayer _player = AudioPlayer();
  
  // Пути к аудиофайлам (null = без звука)
  final List<String?> _audioPaths = [null, null, null, null];
  
  // Состояние игры
  bool _isPlayingSequence = false;
  bool _gameOver = false;
  int _score = 0;
  
  // Для анимации подсветки
  int _activeLightIndex = -1;
  String _statusText = "Нажми Старт!";

  final List<Color> _baseColors = [
    Colors.red[900]!,
    Colors.green[900]!,
    Colors.blue[900]!,
    Colors.yellow[900]!,
  ];

  final List<Color> _brightColors = [
    Colors.redAccent,
    Colors.greenAccent,
    Colors.blueAccent,
    Colors.yellowAccent,
  ];

  final List<String> _colorNames = ["Красный", "Зеленый", "Синий", "Желтый"];

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // --- ЛОГИКА ИГРЫ ---

  void _startGame() {
    setState(() {
      _sequence.clear();
      _userSequence.clear();
      _score = 0;
      _gameOver = false;
      _statusText = "Смотри...";
    });
    _nextRound();
  }

  void _nextRound() async {
    _sequence.add(_random.nextInt(4));
    setState(() {
      _userSequence.clear();
      _isPlayingSequence = true;
      _statusText = "Запоминай!";
    });

    await Future.delayed(const Duration(seconds: 1));
    for (int index in _sequence) {
      await _activateButton(index);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    setState(() {
      _isPlayingSequence = false;
      _statusText = "Твой ход!";
    });
  }

  Future<void> _activateButton(int index) async {
    // 1. Визуальная подсветка
    setState(() {
      _activeLightIndex = index;
    });

    // 2. Звук
    _playSound(index);

    // Ждем
    await Future.delayed(const Duration(milliseconds: 400));
    
    // Выключаем подсветку
    setState(() {
      _activeLightIndex = -1;
    });
  }

  Future<void> _playSound(int index) async {
    String? path = _audioPaths[index];
    if (path != null) {
      try {
        if (kIsWeb) {
             // На вебе сложнее с локальными путями из пикера, пока пропустим или нужны URL
             // Для простоты оставим пустым для веба, если файл не из ассетов
        } else {
             await _player.stop(); // Остановить предыдущий звук
             await _player.play(DeviceFileSource(path));
        }
      } catch (e) {
        debugPrint("Ошибка воспроизведения: $e");
      }
    }
  }

  void _handleButtonTap(int index) async {
    if (_gameOver || _isPlayingSequence) return;

    _activateButton(index); // Светим и играем

    if (index == _sequence[_userSequence.length]) {
      _userSequence.add(index);
      
      if (_userSequence.length == _sequence.length) {
        setState(() {
          _score++;
          _statusText = "Отлично! Уровень $_score";
          _isPlayingSequence = true; 
        });
        await Future.delayed(const Duration(seconds: 1));
        _nextRound();
      }
    } else {
      setState(() {
        _gameOver = true;
        _statusText = "ОШИБКА! Счет: $_score";
      });
    }
  }

  // --- НАСТРОЙКИ ЗВУКА ---

  Future<void> _pickAudioFile(int index) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _audioPaths[index] = result.files.single.path!;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Звук для ${_colorNames[index]} выбран!")),
      );
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Настройка звуков"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (index) {
              return ListTile(
                leading: CircleAvatar(backgroundColor: _baseColors[index]),
                title: Text(_colorNames[index]),
                subtitle: Text(_audioPaths[index] != null ? "Файл выбран" : "Без звука"),
                trailing: IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _pickAudioFile(index);
                  },
                ),
              );
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Закрыть"),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simon Says'),
        backgroundColor: Colors.black45,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          )
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Text(
                  _statusText,
                  style: TextStyle(
                    fontSize: 28, 
                    color: _gameOver ? Colors.red : Colors.white,
                    fontWeight: FontWeight.bold
                  ),
                ),
                if (_gameOver)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ElevatedButton(
                      onPressed: _startGame,
                      child: const Text("ИГРАТЬ СНОВА"),
                    ),
                  )
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: 4,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTapDown: (_) {
                       if (!_isPlayingSequence && !_gameOver) {
                         setState(() => _activeLightIndex = index);
                       }
                    },
                    onTapUp: (_) {
                       if (!_isPlayingSequence && !_gameOver) {
                         setState(() => _activeLightIndex = -1);
                         _handleButtonTap(index);
                       }
                    },
                    onTapCancel: () {
                       setState(() => _activeLightIndex = -1);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      decoration: BoxDecoration(
                        color: _activeLightIndex == index 
                            ? _brightColors[index] 
                            : _baseColors[index],
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          if (_activeLightIndex == index)
                            BoxShadow(
                              color: _brightColors[index].withOpacity(0.6),
                              blurRadius: 20,
                              spreadRadius: 5,
                            )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          const SizedBox(height: 50),
          
          if (!_gameOver && _score == 0 && _sequence.isEmpty)
             ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  textStyle: const TextStyle(fontSize: 20),
                ),
                child: const Text("СТАРТ"),
              ),
        ],
      ),
    );
  }
}
