import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int maxLength = 500;

  Future<Map<String, String>> _getProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Please log in first.');
    }

    final userDoc = await _db
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      throw Exception('User profile not found.');
    }

    final data = userDoc.data()!;
    final coupleId = data['coupleId'];

    if (coupleId == null) {
      throw Exception('Please connect with your partner first.');
    }

    var name = ((data['name'] as String?) ?? '').trim();

    if (name.isEmpty) name = 'Your partner';
    if (name.length > 30) name = name.substring(0, 30);

    return {
      'uid': user.uid,
      'coupleId': coupleId as String,
      'name': name,
    };
  }

  Future<Stream<QuerySnapshot<Map<String, dynamic>>>>
      getMessageStream() async {
    final profile = await _getProfile();

    return _db
        .collection('couples')
        .doc(profile['coupleId']!)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  Future<void> sendMessage(String text) async {
    final message = text.trim();

    if (message.isEmpty) {
      throw Exception('Please type a message.');
    }

    if (message.length > maxLength) {
      throw Exception('Message must be $maxLength characters or less.');
    }

    final profile = await _getProfile();

    await _db
        .collection('couples')
        .doc(profile['coupleId']!)
        .collection('messages')
        .add({
      'fromUid': profile['uid'],
      'fromName': profile['name'],
      'text': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage(String messageId) async {
    final profile = await _getProfile();

    await _db
        .collection('couples')
        .doc(profile['coupleId']!)
        .collection('messages')
        .doc(messageId)
        .delete();
  }
}