import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/network/firebase_config.dart';
import 'core/auth_wrapper.dart';
import 'theme/urja_theme.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Pro-level Firebase Init
  await FirebaseConfig.initialize();
  
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('appliances');

  // Final Kill to White Lines (Web)
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
  
  runApp(const ProviderScope(child: UrjaBuddyApp()));
}

class UrjaBuddyApp extends ConsumerWidget {
  const UrjaBuddyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'URJA BUDDY',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: UrjaTheme.lightTheme.copyWith(
        visualDensity: VisualDensity.adaptivePlatformDensity,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        applyElevationOverlayColor: false,
      ),
      darkTheme: UrjaTheme.darkTheme.copyWith(
        visualDensity: VisualDensity.adaptivePlatformDensity,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        applyElevationOverlayColor: false,
      ),
      home: const AuthWrapper(),
    );
  }
}


