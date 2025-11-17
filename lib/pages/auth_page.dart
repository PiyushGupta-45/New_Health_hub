// Authentication page with signup and signin tabs

import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';

class AuthPage extends StatefulWidget {
  final AuthController authController;

  const AuthPage({
    super.key,
    required this.authController,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  // Sign In Controllers
  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();

  // Sign Up Controllers
  final _signUpNameController = TextEditingController();
  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _signUpConfirmPasswordController = TextEditingController();

  bool _obscureSignInPassword = true;
  bool _obscureSignUpPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _signUpNameController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    _signUpConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_signInFormKey.currentState!.validate()) return;

    final result = await widget.authController.signIn(
      email: _signInEmailController.text.trim(),
      password: _signInPasswordController.text,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed in successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Sign in failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleSignUp() async {
    if (!_signUpFormKey.currentState!.validate()) return;

    final result = await widget.authController.signUp(
      name: _signUpNameController.text.trim(),
      email: _signUpEmailController.text.trim(),
      password: _signUpPasswordController.text,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Sign up failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final result = await widget.authController.signInWithGoogle();

    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed in with Google successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Google sign in failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Welcome to FitTrack',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue or create a new account',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.indigo.shade600,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: Colors.indigo.shade600,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    tabs: const [
                      Tab(text: 'Sign In'),
                      Tab(text: 'Sign Up'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSignInForm(),
                  _buildSignUpForm(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
      child: Form(
        key: _signInFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          _buildTextField(
            controller: _signInEmailController,
            label: 'Email',
            hint: 'Enter your email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _signInPasswordController,
            label: 'Password',
            hint: 'Enter your password',
            icon: Icons.lock_outlined,
            obscureText: _obscureSignInPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureSignInPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscureSignInPassword = !_obscureSignInPassword;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: widget.authController.isLoading ? null : _handleSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: widget.authController.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: widget.authController.isLoading
                ? null
                : _handleGoogleSignIn,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E293B),
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: Image.asset(
              'assets/google_logo.png',
              height: 20,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.g_mobiledata, size: 24);
              },
            ),
            label: const Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildSignUpForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
      child: Form(
        key: _signUpFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          _buildTextField(
            controller: _signUpNameController,
            label: 'Full Name',
            hint: 'Enter your full name',
            icon: Icons.person_outlined,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your name';
              }
              if (value.length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _signUpEmailController,
            label: 'Email',
            hint: 'Enter your email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _signUpPasswordController,
            label: 'Password',
            hint: 'Create a password',
            icon: Icons.lock_outlined,
            obscureText: _obscureSignUpPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureSignUpPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscureSignUpPassword = !_obscureSignUpPassword;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _signUpConfirmPasswordController,
            label: 'Confirm Password',
            hint: 'Confirm your password',
            icon: Icons.lock_outlined,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _signUpPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed:
                widget.authController.isLoading ? null : _handleSignUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: widget.authController.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Sign Up',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: widget.authController.isLoading
                ? null
                : _handleGoogleSignIn,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E293B),
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: Image.asset(
              'assets/google_logo.png',
              height: 20,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.g_mobiledata, size: 24);
              },
            ),
            label: const Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.grey.shade400),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.indigo.shade600, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}

