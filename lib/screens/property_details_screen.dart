import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/property_model.dart';
import '../themes.dart';
import '../utils/responsive.dart';


// Helper functions delegated to AppTheme
double responsiveFontSize(BuildContext context, double baseFontSize) => AppTheme.responsiveFontSize(context, baseFontSize);
EdgeInsets responsivePadding(BuildContext context, {double horizontal = 24.0, double vertical = 0.0}) => AppTheme.responsivePadding(context, horizontal: horizontal, vertical: vertical);

class PropertyDetailsScreen extends StatefulWidget {
  final Property property;

  const PropertyDetailsScreen({Key? key, required this.property}) : super(key: key);

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();
  bool _isSaving = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _checkIfSaved();
  }

  Future<void> _checkIfSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final savedProperties = prefs.getStringList('saved_properties') ?? [];
    setState(() {
      _isSaved = savedProperties.contains(widget.property.id);
    });
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final savedProperties = prefs.getStringList('saved_properties') ?? [];

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isSaved) {
        savedProperties.remove(widget.property.id);
        await prefs.setStringList('saved_properties', savedProperties);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from favorites'), backgroundColor: Colors.orange),
        );
      } else {
        savedProperties.add(widget.property.id!);
        await prefs.setStringList('saved_properties', savedProperties);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to favorites'), backgroundColor: Colors.green),
        );
      }
      setState(() {
        _isSaved = !_isSaved;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update favorites: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showContactOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        padding: responsivePadding(context, horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondaryColor(context).withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Contact Agent',
              style: TextStyle(
                fontSize: responsiveFontSize(context, 20),
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor(context),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose how you\'d like to contact the agent for "${widget.property.title}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsiveFontSize(context, 14),
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
            const SizedBox(height: 24),
            _buildContactOption(
              icon: Icons.call_rounded,
              title: 'Call Now',
              subtitle: '055 792 2593',
              color: Colors.green,
              onTap: () => _makePhoneCall('0557922593'),
            ),
            const SizedBox(height: 12),
            _buildContactOption(
              icon: Icons.chat_rounded,
              title: 'Send Message',
              subtitle: 'Start a chat conversation',
              color: Colors.blue,
              onTap: () => _sendSms('0557922593'),
            ),
            const SizedBox(height: 12),
            _buildContactOption(
              icon: Icons.contact_phone_rounded,
              title: 'WhatsApp',
              subtitle: 'Contact via WhatsApp',
              color: Colors.green,
              onTap: () => _openWhatsApp('0557922593'),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondaryColor(context),
                side: BorderSide(color: AppTheme.textSecondaryColor(context).withOpacity(0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    Navigator.pop(context);

    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final Uri url = Uri(scheme: 'tel', path: phoneNumber);

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot make call to $phoneNumber'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendSms(String? phoneNumber) async {
    Navigator.pop(context);

    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number available for SMS'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final Uri url = Uri(scheme: 'sms', path: phoneNumber);

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot send SMS to $phoneNumber'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openWhatsApp(String? phoneNumber) async {
    Navigator.pop(context);

    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number available for WhatsApp'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final Uri url = Uri.parse("https://wa.me/$cleanNumber");

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot open WhatsApp'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
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
    );
  }

  Widget _buildImageGallery() {
    final images = widget.property.allImageUrls;

    if (images.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryRed.withOpacity(0.1),
              AppTheme.gold.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.home_work_rounded,
                color: AppTheme.primaryRed.withOpacity(0.5),
                size: 80,
              ),
              const SizedBox(height: 8),
              Text(
                'No Images Available',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor(context),
                  fontSize: responsiveFontSize(context, 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: index == 0 
                    ? Hero(
                        tag: 'property_image_${widget.property.id}',
                        child: _buildNetworkImage(images[index], context),
                      )
                    : _buildNetworkImage(images[index], context),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),
        if (images.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length, (index) {
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentImageIndex == index
                      ? AppTheme.primaryRed
                      : AppTheme.textSecondaryColor(context).withOpacity(0.3),
                ),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildNetworkImage(String url, BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: AppTheme.primaryRed.withOpacity(0.1),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: AppTheme.primaryRed.withOpacity(0.1),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image_rounded,
                color: AppTheme.primaryRed.withOpacity(0.5),
                size: 60,
              ),
              const SizedBox(height: 8),
              Text(
                'Failed to load image',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyInfo(Property property) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                property.title,
                style: TextStyle(
                  fontSize: responsiveFontSize(context, 24),
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textColor(context),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryRed),
              ),
              child: Text(
                (property.status ?? 'available').toUpperCase(),
                style: TextStyle(
                  fontSize: responsiveFontSize(context, 12),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryRed,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'GHC ${property.price} / month',
          style: TextStyle(
            fontSize: responsiveFontSize(context, 28),
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryRed,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              Icons.location_on_rounded,
              color: AppTheme.textSecondaryColor(context),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              property.location,
              style: TextStyle(
                fontSize: responsiveFontSize(context, 16),
                color: AppTheme.textSecondaryColor(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.category_rounded,
              color: AppTheme.textSecondaryColor(context),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              property.type,
              style: TextStyle(
                fontSize: responsiveFontSize(context, 16),
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Description',
                style: TextStyle(
                  fontSize: responsiveFontSize(context, 18),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                (property.plainDescription.isNotEmpty
                    ? property.plainDescription
                    : 'A comfortable and well-maintained property located in ${property.location}. Perfect for students and professionals looking for quality accommodation.'),
                style: TextStyle(
                  fontSize: responsiveFontSize(context, 14),
                  color: AppTheme.textSecondaryColor(context),
                  height: 1.5,
                ),
              ),
              if (property.amenities.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Amenities',
                  style: TextStyle(
                    fontSize: responsiveFontSize(context, 16),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor(context),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: property.amenities.map((key) {
                    final amenity = kAmenities.firstWhere(
                      (a) => a['key'] == key,
                      orElse: () => {'key': key, 'label': key, 'icon': 0xe1a5},
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primaryRed.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            IconData(amenity['icon'] as int, fontFamily: 'MaterialIcons'),
                            size: 15,
                            color: AppTheme.primaryRed,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            amenity['label'] as String,
                            style: TextStyle(
                              fontSize: responsiveFontSize(context, 13),
                              color: AppTheme.primaryRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final property = widget.property;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: Responsive(
        mobile: _buildMobileLayout(property),
        desktop: _buildDesktopLayout(property),
      ),
      bottomNavigationBar: !Responsive.isDesktop(context) 
          ? _buildBottomActions() 
          : null,
    );
  }

  Widget _buildMobileLayout(Property property) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppTheme.cardColor(context),
          elevation: 0,
          pinned: true,
          expandedHeight: 320,
          flexibleSpace: FlexibleSpaceBar(
            background: _buildImageGallery(),
          ),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: responsivePadding(context, horizontal: 24, vertical: 24),
            child: _buildPropertyInfo(property),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(Property property) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Gallery (60%)
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      label: const Text('Back to Results'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondaryColor(context),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: _buildImageGallery(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Right: Info and Actions (40%)
            Expanded(
              flex: 2,
              child: Container(
                height: MediaQuery.of(context).size.height,
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor(context).withOpacity(0.5),
                  border: Border(left: BorderSide(color: Colors.grey.withOpacity(0.1))),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildPropertyInfo(property),
                      const SizedBox(height: 40),
                      _buildBottomActions(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: responsivePadding(context, horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        boxShadow: [
          if (!Responsive.isDesktop(context))
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
        ],
        borderRadius: Responsive.isDesktop(context) 
            ? BorderRadius.circular(16) 
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showContactOptions(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryRed,
                side: const BorderSide(color: AppTheme.primaryRed),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Contact Agent'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _toggleFavorite,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSaved ? Colors.grey : AppTheme.primaryRed,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(_isSaved ? Icons.check : Icons.save, color: Colors.white),
              label: Text(
                _isSaved ? 'Saved' : 'Save',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}