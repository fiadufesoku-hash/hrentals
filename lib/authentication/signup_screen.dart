
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../themes.dart';
import '../services/graphql_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'dart:convert';


// Helper function to calculate responsive font size
double responsiveFontSize(BuildContext context, double baseFontSize) {
  final screenWidth = MediaQuery.of(context).size.width;
  if (screenWidth < 360) return baseFontSize * 0.8;
  if (screenWidth < 400) return baseFontSize * 0.9;
  return baseFontSize;
}

// Helper function to calculate responsive padding
EdgeInsets responsivePadding(BuildContext context,
    {double horizontal = 24.0, double vertical = 0.0}) {
  final screenWidth = MediaQuery.of(context).size.width;
  if (screenWidth < 360) return EdgeInsets.symmetric(horizontal: horizontal * 0.8, vertical: vertical);
  if (screenWidth < 400) return EdgeInsets.symmetric(horizontal: horizontal * 0.9, vertical: vertical);
  return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _acceptTerms = false;
  final _storage = const FlutterSecureStorage();

  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    GraphQLService.validateGraphQLUrl();
  }

  void _signUp() async {
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (fullName.isEmpty || phone.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill in all fields');
      return;
    }
    if (phone.length < 10) {
      _showSnackBar('Phone must be at least 10 digits');
      return;
    }
    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters');
      return;
    }
    if (password != confirmPassword) {
      _showSnackBar('Passwords do not match');
      return;
    }
    if (!_acceptTerms) {
      _showSnackBar('Please accept the terms and conditions');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final autoEmail = '$phone@horentals.com';
      final result = await _authService.register(
        name: fullName,
        phone: phone,
        password: password,
        email: autoEmail,
      );

      if (result['token'] != null && result['user'] != null) {
        await _storage.write(key: 'auth_token', value: result['token']);
        await _storage.write(key: 'user_data', value: json.encode(result['user']));
        await _storage.write(key: 'user_role', value: result['user']['role'] ?? 'user');

        _showSnackBar('Account created! Welcome, $fullName');
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showSnackBar('Registration completed! Please login with your phone number.');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (e.toString().contains('User_email_key') || e.toString().contains('P2002')) {
        _showSnackBar('Phone number already registered. Please try logging in.');
      } else if (e.toString().contains('phone') && e.toString().contains('unique')) {
        _showSnackBar('Phone number already registered. Please try logging in.');
      } else {
        _showSnackBar('Signup error: ${e.toString()}');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.primaryRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.security_rounded,
                color: Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: responsiveFontSize(context, 20),
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor(context),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPolicySection('Last Updated', 'December 2024'),
                  const SizedBox(height: 16),

                  _buildPolicySection('1. Information We Collect',
                      'We collect personal and non-personal information to provide and improve our services:\n\n'
                          '• Account Information: Name, email, phone number\n'
                          '• Property Information: Property details, photos, descriptions\n'
                          '• Payment Information: Billing details, transaction history\n'
                          '• Usage Data: How you use our app, features accessed\n'
                          '• Device Information: Device type, operating system, IP address\n'
                          '• Location Data: Approximate location for property recommendations'
                  ),

                  _buildPolicySection('2. How We Use Your Information',
                      'We use your information to:\n\n'
                          '• Provide and maintain our services\n'
                          '• Facilitate property sales, rentals, and management\n'
                          '• Verify user identities and prevent fraud\n'
                          '• Communicate about your account and transactions\n'
                          '• Personalize your experience\n'
                          '• Process payments securely\n'
                          '• Comply with legal obligations'
                  ),

                  _buildPolicySection('3. Data Security',
                      'We use industry-standard security measures to protect your personal information, including encryption and secure servers. However, no system is completely secure, and we cannot guarantee absolute security.'
                  ),

                  _buildPolicySection('4. Your Privacy Rights',
                      'You have the right to:\n\n'
                          '• Access and receive a copy of your personal information\n'
                          '• Correct or update inaccurate information\n'
                          '• Request deletion of your data\n'
                          '• Withdraw consent for certain processing activities'
                  ),

                  _buildPolicySection('5. Contact Us',
                      'If you have any questions about this Privacy Policy, please contact us at:\n\n'
                          'Ho Rentals\n'
                          'Email: thehorentals@gmail.com\n'
                          'Phone: 0204940602, 0595744526, 0599682185\n'
                          'Address: Ho, Ghana'
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.description_rounded,
                color: Colors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Terms & Conditions',
              style: TextStyle(
                fontSize: responsiveFontSize(context, 20),
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor(context),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPolicySection('Last Updated', 'December 2024'),
                  const SizedBox(height: 16),

                  _buildPolicySection('1. About Ho Rentals',
                      'Ho Rentals provides an online platform that connects property owners, buyers, and renters for property sales, rentals, and management. We act as a middleman and property manager to ensure smooth and trustworthy transactions.'
                  ),

                  _buildPolicySection('2. Eligibility',
                      'To use our Services, you must:\n\n'
                          '• Be at least 18 years old\n'
                          '• Have legal capacity to enter into agreements\n'
                          '• Provide accurate and truthful information'
                  ),

                  _buildPolicySection('3. Account Registration',
                      '• You must create an account to access most features\n'
                          '• You are responsible for maintaining account security\n'
                          '• Notify us immediately of unauthorized access\n'
                          '• We reserve the right to suspend accounts for misuse'
                  ),

                  _buildPolicySection('4. Our Role',
                      'Ho Rentals serves as an intermediary between property owners and clients. We facilitate property listings, inquiries, and management, but we do not own or control the properties listed unless stated otherwise.'
                  ),

                  _buildPolicySection('5. Property Listings',
                      'If you list a property:\n\n'
                          '• Ensure all information is accurate and up-to-date\n'
                          '• Confirm you have legal right to list the property\n'
                          '• Ho Rentals is not liable for false or misleading listings'
                  ),

                  _buildPolicySection('6. Payments and Fees',
                      '• Some features may require payment\n'
                          '• All payments through approved methods\n'
                          '• Provide accurate billing information\n'
                          '• Fees are generally non-refundable'
                  ),

                  _buildPolicySection('7. Prohibited Activities',
                      'You agree not to:\n\n'
                          '• Use the app for unlawful activities\n'
                          '• Post false or offensive content\n'
                          '• Impersonate others\n'
                          '• Circumvent payment systems\n'
                          '• Disrupt app functionality'
                  ),

                  _buildPolicySection('8. Limitation of Liability',
                      'Ho Rentals and its affiliates are not liable for indirect, incidental, or consequential damages. We make no warranties regarding accuracy, availability, or reliability of property listings.'
                  ),

                  _buildPolicySection('9. Contact Information',
                      'Ho Rentals\n'
                          'Email: thehorentals@gmail.com\n'
                          'Phone: 0204940602, 0595744526, 0599682185\n'
                          'Address: Ho, Ghana'
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: responsiveFontSize(context, 16),
              fontWeight: FontWeight.w700,
              color: AppTheme.textColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: responsiveFontSize(context, 14),
              color: AppTheme.textSecondaryColor(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: responsivePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  _buildBackButton(context),
                  const SizedBox(height: 20),
                  _buildLogo(),
                  const SizedBox(height: 20),
                  _buildHeader(context),
                  const SizedBox(height: 32),
                  _buildForm(context),
                  const SizedBox(height: 32),
                  _buildLoginLink(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.arrow_back_rounded, color: AppTheme.textColor(context), size: 20),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(25)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Image.asset(
          'assets/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppTheme.primaryRed,
            child: const Center(
              child: Text('LOGO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Text(
          "Create Account",
          style: TextStyle(
            fontSize: responsiveFontSize(context, 24),
            fontWeight: FontWeight.w800,
            color: AppTheme.textColor(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Join thousands finding their perfect home in Ghana",
          style: TextStyle(
            fontSize: responsiveFontSize(context, 16),
            color: AppTheme.textSecondaryColor(context),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Container(
      padding: responsivePadding(context, horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildTextField(_fullNameController, "Full Name", "Enter your full name"),
          const SizedBox(height: 20),
          _buildTextField(_phoneController, "Phone Number", "Enter your phone number",
              keyboardType: TextInputType.phone),
          const SizedBox(height: 20),
          _buildTextField(_passwordController, "Password", "Create a password",
              isPassword: true, obscureText: _obscurePassword, toggleObscure: () {
                setState(() => _obscurePassword = !_obscurePassword);
              }),
          const SizedBox(height: 20),
          _buildTextField(_confirmPasswordController, "Confirm Password", "Confirm your password",
              isPassword: true, obscureText: _obscureConfirmPassword, toggleObscure: () {
                setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
              }),
          const SizedBox(height: 20),
          _buildTerms(),
          const SizedBox(height: 24),
          _buildSignUpButton(),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint,
      {TextInputType keyboardType = TextInputType.text,
        bool isPassword = false,
        bool obscureText = false,
        VoidCallback? toggleObscure}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textColor(context))),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: TextStyle(color: AppTheme.textColor(context)),
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              suffixIcon: isPassword
                  ? IconButton(
                icon: Icon(obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                onPressed: toggleObscure,
              )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTerms() {
    return Row(
      children: [
        Checkbox(
          value: _acceptTerms,
          onChanged: (v) => setState(() => _acceptTerms = v!),
          fillColor: WidgetStateProperty.all(AppTheme.primaryRed),
        ),
        Expanded(
          child: Wrap(
            children: [
              Text("I agree to the ", style: TextStyle(color: AppTheme.textSecondaryColor(context))),
              GestureDetector(
                  onTap: _showTermsAndConditions,
                  child: const Text("Terms & Conditions", style: TextStyle(color: AppTheme.primaryRed))),
              Text(" and ", style: TextStyle(color: AppTheme.textSecondaryColor(context))),
              GestureDetector(
                  onTap: _showPrivacyPolicy,
                  child: const Text("Privacy Policy", style: TextStyle(color: AppTheme.primaryRed))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signUp,
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
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text("CREATE ACCOUNT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildLoginLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Already have an account? ", style: TextStyle(color: AppTheme.textSecondaryColor(context))),
        GestureDetector(
          onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          child: const Text("Sign In", style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
