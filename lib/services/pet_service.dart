import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> _getCoupleId() async {
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

    final coupleId = userDoc.data()?['coupleId'];

    if (coupleId == null) {
      throw Exception('Please connect with your partner first.');
    }

    return coupleId as String;
  }

  Future<DocumentReference<Map<String, dynamic>>> _getPetRef() async {
    final coupleId = await _getCoupleId();

    return _db
        .collection('couples')
        .doc(coupleId)
        .collection('pet')
        .doc('state');
  }

  Future<void> initializePet() async {
    final petRef = await _getPetRef();

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(petRef);

      if (snapshot.exists) return;

      transaction.set(petRef, {
        'name': 'Mochi',
        'species': 'cat',
        'hunger': 80,
        'happiness': 80,
        'energy': 100,
        'xp': 0,
        'level': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<Stream<DocumentSnapshot<Map<String, dynamic>>>>
      getPetStream() async {
    final petRef = await _getPetRef();
    return petRef.snapshots();
  }

  Future<void> changeSpecies(String species) async {
    final petRef = await _getPetRef();

    await petRef.update({
      'species': species,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> renamePet(String newName) async {
    final name = newName.trim();

    if (name.isEmpty) {
      throw Exception('Please enter a name.');
    }

    if (name.length > 20) {
      throw Exception('Name must be 20 characters or less.');
    }

    final petRef = await _getPetRef();

    await petRef.update({
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> feedPet() async {
    await _updatePet(
      hungerChange: 25,
      happinessChange: 5,
      energyChange: 0,
    );
  }

  Future<void> playWithPet() async {
    await _updatePet(
      hungerChange: -10,
      happinessChange: 20,
      energyChange: -15,
    );
  }

  Future<void> letPetSleep() async {
    await _updatePet(
      hungerChange: -5,
      happinessChange: 0,
      energyChange: 35,
    );
  }

  Future<void> _updatePet({
    required int hungerChange,
    required int happinessChange,
    required int energyChange,
  }) async {
    final petRef = await _getPetRef();

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(petRef);

      if (!snapshot.exists) {
        throw Exception('Mochi has not been initialized yet.');
      }

      final data = snapshot.data()!;

      int updateStat(dynamic value, int change) {
        final current = (value as num?)?.toInt() ?? 0;
        return (current + change).clamp(0, 100);
      }

      final newHunger = updateStat(data['hunger'], hungerChange);
      final newHappiness =
          updateStat(data['happiness'], happinessChange);
      final newEnergy = updateStat(data['energy'], energyChange);

      final newXp = ((data['xp'] as num?)?.toInt() ?? 0) + 10;
      final newLevel = (newXp ~/ 100) + 1;

      transaction.update(petRef, {
        'hunger': newHunger,
        'happiness': newHappiness,
        'energy': newEnergy,
        'xp': newXp,
        'level': newLevel,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}