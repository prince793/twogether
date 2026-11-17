import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.partnerName = 'Your partner'});

  final String partnerName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final String? _myUid = FirebaseAuth.instance.currentUser?.uid;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late final Future<Stream<QuerySnapshot<Map<String, dynamic>>>>
      _streamFuture;

  static const Color pink = Color(0xFFFFA9C9);
  static const Color lavender = Color(0xFFB9A7F8);
  static const Color background = Color(0xFFFFF5FA);
  static const Color darkText = Color(0xFF59465D);

  @override
  void initState() {
    super.initState();
    _streamFuture = _chatService.getMessageStream();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Something went wrong: ${error.toString().replaceFirst('Exception: ', '')}',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();

    if (text.isEmpty) return;

    _controller.clear();
    _focusNode.requestFocus();

    try {
      await _chatService.sendMessage(text);
    } catch (error) {
      if (!mounted) return;

      // Put the text back so nothing is lost.
      if (_controller.text.isEmpty) {
        _controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }

      _showError(error);
    }
  }

  Future<void> _confirmUnsend(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          title: const Text(
            'Unsend message?',
            style: TextStyle(
              color: darkText,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'This message will be removed for both of you.',
            style: TextStyle(color: Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: pink,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text('Unsend'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _chatService.deleteMessage(messageId);
    } catch (error) {
      _showError(error);
    }
  }

  DateTime _dateOf(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    return createdAt is Timestamp ? createdAt.toDate() : DateTime.now();
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';

    return DateFormat('EEEE, MMM d').format(date);
  }

  Widget _dateHeader(DateTime date) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: lavender.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _dayLabel(date),
          style: const TextStyle(
            color: darkText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _messageItem(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool showDate,
  ) {
    final data = doc.data();
    final mine = data['fromUid'] == _myUid;
    final text = (data['text'] as String?) ?? '';
    final createdAt = data['createdAt'];

    final time = createdAt is Timestamp
        ? DateFormat('h:mm a').format(createdAt.toDate())
        : 'Sending...';

    final bubble = GestureDetector(
      onLongPress: mine ? () => _confirmUnsend(doc.id) : null,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: mine ? pink : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: (mine ? pink : lavender).withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: darkText,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: darkText.withValues(alpha: 0.55),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      children: [
        if (showDate) _dateHeader(_dateOf(data)),
        Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: bubble,
          ),
        ),
      ],
    );
  }

  Widget _messageList() {
    return FutureBuilder<Stream<QuerySnapshot<Map<String, dynamic>>>>(
      future: _streamFuture,
      builder: (context, streamSnapshot) {
        if (streamSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load messages.\n${streamSnapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: darkText),
              ),
            ),
          );
        }

        if (!streamSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: lavender),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: streamSnapshot.data,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Unable to load messages.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: darkText),
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: lavender),
              );
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('💌', style: TextStyle(fontSize: 60)),
                      const SizedBox(height: 12),
                      Text(
                        'Say hi to ${widget.partnerName}! 💗',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: darkText,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // The list is newest-first and reversed, so the latest
            // message sits at the bottom, right above the input bar.
            return ListView.builder(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final isOldest = index == docs.length - 1;

                final showDate = isOldest ||
                    !_sameDay(
                      _dateOf(doc.data()),
                      _dateOf(docs[index + 1].data()),
                    );

                return _messageItem(doc, showDate);
              },
            );
          },
        );
      },
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        color: background,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLength: ChatService.maxLength,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _send(),
                style: const TextStyle(color: darkText),
                decoration: InputDecoration(
                  hintText: 'Message ${widget.partnerName}...',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: pink,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _send,
                child: const Padding(
                  padding: EdgeInsets.all(13),
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.partnerName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Text(
              'Our little chat 💗',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _messageList()),
          _inputBar(),
        ],
      ),
    );
  }
}