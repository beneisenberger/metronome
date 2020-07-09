import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soundpool/soundpool.dart';

Soundpool _soundpool;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _soundpool = Soundpool();
  runApp(MyApp());
}

// void main() {
//   runApp(MyApp());
// }

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Metronome',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: Scaffold(
          appBar: AppBar(title: Text("Metronome")), body: MetronomeControl()),
    );
  }
}

enum MetronomeState { Playing, Stopped, Stopping }

class MetronomeControl extends StatefulWidget {
  MetronomeControl();
  MetronomeControlState createState() => new MetronomeControlState();
}

class MetronomeControlState extends State<MetronomeControl> {
  MetronomeControlState();

  int _alarmSoundStreamId;
  Future<int> _soundId;

  String get _cheeringUrl => kIsWeb ? '/c-c-1.mp3' : 'https://raw.githubusercontent.com/ukasz123/soundpool/feature/web_support/example/web/c-c-1.mp3';

  void initState(){
    _soundId = _loadSound();
  }

  double _tempo = 60;
  String _beat = 'quarter';
  MetronomeState _metronomeState = MetronomeState.Stopped;
  Timer _tickTimer;
  int _tickInterval;
  List<int> _tapTimes = List();

  @override
  Widget build(BuildContext context) {
    return Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            GestureDetector(
                child: _metronomeState == MetronomeState.Stopped
                    ? Icon(Icons.play_arrow, color: Colors.purple, size: 30.0)
                    : Icon(Icons.stop, color: Colors.purple, size: 30.0),
                onTap: _metronomeState == MetronomeState.Stopping
                    ? null
                    : () {
                        _metronomeState == MetronomeState.Stopped
                            ? _start()
                            : _stop();
                      }),
            GestureDetector(
              onTap: () {
                _tap();
              },
              child: Icon(Icons.fingerprint, color: Colors.purple, size: 30.0),
            ),
          ]),
          SizedBox(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            GestureDetector(
              onTap: () {
                _subtractOne();
              },
              child: Icon(Icons.remove, color: Colors.purple, size: 30.0),
            ),
            Text("${_tempo.ceil().toString()}"),
            GestureDetector(
              onTap: () {
                _addOne();
              },
              child: Icon(Icons.add, color: Colors.purple, size: 30.0),
            ),
          ]),
          Container(
              width: 300,
              child: Slider(
                  min: 32,
                  max: 255,
                  divisions: 223,
                  value: _tempo,
                  onChanged: (value) {
                    setState(() {
                      _tempo = value;
                    });
                  })),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: () {
                  _changeBeat('quarter');
                },
                child: Opacity(
                  opacity: _beat == 'quarter' ? 1.0 : 0.3,
                  child: Image.asset('assets/quarter.png', height: 30),
                ),
              ),
              GestureDetector(
                onTap: () {
                  _changeBeat('eighth');
                },
                child: Opacity(
                  opacity: _beat == 'eighth' ? 1.0 : 0.3,
                  child: Image.asset('assets/eighth.png', height: 25),
                ),
              ),
              GestureDetector(
                onTap: () {
                  _changeBeat('triplet');
                },
                child: Opacity(
                  opacity: _beat == 'triplet' ? 1.0 : 0.3,
                  child: Image.asset('assets/triplet.png', width: 35),
                ),
              ),
              GestureDetector(
                onTap: () {
                  _changeBeat('sixteenth');
                },
                child: Opacity(
                  opacity: _beat == 'sixteenth' ? 1.0 : 0.3,
                  child: Image.asset('assets/sixteenth.png', height: 20),
                ),
              ),
            ],
          ),
        ]);
  }

  void _start() {
    _metronomeState = MetronomeState.Playing;
    double bps;

    if (_beat == 'quarter') {
      bps = _tempo / 60;
    }
    if (_beat == 'eighth') {
      bps = _tempo / 30;
    }
    if (_beat == 'triplet') {
      bps = _tempo / 20;
    }
    if (_beat == 'sixteenth') {
      bps = _tempo / 15;
    }

    _tickInterval = 1000 ~/ bps;
    _tickTimer =
        new Timer.periodic(new Duration(milliseconds: _tickInterval), _onTick);

    SystemSound.play(SystemSoundType.click);

    if (mounted) setState(() {});
  }

  void _onTick(Timer t) {
    if (_metronomeState == MetronomeState.Playing) {
      if (_beat == 'quarter') {
        SystemSound.play(SystemSoundType.click);
      }
      if (_beat == 'eighth') {
        var eighthBeat = 1;
        eighthBeat / 2 == 1
            ? _playSound()
            : SystemSound.play(SystemSoundType.click);
        eighthBeat++;
      }
      if (_beat == 'triplet') {
        SystemSound.play(SystemSoundType.click);
      }
      if (_beat == 'sixteenth') {
        SystemSound.play(SystemSoundType.click);
      }
    } else if (_metronomeState == MetronomeState.Stopping) {
      _tickTimer?.cancel();
      _metronomeState = MetronomeState.Stopped;
    }
  }

  void _stop() {
    _metronomeState = MetronomeState.Stopped;
    if (mounted) setState(() {});
    _tickTimer.cancel();
  }

  void _tap() {
    if (_metronomeState != MetronomeState.Stopped) return;
    int now = DateTime.now().millisecondsSinceEpoch;
    _tapTimes.add(now);
    if (_tapTimes.length > 3) {
      _tapTimes.removeAt(0);
    }
    int tapCount = 0;
    int tapIntervalSum = 0;

    for (int i = _tapTimes.length - 1; i >= 1; i--) {
      int currentTapTime = _tapTimes[i];
      int previousTapTime = _tapTimes[i - 1];
      int currentInterval = currentTapTime - previousTapTime;
      if (currentInterval > 3000) break;

      tapIntervalSum += currentInterval;
      tapCount++;
    }
    if (tapCount > 0) {
      int msBetweenTicks = tapIntervalSum ~/ tapCount;
      double bps = 1000 / msBetweenTicks;
      _tempo = min(max((bps * 60).toDouble(), 32), 255);
    }
    if (mounted) setState(() {});
  }

  void _addOne() {
    if (_tempo < 255) {
      setState(() {
        _tempo += 1;
      });
    }
  }

  void _subtractOne() {
    if (_tempo > 32) {
      setState(() {
        _tempo -= 1;
      });
    }
  }

  void _changeBeat(value) {
    setState(() {
      _beat = value;
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }
  
  Future<int> _loadSound() async {
    var asset = await rootBundle.load("sounds/do-you-like-it.wav");
    return await _soundpool.load(asset);
  }

  Future<void> _playSound() async {
    var _alarmSound = await _soundId;
    _alarmSoundStreamId = await _soundpool.play(_alarmSound);
  }
}
  