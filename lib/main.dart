import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

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

  final List<AudioSource?> _audioSources = List.filled(7, null);
  bool _isSoloudInited = false;

  final int _keysCount = 7;
  final List<String> _noteNames = ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Si'];

  bool _isPlayingSequence = false;
  bool _gameOver = false;
  int _score = 0;
  int _activeKeyIndex = -1;
  String _statusText = 'Загрузка звуков...';

  @override
  void initState() {
    super.initState();
    _initSoloud();
  }

  Future<void> _initSoloud() async {
    try {
      await SoLoud.instance.init();
      if (mounted) {
        setState(() {
          _isSoloudInited = true;
          _statusText = 'Нажмите Старт';
        });
        _loadSounds();
      }
    } catch (e) {
      debugPrint('SoLoud init error: $e');
    }
  }

  Future<void> _loadSounds() async {
    for (int i = 0; i < _keysCount; i++) {
      try {
        final source = await SoLoud.instance.loadAsset('assets/note${i + 1}.mp3');
        if (mounted) {
          setState(() {
            _audioSources[i] = source;
          });
        }
      } catch (e) {
        debugPrint('Error loading sound $i: $e');
      }
    }
  }

  @override
  void dispose() {
    SoLoud.instance.deinit();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _startGame() {
    if (!_isSoloudInited) return;
    setState(() {
      _sequence.clear();
      _userSequence.clear();
      _score = 0;
      _gameOver = false;
      _statusText = 'Слушайте...';
    });
    _nextRound();
  }

  void _nextRound() async {
    _sequence.add(_random.nextInt(_keysCount));
    setState(() {
      _userSequence.clear();
      _isPlayingSequence = true;
      _statusText = 'Запоминайте!';
    });

    await Future.delayed(const Duration(seconds: 1));
    for (int index in _sequence) {
      await _activateKey(index);
      await Future.delayed(const Duration(milliseconds: 200));
    }

    setState(() {
      _isPlayingSequence = false;
      _statusText = 'Повторяйте!';
    });
  }

  Future<void> _activateKey(int index) async {
    if (!mounted) return;
    setState(() => _activeKeyIndex = index);
    _playSound(index);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _activeKeyIndex = -1);
  }

  void _playSound(int index) {
    final source = _audioSources[index];
    if (source != null && _isSoloudInited) {
      SoLoud.instance.play(source);
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
          _statusText = 'Верно! Уровень $_score';
          _isPlayingSequence = true;
        });
        await Future.delayed(const Duration(seconds: 1));
        _nextRound();
      }
    } else {
      setState(() {
        _gameOver = true;
        _statusText = 'Ошибка! Счёт: $_score';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Повтори мелодию'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
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
                        _gameOver ? 'Заново' : 'Старт',
                        style: const TextStyle(fontSize: 18)
                      ),
                    ),
                ],
              ),
            ),
          ),
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
