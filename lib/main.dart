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

class HomePage extends StatefulWidget {
  final bool isDarkMode;
  const HomePage({super.key, this.isDarkMode = false});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  Color get bg => widget.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;
  Color get sidebarBg => widget.isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF9F9F9);
  Color get text => widget.isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
  Color get subtext => widget.isDarkMode ? const Color(0xFF8E8E93) : const Color(0xFF888888);
  Color get dividerColor => widget.isDarkMode ? const Color(0xFF3A3A3C) : const Color(0xFFEEEEEE);

  final List<Widget> _pages = const [
    _FeedPage(),
    _PlaceholderPage(icon: Icons.search, label: 'Search'),
    _PlaceholderPage(icon: Icons.notifications_none, label: 'Activity'),
    _PlaceholderPage(icon: Icons.mail_outline, label: 'Messages'),
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: bg,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 64,
            color: sidebarBg,
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Logo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('D',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: text)),
                ),
                const SizedBox(height: 28),
                // Nav icons
                _SidebarIcon(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  selected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                  color: text,
                  subtext: subtext,
                ),
                const SizedBox(height: 4),
                _SidebarIcon(
                  icon: Icons.search,
                  activeIcon: Icons.search,
                  selected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                  color: text,
                  subtext: subtext,
                ),
                const SizedBox(height: 4),
                _SidebarIcon(
                  icon: Icons.notifications_none,
                  activeIcon: Icons.notifications,
                  selected: _selectedIndex == 2,
                  onTap: () => setState(() => _selectedIndex = 2),
                  color: text,
                  subtext: subtext,
                ),
                const SizedBox(height: 4),
                _SidebarIcon(
                  icon: Icons.mail_outline,
                  activeIcon: Icons.mail,
                  selected: _selectedIndex == 3,
                  onTap: () => setState(() => _selectedIndex = 3),
                  color: text,
                  subtext: subtext,
                ),
                const Spacer(),
                // Settings
                _SidebarIcon(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  selected: false,
                  onTap: () {},
                  color: text,
                  subtext: subtext,
                ),
                const SizedBox(height: 8),
                // Divider above pfp
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Divider(height: 1, color: dividerColor),
                ),
                const SizedBox(height: 12),
                // Profile picture
                GestureDetector(
                  onTap: () {},
                  child: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .get(),
                    builder: (context, snapshot) {
                      final data = snapshot.data?.data() as Map<String, dynamic>?;
                      final photoUrl = data?['photoUrl'] as String?;
                      return CircleAvatar(
                        radius: 16,
                        backgroundColor: dividerColor,
                        backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl == null || photoUrl.isEmpty
                            ? Text(
                                (data?['username'] ?? 'U')[0].toUpperCase(),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: text),
                              )
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          // Vertical divider
          VerticalDivider(width: 1, thickness: 1, color: dividerColor),
          // Main content
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}

class _SidebarIcon extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final Color subtext;

  const _SidebarIcon({
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
    required this.color,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
        child: Icon(
          selected ? activeIcon : icon,
          size: 22,
          color: selected ? color : subtext,
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlaceholderPage({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: const Color(0xFF888888)),
          const SizedBox(height: 10),
          Text(label,
              style: const TextStyle(fontSize: 15, color: Color(0xFF888888))),
        ],
      ),
    );
  }
}

class _FeedPage extends StatelessWidget {
  const _FeedPage();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Nothing here yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                Text('Be the first to post',
                    style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
              ],
            ),
          );
        }
        final posts = snapshot.data!.docs;
        return ListView.separated(
          itemCount: posts.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
          itemBuilder: (context, index) {
            final d = posts[index].data() as Map<String, dynamic>;
            return _PostTile(
              username: d['username'] ?? 'user',
              content: d['content'] ?? '',
              timestamp: d['createdAt'],
            );
          },
        );
      },
    );
  }
}

class _PostTile extends StatelessWidget {
  final String username;
  final String content;
  final dynamic timestamp;

  const _PostTile({
    required this.username,
    required this.content,
    this.timestamp,
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
            backgroundColor: const Color(0xFFEEEEEE),
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@$username',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A))),
                const SizedBox(height: 4),
                Text(content,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1A1A1A),
                        height: 1.4)),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(Icons.favorite_border, size: 18, color: Color(0xFF888888)),
                    SizedBox(width: 16),
                    Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF888888)),
                    SizedBox(width: 16),
                    Icon(Icons.repeat, size: 18, color: Color(0xFF888888)),
                    SizedBox(width: 16),
                    Icon(Icons.share_outlined, size: 18, color: Color(0xFF888888)),
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