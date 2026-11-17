import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/pet_service.dart';
import '../widgets/sprite_pet.dart';

class PetScreen extends StatefulWidget {
  const PetScreen({super.key});

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> {
  final PetService _petService = PetService();

  late Future<Stream<DocumentSnapshot<Map<String, dynamic>>>> _petStreamFuture;

  bool _isLoading = false;

  static const Color pink = Color(0xFFFFA9C9);
  static const Color lavender = Color(0xFFB9A7F8);
  static const Color background = Color(0xFFFFF5FA);
  static const Color darkText = Color(0xFF59465D);

  @override
  void initState() {
    super.initState();
    _petStreamFuture = _preparePet();
  }

  Future<Stream<DocumentSnapshot<Map<String, dynamic>>>> _preparePet() async {
    await _petService.initializePet();
    return _petService.getPetStream();
  }

  Future<void> _performAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await action();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
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
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showRenameDialog(String currentName) async {
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          title: const Text(
            'Rename your pet',
            style: TextStyle(
              color: darkText,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 20,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: darkText),
            decoration: InputDecoration(
              hintText: 'Enter a name',
              filled: true,
              fillColor: background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (value) =>
                Navigator.of(dialogContext).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: lavender,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName == null || newName.isEmpty || newName == currentName) {
      return;
    }

    if (!mounted) return;

    await _performAction(
      () => _petService.renamePet(newName),
      'Your pet is now called $newName!',
    );
  }

  int _readStat(dynamic value) {
    if (value is num) return value.toInt();
    return 0;
  }

  Widget _statBar({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    final safeValue = value.clamp(0, 100);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: darkText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '$safeValue%',
                style: const TextStyle(
                  color: darkText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: safeValue / 100,
              minHeight: 11,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required String emoji,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: darkText,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            vertical: 15,
            horizontal: 5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 25)),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPet(Map<String, dynamic> data) {
    final hunger = _readStat(data['hunger']);
    final happiness = _readStat(data['happiness']);
    final energy = _readStat(data['energy']);
    final xp = _readStat(data['xp']);
    final level = _readStat(data['level']);

    final rawName = ((data['name'] as String?) ?? '').trim();
    final petName = rawName.isEmpty ? 'Mochi' : rawName;

    final species = (data['species'] as String?) ?? 'cat';
    String anim;
    String message;

    if (hunger < 25) {
      anim = 'idle';
      message = '$petName is hungry! Feed your little friend.';
    } else if (energy < 25) {
      anim = 'sleep';
      message = '$petName is sleepy. Let $petName rest!';
    } else if (happiness < 25) {
      anim = 'idle';
      message = '$petName misses you. Play together!';
    } else {
      anim = 'happy';
      message = '$petName is happy because you are together!';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 8),

          const Text(
            'OUR LITTLE WORLD',
            style: TextStyle(
              color: lavender,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Meet $petName!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: darkText,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Your shared little companion',
            style: TextStyle(color: Colors.black54),
          ),

          const SizedBox(height: 25),

          // PET DISPLAY
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFD9E8),
                  Color(0xFFE9DDFF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              children: [
                Container(
                  width: 185,
                  height: 185,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: lavender.withValues(alpha: 0.2),
                        blurRadius: 25,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: SpritePet(
                      species: species,
                      animation: anim,
                      displaySize: 130,
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // PET NAME + RENAME BUTTON
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        petName.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: darkText,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Rename',
                      onPressed: _isLoading
                          ? null
                          : () => _showRenameDialog(petName),
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: lavender,
                        size: 22,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 2),

                Text(
                  'Level $level • $xp XP',
                  style: const TextStyle(
                    color: darkText,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 13),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: darkText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // PET STATS
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: pink.withValues(alpha: 0.12),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${petName.toUpperCase()}\'S STATUS',
                  style: const TextStyle(
                    color: darkText,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 12),

                _statBar(
                  label: 'Hunger',
                  value: hunger,
                  icon: Icons.restaurant,
                  color: Colors.orange,
                ),

                _statBar(
                  label: 'Happiness',
                  value: happiness,
                  icon: Icons.favorite,
                  color: pink,
                ),

                _statBar(
                  label: 'Energy',
                  value: energy,
                  icon: Icons.bolt,
                  color: lavender,
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'TAKE CARE OF ${petName.toUpperCase()}',
              style: const TextStyle(
                color: darkText,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              _actionButton(
                label: 'FEED',
                emoji: '🍓',
                color: const Color(0xFFFFD6A5),
                onPressed: () => _performAction(
                  _petService.feedPet,
                  '$petName enjoyed the yummy food!',
                ),
              ),

              const SizedBox(width: 10),

              _actionButton(
                label: 'PLAY',
                emoji: '🎾',
                color: const Color(0xFFC8F2E5),
                onPressed: () => _performAction(
                  _petService.playWithPet,
                  '$petName had fun playing with you!',
                ),
              ),

              const SizedBox(width: 10),

              _actionButton(
                label: 'SLEEP',
                emoji: '🌙',
                color: const Color(0xFFE4D9FF),
                onPressed: () => _performAction(
                  _petService.letPetSleep,
                  'Good night, $petName! Rest well.',
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'CHOOSE ${petName.toUpperCase()}\'S LOOK',
              style: const TextStyle(
                color: darkText,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: SpritePet.species12.map((s) {
              final selected = s == species;

              return GestureDetector(
                onTap: _isLoading || selected
                    ? null
                    : () => _performAction(
                          () => _petService.changeSpecies(s),
                          '$petName is now a $s!',
                        ),
                child: Container(
                  width: 72,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? lavender.withValues(alpha: 0.2)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? lavender : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      SpritePet(
                        species: s,
                        animation: 'idle',
                        sheetSize: 32,
                        displaySize: 48,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s[0].toUpperCase() + s.substring(1),
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
            }).toList(),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(color: lavender),
            ),

          const SizedBox(height: 15),

          Text(
            'Every little moment together makes $petName happy. 💗',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 20),
        ],
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
        title: const Text(
          'Our Pet',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<
          Stream<DocumentSnapshot<Map<String, dynamic>>>>(
        future: _petStreamFuture,
        builder: (context, streamSnapshot) {
          if (streamSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load your pet.\n${streamSnapshot.error}',
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

          return StreamBuilder<
              DocumentSnapshot<Map<String, dynamic>>>(
            stream: streamSnapshot.data,
            builder: (context, petSnapshot) {
              if (petSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Unable to load pet data.\n${petSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!petSnapshot.hasData ||
                  !petSnapshot.data!.exists) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: lavender,
                  ),
                );
              }

              final data = petSnapshot.data!.data();

              if (data == null) {
                return const Center(
                  child: Text('Pet data is empty.'),
                );
              }

              return _buildPet(data);
            },
          );
        },
      ),
    );
  }
}