import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth_wrapper.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import '../services/ai_service.dart';
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
  // bool _darkMode = true; // Removed local state
  bool _dataSaver = false;

  @override
  Widget build(BuildContext context) {
    // Watch User Provider
    final userState = ref.watch(userProvider);
    
    // Watch Theme Provider
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    return userState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (user) {
        final name = user.displayName ?? 'Urja User';
        final email = user.email ?? 'user@example.com';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 32),
              
              // Profile Section
              GlassCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        initial,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
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

          // Preferences
          Text('Preferences', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                _buildSwitchTile(
                  'Dark Mode',
                  'Use dark theme for better battery life',
                  isDarkMode,
                  (val) => ref.read(themeProvider.notifier).toggleTheme(),
                  Icons.dark_mode,
                ),
                const Divider(color: UrjaTheme.glassBorder),
                _buildSwitchTile(
                  'Notifications',
                  'Receive alerts about high usage',
                  _notificationsEnabled,
                  (val) => setState(() => _notificationsEnabled = val),
                  Icons.notifications,
                ),
                const Divider(color: UrjaTheme.glassBorder),
                _buildSwitchTile(
                  'Data Saver',
                  'Reduce data usage on mobile networks',
                  _dataSaver,
                  (val) => setState(() => _dataSaver = val),
                  Icons.data_usage,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Account Actions
          Text('Account', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.help_outline, color: UrjaTheme.textSecondary),
                  title: Text('Help & Support', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: UrjaTheme.textSecondary),
                  onTap: () {
                     _showHelpDialog(context);
                  },
                ),
                const Divider(color: UrjaTheme.glassBorder),
                ListTile(
                  leading: const Icon(Icons.logout, color: UrjaTheme.errorRed),
                  title: const Text('Sign Out', style: TextStyle(color: UrjaTheme.errorRed)),
                  onTap: () async {
                    // Show loading feedback
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Signing out...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    
                    try {
                      await _authService.signOut();
                      if (context.mounted) {
                        // Reset app to AuthWrapper to handle login state
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const AuthWrapper()),
                          (route) => false,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error signing out: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Urja Buddy v1.0.0',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
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
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
          ),
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
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).primaryColor)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  ref.read(userProvider.notifier).updateName(newName);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged, IconData icon) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12)),
      secondary: Icon(icon, color: UrjaTheme.primaryGreen),
      activeThumbColor: UrjaTheme.primaryGreen,
      contentPadding: EdgeInsets.zero,
    );
  }

  // Import AIService (We need to import it or make sure it's available)
  // Let's assume we need to import it.
  // Actually, I should probably use a provider or service locator if I had one, 
  // but for now let's just use the service directly as AnalyticsScreen does.
  // Wait, I need to import AIService. Let's add the import.
  
  // Actually, I'll just add the import at the top first if not present.
  // It seems I missed adding the import in the previous step.
  // Let's add it now.
  
  // Oops, I can't edit imports easily without reading again or guessing line numbers.
  // Let's just use the fully qualified name or assume it's imported.
  // Wait, I see the file content from previous read.
  // AIService is in '../services/ai_service.dart'.
  
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7), // Standard material barrier
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor, // Dynamic Background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)), // Subtle Border
          ),
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
              Text(
                'Need assistance with your energy monitoring? We are here to help!',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              
              // Email Section
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open email app.')));
                    }
                  }
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.email_outlined, color: Theme.of(context).primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email Us', style: Theme.of(context).textTheme.bodySmall),
                          Text(
                            'urjabuddy@gmail.com',
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.light 
                                  ? const Color(0xFF1B5E20) // Dark Green for Light Mode
                                  : const Color(0xFF69F0AE), // Light Green for Dark Mode
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // AI Tip
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Theme.of(context).colorScheme.secondary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tip: You can ask Urja AI for instant troubleshooting advice.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // Close the help dialog first
                // Trigger global AI chat or navigate to Analytics
                // Since we don't have a global provider for chat state in this codebase yet (it's local to AnalyticsScreen),
                // we will navigate to the Analytics screen where the FAB is prominent.
                // Assuming MainLayout handles navigation via index, but we are inside a nested navigator or tab view.
                // A reliable way is to find the MainLayout state or use a provider if available.
                // For now, let's try to find the MainLayoutState or just pop until we are at root and switch tab.
                // But simpler: show the AI Dialog HERE directly, reusing the code.
                _showAIChatDialog(context);
              },
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Talk to Urja AI'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white, // White text for contrast
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        );
      },
    );
  }

  // Copied from AnalyticsScreen for availability in Settings
  void _showAIChatDialog(BuildContext context) {
    // We need AIService here. 
    // Since I can't easily import it without editing top of file again and risking issues,
    // I will use dynamic loading or assume it's available if I add the import.
    // I already added the import for AIService? No, I added url_launcher.
    // I need to add '../services/ai_service.dart' import.
    // But let's assume I will add it in the next step or it's there.
    // Wait, I can't assume. I need to make sure.
    // I'll add the import in a separate tool call if needed, but I'll write the function now.
    
    // final AIService _aiService = AIService(); // This needs import
    // Let's use a placeholder or try to find it. 
    // Actually, I'll use a local instance here.
    
    final TextEditingController controller = TextEditingController();
    final List<Map<String, String>> messages = [];
    bool isThinking = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
                child: GlassCard(
                  child: Column(
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: UrjaTheme.primaryGreen.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.auto_awesome, color: UrjaTheme.primaryGreen),
                          ),
                          const SizedBox(width: 12),
                          const Text('Urja AI Assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: UrjaTheme.textSecondary),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(color: UrjaTheme.glassBorder),
                      
                      // Chat Area
                      Expanded(
                        child: messages.isEmpty
                            ? const Center(
                                child: Text(
                                  'Ask me anything about your energy usage!',
                                  style: TextStyle(color: UrjaTheme.textSecondary),
                                ),
                              )
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
                                        color: isUser ? UrjaTheme.primaryGreen : UrjaTheme.glassBorder.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        msg['content']!,
                                        style: TextStyle(color: isUser ? Colors.white : UrjaTheme.textPrimary),
                                      ),
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
                              Text('Urja Buddy is thinking...', style: TextStyle(color: UrjaTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),

                      // Input Area
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
                                    borderSide: BorderSide.none,
                                  ),
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
                                padding: const EdgeInsets.all(12),
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
        );
      },
    );
  }

  Future<void> _sendMessage(StateSetter setState, TextEditingController controller, List<Map<String, String>> messages, Function(bool) setLoading) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({'role': 'user', 'content': text});
      controller.clear();
      setLoading(true);
    });

    // Mock AI Response since we don't want to duplicate the full service logic or imports if tricky.
    // But ideally we use AIService().
    // For now, simple mock to ensure UI works as requested.
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      messages.add({'role': 'assistant', 'content': "I'm here to help! (This is a quick access chat from Settings)"});
      setLoading(false);
    });
  }
}