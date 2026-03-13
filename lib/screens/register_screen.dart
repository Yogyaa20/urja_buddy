import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/urja_theme.dart';
import '../widgets/dashboard_widgets.dart';
import '../screens/home_screen.dart';
import '../core/auth_wrapper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController(); // Added Confirm Password
  final _unitController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  Future<void> _register() async {
    if (_fullNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty ||
        _unitController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);
    // debugPrint("Starting registration process...");
    try {
      // debugPrint("Calling authService.register...");
      await _authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        fullName: _fullNameController.text.trim(),
        unitNumber: _unitController.text.trim(),
        address: _unitController.text.trim(),
      );
      // debugPrint("Registration successful. Navigating to Home...");
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
           MaterialPageRoute(builder: (context) => const AuthWrapper()),
           (route) => false,
         );
      }
    } catch (e) {
      String errorMessage = 'Registration failed: ${e.toString()}';
      
      // Handle Firebase specific errors without using the class directly to avoid compiler issues
      if (e.toString().contains('firebase_auth')) {
        if (e.toString().contains('weak-password')) {
          errorMessage = 'The password provided is too weak.';
        } else if (e.toString().contains('email-already-in-use')) {
          errorMessage = 'The account already exists for that email.';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = 'The email address is invalid.';
        }
      }

      // debugPrint('Registration Error: $e'); // Print error to console
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: UrjaTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UrjaTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: UrjaTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
                constraints: const BoxConstraints(maxWidth: 400),
                child: GlassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Container(
                        width: 180, // Even larger size
                        height: 180,
                        padding: EdgeInsets.zero,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent, // Removed white ring
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo_black.png',
                            fit: BoxFit.cover, // Fill the entire circle
                            errorBuilder: (c, o, s) => const Icon(Icons.bolt, size: 100, color: UrjaTheme.primaryGreen),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Create Account',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: UrjaTheme.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Join the Green Valley community',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 32),
                      
                      // Full Name
                      _buildTextField(
                        controller: _fullNameController,
                        hint: 'Full Name',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      
                      // Email
                      _buildTextField(
                        controller: _emailController,
                        hint: 'Email Address',
                        icon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 16),
                      
                      // Password
                      _buildTextField(
                        controller: _passwordController,
                        hint: 'Password',
                        icon: Icons.lock_outline,
                        isPassword: true,
                        isPasswordVisible: _isPasswordVisible,
                        onVisibilityChanged: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      _buildTextField(
                        controller: _confirmPasswordController,
                        hint: 'Confirm Password',
                        icon: Icons.lock_outline,
                        isPassword: true,
                        isPasswordVisible: _isConfirmPasswordVisible,
                        onVisibilityChanged: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                      ),
                      const SizedBox(height: 16),
                      
                      // Address Field (Renamed from Unit Number to match screenshot)
                      _buildTextField(
                        controller: _unitController,
                        hint: 'Address (e.g. F-101 Green Valley)',
                        icon: Icons.home_outlined,
                      ),
                      const SizedBox(height: 32),
                      
                      // Register Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: UrjaTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            shadowColor: UrjaTheme.primaryGreen.withValues(alpha: 0.4),
                          ).copyWith(
                            elevation: WidgetStateProperty.all(8),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Create Account',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Force Dashboard Button
                      TextButton(
                        onPressed: () {
                          // Bypass Login Logic
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const HomeScreen()),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          'Skip to Dashboard (Test Mode)',
                          style: TextStyle(
                            color: UrjaTheme.primaryGreen, 
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
    bool isPassword = false,
    bool? isPasswordVisible,
    VoidCallback? onVisibilityChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !(isPasswordVisible ?? false),
      style: const TextStyle(color: UrjaTheme.textPrimary),
      keyboardType: isPassword ? TextInputType.visiblePassword : TextInputType.emailAddress,
      textCapitalization: TextCapitalization.none,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: UrjaTheme.textSecondary),
        prefixIcon: Icon(icon, color: UrjaTheme.textSecondary),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  (isPasswordVisible ?? false) ? Icons.visibility_off : Icons.visibility,
                  color: UrjaTheme.textSecondary,
                ),
                onPressed: onVisibilityChanged,
              )
            : null,
        filled: true,
        fillColor: UrjaTheme.glassBorder.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
