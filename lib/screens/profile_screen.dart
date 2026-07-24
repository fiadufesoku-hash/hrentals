import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../themes.dart';
import '../authentication/login_screen.dart';
import 'personal_information_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'saved_properties_screen.dart';


// Helper functions delegated to AppTheme
double responsiveFontSize(BuildContext context, double baseFontSize) => AppTheme.responsiveFontSize(context, baseFontSize);
EdgeInsets responsivePadding(BuildContext context, {double horizontal = 24.0, double vertical = 0.0}) => AppTheme.responsivePadding(context, horizontal: horizontal, vertical: vertical);

class ProfileScreen extends StatefulWidget {
  final Function(bool) toggleTheme;

  const ProfileScreen({super.key, required this.toggleTheme});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final List<Map<String, dynamic>> _profileOptions = [
    {
      'title': 'Personal Information',
      'subtitle': 'Update your profile details',
      'icon': Icons.person_outline_rounded,
      'color': AppTheme.primaryRed,
      'route': '/personal_info',
    },
    {
      'title': 'Saved Properties',
      'subtitle': 'View your favorite listings',
      'icon': Icons.bookmark_border_rounded,
      'color': AppTheme.gold,
    },
    {
      'title': 'Privacy Policy',
      'subtitle': 'Read our privacy policy',
      'icon': Icons.security_rounded,
      'color': AppTheme.primaryRed,
    },
    {
      'title': 'Terms & Conditions',
      'subtitle': 'Read our terms of service',
      'icon': Icons.description_rounded,
      'color': AppTheme.primaryRed,
    },
    {
      'title': 'Help & Support',
      'subtitle': 'Get help and contact support',
      'icon': Icons.help_outline_rounded,
      'color': AppTheme.primaryRed,
      'route': '/help_support',
    },
    {
      'title': 'About Ho Rentals',
      'subtitle': 'Learn more about our app',
      'icon': Icons.info_outline_rounded,
      'color': AppTheme.primaryRed,
    },
  ];

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Map<String, dynamic>? _currentUser;
  bool _isDarkMode = false;
  bool _isInitialized = false;

  List<Map<String, dynamic>> get _getEffectiveProfileOptions {
    final options = List<Map<String, dynamic>>.from(_profileOptions);
    final role = _currentUser?['role']?.toString().toLowerCase() ?? 'user';
    if (role == 'admin' || role == 'partner') {
      if (!options.any((opt) => opt['title'] == 'Admin Dashboard')) {
        options.insert(0, {
          'title': 'Admin Dashboard',
          'subtitle': 'Manage properties and users',
          'icon': Icons.admin_panel_settings_rounded,
          'color': AppTheme.gold,
        });
      }
    }
    return options;
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _checkCurrentTheme();
      _isInitialized = true;
    }
  }

  Future<void> _loadUserData() async {
    final userData = await _storage.read(key: 'user_data');
    if (userData != null) {
      setState(() {
        _currentUser = json.decode(userData);
      });
    }
  }

  void _checkCurrentTheme() {
    final brightness = Theme.of(context).brightness;
    setState(() {
      _isDarkMode = brightness == Brightness.dark;
    });
  }

  String _getUserInitials() {
    if (_currentUser == null) return 'U';
    final name = _currentUser!['name'] ?? _currentUser!['email'] ?? 'User';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String _getUserName() {
    if (_currentUser == null) return 'User';
    return _currentUser!['name'] ?? _currentUser!['email']?.split('@').first ?? 'User';
  }

  String _getUserEmail() {
    if (_currentUser == null) return 'user@email.com';
    return _currentUser!['email'] ?? '${_currentUser!['phone']}@horentals.com';
  }

  String _getUserRole() {
    if (_currentUser == null) return 'Student Account';
    final role = _currentUser!['role'] ?? 'user';
    return '${role[0].toUpperCase()}${role.substring(1)} Account';
  }

  void _showLogoutDialog() {
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
                color: AppTheme.primaryRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppTheme.primaryRed,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Log Out',
              style: TextStyle(
                fontSize: responsiveFontSize(context, 20),
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor(context),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of your account?',
          style: TextStyle(
            fontSize: responsiveFontSize(context, 16),
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondaryColor(context),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _performLogout() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Logging out...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryRed,
        duration: Duration(seconds: 2),
      ),
    );

    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_data');

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    });
  }

  void _showAboutDialog() {
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
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'About Ho Rentals',
              style: TextStyle(
                fontSize: responsiveFontSize(context, 20),
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor(context),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ho Rentals is your trusted platform for finding the perfect student accommodation in Ho and surrounding areas. We connect students with quality hostels, rooms, and apartments.',
              style: TextStyle(
                fontSize: responsiveFontSize(context, 14),
                color: AppTheme.textSecondaryColor(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Version', '1.0.0'),
            _buildInfoRow('Build Number', '2024.12.1'),
            _buildInfoRow('Last Updated', 'December 2024'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryRed,
            ),
            child: const Text('Close'),
          ),
        ],
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
                          'Phone: 0557922593, 0595744526, 0599682185\n'
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
                          'Phone: 0557922593, 0595744526, 0599682185\n'
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: responsiveFontSize(context, 14),
              fontWeight: FontWeight.w500,
              color: AppTheme.textColor(context),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: responsiveFontSize(context, 14),
              color: AppTheme.textSecondaryColor(context),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),

        slivers: [
          // Profile Header
          SliverAppBar(
            backgroundColor: AppTheme.cardColor(context),
            elevation: 0,
            pinned: true,
            expandedHeight: 120, // Changed from 160 to 120
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                ),
                child: Padding(
                  padding: responsivePadding(context, horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end, // Keep this
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Make avatar clickable for editing
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PersonalInformationScreen(userData: _currentUser),
                                ),
                              );
                            },
                            child: Container(
                              width: 45, // Slightly smaller
                              height: 45,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _getUserInitials(),
                                  style: TextStyle(
                                    color: AppTheme.primaryRed,
                                    fontSize: responsiveFontSize(context, 16), // Slightly smaller
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getUserName(),
                                  style: TextStyle(
                                    fontSize: responsiveFontSize(context, 18),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getUserEmail(),
                                  style: TextStyle(
                                    fontSize: responsiveFontSize(context, 12),
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getUserRole(),
                                    style: TextStyle(
                                      fontSize: responsiveFontSize(context, 12),
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Profile Options
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: responsivePadding(context, horizontal: 24, vertical: 24),
                child: Column(
                  children: [
                    // Theme Toggle (Moved up)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _isDarkMode = !_isDarkMode;
                        });
                        widget.toggleTheme(_isDarkMode);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16), // Add margin below
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor(context),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                              color: Colors.amber,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'Dark Mode',
                            style: TextStyle(
                              fontSize: responsiveFontSize(context, 16),
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textColor(context),
                            ),
                          ),
                          subtitle: Text(
                            _isDarkMode ? 'Dark theme enabled' : 'Light theme enabled',
                            style: TextStyle(
                              fontSize: responsiveFontSize(context, 14),
                              color: AppTheme.textSecondaryColor(context),
                            ),
                          ),
                          trailing: Switch(
                            value: _isDarkMode,
                            onChanged: (value) {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _isDarkMode = value;
                              });
                              widget.toggleTheme(value);
                            },
                            activeThumbColor: AppTheme.primaryRed,
                          ),
                        ),
                      ),
                    ),

                    // Profile Sections
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor(context),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: () {
                          final options = _getEffectiveProfileOptions;
                          return options.map((option) {
                            final index = options.indexOf(option);
                            return Column(
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    splashColor: option['color'].withOpacity(0.1),
                                    onTap: () {
                                      HapticFeedback.lightImpact();

                                      if (option['title'] == 'Personal Information') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PersonalInformationScreen(userData: _currentUser),
                                          ),
                                        );
                                      } else if (option['title'] == 'Admin Dashboard') {
                                        Navigator.pushNamed(context, '/admin');
                                      } else if (option['title'] == 'Saved Properties') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const SavedPropertiesScreen(),
                                        ),
                                      );
                                    } else if (option['title'] == 'About Ho Rentals') {
                                      _showAboutDialog();
                                    } else if (option['title'] == 'Privacy Policy') {
                                      _showPrivacyPolicy();
                                    } else if (option['title'] == 'Terms & Conditions') {
                                      _showTermsAndConditions();
                                    } else if (option['title'] == 'Help & Support') {
                                      _showHelpSupportDialog();
                                    }
                                  },

                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: ListTile(
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: option['color'].withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          option['icon'],
                                          color: option['color'],
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        option['title'],
                                        style: TextStyle(
                                          fontSize: responsiveFontSize(context, 16),
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textColor(context),
                                        ),
                                      ),
                                      subtitle: Text(
                                        option['subtitle'],
                                        style: TextStyle(
                                          fontSize: responsiveFontSize(context, 14),
                                          color: AppTheme.textSecondaryColor(context),
                                        ),
                                      ),
                                      trailing: Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: AppTheme.textSecondaryColor(context),
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Add subtle divider (except after last item)
                              if (index != _profileOptions.length - 1)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Divider(
                                    height: 1,
                                    color: AppTheme.textSecondaryColor(context)
                                        .withOpacity(0.1),
                                    thickness: 0.5,
                                  ),
                                ),
                            ],
                          );
                        }).toList();
                      }(),
                    ),
                    ),

                    const SizedBox(height: 24),

                    // Logout Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor(context),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryRed.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: AppTheme.primaryRed,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: responsiveFontSize(context, 16),
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryRed,
                          ),
                        ),
                        subtitle: Text(
                          'Sign out of your account',
                          style: TextStyle(
                            fontSize: responsiveFontSize(context, 14),
                            color: AppTheme.primaryRed.withOpacity(0.7),
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppTheme.primaryRed,
                          size: 16,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showLogoutDialog();
                        },
                      ),
                    ),

                    const SizedBox(height: 32),

                    // App Version
                    Text(
                      'Ho Rentals v1.0.0',
                      style: TextStyle(
                        fontSize: responsiveFontSize(context, 14),
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '© 2024 Ho Rentals. All rights reserved.',
                      style: TextStyle(
                        fontSize: responsiveFontSize(context, 12),
                        color: AppTheme.textSecondaryColor(context)
                            .withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    ),
  ),
);

  }

  void _showHelpSupportDialog() {
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
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.help_rounded,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Help & Support',
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Need help? Contact us through any of these methods:',
                style: TextStyle(
                  fontSize: responsiveFontSize(context, 16),
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
              const SizedBox(height: 20),

              // Contact Methods
              _buildHelpContactMethod(
                icon: Icons.phone_rounded,
                title: 'Call Us',
                subtitle: '0557922593',
                onTap: () => _launchPhone('0557922593'),
              ),
              const SizedBox(height: 12),

              _buildHelpContactMethod(
                icon: Icons.email_rounded,
                title: 'Email Us',
                subtitle: 'thehorentals@gmail.com',
                onTap: () => _launchEmail(),
              ),
              const SizedBox(height: 12),

              _buildHelpContactMethod(
                icon: Icons.chat_rounded, //
                title: 'WhatsApp',
                subtitle: '0557922593',
                onTap: () => _launchWhatsapp('0557922593'),
              ),

              const SizedBox(height: 16),
              Divider(
                color: AppTheme.textSecondaryColor(context).withOpacity(0.1),
              ),
              const SizedBox(height: 8),

              // Support Hours
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    color: AppTheme.textSecondaryColor(context),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Support: 8:00 AM - 8:00 PM (GMT)',
                    style: TextStyle(
                      fontSize: responsiveFontSize(context, 14),
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryRed,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpContactMethod({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.backgroundColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.textSecondaryColor(context).withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: responsiveFontSize(context, 16),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: responsiveFontSize(context, 14),
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppTheme.textSecondaryColor(context),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchPhone(String phoneNumber) async {
    final Uri telLaunchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    _launchUri(telLaunchUri, 'phone');
  }

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'thehorentals@gmail.com',
      query: 'subject=Ho Rentals Support&body=Hello Ho Rentals team, I need help with:',
    );
    _launchUri(emailLaunchUri, 'email');
  }

  Future<void> _launchWhatsapp(String phoneNumber) async {
    final Uri whatsappLaunchUri = Uri.parse("https://wa.me/233${phoneNumber.substring(1)}?text=Hello%20Ho%20Rentals%20team,%20I%20need%20help%20with:");
    _launchUri(whatsappLaunchUri, 'WhatsApp');
  }

  Future<void> _launchUri(Uri url, String appName) async {
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context); // Close dialog
      }
    } else {
      _showSnackBar('Could not launch $appName app');
    }
  }

    void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.primaryRed,
      ),
    );
  }
}