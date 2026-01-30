import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(const PianoGameApp());
  });
}

class PianoGameApp extends StatelessWidget {
  const PianoGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Повтори мелодию',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      ),
      home: const PianoGamePage(),
    );
  }
}

class PianoGamePage extends StatefulWidget {
  const PianoGamePage({super.key});

  @override
  State<PianoGamePage> createState() => _PianoGamePageState();
}

class _PianoGamePageState extends State<PianoGamePage> {
  final List<int> _sequence = [];
  final List<int> _userSequence = [];
  final Random _random = Random();
  final List<AudioPlayer> _players = List.generate(7, (_) => AudioPlayer());

  final int _keysCount = 7;
  final List<String?> _userNotePaths = List.filled(7, null);
  final List<String> _noteNames = ["Do", "Re", "Mi", "Fa", "Sol", "La", "Si"];

  bool _isPlayingSequence = false;
  bool _gameOver = false;
  int _score = 0;
  int _activeKeyIndex = -1;
  String _statusText = "Нажмите старт";

  @override
  void dispose() {
    for (var player in _players) {
      player.dispose();
    }
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _sequence.clear();
      _userSequence.clear();
      _score = 0;
      _gameOver = false;
      _statusText = "Слушай...";
    });
    _nextRound();
  }

  void _nextRound() async {
    _sequence.add(_random.nextInt(_keysCount));
    setState(() {
      _userSequence.clear();
      _isPlayingSequence = true;
      _statusText = "Запоминай!";
    });

    await Future.delayed(const Duration(seconds: 1));
    for (int index in _sequence) {
      await _activateKey(index);
      await Future.delayed(const Duration(milliseconds: 200));
    }

    setState(() {
      _isPlayingSequence = false;
      _statusText = "Повторяй!";
    });
  }

  Future<void> _activateKey(int index) async {
    setState(() => _activeKeyIndex = index);
    _playSound(index);
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _activeKeyIndex = -1);
  }

  void _playSound(int index) {
    try {
      final player = _players[index];
      player.stop();

      String? userPath = _userNotePaths[index];
      if (userPath != null) {
        if (!kIsWeb) {
           player.play(DeviceFileSource(userPath));
        }
      } else {
        player.play(AssetSource('note${index + 1}.mp3'));
      }
    } catch (e) {
      debugPrint("Error playing sound: $e");
    }
  }

  void _handleKeyTap(int index) async {
    if (_gameOver || _isPlayingSequence || _sequence.isEmpty) {
        if (_sequence.isEmpty && !_gameOver) {
             _activateKey(index);
        }
        return;
    }

    _activateKey(index);

    if (index == _sequence[_userSequence.length]) {
      _userSequence.add(index);

      if (_userSequence.length == _sequence.length) {
        setState(() {
          _score++;
          _statusText = "Супер! Уровень $_score";
          _isPlayingSequence = true;
        });
        await Future.delayed(const Duration(seconds: 1));
        _nextRound();
      }
    } else {
      setState(() {
        _gameOver = true;
        _statusText = "Ошибка! Счет: $_score";
      });
    }
  }

  Future<void> _pickAudioFile(int index) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _userNotePaths[index] = result.files.single.path!;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Звук для ${_noteNames[index]} заменен")));
    }
  }

  void _resetSound(int index) {
    setState(() {
      _userNotePaths[index] = null;
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Сброшен звук для ${_noteNames[index]}")));
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Настройка звуков"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _keysCount,
            itemBuilder: (ctx, i) => ListTile(
              title: Text(_noteNames[i]),
              subtitle: Text(_userNotePaths[i] != null ? "Используется кастомный" : "По умолчанию (Пианино)"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_userNotePaths[i] != null)
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.orange),
                      onPressed: () => _resetSound(i),
                    ),
                  IconButton(
                    icon: const Icon(Icons.folder_open),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _pickAudioFile(i);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Повтори мелодию'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: _showSettings)
        ],
      ),
      body: Column(
        children: [
          // Info Area
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(20),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 20,
                runSpacing: 10,
                children: [
                  Text(_statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)
                  ),
                  if (_gameOver || (!_gameOver && _score == 0 && _sequence.isEmpty))
                    ElevatedButton(
                      onPressed: _startGame,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        _gameOver ? "Заново" : "Старт",
                        style: const TextStyle(fontSize: 18)
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Piano Keys Area
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(10),
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(_keysCount, (index) {
                  bool isActive = _activeKeyIndex == index;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: GestureDetector(
                        onTapDown: (_) {
                          if (!_isPlayingSequence && !_gameOver) setState(() => _activeKeyIndex = index);
                        },
                        onTapUp: (_) {
                          if (!_isPlayingSequence && !_gameOver) {
                            setState(() => _activeKeyIndex = -1);
                            _handleKeyTap(index);
                          }
                        },
                        onTapCancel: () => setState(() => _activeKeyIndex = -1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.yellowAccent : Colors.white,
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                            boxShadow: isActive ? [BoxShadow(color: Colors.yellow.withOpacity(0.5), blurRadius: 15, spreadRadius: 2)] : [],
                          ),
                          alignment: Alignment.bottomCenter,
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Text(
                            _noteNames[index],
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
