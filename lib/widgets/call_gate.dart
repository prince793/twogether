import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/call_screen.dart';

class CallGate extends StatefulWidget {
  const CallGate({super.key, required this.child});

  final Widget child;

  @override
  State<CallGate> createState() => _CallGateState();
}

class _CallGateState extends State<CallGate> {
  final String? _myUid = FirebaseAuth.instance.currentUser?.uid;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _callSub;

  String? _coupleId;
  String _partnerName = 'Your partner';
  final Set<String> _handled = {};

  @override
  void initState() {
    super.initState();

    final uid = _myUid;

    if (uid == null) return;

    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(_onUser, onError: (_) {});
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _callSub?.cancel();
    super.dispose();
  }

  void _onUser(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();

    if (data == null) return;

    final partner = (data['partnerName'] as String?)?.trim();

    if (partner != null && partner.isNotEmpty) {
      _partnerName = partner;
    }

    final coupleId = data['coupleId'] as String?;

    if (coupleId != _coupleId) {
      _coupleId = coupleId;
      _listenCalls();
    }
  }

  void _listenCalls() {
    _callSub?.cancel();
    _callSub = null;

    final coupleId = _coupleId;

    if (coupleId == null) return;

    _callSub = FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('calls')
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen(_onCalls, onError: (_) {});
  }

  void _onCalls(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!mounted || CallScreen.isOpen) return;

    final coupleId = _coupleId;

    if (coupleId == null) return;

    for (final doc in snap.docs) {
      if (_handled.contains(doc.id)) continue;

      final data = doc.data();

      // Ignore calls that I started myself.
      if (data['callerUid'] == _myUid) continue;

      final createdAt = data['createdAt'];

      if (createdAt is! Timestamp) continue;

      // Ignore old calls that were never closed.
      final age = DateTime.now().difference(createdAt.toDate());

      if (age.inSeconds > 60) continue;

      _handled.add(doc.id);
      _openIncoming(coupleId, doc.id);
      break;
    }
  }

  Future<void> _openIncoming(String coupleId, String callId) async {
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CallScreen(
          coupleId: coupleId,
          partnerName: _partnerName,
          incomingCallId: callId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}