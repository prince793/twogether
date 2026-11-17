import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'services/pairing_service.dart';
import 'screens/pet_screen.dart';
import 'screens/hug_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/call_screen.dart';
import 'widgets/call_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const TwoGetherApp());
}

// COLORS
const pink = Color(0xFFFFA9C9);
const lavender = Color(0xFFB9A7F8);
const darkText = Color(0xFF59465D);
const background = Color(0xFFFFF5FA);

// APP
class TwoGetherApp extends StatelessWidget {
  const TwoGetherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TWOGETHER',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: pink,
          primary: pink,
          secondary: lavender,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// AUTH GATE
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: pink),
            ),
          );
        }

        if (snapshot.data != null) {
          return const CallGate(child: DashboardScreen());
        }

        return const WelcomeScreen();
      },
    );
  }
}

// WELCOME SCREEN
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF0F6), Color(0xFFF0EBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 125,
                    width: 125,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: pink,
                      size: 75,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'TWOGETHER',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Two Hearts. One Little World.',
                    style: TextStyle(color: Color(0xFF9D829F)),
                  ),
                  const SizedBox(height: 45),
                  SizedBox(
                    width: 280,
                    height: 55,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: pink,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const RegistrationScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Create an Account',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 280,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: darkText,
                        side: const BorderSide(color: lavender),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Already have an account? Log In',
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Made with love, for two. 💗',
                    style: TextStyle(color: Color(0xFFB19CB7)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// REGISTRATION SCREEN
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() =>
      _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  bool showPassword = false;
  bool showConfirmPassword = false;
  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration fieldDecoration(
    String label,
    IconData icon, {
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: lavender),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFF2DDEA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: pink, width: 2),
      ),
    );
  }

  Future<void> registerAccount() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    UserCredential? credential;

    try {
      credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final user = credential.user!;

      await user.updateDisplayName(nameController.text.trim());

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'coupleId': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully! 💗'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered. Please log in.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          message = 'Password must be at least 6 characters.';
          break;
        default:
          message = e.message ?? 'Registration failed.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } on FirebaseException catch (e) {
      if (credential?.user != null) {
        await FirebaseAuth.instance.signOut();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database error: ${e.message ?? e.code}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: background,
        title: const Text(
          'Create Account',
          style: TextStyle(
            color: darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF5FA), Color(0xFFF0EBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: pink,
                        size: 65,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Start Your Love Story',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create your account and begin your little world together.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF9D829F)),
                      ),
                      const SizedBox(height: 30),

                      TextFormField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: fieldDecoration(
                          'Full Name',
                          Icons.person_outline,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: fieldDecoration(
                          'Email Address',
                          Icons.email_outlined,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email.';
                          }
                          if (!RegExp(
                            r'^[^@]+@[^@]+\.[^@]+$',
                          ).hasMatch(value.trim())) {
                            return 'Enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: passwordController,
                        obscureText: !showPassword,
                        decoration: fieldDecoration(
                          'Password',
                          Icons.lock_outline,
                          suffix: IconButton(
                            icon: Icon(
                              showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                showPassword = !showPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Password must be at least 6 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: !showConfirmPassword,
                        decoration: fieldDecoration(
                          'Confirm Password',
                          Icons.lock_reset_outlined,
                          suffix: IconButton(
                            icon: Icon(
                              showConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                showConfirmPassword =
                                    !showConfirmPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value != passwordController.text) {
                            return 'Passwords do not match.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      SizedBox(
                        height: 55,
                        child: FilledButton(
                          onPressed: isLoading ? null : registerAccount,
                          style: FilledButton.styleFrom(
                            backgroundColor: pink,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Create My Account 💗',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Two Hearts. One Little World.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFB19CB7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// LOGIN SCREEN
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool hidePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage('Please enter your email and password.');
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          message = 'Incorrect email or password.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;
        default:
          message = e.message ?? 'Login failed. Please try again.';
      }

      showMessage(message);
    } catch (e) {
      showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> forgotPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage('Enter your email address first.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      showMessage(
        'If an account exists for this email, a reset email will be sent.',
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') {
        showMessage('Please enter a valid email address.');
      } else {
        showMessage(
          'If an account exists for this email, a reset email will be sent.',
        );
      }
    } catch (e) {
      showMessage('Could not send the reset email. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Log In',
          style: TextStyle(color: darkText),
        ),
        backgroundColor: background,
        foregroundColor: darkText,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    color: pink,
                    size: 80,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Welcome Back!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your little world is waiting for you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF9D829F)),
                  ),
                  const SizedBox(height: 35),

                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: lavender,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: passwordController,
                    obscureText: hidePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: lavender,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            hidePassword = !hidePassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => login(),
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: forgotPassword,
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: darkText),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  SizedBox(
                    height: 55,
                    child: FilledButton(
                      onPressed: isLoading ? null : login,
                      style: FilledButton.styleFrom(
                        backgroundColor: pink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              'LOG IN',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// DASHBOARD SCREEN
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const WelcomeScreen();
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF0F6), Color(0xFFF0EBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: pink),
                );
              }

              if (snapshot.hasError) {
                return const Center(
                  child: Text('Unable to load your profile.'),
                );
              }

              final data = snapshot.data?.data()
                      as Map<String, dynamic>? ??
                  {};

              final name = data['name'] ??
                  user.displayName ??
                  'Love';

              final isPaired = data['coupleId'] != null;
              final partnerName =
                  data['partnerName'] ?? 'Your Partner';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TWOGETHER 💗',
                          style: TextStyle(
                            color: darkText,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            letterSpacing: 2,
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                          },
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: darkText,
                          ),
                          tooltip: 'Log out',
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    Text(
                      'Hello, $name! 💕',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Welcome to your little world together.',
                      style: TextStyle(
                        color: Color(0xFF9D829F),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // COUPLE CONNECTION CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: pink.withValues(alpha: 0.12),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            isPaired
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: pink,
                            size: 45,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isPaired
                                ? 'You are connected! 💗'
                                : 'Connect with your partner',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: darkText,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            isPaired
                                ? 'Your little world is shared with $partnerName.'
                                : 'Pair your accounts to start your little world together.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF9D829F),
                            ),
                          ),
                          const SizedBox(height: 18),

                          if (isPaired)
                            const Text(
                              '💕 BOTH ACCOUNTS CONNECTED 💕',
                              style: TextStyle(
                                color: Color(0xFFB477A2),
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const PairingScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.link_rounded),
                                label: const Text(
                                  'Connect with Partner',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: pink,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                    const Text(
                      'YOUR LITTLE WORLD',
                      style: TextStyle(
                        color: darkText,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // FIRST ROW
                    Row(
                      children: [
                        Expanded(
                          child: _featureCard(
                            icon: Icons.favorite_rounded,
                            title: 'Virtual Hugs',
                            subtitle: 'Send love',
                            color: pink,
                            onTap: () {
                              if (!isPaired) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Connect with your partner first! 💗',
                                    ),
                                  ),
                                );
                                return;
                              }

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HugScreen(
                                    partnerName: partnerName.toString(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _featureCard(
                            icon: Icons.pets_rounded,
                            title: 'Our Pet',
                            subtitle: 'Care together',
                            color: lavender,
                            onTap: () {
                              if (!isPaired) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Connect with your partner first! 💗',
                                    ),
                                  ),
                                );
                                return;
                              }

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PetScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // SECOND ROW
                    Row(
                      children: [
                        Expanded(
                          child: _featureCard(
                            icon: Icons.chat_bubble_rounded,
                            title: 'Messages',
                            subtitle: 'Talk anytime',
                            color: lavender,
                            onTap: () {
                              if (!isPaired) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Connect with your partner first! 💗',
                                    ),
                                  ),
                                );
                                return;
                              }

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    partnerName: partnerName.toString(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _featureCard(
                            icon: Icons.call_rounded,
                            title: 'Voice Calls',
                            subtitle: 'Hear each other',
                            color: pink,
                            onTap: () {
                              if (!isPaired) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Connect with your partner first! 💗',
                                    ),
                                  ),
                                );
                                return;
                              }

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  fullscreenDialog: true,
                                  builder: (_) => CallScreen(
                                    coupleId: data['coupleId'] as String,
                                    partnerName: partnerName.toString(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),
                    const Center(
                      child: Text(
                        'Made with love, for two. 💗',
                        style: TextStyle(
                          color: Color(0xFFB19CB7),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // CLICKABLE FEATURE CARD
  static Widget _featureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            vertical: 22,
            horizontal: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 35),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF9D829F),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// PAIRING SCREEN
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final PairingService pairingService = PairingService();
  final TextEditingController codeController =
      TextEditingController();

  String? generatedCode;
  bool isGenerating = false;
  bool isJoining = false;

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> generateCode() async {
    setState(() {
      isGenerating = true;
      generatedCode = null;
    });

    try {
      final code = await pairingService.createPairingCode();

      if (!mounted) return;

      setState(() {
        generatedCode = code;
      });
    } catch (e) {
      showMessage(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => isGenerating = false);
      }
    }
  }

  Future<void> joinPartner() async {
    if (codeController.text.trim().isEmpty) {
      showMessage('Please enter your partner\'s code.');
      return;
    }

    setState(() => isJoining = true);

    try {
      await pairingService.joinWithCode(
        codeController.text.trim(),
      );

      if (!mounted) return;

      showMessage('Successfully connected! 💗');
      Navigator.pop(context);
    } catch (e) {
      showMessage(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => isJoining = false);
      }
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Couple Pairing 💗',
          style: TextStyle(
            color: darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: background,
        foregroundColor: darkText,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF0F6), Color(0xFFF0EBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: pink),
              );
            }

            if (snapshot.hasError) {
              return const Center(
                child: Text('Unable to load your profile.'),
              );
            }

            final data = snapshot.data?.data()
                    as Map<String, dynamic>? ??
                {};

            final isPaired = data['coupleId'] != null;

            if (isPaired) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: pink,
                        size: 85,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'You are connected! 💕',
                        style: TextStyle(
                          color: darkText,
                          fontWeight: FontWeight.bold,
                          fontSize: 25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your partner is ${data['partnerName'] ?? 'your special someone'}.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF9D829F),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: pink,
                        size: 75,
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'Find Your Other Half',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: darkText,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Connect your account with your partner and build your little world together.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF9D829F),
                        ),
                      ),
                      const SizedBox(height: 35),

                      // GENERATE CODE CARD
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.qr_code_rounded,
                              color: lavender,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Create a Pairing Code',
                              style: TextStyle(
                                color: darkText,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Generate a code and share it with your partner. It expires after 10 minutes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF9D829F),
                                fontSize: 13,
                              ),
                            ),

                            if (generatedCode != null) ...[
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(15),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF0F6),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'YOUR PAIRING CODE',
                                      style: TextStyle(
                                        color: Color(0xFF9D829F),
                                        fontSize: 11,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SelectableText(
                                      generatedCode!,
                                      style: const TextStyle(
                                        color: darkText,
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Share this code with your partner.',
                                      style: TextStyle(
                                        color: Color(0xFF9D829F),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                onPressed: isGenerating
                                    ? null
                                    : generateCode,
                                style: FilledButton.styleFrom(
                                  backgroundColor: pink,
                                  foregroundColor: Colors.white,
                                ),
                                child: isGenerating
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : const Text('Generate My Code'),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 15,
                            ),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: Color(0xFF9D829F),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // JOIN CODE CARD
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.link_rounded,
                              color: lavender,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Enter Partner Code',
                              style: TextStyle(
                                color: darkText,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 15),
                            TextField(
                              controller: codeController,
                              keyboardType: TextInputType.number,
                              maxLength: 8,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                hintText: 'Enter 8-digit code',
                                counterText: '',
                                filled: true,
                                fillColor: const Color(0xFFFFF5FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                onPressed:
                                    isJoining ? null : joinPartner,
                                style: FilledButton.styleFrom(
                                  backgroundColor: lavender,
                                  foregroundColor: Colors.white,
                                ),
                                child: isJoining
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : const Text(
                                        'Connect to Partner 💗',
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}