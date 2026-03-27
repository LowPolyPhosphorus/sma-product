import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';

// ─────────────────────────────────────────────
// Shell (sidebar + profile page side-by-side)
// ─────────────────────────────────────────────

class ProfileShell extends StatefulWidget {
  final bool isDarkMode;
  const ProfileShell({super.key, this.isDarkMode = false});

  @override
  State<ProfileShell> createState() => _ProfileShellState();
}

class _ProfileShellState extends State<ProfileShell> {
  Color get bg =>
      widget.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;
  Color get sidebarBg =>
      widget.isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF9F9F9);
  Color get text =>
      widget.isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
  Color get subtext =>
      widget.isDarkMode ? const Color(0xFF8E8E93) : const Color(0xFF888888);
  Color get dividerColor =>
      widget.isDarkMode ? const Color(0xFF3A3A3C) : const Color(0xFFEEEEEE);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: bg,
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────
          Container(
            width: 64,
            color: sidebarBg,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'D',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: text),
                  ),
                ),
                const SizedBox(height: 28),
                _SidebarIconBtn(
                  icon: Icons.home_outlined,
                  color: subtext,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 4),
                _SidebarIconBtn(
                    icon: Icons.search, color: subtext, onTap: () {}),
                const SizedBox(height: 4),
                _SidebarIconBtn(
                    icon: Icons.notifications_none,
                    color: subtext,
                    onTap: () {}),
                const SizedBox(height: 4),
                _SidebarIconBtn(
                    icon: Icons.mail_outline, color: subtext, onTap: () {}),
                const Spacer(),
                _SidebarIconBtn(
                    icon: Icons.settings_outlined,
                    color: subtext,
                    onTap: () {}),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Divider(height: 1, color: dividerColor),
                ),
                const SizedBox(height: 12),
                // Active-user avatar with border
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .get(),
                  builder: (context, snapshot) {
                    final data =
                        snapshot.data?.data() as Map<String, dynamic>?;
                    final photoUrl = data?['photoUrl'] as String? ?? '';
                    final username = data?['username'] as String? ?? 'U';
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: text, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: dividerColor,
                        backgroundImage: photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl.isEmpty
                            ? Text(
                                username[0].toUpperCase(),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: text),
                              )
                            : null,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: dividerColor),
          Expanded(child: ProfilePage(isDarkMode: widget.isDarkMode)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Sidebar icon button
// ─────────────────────────────────────────────

class _SidebarIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SidebarIconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Profile page (stream-driven, no hover state)
// ─────────────────────────────────────────────

class ProfilePage extends StatefulWidget {
  final bool isDarkMode;
  const ProfilePage({super.key, this.isDarkMode = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Color get bg =>
      widget.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;
  Color get text =>
      widget.isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
  Color get subtext =>
      widget.isDarkMode ? const Color(0xFF8E8E93) : const Color(0xFF888888);
  Color get dividerColor =>
      widget.isDarkMode ? const Color(0xFF3A3A3C) : const Color(0xFFEEEEEE);
  Color get cardBg =>
      widget.isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF9F9F9);
  Color get bioBg =>
      widget.isDarkMode ? const Color(0xFF3A3A3C) : const Color(0xFFEEEEEE);
  Color get bioBgHover =>
      widget.isDarkMode ? const Color(0xFF48484A) : const Color(0xFFE0E0E0);

  // ── Upload profile picture ──────────────────

  Future<void> _pickAndUploadPfp(String uid) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    try {
      final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/dvb8b4ogj/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = 'sma_uploads'
        ..fields['public_id'] = 'profile_$uid'
        ..files.add(http.MultipartFile.fromBytes('file', bytes,
            filename: 'profile.jpg'));
      final response = await request.send();
      final body = await response.stream.bytesToString();
      final json = jsonDecode(body);
      final url = json['secure_url'] as String?;
      if (url != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'photoUrl': url});
      }
    } catch (e) {
      debugPrint('Upload error: $e');
    }
  }

  // ── Edit bio dialog ─────────────────────────

  void _editBio(BuildContext context, String currentBio, String uid) {
    final controller = TextEditingController(text: currentBio);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardBg,
        title: Text(
          'Edit bio',
          style: TextStyle(
              color: text, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 150,
          style: TextStyle(color: text, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Tell people about yourself...',
            hintStyle: TextStyle(color: subtext),
            filled: true,
            fillColor: bioBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: subtext)),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({'bio': controller.text.trim()});
              if (context.mounted) Navigator.pop(context);
            },
            child: Text('Save',
                style: TextStyle(
                    color: text, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: text));
        }

        final data =
            snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final photoUrl = data['photoUrl'] as String? ?? '';
        final username = data['username'] as String? ?? 'user';
        final displayName = data['displayName'] as String? ?? '';
        final bio = data['bio'] as String? ?? '';
        final followers = data['followers'] ?? 0;
        final following = data['following'] ?? 0;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // ── Profile header (constrained + centered) ──
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 740),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: avatar + stats
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _HoverablePfp(
                              photoUrl: photoUrl,
                              username: username,
                              text: text,
                              dividerColor: dividerColor,
                              onTap: () => _pickAndUploadPfp(uid),
                            ),
                            const SizedBox(width: 64),
                            _StatColumn(
                                label: 'Posts',
                                value: '0',
                                text: text,
                                subtext: subtext),
                            const SizedBox(width: 40),
                            _StatColumn(
                                label: 'Followers',
                                value: followers.toString(),
                                text: text,
                                subtext: subtext),
                            const SizedBox(width: 40),
                            _StatColumn(
                                label: 'Following',
                                value: following.toString(),
                                text: text,
                                subtext: subtext),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Name + username
                        if (displayName.isNotEmpty)
                          Text(
                            displayName,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: text),
                          ),
                        Text(
                          '@$username',
                          style: TextStyle(fontSize: 16, color: subtext),
                        ),

                        const SizedBox(height: 12),

                        // Bio box (isolated hover widget)
                        _HoverableBioBox(
                          bio: bio,
                          uid: uid,
                          bioBg: bioBg,
                          bioBgHover: bioBgHover,
                          text: text,
                          subtext: subtext,
                          onEdit: _editBio,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Divider(height: 1, color: dividerColor),

              // ── Posts grid ────────────────────
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .where('uid', isEqualTo: uid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Center(
                          child:
                              CircularProgressIndicator(color: text)),
                    );
                  }
                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 64),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.grid_off_outlined,
                                size: 36, color: subtext),
                            const SizedBox(height: 10),
                            Text('No posts yet',
                                style: TextStyle(
                                    fontSize: 14, color: subtext)),
                          ],
                        ),
                      ),
                    );
                  }
                  final posts = snapshot.data!.docs;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 1,
                      mainAxisSpacing: 1,
                    ),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final d = posts[index].data()
                          as Map<String, dynamic>;
                      final imageUrl =
                          d['imageUrl'] as String? ?? '';
                      return Container(
                        color: cardBg,
                        child: imageUrl.isNotEmpty
                            ? Image.network(imageUrl,
                                fit: BoxFit.cover)
                            : Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  d['content'] ?? '',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11, color: subtext),
                                ),
                              ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Isolated hoverable profile picture
// Keeps hover setState out of the StreamBuilder
// ─────────────────────────────────────────────

class _HoverablePfp extends StatefulWidget {
  final String photoUrl;
  final String username;
  final Color text;
  final Color dividerColor;
  final VoidCallback onTap;

  const _HoverablePfp({
    required this.photoUrl,
    required this.username,
    required this.text,
    required this.dividerColor,
    required this.onTap,
  });

  @override
  State<_HoverablePfp> createState() => _HoverablePfpState();
}

class _HoverablePfpState extends State<_HoverablePfp> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 72,
              backgroundColor: widget.dividerColor,
              backgroundImage: widget.photoUrl.isNotEmpty
                  ? NetworkImage(widget.photoUrl)
                  : null,
              child: widget.photoUrl.isEmpty
                  ? Text(
                      widget.username[0].toUpperCase(),
                      style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w600,
                          color: widget.text),
                    )
                  : null,
            ),
            if (_hovered)
              Container(
                width: 144,
                height: 144,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.4),
                ),
                child: const Icon(Icons.edit,
                    color: Colors.white, size: 22),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Isolated hoverable bio box
// Keeps hover setState out of the StreamBuilder
// ─────────────────────────────────────────────

class _HoverableBioBox extends StatefulWidget {
  final String bio;
  final String uid;
  final Color bioBg;
  final Color bioBgHover;
  final Color text;
  final Color subtext;
  final void Function(BuildContext, String, String) onEdit;

  const _HoverableBioBox({
    required this.bio,
    required this.uid,
    required this.bioBg,
    required this.bioBgHover,
    required this.text,
    required this.subtext,
    required this.onEdit,
  });

  @override
  State<_HoverableBioBox> createState() => _HoverableBioBoxState();
}

class _HoverableBioBoxState extends State<_HoverableBioBox> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onEdit(context, widget.bio, widget.uid),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? widget.bioBgHover : widget.bioBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            widget.bio.isNotEmpty ? widget.bio : 'Add a bio...',
            style: TextStyle(
              fontSize: 14,
              color:
                  widget.bio.isNotEmpty ? widget.text : widget.subtext,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Stat column (posts / followers / following)
// ─────────────────────────────────────────────

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color text;
  final Color subtext;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.text,
    required this.subtext,
  });
  
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: text),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 15, color: subtext)),
      ],
    );
  }
}
