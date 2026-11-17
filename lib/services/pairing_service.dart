
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PairingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Please log in first.');
    }

    return user.uid;
  }

  // Generate a unique 8-digit pairing code.
  Future<String> createPairingCode() async {
    final uid = _uid;
    final userRef = _db.collection('users').doc(uid);

    for (int attempt = 0; attempt < 5; attempt++) {
      final code =
          (Random.secure().nextInt(90000000) + 10000000).toString();

      final codeRef = _db.collection('pairingCodes').doc(code);

      final created = await _db.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        final codeSnapshot = await transaction.get(codeRef);

        if (!userSnapshot.exists) {
          throw Exception('Your user profile was not found.');
        }

        final userData = userSnapshot.data()!;

        if (userData['coupleId'] != null) {
          throw Exception('You are already connected to a partner.');
        }

        if (codeSnapshot.exists) {
          return false;
        }

        transaction.set(codeRef, {
          'ownerUid': uid,
          'ownerName': userData['name'] ?? 'Your partner',
          'used': false,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(minutes: 10)),
          ),
        });

        return true;
      });

      if (created) return code;
    }

    throw Exception('Could not generate a code. Please try again.');
  }

  // Join using your partner's pairing code.
  Future<String> joinWithCode(String enteredCode) async {
    final uid = _uid;
    final code = enteredCode.trim();

    if (!RegExp(r'^\d{8}$').hasMatch(code)) {
      throw Exception('Please enter a valid 8-digit code.');
    }

    final codeRef = _db.collection('pairingCodes').doc(code);
    final myRef = _db.collection('users').doc(uid);
    final coupleRef = _db.collection('couples').doc();

    return _db.runTransaction((transaction) async {
      // Read the code and current user's profile.
      final codeSnapshot = await transaction.get(codeRef);
      final mySnapshot = await transaction.get(myRef);

      if (!codeSnapshot.exists) {
        throw Exception('Pairing code not found.');
      }

      if (!mySnapshot.exists) {
        throw Exception('Your user profile was not found.');
      }

      final codeData = codeSnapshot.data()!;
      final myData = mySnapshot.data()!;

      final ownerUid = codeData['ownerUid'] as String;
      final ownerName = codeData['ownerName'] as String? ?? 'Your partner';
      final myName = myData['name'] as String? ?? 'Partner';

      if (codeData['used'] == true) {
        throw Exception('This pairing code has already been used.');
      }

      final expiresAt = codeData['expiresAt'] as Timestamp;

      if (!expiresAt.toDate().isAfter(DateTime.now())) {
        throw Exception('This pairing code has expired.');
      }

      if (ownerUid == uid) {
        throw Exception('You cannot use your own pairing code.');
      }

      if (myData['coupleId'] != null) {
        throw Exception('You are already connected to a partner.');
      }

      // Create the couple document.
      transaction.set(coupleRef, {
        'members': [ownerUid, uid],
        'pairingCode': code,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Claim the pairing code.
      transaction.update(codeRef, {
        'used': true,
        'claimedBy': uid,
      });

      // Update the code owner's profile.
      transaction.update(
        _db.collection('users').doc(ownerUid),
        {
          'coupleId': coupleRef.id,
          'partnerUid': uid,
          'partnerName': myName,
        },
      );

      // Update the joining user's profile.
      transaction.update(myRef, {
        'coupleId': coupleRef.id,
        'partnerUid': ownerUid,
        'partnerName': ownerName,
      });

      return coupleRef.id;
    });
  }
}
