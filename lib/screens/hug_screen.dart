import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/hug_service.dart';

class _HugType {
  const _HugType(this.id, this.emoji, this.label, this.received);

  final String id;
  final String emoji;
  final String label;
  final String received;
}

const List<_HugType> _hugTypes = [
  _HugType('hug', '🤗', 'Big Hug', 'sent you a big hug'),
  _HugType('cuddle', '🫂', 'Cuddle', 'wants to cuddle with you'),
  _HugType('kiss', '😘', 'Kiss', 'sent you a kiss'),
  _HugType('miss', '🥺', 'Miss You', 'misses you so much'),
  _HugType('love', '💗', 'Love', 'sent you lots of love'),
];

_HugType _typeById(String? id) {
  return _hugTypes.firstWhere(
    (t) => t.id == id,
    orElse: () => _hugTypes.first,
  );
}

class HugScreen extends StatefulWidget {
  const HugScreen({super.key, this.partnerName = 'your partner'});

  final String partnerName;

  @override
  State<HugScreen> createState() => _HugScreenState();
}

class _HugScreenState extends State<HugScreen> {
  final HugService _hugService = HugService();
  final String? _myUid = FirebaseAuth.instance.currentUser?.uid;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _hugs = [];
  bool _loading = true;
  String? _error;
  bool _firstSnapshot = true;

  _HugType _selected = _hugTypes.first;
  bool _sending = false;
  bool _cooling = false;
  bool _pulse = false;

  static const Color pink = Color(0xFFFFA9C9);
  static const Color lavender = Color(0xFFB9A7F8);
  static const Color background = Color(0xFFFFF5FA);
  static const Color darkText = Color(0xFF59465D);

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _listen() async {
    try {
      final stream = await _hugService.getHugStream();

      if (!mounted) return;

      _sub = stream.listen(
        _onSnapshot,
        onError: (Object error) {
          if (!mounted) return;
          setState(() {
            _error = error.toString();
            _loading = false;
          });
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!mounted) return;

    final isFirst = _firstSnapshot;
    _firstSnapshot = false;

    // After the first load, pop up any NEW hug from the partner.
    if (!isFirst) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;

        final data = change.doc.data();

        if (data != null && data['fromUid'] != _myUid) {
          _showIncoming(data);
        }
      }
    }

    setState(() {
      _hugs = snap.docs;
      _loading = false;
      _error = null;
    });
  }

  void _showIncoming(Map<String, dynamic> data) {
    final type = _typeById(data['type'] as String?);
    final fromName = (data['fromName'] as String?) ?? widget.partnerName;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },
                child: Text(
                  type.emoji,
                  style: const TextStyle(fontSize: 80),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$fromName ${type.received}!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: darkText,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _send(type);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: pink,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text('Hug back 💗'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _send(_HugType type) async {
    if (_sending || _cooling) return;

    setState(() {
      _sending = true;
      _selected = type;
    });

    try {
      await _hugService.sendHug(type.id);

      if (!mounted) return;

      setState(() {
        _pulse = true;
        _cooling = true;
      });

      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _pulse = false);
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _cooling = false);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${type.emoji} ${type.label} sent to ${widget.partnerName}!',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: darkText,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong: $error'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Widget _typeChip(_HugType type) {
    final selected = type.id == _selected.id;

    return GestureDetector(
      onTap: () => setState(() => _selected = type),
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? lavender.withValues(alpha: 0.2) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? lavender : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(type.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 4),
            Text(
              type.label,
              style: const TextStyle(
                color: darkText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyTile(Map<String, dynamic> data) {
    final type = _typeById(data['type'] as String?);
    final mine = data['fromUid'] == _myUid;
    final fromName = (data['fromName'] as String?) ?? widget.partnerName;
    final createdAt = data['createdAt'];

    final time = createdAt is Timestamp
        ? DateFormat('MMM d • h:mm a').format(createdAt.toDate())
        : 'Sending...';

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: mine
              ? pink.withValues(alpha: 0.25)
              : lavender.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(type.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mine
                        ? 'You sent a ${type.label}'
                        : '$fromName ${type.received}',
                    style: const TextStyle(
                      color: darkText,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historySection() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(color: lavender),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Unable to load hugs.\n$_error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: darkText),
        ),
      );
    }

    if (_hugs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No hugs yet. Send the first one! 💗',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return Column(
      children: _hugs.map((d) => _historyTile(d.data())).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Virtual Hugs',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // HERO CARD
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD9E8), Color(0xFFE9DDFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              children: [
                AnimatedScale(
                  scale: _pulse ? 1.3 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: Text(
                    _selected.emoji,
                    style: const TextStyle(fontSize: 90),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Send a ${_selected.label} to ${widget.partnerName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'They will see it right away 💗',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          const Text(
            'CHOOSE A HUG',
            style: TextStyle(
              color: darkText,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _hugTypes.map(_typeChip).toList(),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed:
                  (_sending || _cooling) ? null : () => _send(_selected),
              style: FilledButton.styleFrom(
                backgroundColor: pink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      _cooling
                          ? 'Sent! 💗'
                          : 'SEND ${_selected.label.toUpperCase()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            'OUR HUGS',
            style: TextStyle(
              color: darkText,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          _historySection(),

          const SizedBox(height: 10),
        ],
      ),
    );
  }
}