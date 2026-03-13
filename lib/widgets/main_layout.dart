import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/urja_theme.dart';
import '../providers/user_provider.dart';

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
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Watch User Provider for dynamic avatar
    final userState = ref.watch(userProvider);
    final userName = userState.value?.displayName ?? 'Urja User';
    // final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
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
                  colors: isDark ? [
                    UrjaTheme.primaryGreen.withValues(alpha: 0.15),
                    Colors.transparent,
                  ] : [
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
                  colors: isDark ? [
                    const Color(0xFF0EA5E9).withValues(alpha: 0.15), // Sky Blue
                    Colors.transparent,
                  ] : [
                    const Color(0xFF0EA5E9).withValues(alpha: 0.05), // Sky Blue
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
      drawer: isDesktop ? null : Drawer(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: _buildSidebarContent(context),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool showMenu) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final userState = ref.watch(userProvider);
    final userName = userState.value?.displayName ?? 'Urja User';
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: isDark ? 0.2 : 0.8))),
            color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.7),
          ),
          child: Row(
            children: [
              if (showMenu)
                IconButton(
                  icon: Icon(Icons.menu, color: Theme.of(context).iconTheme.color),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              if (showMenu) const SizedBox(width: 16),
              Text(
                'Dashboard',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24),
              ),
              const Spacer(),
              // Removed Search Icon
              _buildIconButton(context, Icons.notifications_outlined, () {
                 // The user requested to use Navigator.push, but SmartAlerts is also a tab (index 2).
                 // For better UX in a bottom/side nav app, switching tabs is preferred.
                 // However, I will honor the request to "redirect" which can be interpreted as switching context.
                 widget.onIndexChanged(2); 
              }),
              const SizedBox(width: 16),
              Container(
                height: 32,
                width: 1,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  userInitial,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(BuildContext context, IconData icon, VoidCallback onTap) {
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
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: Theme.of(context).iconTheme.color, size: 20),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.5),
        border: Border(right: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5))),
      ),
      child: _buildSidebarContent(context),
    );
  }

  Widget _buildSidebarContent(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory, // Disable splash globally for sidebar
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, // Center logo and text
              children: [
                // Logo Replacement (Image Asset)
                Container(
                  width: 50, // Constrained size (40-50)
                  height: 50,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent, // Transparent background
                  ),
                  child: Image.asset(
                    'assets/images/logo_black.png', // New black logo
                    fit: BoxFit.contain,
                  ),
                ),
              const SizedBox(width: 12),
              Text(
                'Urja Buddy',
                style: GoogleFonts.poppins(
                  textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w900, // Extra Bold
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildNavItem(0, Icons.grid_view_rounded, 'Dashboard'),
        _buildNavItem(1, Icons.pie_chart_rounded, 'Analytics'),
        _buildNavItem(2, Icons.bolt_rounded, 'Smart Alerts'),
        _buildNavItem(3, Icons.people_rounded, 'Community'),
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
    
    // Determine colors based on state
    final Color textColor = widget.isSelected 
        ? primaryColor 
        : (_isHovered ? primaryColor.withValues(alpha: 0.8) : Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey);
        
    final Color iconColor = widget.isSelected 
        ? primaryColor 
        : (_isHovered ? primaryColor.withValues(alpha: 0.8) : Theme.of(context).iconTheme.color ?? Colors.grey);

    final Color backgroundColor = widget.isSelected 
        ? primaryColor.withValues(alpha: 0.15) 
        : (_isHovered ? primaryColor.withValues(alpha: 0.05) : Colors.transparent);
        
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
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
