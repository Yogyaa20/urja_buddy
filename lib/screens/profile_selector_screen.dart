import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/home_screen.dart';
import '../theme/urja_theme.dart';

class ProfileSelectorScreen extends StatefulWidget {
  const ProfileSelectorScreen({super.key});

  @override
  State<ProfileSelectorScreen> createState() => _ProfileSelectorScreenState();
}

class _ProfileSelectorScreenState extends State<ProfileSelectorScreen> {
  bool _isLoading = true;
  String _familyName = '';
  List<Map<String, dynamic>> _profiles = [];

  @override
  void initState() {
    super.initState();
    _fetchProfiles();
  }

  Future<void> _fetchProfiles() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            _familyName = doc.data()?['familyName'] ?? 'Family';
          });
          if (doc.data()!.containsKey('family_members')) {
            final members = List<Map<String, dynamic>>.from(doc.data()!['family_members']);
            setState(() {
              _profiles = members;
              _isLoading = false;
            });
          } else {
            // If no members, maybe use full name as an option
            final name = doc.data()?['fullName'] ?? 'Admin';
            setState(() {
              _profiles = [{'name': name, 'email': user.email ?? ''}];
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profiles: $e'), backgroundColor: UrjaTheme.errorRed),
        );
      }
    }
  }

  Future<void> _selectProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activeUser', jsonEncode(profile));
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UrjaTheme.darkBackground,
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
            child: _isLoading
                ? const CircularProgressIndicator(color: UrjaTheme.primaryGreen)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_familyName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            "Welcome, $_familyName to Urja Buddy!",
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: UrjaTheme.primaryGreen,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      Text(
                        "Who's using?",
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: UrjaTheme.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 48),
                      if (_profiles.isEmpty)
                        const Text(
                          "No profiles found.",
                          style: TextStyle(color: UrjaTheme.textSecondary),
                        )
                      else
                        Wrap(
                          spacing: 32,
                          runSpacing: 32,
                          alignment: WrapAlignment.center,
                          children: _profiles.map((profile) {
                            return GestureDetector(
                              onTap: () => _selectProfile(profile),
                              child: _ProfileCard(name: profile['name']),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatefulWidget {
  final String name;

  const _ProfileCard({required this.name});

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(_isHovering ? 1.05 : 1.0),
        child: Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: UrjaTheme.glassBorder.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isHovering ? UrjaTheme.primaryGreen : Colors.transparent,
                  width: 2,
                ),
                boxShadow: _isHovering
                    ? [
                        BoxShadow(
                          color: UrjaTheme.primaryGreen.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: UrjaTheme.primaryGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: _isHovering ? FontWeight.bold : FontWeight.normal,
                color: _isHovering ? UrjaTheme.textPrimary : UrjaTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
