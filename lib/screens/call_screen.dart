import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/call_service.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.coupleId,
    required this.partnerName,
    this.incomingCallId,
  });

  final String coupleId;
  final String partnerName;

  /// If this is set, we are answering a call. If it is null, we are calling.
  final String? incomingCallId;

  /// True while a call screen is on the screen (prevents double screens).
  static bool isOpen = false;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final CallService _service;
  Timer? _ticker;

  bool _closing = false;
  bool _accepting = false;
  bool _speakerOn = false;
  String? _error;

  static const Color pink = Color(0xFFFFA9C9);
  static const Color lavender = Color(0xFFB9A7F8);
  static const Color darkText = Color(0xFF59465D);

  bool get _isIncoming => widget.incomingCallId != null;

  @override
  void initState() {
    super.initState();

    CallScreen.isOpen = true;

    _service = CallService(coupleId: widget.coupleId);
    _service.status.addListener(_onStatusChanged);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _service.status.value == CallStatus.connected) {
        setState(() {});
      }
    });

    _start();
  }

  @override
  void dispose() {
    CallScreen.isOpen = false;

    _ticker?.cancel();
    _service.status.removeListener(_onStatusChanged);
    _service.dispose();

    super.dispose();
  }

  Future<void> _start() async {
    try {
      await _service.init();

      if (_isIncoming) {
        await _service.watchIncoming(widget.incomingCallId!);
      } else {
        await _service.startCall();
      }
    } catch (error) {
      _fail(error);
    }
  }

  String _friendly(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    final lower = text.toLowerCase();

    if (lower.contains('notallowed') ||
        lower.contains('permission') ||
        lower.contains('denied')) {
      return 'Microphone permission is needed to make calls.';
    }

    if (lower.contains('notfound')) {
      return 'No microphone was found.';
    }

    return text;
  }

  void _fail(Object error) {
    if (!mounted || _closing) return;

    setState(() => _error = _friendly(error));
    _closeSoon();
  }

  void _closeSoon() {
    if (_closing) return;

    _closing = true;

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _onStatusChanged() {
    if (!mounted) return;

    if (_service.status.value == CallStatus.ended && !_closing) {
      setState(() {});
      _closeSoon();
    }
  }

  Future<void> _accept() async {
    if (_accepting || _closing) return;

    setState(() => _accepting = true);

    try {
      await _service.acceptCall();
    } catch (error) {
      _fail(error);
      await _service.declineCall();
    }
  }

  Future<void> _decline() async {
    if (_closing) return;

    _closing = true;
    await _service.declineCall();

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _hangUp() async {
    if (_closing) return;

    _closing = true;
    await _service.hangUp();

    if (mounted) Navigator.of(context).pop();
  }

  void _handleBack() {
    if (_closing) {
      Navigator.of(context).pop();
      return;
    }

    final ringingIncoming = _isIncoming &&
        _service.status.value == CallStatus.ringing &&
        !_accepting;

    if (ringingIncoming) {
      _decline();
    } else {
      _hangUp();
    }
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _speakerOn = !_speakerOn);

    try {
      await Helper.setSpeakerphoneOn(_speakerOn);
    } catch (_) {}
  }

  String _duration() {
    final start = _service.connectedAt;

    if (start == null) return '00:00';

    final d = DateTime.now().difference(start);
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  String _statusText(CallStatus status) {
    if (_error != null) return _error!;

    switch (status) {
      case CallStatus.idle:
        return 'Starting...';
      case CallStatus.calling:
        return 'Calling...';
      case CallStatus.ringing:
        return _accepting ? 'Connecting...' : 'Incoming voice call';
      case CallStatus.connecting:
        return 'Connecting...';
      case CallStatus.connected:
        return _duration();
      case CallStatus.ended:
        return _service.endReason;
    }
  }

  Widget _roundButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    required String label,
    Color iconColor = Colors.white,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 3,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Icon(icon, color: iconColor, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: darkText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _controls(CallStatus status) {
    final ringingIncoming =
        _isIncoming && status == CallStatus.ringing && !_accepting;

    if (ringingIncoming) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _roundButton(
            icon: Icons.call_end_rounded,
            color: Colors.redAccent,
            label: 'Decline',
            onTap: _closing ? null : _decline,
          ),
          _roundButton(
            icon: Icons.call_rounded,
            color: Colors.green,
            label: 'Accept',
            onTap: _closing ? null : _accept,
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: _service.muted,
          builder: (context, isMuted, _) {
            return _roundButton(
              icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              color: isMuted ? darkText : Colors.white,
              iconColor: isMuted ? Colors.white : darkText,
              label: isMuted ? 'Unmute' : 'Mute',
              onTap: _closing ? null : _service.toggleMute,
            );
          },
        ),
        _roundButton(
          icon: Icons.call_end_rounded,
          color: Colors.redAccent,
          label: 'End',
          onTap: _closing ? null : _hangUp,
        ),
        if (kIsWeb)
          const SizedBox(width: 68)
        else
          _roundButton(
            icon: _speakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_down_rounded,
            color: _speakerOn ? darkText : Colors.white,
            iconColor: _speakerOn ? Colors.white : darkText,
            label: 'Speaker',
            onTap: _closing ? null : _toggleSpeaker,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.partnerName.trim().isEmpty
        ? '💗'
        : widget.partnerName.trim()[0].toUpperCase();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFD9E8), Color(0xFFE9DDFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: ValueListenableBuilder<CallStatus>(
              valueListenable: _service.status,
              builder: (context, status, _) {
                return Stack(
                  children: [
                    // Hidden player. It is needed so the partner's voice
                    // is played in the browser.
                    Positioned(
                      left: 0,
                      top: 0,
                      child: SizedBox(
                        width: 1,
                        height: 1,
                        child: RTCVideoView(_service.remoteRenderer),
                      ),
                    ),
                    Column(
                      children: [
                        const Spacer(flex: 2),
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: lavender.withValues(alpha: 0.3),
                                blurRadius: 30,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: pink,
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          widget.partnerName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: darkText,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            _statusText(status),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: darkText.withValues(alpha: 0.7),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(flex: 3),
                        _controls(status),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}