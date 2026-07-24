import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'signup_screen.dart';
import '../themes.dart';
import '../services/graphql_service.dart';
import '../services/auth_service.dart';
import 'forgot_password_screen.dart';
import '../utils/responsive.dart';

// Helper function to calculate responsive font size
double responsiveFontSize(BuildContext context, double baseFontSize) {
  final screenWidth = MediaQuery.of(context).size.width;
  // Adjust the base font size based on the screen width
  if (screenWidth < 360) {
    return baseFontSize * 0.8;
  } else if (screenWidth < 400) {
    return baseFontSize * 0.9;
  }
  return baseFontSize;
}

// Helper function to calculate responsive padding
EdgeInsets responsivePadding(BuildContext context, {double horizontal = 24.0, double vertical = 0.0}) {
  final screenWidth = MediaQuery.of(context).size.width;
  // Adjust horizontal padding based on screen width
  if (screenWidth < 360) {
    return EdgeInsets.symmetric(horizontal: horizontal * 0.8, vertical: vertical);
  } else if (screenWidth < 400) {
    return EdgeInsets.symmetric(horizontal: horizontal * 0.9, vertical: vertical);
  }
  return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  late AuthService _authService;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _loadRememberedCredentials();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await GraphQLService.testConnection();
    });
  }

  void _loadRememberedCredentials() async {
    final rememberedPhone = await _storage.read(key: 'remembered_phone');
    if (rememberedPhone != null) {
      setState(() {
        _phoneController.text = rememberedPhone;
        _rememberMe = true;
      });
    }
  }

  void _login() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill in all fields', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String emailForBackend;
      if (phone.contains('@')) {
        emailForBackend = phone;
      } else if (phone.toLowerCase() == 'admin') {
        emailForBackend = 'admin@horentals.com';
      } else {
        emailForBackend = '$phone@horentals.com';
      }
      
      final result = await GraphQLService.login(emailForBackend, password);

      if (result['token'] != null && result['user'] != null) {
        final userRole = result['user']['role']?.toString().toLowerCase() ?? 'user';
        final userName = result['user']['name'] ?? 'User';

        _showSnackBar('Welcome back, $userName!');

        if (!mounted) return;

        if (userRole == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        _showSnackBar('Login failed. Please check your phone number and password.', isError: true);
      }

    } catch (e) {
      if (e.toString().contains('Invalid credentials')) {
        _showSnackBar('Invalid phone number or password', isError: true);
      } else if (e.toString().contains('timeout')) {
        _showSnackBar('Connection timeout. Please check your internet.', isError: true);
      } else if (e.toString().contains('Network error')) {
        _showSnackBar('Cannot connect to server. Please try again.', isError: true);
      } else {
        _showSnackBar('Login error: $e', isError: true);
      }
    } finally {
      if (_rememberMe) {
        await _storage.write(key: 'remembered_phone', value: phone);
      } else {
        await _storage.delete(key: 'remembered_phone');
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: Row(
        children: [
          if (Responsive.isDesktop(context) || Responsive.isTablet(context))
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Image.asset('assets/logo.png'),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'HO Rentals',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'The premium student housing platform.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: responsivePadding(context),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          if (!(Responsive.isDesktop(context) || Responsive.isTablet(context)))
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: Image.asset(
                                  'assets/logo.png',
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: AppTheme.primaryRed,
                                      child: Center(
                                        child: Text(
                                          'LOGO',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: responsiveFontSize(context, 16),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          // Header Section
                          Column(
                            children: [
                              Text(
                                "Welcome Back",
                                style: TextStyle(
                                  fontSize: responsiveFontSize(context, 28),
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textColor(context),
                                  letterSpacing: -0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Sign in with your phone number",
                                style: TextStyle(
                                  fontSize: responsiveFontSize(context, 16),
                                  color: AppTheme.textSecondaryColor(context),
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          // Form Container
                          // ... Rest of the column content continues
                          Container(
                  padding: responsivePadding(context, horizontal: 24, vertical: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor(context),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Phone Number Field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Phone Number",
                            style: TextStyle(
                              fontSize: responsiveFontSize(context, 14),
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textColor(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                              ),
                            ),
                            child: TextField(
                              controller: _phoneController,
                              style: TextStyle(
                                color: AppTheme.textColor(context),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: "Enter your phone number",
                                hintStyle: TextStyle(
                                  color: AppTheme.textSecondaryColor(context),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Password Field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Password",
                            style: TextStyle(
                              fontSize: responsiveFontSize(context, 14),
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textColor(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                              ),
                            ),
                            child: TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: TextStyle(
                                color: AppTheme.textColor(context),
                              ),
                              decoration: InputDecoration(
                                hintText: "Enter your password",
                                hintStyle: TextStyle(
                                  color: AppTheme.textSecondaryColor(context),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Transform.translate(
                                    offset: const Offset(18, 0),
                                    child: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                        color: AppTheme.textSecondaryColor(context),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Remember Me & Forgot Password
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value!;
                                  });
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                fillColor: WidgetStateProperty.resolveWith<Color>(
                                      (Set<WidgetState> states) {
                                    return AppTheme.primaryRed;
                                  },
                                ),
                              ),
                              Text(
                                'Remember me',
                                style: TextStyle(
                                  fontSize: responsiveFontSize(context, 14),
                                  color: AppTheme.textSecondaryColor(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                              );
                            },
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(
                                fontSize: responsiveFontSize(context, 10),
                                color: AppTheme.primaryRed,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Sign In Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryRed,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor: AppTheme.primaryRed.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : Text(
                            "SIGN IN",
                            style: TextStyle(
                              fontSize: responsiveFontSize(context, 16),
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Sign Up Link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          fontSize: responsiveFontSize(context, 15),
                          color: AppTheme.textSecondaryColor(context),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => const SignupScreen(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                const begin = Offset(1.0, 0.0);
                                const end = Offset.zero;
                                const curve = Curves.easeInOut;
                                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                var offsetAnimation = animation.drive(tween);
                                return SlideTransition(
                                  position: offsetAnimation,
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                        child: Text(
                          "Sign Up",
                          style: TextStyle(
                            fontSize: responsiveFontSize(context, 15),
                            color: AppTheme.primaryRed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
