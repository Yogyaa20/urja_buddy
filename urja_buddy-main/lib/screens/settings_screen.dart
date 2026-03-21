import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth_wrapper.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../screens/profile_selector_screen.dart';
import '../services/auth_service.dart';
import '../theme/urja_theme.dart';
import '../widgets/dashboard_widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final AuthService _authService = AuthService();
  bool _notificationsEnabled = true;
  String _activeUserName = '';
  String _activeUserEmail = '';

  @override
  void initState() {
    super.initState();
    _loadActiveUser();
  }

  Future<void> _loadActiveUser() async {
    final prefs = await SharedPreferences.getInstance();
    final activeUser = prefs.getString('activeUser');
    if (activeUser != null && activeUser.isNotEmpty) {
      try {
        final profile = jsonDecode(activeUser);
        if (mounted) {
          setState(() {
            _activeUserName = profile['name'] ?? '';
            _activeUserEmail = profile['email'] ?? '';
          });
        }
      } catch (e) {
        // Ignore
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    return userState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (user) {
        // ✅ Active profile ka naam dikhao, fallback Firebase name
        final name = _activeUserName.isNotEmpty
            ? _activeUserName
            : (user.displayName ?? 'Urja User');
        final email = _activeUserEmail.isNotEmpty
            ? _activeUserEmail
            : (user.email ?? 'user@example.com');
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 32),
              GlassCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(initial,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: Theme.of(context).textTheme.titleLarge),
                          Text(email, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _showEditProfileDialog(context, name),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                      child: const Text('Edit'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text('Preferences', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  children: [
                    _buildSwitchTile(
                      'Dark Mode', 'Use dark theme for better battery life',
                      isDarkMode,
                      (val) => ref.read(themeProvider.notifier).toggleTheme(),
                      Icons.dark_mode,
                    ),
                    const Divider(color: UrjaTheme.glassBorder),
                    _buildSwitchTile(
                      'Notifications', 'Receive alerts about high usage',
                      _notificationsEnabled,
                      (val) => setState(() => _notificationsEnabled = val),
                      Icons.notifications,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text('Account', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.switch_account_rounded, color: UrjaTheme.primaryGreen),
                      title: Text("Change Who's Using",
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w500)),
                      subtitle: Text('Switch to another family profile',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: UrjaTheme.textSecondary),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const ProfileSelectorScreen()),
                        );
                        _loadActiveUser(); // Reload naam after switching
                      },
                    ),
                    const Divider(color: UrjaTheme.glassBorder),
                    ListTile(
                      leading: const Icon(Icons.help_outline, color: UrjaTheme.textSecondary),
                      title: Text('Help & Support',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: UrjaTheme.textSecondary),
                      onTap: () => _showHelpDialog(context),
                    ),
                    const Divider(color: UrjaTheme.glassBorder),
                    ListTile(
                      leading: const Icon(Icons.logout, color: UrjaTheme.errorRed),
                      title: const Text('Sign Out', style: TextStyle(color: UrjaTheme.errorRed)),
                      onTap: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Signing out...'), duration: Duration(seconds: 1)));
                        try {
                          await _authService.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => const AuthWrapper()),
                              (route) => false,
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error signing out: $e')));
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Center(child: Text('Urja Buddy v1.0.0', style: Theme.of(context).textTheme.bodySmall)),
            ],
          ),
        );
      },
    );
  }

  void _showEditProfileDialog(BuildContext context, String currentName) {
    final nameController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
        title: Text('Edit Profile', style: Theme.of(context).textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                labelText: 'Full Name',
                labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Theme.of(context).primaryColor)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color))),
          ElevatedButton(
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                ref.read(userProvider.notifier).updateName(newName);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully!')));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value,
      Function(bool) onChanged, IconData icon) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12)),
      secondary: Icon(icon, color: UrjaTheme.primaryGreen),
      activeThumbColor: UrjaTheme.primaryGreen,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
        title: Row(
          children: [
            Icon(Icons.support_agent, color: Theme.of(context).primaryColor, size: 28),
            const SizedBox(width: 12),
            Text('Help & Support', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need assistance with your energy monitoring? We are here to help!',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            InkWell(
              onTap: () async {
                final Uri emailLaunchUri = Uri(
                  scheme: 'mailto',
                  path: 'urjabuddy@gmail.com',
                  queryParameters: {'subject': 'Support Request: Urja Buddy App'},
                );
                if (await canLaunchUrl(emailLaunchUri)) {
                  await launchUrl(emailLaunchUri);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open email app.')));
                  }
                }
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle),
                    child: Icon(Icons.email_outlined, color: Theme.of(context).primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email Us', style: Theme.of(context).textTheme.bodySmall),
                        Text('urjabuddy@gmail.com',
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.light
                                  ? const Color(0xFF1B5E20)
                                  : const Color(0xFF69F0AE),
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: Theme.of(context).colorScheme.secondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Tip: You can ask Urja AI for instant troubleshooting advice.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close',
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color))),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showAIChatDialog(context);
            },
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Talk to Urja AI'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
          ),
        ],
      ),
    );
  }

  void _showAIChatDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    final List<Map<String, String>> messages = [];
    bool isThinking = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
            child: GlassCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: UrjaTheme.primaryGreen.withValues(alpha: 0.1),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.auto_awesome, color: UrjaTheme.primaryGreen),
                      ),
                      const SizedBox(width: 12),
                      const Text('Urja AI Assistant',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                          icon: const Icon(Icons.close, color: UrjaTheme.textSecondary),
                          onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const Divider(color: UrjaTheme.glassBorder),
                  Expanded(
                    child: messages.isEmpty
                        ? const Center(
                            child: Text('Ask me anything about your energy usage!',
                                style: TextStyle(color: UrjaTheme.textSecondary)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              final isUser = msg['role'] == 'user';
                              return Align(
                                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isUser
                                        ? UrjaTheme.primaryGreen
                                        : UrjaTheme.glassBorder.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(msg['content']!,
                                      style: TextStyle(
                                          color: isUser ? Colors.white : UrjaTheme.textPrimary)),
                                ),
                              );
                            },
                          ),
                  ),
                  if (isThinking)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Urja Buddy is thinking...',
                              style: TextStyle(color: UrjaTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            style: const TextStyle(color: UrjaTheme.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Type your question...',
                              hintStyle: const TextStyle(color: UrjaTheme.textSecondary),
                              filled: true,
                              fillColor: UrjaTheme.glassBorder.withValues(alpha: 0.3),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            onSubmitted: (_) => _sendMessage(setState, controller, messages, (val) => isThinking = val),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () => _sendMessage(setState, controller, messages, (val) => isThinking = val),
                          icon: const Icon(Icons.send, color: UrjaTheme.primaryGreen),
                          style: IconButton.styleFrom(
                              backgroundColor: UrjaTheme.glassBorder.withValues(alpha: 0.3),
                              padding: const EdgeInsets.all(12)),
                        ),
                      ],
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

  Future<void> _sendMessage(StateSetter setState, TextEditingController controller,
      List<Map<String, String>> messages, Function(bool) setLoading) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add({'role': 'user', 'content': text});
      controller.clear();
      setLoading(true);
    });
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      messages.add({'role': 'assistant', 'content': "I'm here to help! (Quick access chat from Settings)"});
      setLoading(false);
    });
  }
}
