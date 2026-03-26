import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'onboarding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drift',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1A1A)),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF9F9F9),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const OnboardingCheck();
        }

        return const LoginPage();
      },
    );
  }
}

class OnboardingCheck extends StatelessWidget {
  const OnboardingCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF9F9F9),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final onboardingComplete = data?['onboardingComplete'] ?? false;
        final isDarkMode = data?['isDarkMode'] ?? false;

        if (!onboardingComplete) {
          return OnboardingFlow();
        }

        return HomePage(isDarkMode: isDarkMode);
      },
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  Future<void> signInWithGoogle() async {
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      final userCredential =
          await FirebaseAuth.instance.signInWithPopup(googleProvider);

      final user = userCredential.user;
      if (user == null) return;

      final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snapshot = await doc.get();

      if (!snapshot.exists) {
        await doc.set({
          'uid': user.uid,
          'displayName': user.displayName,
          'photoUrl': user.photoURL,
          'followers': 0,
          'following': 0,
          'onboardingComplete': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Login error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Drift',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'find your people',
              style: TextStyle(fontSize: 15, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 48),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: signInWithGoogle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Continue with Google',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final bool isDarkMode;
  const HomePage({super.key, this.isDarkMode = false});

  Color get bg => isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;
  Color get surface => isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF9F9F9);
  Color get text => isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
  Color get subtext => isDarkMode ? const Color(0xFF8E8E93) : const Color(0xFF888888);
  Color get divider => isDarkMode ? const Color(0xFF3A3A3C) : const Color(0xFFEEEEEE);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            centerTitle: true,
            title: Text('Drift',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: text)),
            actions: [
              IconButton(
                icon: Icon(Icons.logout, color: subtext, size: 20),
                onPressed: () => FirebaseAuth.instance.signOut(),
              )
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: divider),
            ),
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .orderBy('createdAt', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: text));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Nothing here yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: text)),
                      const SizedBox(height: 6),
                      Text('Be the first to post',
                          style: TextStyle(fontSize: 13, color: subtext)),
                    ],
                  ),
                );
              }

              final posts = snapshot.data!.docs;
              return ListView.separated(
                itemCount: posts.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: divider),
                itemBuilder: (context, index) {
                  final d = posts[index].data() as Map<String, dynamic>;
                  return _PostTile(
                    username: d['username'] ?? 'user',
                    content: d['content'] ?? '',
                    timestamp: d['createdAt'],
                    isDarkMode: isDarkMode,
                    text: text,
                    subtext: subtext,
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {},
            backgroundColor: text,
            foregroundColor: bg,
            elevation: 0,
            child: const Icon(Icons.add, size: 22),
          ),
        );
      },
    );
  }
}

class _PostTile extends StatelessWidget {
  final String username;
  final String content;
  final dynamic timestamp;
  final bool isDarkMode;
  final Color text;
  final Color subtext;

  const _PostTile({
    required this.username,
    required this.content,
    this.timestamp,
    required this.isDarkMode,
    required this.text,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isDarkMode ? const Color(0xFF3A3A3C) : const Color(0xFFEEEEEE),
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: text),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@$username',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: text)),
                const SizedBox(height: 4),
                Text(content, style: TextStyle(fontSize: 14, color: text, height: 1.4)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.favorite_border, size: 18, color: subtext),
                    const SizedBox(width: 16),
                    Icon(Icons.chat_bubble_outline, size: 18, color: subtext),
                    const SizedBox(width: 16),
                    Icon(Icons.repeat, size: 18, color: subtext),
                    const SizedBox(width: 16),
                    Icon(Icons.share_outlined, size: 18, color: subtext),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}