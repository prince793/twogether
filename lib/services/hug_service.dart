import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HugService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const List<String> validTypes = [
    'hug',
    'cuddle',
    'kiss',
    'miss',
    'love',
  ];

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
      getHugStream() async {
    final profile = await _getProfile();

    return _db
        .collection('couples')
        .doc(profile['coupleId']!)
        .collection('hugs')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots();
  }

  Future<void> sendHug(String type) async {
    if (!validTypes.contains(type)) {
      throw Exception('Unknown hug type.');
    }

    final profile = await _getProfile();

    await _db
        .collection('couples')
        .doc(profile['coupleId']!)
        .collection('hugs')
        .add({
      'fromUid': profile['uid'],
      'fromName': profile['name'],
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}