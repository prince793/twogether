import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum CallStatus { idle, calling, ringing, connecting, connected, ended }

class CallService {
  CallService({required this.coupleId});

  final String coupleId;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  final ValueNotifier<CallStatus> status = ValueNotifier(CallStatus.idle);
  final ValueNotifier<bool> muted = ValueNotifier(false);

  String endReason = '';
  DateTime? connectedAt;

  // STUN servers help two devices find each other.
  // TODO: add a TURN server below if calls fail on strict networks.
  static const Map<String, dynamic> _config = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ],
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  DocumentReference<Map<String, dynamic>>? _callRef;

  bool _isCaller = false;
  bool _remoteSet = false;
  bool _answerApplying = false;
  bool _finished = false;

  final List<RTCIceCandidate> _pending = [];

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _candSub;
  Timer? _ringTimer;

  CollectionReference<Map<String, dynamic>> get _callsRef =>
      _db.collection('couples').doc(coupleId).collection('calls');

  Future<void> init() async {
    await remoteRenderer.initialize();
  }

  Future<String> _myName() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Please log in first.');
    }

    final doc = await _db.collection('users').doc(user.uid).get();

    var name = ((doc.data()?['name'] as String?) ?? '').trim();

    if (name.isEmpty) name = 'Your partner';
    if (name.length > 30) name = name.substring(0, 30);

    return name;
  }

  // ---------------------------------------------------------------
  // PEER CONNECTION
  // ---------------------------------------------------------------

  Future<void> _setupPeer(String candidateCollection) async {
    final pc = await createPeerConnection(_config);
    _pc = pc;

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    for (final track in _localStream!.getAudioTracks()) {
      await pc.addTrack(track, _localStream!);
    }

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      final c = candidate.candidate;

      if (c == null || c.isEmpty) return;

      _pushCandidate(candidateCollection, {
        'candidate': c,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
      }
    };

    pc.onIceConnectionState = (RTCIceConnectionState state) {
      if (_finished) return;

      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          _ringTimer?.cancel();

          if (status.value != CallStatus.connected) {
            connectedAt = DateTime.now();
            status.value = CallStatus.connected;
          }
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _finish('Connection failed. Please try again.');
          break;
        default:
          break;
      }
    };
  }

  Future<void> _pushCandidate(
    String collection,
    Map<String, dynamic> data,
  ) async {
    try {
      await _callRef?.collection(collection).add(data);
    } catch (_) {}
  }

  Future<void> _addCandidate(RTCIceCandidate candidate) async {
    try {
      await _pc?.addCandidate(candidate);
    } catch (e) {
      debugPrint('addCandidate failed: $e');
    }
  }

  Future<void> _flushPending() async {
    _remoteSet = true;

    final queued = List<RTCIceCandidate>.from(_pending);
    _pending.clear();

    for (final candidate in queued) {
      await _addCandidate(candidate);
    }
  }

  // ---------------------------------------------------------------
  // SIGNALING LISTENERS
  // ---------------------------------------------------------------

  void _listenCandidates(String collection) {
    _candSub = _callRef!.collection(collection).snapshots().listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;

        final d = change.doc.data();

        if (d == null) continue;

        final candidate = RTCIceCandidate(
          d['candidate'] as String?,
          d['sdpMid'] as String?,
          d['sdpMLineIndex'] as int?,
        );

        if (_remoteSet) {
          _addCandidate(candidate);
        } else {
          _pending.add(candidate);
        }
      }
    }, onError: (_) {});
  }

  void _listenCall() {
    _callSub = _callRef!.snapshots().listen((snap) async {
      if (_finished) return;

      final data = snap.data();

      if (data == null) return;

      final st = (data['status'] as String?) ?? '';
      final answer = data['answer'];

      // The caller applies the answer once the partner accepts.
      if (_isCaller && !_answerApplying && answer is Map && _pc != null) {
        _answerApplying = true;

        try {
          await _pc!.setRemoteDescription(
            RTCSessionDescription(
              answer['sdp'] as String?,
              answer['type'] as String?,
            ),
          );

          await _flushPending();
          _ringTimer?.cancel();

          if (!_finished && status.value == CallStatus.calling) {
            status.value = CallStatus.connecting;
          }
        } catch (e) {
          _finish('Could not connect the call.');
        }
      }

      if (st == 'declined') {
        _finish('Call declined');
      } else if (st == 'missed') {
        _finish('No answer');
      } else if (st == 'ended') {
        _finish('Call ended');
      }
    }, onError: (_) {});
  }

  // ---------------------------------------------------------------
  // CALLER
  // ---------------------------------------------------------------

  Future<String> startCall() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Please log in first.');
    }

    final name = await _myName();

    final callRef = _callsRef.doc();
    _callRef = callRef;
    _isCaller = true;

    await _setupPeer('callerCandidates');

    final offer = await _pc!.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 0,
    });

    await _pc!.setLocalDescription(offer);

    await callRef.set({
      'callerUid': user.uid,
      'callerName': name,
      'status': 'ringing',
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'createdAt': FieldValue.serverTimestamp(),
    });

    status.value = CallStatus.calling;

    _listenCall();
    _listenCandidates('calleeCandidates');

    _ringTimer = Timer(const Duration(seconds: 45), () async {
      if (_finished || status.value != CallStatus.calling) return;

      try {
        await _callRef?.update({
          'status': 'missed',
          'endedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      _finish('No answer');
    });

    return callRef.id;
  }

  // ---------------------------------------------------------------
  // RECEIVER
  // ---------------------------------------------------------------

  // Watch an incoming call while it is still ringing.
  Future<void> watchIncoming(String callId) async {
    _callRef = _callsRef.doc(callId);
    _isCaller = false;
    status.value = CallStatus.ringing;
    _listenCall();
  }

  Future<void> acceptCall() async {
    final callRef = _callRef;

    if (callRef == null) {
      throw Exception('No call to answer.');
    }

    final snap = await callRef.get();
    final data = snap.data();

    if (data == null || data['status'] != 'ringing') {
      throw Exception('This call is no longer available.');
    }

    final offer = data['offer'];

    if (offer is! Map) {
      throw Exception('The call offer is missing.');
    }

    status.value = CallStatus.connecting;

    await _setupPeer('calleeCandidates');

    await _pc!.setRemoteDescription(
      RTCSessionDescription(
        offer['sdp'] as String?,
        offer['type'] as String?,
      ),
    );

    _remoteSet = true;

    final answer = await _pc!.createAnswer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 0,
    });

    await _pc!.setLocalDescription(answer);

    await callRef.update({
      'status': 'accepted',
      'answer': {'sdp': answer.sdp, 'type': answer.type},
    });

    _listenCandidates('callerCandidates');
  }

  Future<void> declineCall() async {
    try {
      await _callRef?.update({
        'status': 'declined',
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    _finish('Call declined');
  }

  // ---------------------------------------------------------------
  // BOTH SIDES
  // ---------------------------------------------------------------

  Future<void> hangUp() async {
    if (_finished) return;

    try {
      await _callRef?.update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    _finish('Call ended');
  }

  void toggleMute() {
    muted.value = !muted.value;

    final tracks = _localStream?.getAudioTracks() ?? <MediaStreamTrack>[];

    for (final track in tracks) {
      track.enabled = !muted.value;
    }
  }

  void _finish(String reason) {
    if (_finished) return;

    _finished = true;
    endReason = reason;

    _ringTimer?.cancel();
    _callSub?.cancel();
    _candSub?.cancel();

    unawaited(_closeMedia());

    status.value = CallStatus.ended;
  }

  Future<void> _closeMedia() async {
    final stream = _localStream;
    final pc = _pc;

    _localStream = null;
    _pc = null;

    try {
      stream?.getTracks().forEach((track) => track.stop());
      await stream?.dispose();
    } catch (_) {}

    try {
      await pc?.close();
    } catch (_) {}
  }

  Future<void> dispose() async {
    if (!_finished) {
      _finished = true;
      _ringTimer?.cancel();
      _callSub?.cancel();
      _candSub?.cancel();
      await _closeMedia();
    }

    try {
      remoteRenderer.srcObject = null;
      await remoteRenderer.dispose();
    } catch (_) {}

    status.dispose();
    muted.dispose();
  }
}