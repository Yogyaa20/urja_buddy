import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/auth_wrapper.dart';
import '../theme/urja_theme.dart';
import '../widgets/dashboard_widgets.dart';

class FamilySetupScreen extends StatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  State<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends State<FamilySetupScreen> {
  final List<Map<String, TextEditingController>> _members = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addMember(); // Start with one empty member row
  }

  @override
  void dispose() {
    for (var member in _members) {
      member['name']?.dispose();
      member['email']?.dispose();
    }
    super.dispose();
  }

  void _addMember() {
    setState(() {
      _members.add({
        'name': TextEditingController(),
        'email': TextEditingController(),
      });
    });
  }

  void _removeMember(int index) {
    setState(() {
      _members[index]['name']?.dispose();
      _members[index]['email']?.dispose();
      _members.removeAt(index);
    });
  }

  Future<void> _saveFamilyMembers() async {
    if (_members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one family member')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated. Please log in again.')),
      );
      return;
    }

    List<Map<String, String>> familyList = [];
    for (var m in _members) {
      final name = m['name']!.text.trim();
      final email = m['email']!.text.trim();

      if (name.isEmpty || email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all name and email fields')),
        );
        return;
      }
      familyList.add({'name': name, 'email': email});
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'family_members': familyList},
        SetOptions(merge: true),
      );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save members: $e'),
            backgroundColor: UrjaTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _skip() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UrjaTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Don't allow going back to register screen easily
        actions: [
          TextButton(
            onPressed: _skip,
            child: const Text(
              'Skip',
              style: TextStyle(color: UrjaTheme.textSecondary, fontSize: 16),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Background Gradient Mesh
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    UrjaTheme.primaryGreen.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: GlassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.family_restroom_outlined, size: 64, color: UrjaTheme.primaryGreen),
                      const SizedBox(height: 24),
                      Text(
                        'Family Members Setup',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: UrjaTheme.textPrimary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your family members to start tracking energy usage together.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _members.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildTextField(
                                    controller: _members[index]['name']!,
                                    hint: 'Name (e.g. Rahul)',
                                    icon: Icons.person_outline,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: _buildTextField(
                                    controller: _members[index]['email']!,
                                    hint: 'Email (rahul@example.com)',
                                    icon: Icons.email_outlined,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  onPressed: () => _removeMember(index),
                                  icon: const Icon(Icons.remove_circle_outline, color: UrjaTheme.errorRed),
                                  splashRadius: 24,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addMember,
                          icon: const Icon(Icons.add_circle_outline, color: UrjaTheme.primaryGreen),
                          label: const Text(
                            'Add Member',
                            style: TextStyle(
                              color: UrjaTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveFamilyMembers,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: UrjaTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 8,
                            shadowColor: UrjaTheme.primaryGreen.withValues(alpha: 0.4),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Save and Continue',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: UrjaTheme.textPrimary),
      keyboardType: hint.contains('Email') ? TextInputType.emailAddress : TextInputType.name,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: UrjaTheme.textSecondary, fontSize: 14),
        prefixIcon: Icon(icon, color: UrjaTheme.textSecondary, size: 20),
        filled: true,
        fillColor: UrjaTheme.glassBorder.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }
}
