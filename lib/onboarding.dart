import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Screen 1
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _isDarkMode = false;
  Uint8List? _pickedImageBytes;
  String? _googlePhotoUrl;

  // Screen 2
  bool _isCreator = false;
  final List<String> _allInterests = [
    'Music', 'Gaming', 'Art', 'Fitness', 'Food',
    'Travel', 'Tech', 'Fashion', 'Sports', 'Film',
    'Books', 'Photography',
  ];
  final List<String> _selectedInterests = [];

  // Screen 3
  bool _limitEnabled = false;
  bool _limitByTime = false;
  int _postLimit = 30;
  int _timeLimit = 30;
  late TextEditingController _limitValueController;

  @override
  void initState() {
    super.initState();
    _limitValueController = TextEditingController(text: '30');
    final user = FirebaseAuth.instance.currentUser;
    _googlePhotoUrl = user?.photoURL;
  }

  @override
  void dispose() {
    _limitValueController.dispose();
    super.dispose();
  }

  // Theme helpers
  Color get bg => _isDarkMode ? const Color(0xFF1C1C1E) : const Color(0xFFF9F9F9);
  Color get cardBg => _isDarkMode ? const Color(0xFF2C2C2E) : Colors.white;
  Color get text => _isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
  Color get subtext => _isDarkMode ? const Color(0xFF8E8E93) : const Color(0xFF888888);
  Color get inputBg => _isDarkMode ? const Color(0xFF3A3A3C) : const Color(0xFFF3F3F3);
  Color get borderColor => _isDarkMode ? const Color(0xFF48484A) : const Color(0xFFE5E5E5);
  Color get primary => _isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
  Color get primaryText => _isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _pickedImageBytes = bytes);
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage++);
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage--);
    }
  }

  void _updateLimitFromText(String val) {
    final parsed = int.tryParse(val);
    if (parsed == null) return;
    setState(() {
      if (_limitByTime) {
        _timeLimit = parsed.clamp(15, 180);
      } else {
        _postLimit = parsed.clamp(5, 200);
      }
    });
  }

  Future<void> _completeOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String photoUrl = _googlePhotoUrl ?? '';

    if (_pickedImageBytes != null) {
      try {
        final uri = Uri.parse(
            'https://api.cloudinary.com/v1_1/dvb8b4ogj/image/upload');
        final request = http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = 'sma_uploads'
          ..fields['public_id'] = 'profile_${user.uid}'
          ..files.add(http.MultipartFile.fromBytes(
            'file',
            _pickedImageBytes!,
            filename: 'profile.jpg',
          ));
        final response = await request.send();
        final body = await response.stream.bytesToString();
        final json = jsonDecode(body);
        photoUrl = json['secure_url'] ?? photoUrl;
      } catch (e) {
        debugPrint('Cloudinary upload error: $e');
      }
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'username': _usernameController.text.trim(),
      'displayName': _displayNameController.text.trim(),
      'bio': _bioController.text.trim(),
      'isCreator': _isCreator,
      'isDarkMode': _isDarkMode,
      'interests': _selectedInterests,
      'limitEnabled': _limitEnabled,
      'limitByTime': _limitByTime,
      'postLimit': _postLimit,
      'timeLimit': _timeLimit,
      'onboardingComplete': true,
      'photoUrl': photoUrl,
    });

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomePage(isDarkMode: _isDarkMode)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 480,
            margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
                  child: Row(
                    children: List.generate(3, (index) {
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: index <= _currentPage ? primary : primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 420, maxHeight: 600),
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildIdentityPage(),
                      _buildVibePage(),
                      _buildLimitPage(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Who are you?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: text)),
          const SizedBox(height: 4),
          Text('Set up your profile',
              style: TextStyle(fontSize: 13, color: subtext)),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: inputBg,
                    backgroundImage: _pickedImageBytes != null
                        ? MemoryImage(_pickedImageBytes!) as ImageProvider
                        : (_googlePhotoUrl != null ? NetworkImage(_googlePhotoUrl!) : null),
                    child: _pickedImageBytes == null && _googlePhotoUrl == null
                        ? Icon(Icons.person, size: 36, color: subtext)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                      child: Icon(Icons.edit, size: 12, color: primaryText),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildUsernameField(),
          const SizedBox(height: 4),
          Text('3 to 20 characters', style: TextStyle(fontSize: 11, color: subtext)),
          const SizedBox(height: 12),
          _buildTextField(_displayNameController, 'Display name', 'what people see'),
          const SizedBox(height: 12),
          _buildTextField(_bioController, 'Bio', 'optional', maxLines: 2),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dark mode',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: text)),
              Switch(
                value: _isDarkMode,
                activeColor: primary,
                onChanged: (val) => setState(() => _isDarkMode = val),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildPrimaryButton('Continue', () {
            if (_usernameController.text.trim().length < 3) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Username must be at least 3 characters')),
              );
              return;
            }
            _nextPage();
          }),
        ],
      ),
    );
  }

  Widget _buildVibePage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your vibe',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: text)),
          const SizedBox(height: 4),
          Text('Customize your experience',
              style: TextStyle(fontSize: 13, color: subtext)),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildToggleChip('Just here to vibe', !_isCreator, () => setState(() => _isCreator = false)),
              const SizedBox(width: 8),
              _buildToggleChip('Creator', _isCreator, () => setState(() => _isCreator = true)),
            ],
          ),
          const SizedBox(height: 20),
          Text('Interests',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: text)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _allInterests.map((interest) {
              final selected = _selectedInterests.contains(interest);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedInterests.remove(interest);
                    } else {
                      _selectedInterests.add(interest);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? primary : inputBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(interest,
                      style: TextStyle(
                          fontSize: 12,
                          color: selected ? primaryText : subtext,
                          fontWeight: FontWeight.w500)),
                ),
              );
            }).toList(),
          ),
          const Spacer(),
          Row(
            children: [
              _buildBackBtn(),
              const SizedBox(width: 10),
              Expanded(child: _buildPrimaryButton('Continue', _nextPage)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLimitPage() {
    final currentValue = _limitByTime ? _timeLimit : _postLimit;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your daily limit',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: text)),
          const SizedBox(height: 4),
          Text('Friends are always unlimited. This only applies to creators and discovery.',
              style: TextStyle(fontSize: 12, color: subtext)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Set a daily limit',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: text)),
              Switch(
                value: _limitEnabled,
                activeColor: primary,
                onChanged: (val) => setState(() => _limitEnabled = val),
              ),
            ],
          ),
          if (_limitEnabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _buildToggleChip('By posts', !_limitByTime, () {
                  setState(() {
                    _limitByTime = false;
                    _limitValueController.text = _postLimit.toString();
                  });
                }),
                const SizedBox(width: 8),
                _buildToggleChip('By time', _limitByTime, () {
                  setState(() {
                    _limitByTime = true;
                    _limitValueController.text = _timeLimit.toString();
                  });
                }),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCounterBtn(Icons.remove, () {
                    setState(() {
                      if (_limitByTime) {
                        if (_timeLimit > 15) _timeLimit -= 5;
                        _limitValueController.text = _timeLimit.toString();
                      } else {
                        if (_postLimit > 5) _postLimit -= 5;
                        _limitValueController.text = _postLimit.toString();
                      }
                    });
                  }),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _limitValueController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: text),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: currentValue.toString(),
                        hintStyle: TextStyle(color: subtext),
                        suffix: Text(
                          _limitByTime ? ' min' : ' posts',
                          style: TextStyle(fontSize: 12, color: subtext),
                        ),
                      ),
                      onChanged: _updateLimitFromText,
                    ),
                  ),
                  _buildCounterBtn(Icons.add, () {
                    setState(() {
                      if (_limitByTime) {
                        if (_timeLimit < 180) _timeLimit += 5;
                        _limitValueController.text = _timeLimit.toString();
                      } else {
                        if (_postLimit < 200) _postLimit += 5;
                        _limitValueController.text = _postLimit.toString();
                      }
                    });
                  }),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _limitByTime ? '15 min to 3 hours' : '5 to 200 posts',
              style: TextStyle(fontSize: 11, color: subtext),
            ),
          ],
          const Spacer(),
          TextButton(
            onPressed: _completeOnboarding,
            child: Text('Skip for now', style: TextStyle(fontSize: 12, color: subtext)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildBackBtn(),
              const SizedBox(width: 10),
              Expanded(child: _buildPrimaryButton('Get started', _completeOnboarding)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameField() {
    return TextField(
      controller: _usernameController,
      maxLength: 20,
      style: TextStyle(fontSize: 14, color: text),
      decoration: InputDecoration(
        counterStyle: TextStyle(fontSize: 11, color: subtext),
        labelText: 'Username',
        prefixText: '@',
        prefixStyle: TextStyle(fontSize: 14, color: subtext, fontWeight: FontWeight.w600),
        hintText: 'yourname',
        labelStyle: TextStyle(fontSize: 13, color: subtext),
        hintStyle: TextStyle(fontSize: 13, color: borderColor),
        filled: true,
        fillColor: inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primary, width: 1.5)),
      ),
    );
  }

  Widget _buildTextField(TextEditingController c, String label, String hint, {int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      style: TextStyle(fontSize: 14, color: text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(fontSize: 13, color: subtext),
        hintStyle: TextStyle(fontSize: 13, color: borderColor),
        filled: true,
        fillColor: inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primary, width: 1.5)),
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 42,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: primaryText,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildBackBtn() {
    return GestureDetector(
      onTap: _prevPage,
      child: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(10)),
        child: Icon(Icons.arrow_back, size: 18, color: text),
      ),
    );
  }

  Widget _buildToggleChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? primary : inputBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? primaryText : subtext)),
      ),
    );
  }

  Widget _buildCounterBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: primaryText),
      ),
    );
  }
}