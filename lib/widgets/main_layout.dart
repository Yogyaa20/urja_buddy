import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/urja_theme.dart';
import '../providers/user_provider.dart';
import '../services/ai_service.dart';
import '../widgets/dashboard_widgets.dart';

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;
  final int currentIndex;
  final Function(int) onIndexChanged;

  const MainLayout({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  final AIService _aiService = AIService();
  String _activeUserName = '';

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
          });
        }
      } catch (e) {
        // Ignore errors
      }
    }
  }

  // Bottom nav bar index (5 items) → actual page index mapping
  // Bottom bar: 0=Dashboard, 1=Analytics, 2=Alerts, 3=Appliances, 4=Settings
  // Page index: 0=Dashboard, 1=Analytics, 2=SmartAlerts, 3=Community, 4=Settings, 5=Appliances
  static const List<int> _bottomToPageIndex = [0, 1, 4, 3];

  int get _bottomNavIndex {
    switch (widget.currentIndex) {
      case 0: return 0; // Dashboard
      case 1: return 1; // Smart Alerts
      case 4: return 2; // Appliances
      case 3: return 3; // Settings
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      bottomNavigationBar: isDesktop ? null : _buildBottomNavBar(context),
      body: Stack(
        children: [
          // Background Gradient Mesh
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isDark
                      ? [
                          UrjaTheme.primaryGreen.withValues(alpha: 0.15),
                          Colors.transparent,
                        ]
                      : [
                          UrjaTheme.primaryGreen.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                          Colors.transparent,
                        ]
                      : [
                          const Color(0xFF0EA5E9).withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                ),
              ),
            ),
          ),

          // Main Layout
          Row(
            children: [
              if (isDesktop) _buildSidebar(context),
              Expanded(
                child: Column(
                  children: [
                    _buildHeader(context, !isDesktop),
                    Expanded(
                      child: widget.child,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: isDesktop
          ? null
          : Drawer(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              child: _buildSidebarContent(context),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAIChatDialog(context),
        backgroundColor: UrjaTheme.primaryGreen,
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
        label: const Text('Ask Urja AI',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (index) {
          widget.onIndexChanged(_bottomToPageIndex[index]);
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: UrjaTheme.primaryGreen,
        unselectedItemColor: isDark
            ? Colors.white.withValues(alpha: 0.5)
            : Colors.black.withValues(alpha: 0.4),
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_rounded),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bolt_rounded),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.electrical_services_rounded),
            label: 'Appliances',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
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
                            child: const Icon(Icons.auto_awesome,
                                color: UrjaTheme.primaryGreen),
                          ),
                          const SizedBox(width: 12),
                          const Text('Urja AI Assistant',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: UrjaTheme.textSecondary),
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
                                  style:
                                      TextStyle(color: UrjaTheme.textSecondary),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final msg = messages[index];
                                  final isUser = msg['role'] == 'user';
                                  return Align(
                                    alignment: isUser
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      margin:
                                          const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isUser
                                            ? UrjaTheme.primaryGreen
                                            : UrjaTheme.glassBorder
                                                .withValues(alpha: 0.3),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        msg['content']!,
                                        style: TextStyle(
                                            color: isUser
                                                ? Colors.white
                                                : UrjaTheme.textPrimary),
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
                              SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text('Urja Buddy is thinking...',
                                  style: TextStyle(
                                      color: UrjaTheme.textSecondary,
                                      fontSize: 12)),
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
                                style: const TextStyle(
                                    color: UrjaTheme.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Type your question...',
                                  hintStyle: const TextStyle(
                                      color: UrjaTheme.textSecondary),
                                  filled: true,
                                  fillColor: UrjaTheme.glassBorder
                                      .withValues(alpha: 0.3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                ),
                                onSubmitted: (_) => _sendMessage(setState,
                                    controller, messages, (val) => isThinking = val),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: () => _sendMessage(setState,
                                  controller, messages, (val) => isThinking = val),
                              icon: const Icon(Icons.send,
                                  color: UrjaTheme.primaryGreen),
                              style: IconButton.styleFrom(
                                backgroundColor: UrjaTheme.glassBorder
                                    .withValues(alpha: 0.3),
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

  Future<void> _sendMessage(
      StateSetter setState,
      TextEditingController controller,
      List<Map<String, String>> messages,
      Function(bool) setLoading) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({'role': 'user', 'content': text});
      controller.clear();
      setLoading(true);
    });

    final response = await _aiService.getAIResponse(text);

    setState(() {
      messages.add({'role': 'assistant', 'content': response});
      setLoading(false);
    });
  }

  Widget _buildHeader(BuildContext context, bool showMenu) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userState = ref.watch(userProvider);
    final userName = _activeUserName.isNotEmpty
        ? _activeUserName
        : (userState.value?.displayName ?? 'Urja User');
    final userInitial =
        userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: Theme.of(context)
                        .dividerColor
                        .withValues(alpha: isDark ? 0.2 : 0.8))),
            color: Theme.of(context)
                .scaffoldBackgroundColor
                .withValues(alpha: 0.7),
          ),
          child: Row(
            children: [
              if (showMenu)
                IconButton(
                  icon: Icon(Icons.menu,
                      color: Theme.of(context).iconTheme.color),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              if (showMenu) const SizedBox(width: 16),
              Text(
                'Dashboard',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 24),
              ),
              const Spacer(),
              _buildIconButton(context, Icons.notifications_outlined, () {
                widget.onIndexChanged(2);
              }),
              const SizedBox(width: 16),
              Container(
                height: 32,
                width: 1,
                color: Theme.of(context)
                    .dividerColor
                    .withValues(alpha: 0.5),
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    Theme.of(context).colorScheme.primary,
                child: Text(
                  userInitial,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(
      BuildContext context, IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      focusNode: FocusNode(skipTraversal: true),
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(
              color: Theme.of(context)
                  .dividerColor
                  .withValues(alpha: 0.5)),
        ),
        child: Icon(icon,
            color: Theme.of(context).iconTheme.color, size: 20),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardColor.withValues(alpha: 0.5),
        border: Border(
            right: BorderSide(
                color: Theme.of(context)
                    .dividerColor
                    .withValues(alpha: 0.5))),
      ),
      child: _buildSidebarContent(context),
    );
  }

  Widget _buildSidebarContent(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
      ),
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                  child: Image.asset(
                    'assets/images/logo_black.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Urja Buddy',
                  style: GoogleFonts.poppins(
                    textStyle:
                        Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildNavItem(0, Icons.grid_view_rounded, 'Dashboard'),
          _buildNavItem(1, Icons.bolt_rounded, 'Smart Alerts'),
          _buildNavItem(2, Icons.people_rounded, 'Community'),
          _buildNavItem(4, Icons.electrical_services_rounded, 'Appliances'),
          const Spacer(),
          _buildNavItem(4, Icons.settings_rounded, 'Settings'),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    return _SidebarNavItem(
      index: index,
      icon: icon,
      label: label,
      isSelected: widget.currentIndex == index,
      onTap: () => widget.onIndexChanged(index),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  final int index;
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final primaryColor = UrjaTheme.primaryGreen;

    final Color textColor = widget.isSelected
        ? primaryColor
        : (_isHovered
            ? primaryColor.withValues(alpha: 0.8)
            : Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey);

    final Color iconColor = widget.isSelected
        ? primaryColor
        : (_isHovered
            ? primaryColor.withValues(alpha: 0.8)
            : Theme.of(context).iconTheme.color ?? Colors.grey);

    final Color backgroundColor = widget.isSelected
        ? primaryColor.withValues(alpha: 0.15)
        : (_isHovered
            ? primaryColor.withValues(alpha: 0.05)
            : Colors.transparent);

    final Border? border = widget.isSelected
        ? Border.all(color: primaryColor.withValues(alpha: 0.2))
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: border,
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: iconColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: widget.isSelected
                      ? FontWeight.w600
                      : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
