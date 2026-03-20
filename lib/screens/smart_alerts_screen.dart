import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../theme/urja_theme.dart';
import '../widgets/dashboard_widgets.dart';

class SmartAlertsScreen extends StatefulWidget {
  const SmartAlertsScreen({super.key});

  @override
  State<SmartAlertsScreen> createState() => _SmartAlertsScreenState();
}

class _SmartAlertsScreenState extends State<SmartAlertsScreen> {
  final List<Map<String, dynamic>> _alerts = [
    {
      'id': 1,
      'title': 'Consumption Spike Detected',
      'message': 'Unusual high energy usage detected in HVAC system.',
      'level': 'critical',
      'time': '10 mins ago',
      'icon': Icons.warning_rounded,
    },
    {
      'id': 2,
      'title': 'AC Budget Exceeded',
      'message': 'Air Conditioner has exceeded the daily set budget of 15kWh.',
      'level': 'warning',
      'time': '2 hours ago',
      'icon': Icons.thermostat_rounded,
    },
    {
      'id': 3,
      'title': 'Peak Rate Active',
      'message': 'Current electricity rates are 1.5x higher until 8 PM.',
      'level': 'warning',
      'time': '4 hours ago',
      'icon': Icons.trending_up_rounded,
    },
    {
      'id': 4,
      'title': 'Weekly Report Ready',
      'message': 'Your weekly consumption analysis is ready to view.',
      'level': 'info',
      'time': 'Yesterday',
      'icon': Icons.assignment_rounded,
    },
  ];

  // Reminder state
  List<Map<String, dynamic>> _reminders = [];
  bool _loadingReminders = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
    _initFCM();
  }

  Future<void> _initFCM() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Save FCM token to Firestore
      final token = await messaging.getToken();
      final user = FirebaseAuth.instance.currentUser;
      if (token != null && user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'fcm_token': token}, SetOptions(merge: true));
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'fcm_token': newToken}, SetOptions(merge: true));
        }
      });
    } catch (e) {
      debugPrint('FCM init error: $e');
    }
  }

  Future<void> _loadReminders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loadingReminders = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reminders')
          .orderBy('created_at', descending: false)
          .get();

      setState(() {
        _reminders = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'label': data['label'] ?? 'Reminder',
            'hour': data['hour'] ?? 20,
            'minute': data['minute'] ?? 0,
            'enabled': data['enabled'] ?? true,
            'days': List<bool>.from(data['days'] ?? List.filled(7, true)),
          };
        }).toList();
        _loadingReminders = false;
      });
    } catch (e) {
      setState(() => _loadingReminders = false);
    }
  }

  Future<void> _saveReminder(Map<String, dynamic> reminder) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = reminder['id'] != null
        ? FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('reminders')
            .doc(reminder['id'] as String)
        : FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('reminders')
            .doc();

    await docRef.set({
      'label': reminder['label'],
      'hour': reminder['hour'],
      'minute': reminder['minute'],
      'enabled': reminder['enabled'],
      'days': reminder['days'],
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _loadReminders();
  }

  Future<void> _deleteReminder(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('reminders')
        .doc(id)
        .delete();

    await _loadReminders();
  }

  Future<void> _toggleReminder(String id, bool enabled) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('reminders')
        .doc(id)
        .update({'enabled': enabled});

    setState(() {
      final idx = _reminders.indexWhere((r) => r['id'] == id);
      if (idx != -1) _reminders[idx]['enabled'] = enabled;
    });
  }

  void _dismissAlert(int id) {
    setState(() => _alerts.removeWhere((alert) => alert['id'] == id));
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'critical': return UrjaTheme.errorRed;
      case 'warning': return UrjaTheme.warningOrange;
      case 'info': return UrjaTheme.accentCyan;
      default: return UrjaTheme.textSecondary;
    }
  }

  String _formatTime(int hour, int minute) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  String _formatDays(List<bool> days) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final selected = <String>[];
    for (int i = 0; i < days.length; i++) {
      if (days[i]) selected.add(names[i]);
    }
    if (selected.length == 7) return 'Every day';
    if (selected.isEmpty) return 'No days';
    return selected.join(', ');
  }

  void _showAddReminderDialog({Map<String, dynamic>? existing}) {
    final labelController = TextEditingController(
        text: existing?['label'] ?? 'Check energy usage');
    int hour = existing?['hour'] ?? 20;
    int minute = existing?['minute'] ?? 0;
    List<bool> days = List<bool>.from(
        existing?['days'] ?? List.filled(7, true));
    const dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: UrjaTheme.cardBackground,
          title: Text(
            existing == null ? 'Add Reminder' : 'Edit Reminder',
            style: const TextStyle(color: UrjaTheme.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
                TextField(
                  controller: labelController,
                  style: const TextStyle(color: UrjaTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    labelStyle: TextStyle(color: UrjaTheme.textSecondary),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: UrjaTheme.glassBorder)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: UrjaTheme.primaryGreen)),
                  ),
                ),
                const SizedBox(height: 24),

                // Time picker
                const Text('Time',
                    style: TextStyle(
                        color: UrjaTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: hour, minute: minute),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: UrjaTheme.primaryGreen,
                            onPrimary: Colors.black,
                            surface: UrjaTheme.cardBackground,
                            onSurface: UrjaTheme.textPrimary,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        hour = picked.hour;
                        minute = picked.minute;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: UrjaTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              UrjaTheme.primaryGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time,
                            color: UrjaTheme.primaryGreen, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(hour, minute),
                          style: const TextStyle(
                              color: UrjaTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Days selector
                const Text('Repeat',
                    style: TextStyle(
                        color: UrjaTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (i) {
                    return GestureDetector(
                      onTap: () =>
                          setDialogState(() => days[i] = !days[i]),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: days[i]
                              ? UrjaTheme.primaryGreen
                              : UrjaTheme.glassBorder.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: days[i]
                                ? UrjaTheme.primaryGreen
                                : UrjaTheme.glassBorder,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            dayNames[i],
                            style: TextStyle(
                              color: days[i]
                                  ? Colors.black
                                  : UrjaTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: UrjaTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _saveReminder({
                  'id': existing?['id'],
                  'label': labelController.text.trim().isEmpty
                      ? 'Reminder'
                      : labelController.text.trim(),
                  'hour': hour,
                  'minute': minute,
                  'enabled': true,
                  'days': days,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reminder saved!'),
                      backgroundColor: UrjaTheme.primaryGreen,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: UrjaTheme.primaryGreen),
              child: const Text('Save',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 32),

          // ── Reminders Section ──────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Reminders',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _showAddReminderDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UrjaTheme.primaryGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_loadingReminders)
            const Center(
              child: CircularProgressIndicator(
                  color: UrjaTheme.primaryGreen),
            )
          else if (_reminders.isEmpty)
            GlassCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Icon(Icons.alarm_add_rounded,
                          size: 40,
                          color: UrjaTheme.textSecondary
                              .withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      const Text(
                        'No reminders set.\nTap "Add" to create one!',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: UrjaTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ..._reminders.map((reminder) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildReminderCard(reminder),
                )),

          const SizedBox(height: 32),

          // ── Active Alerts Section ──────────────────────────────────
          Text('Active Alerts',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          if (_alerts.isEmpty)
            Center(
              child: Text('No active alerts',
                  style: Theme.of(context).textTheme.bodyLarge),
            )
          else
            ..._alerts.map((alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildAlertCard(context, alert),
                )),
        ],
      ),
    );
  }

  Widget _buildReminderCard(Map<String, dynamic> reminder) {
    final enabled = reminder['enabled'] as bool;
    final days = reminder['days'] as List<bool>;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Time display
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: enabled
                  ? UrjaTheme.primaryGreen.withValues(alpha: 0.1)
                  : UrjaTheme.glassBorder.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: enabled
                      ? UrjaTheme.primaryGreen.withValues(alpha: 0.3)
                      : UrjaTheme.glassBorder),
            ),
            child: Text(
              _formatTime(
                  reminder['hour'] as int, reminder['minute'] as int),
              style: TextStyle(
                color: enabled
                    ? UrjaTheme.primaryGreen
                    : UrjaTheme.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Label + days
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder['label'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? UrjaTheme.textPrimary
                        : UrjaTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDays(days),
                  style: const TextStyle(
                      color: UrjaTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),

          // Toggle
          Switch(
            value: enabled,
            onChanged: (val) =>
                _toggleReminder(reminder['id'] as String, val),
            activeColor: UrjaTheme.primaryGreen,
          ),

          // Edit
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: UrjaTheme.textSecondary, size: 20),
            onPressed: () => _showAddReminderDialog(existing: reminder),
            tooltip: 'Edit',
          ),

          // Delete
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: UrjaTheme.errorRed, size: 20),
            onPressed: () async {
              await _deleteReminder(reminder['id'] as String);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reminder deleted'),
                    backgroundColor: UrjaTheme.errorRed,
                  ),
                );
              }
            },
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: UrjaTheme.warningOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.notifications_active_rounded,
                color: UrjaTheme.warningOrange, size: 32),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Smart Alerts Center',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Set custom reminders and get real-time energy alerts',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(
      BuildContext context, Map<String, dynamic> alert) {
    final color = _getLevelColor(alert['level'] as String);

    return GlassCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(alert['icon'] as IconData,
                          color: color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                alert['title'] as String,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                        color: color, fontSize: 18),
                              ),
                              Text(alert['time'] as String,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(alert['message'] as String,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () =>
                          _dismissAlert(alert['id'] as int),
                      icon: const Icon(Icons.close_rounded,
                          color: UrjaTheme.textSecondary),
                      tooltip: 'Dismiss',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}