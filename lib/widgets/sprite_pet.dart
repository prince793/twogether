// lib/widgets/sprite_pet.dart
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Plays one Tiny Pets spritesheet (8 frames laid out horizontally).
///
/// Asset path format: assets/pets/<species>_<animation>_<size>.png
/// Example: assets/pets/cat_idle_64.png
class SpritePet extends StatefulWidget {
  const SpritePet({
    super.key,
    required this.species,
    this.animation = 'idle',
    this.sheetSize = 64, // 32 or 64 (pixel size of the sheet)
    this.displaySize = 160, // size on screen
  });

  final String species; // cat, dog, bunny, chick, bear, slime, dragon, fox, frog, ghost, panda, penguin
  final String animation; // idle, jump, sleep, happy
  final int sheetSize;
  final double displaySize;

  static const List<String> species12 = [
    'bear', 'bunny', 'cat', 'chick', 'dog', 'dragon',
    'fox', 'frog', 'ghost', 'panda', 'penguin', 'slime',
  ];

  static const Map<String, int> _fps = {
    'idle': 8,
    'jump': 12,
    'sleep': 6,
    'happy': 10,
  };

  @override
  State<SpritePet> createState() => _SpritePetState();
}

class _SpritePetState extends State<SpritePet> {
  static const int _frames = 8;

  ui.Image? _image;
  Timer? _timer;
  int _frame = 0;

  String get _safeSpecies {
    final s = widget.species.toLowerCase().trim();
    return SpritePet.species12.contains(s) ? s : 'cat'; // fallback
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SpritePet old) {
    super.didUpdateWidget(old);
    if (old.species != widget.species ||
        old.animation != widget.animation ||
        old.sheetSize != widget.sheetSize) {
      _load();
    }
  }

  Future<void> _load() async {
    final path =
        'assets/pets/${_safeSpecies}_${widget.animation}_${widget.sheetSize}.png';
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _image = frame.image;
        _frame = 0;
      });
      _startTimer();
    } catch (e) {
      debugPrint('SpritePet: cannot load $path -> $e');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    final fps = SpritePet._fps[widget.animation] ?? 8;
    _timer = Timer.periodic(Duration(milliseconds: 1000 ~/ fps), (_) {
      if (!mounted) return;
      setState(() => _frame = (_frame + 1) % _frames);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    return SizedBox(
      width: widget.displaySize,
      height: widget.displaySize,
      child: img == null
          ? const SizedBox.shrink()
          : CustomPaint(
              painter: _SpritePainter(img, _frame, widget.sheetSize.toDouble()),
            ),
    );
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.image, this.frame, this.frameSize);

  final ui.Image image;
  final int frame;
  final double frameSize;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(frame * frameSize, 0, frameSize, frameSize);
    final dst = Offset.zero & size;
    // FilterQuality.none keeps pixel art crisp when scaled up
    canvas.drawImageRect(image, src, dst, Paint()..filterQuality = FilterQuality.none);
  }

  @override
  bool shouldRepaint(covariant _SpritePainter old) =>
      old.frame != frame || old.image != image;
}
