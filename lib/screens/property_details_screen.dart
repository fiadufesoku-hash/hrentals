import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  String get _contactPhone {
    final raw = widget.property.contact;
    if (raw != null && raw.trim().isNotEmpty) return raw.trim();
    final ownerPhone = widget.property.owner?['phone']?.toString();
    if (ownerPhone != null && ownerPhone.trim().isNotEmpty) return ownerPhone.trim();
    return '0204940602';
  }

  String get _displayContactPhone {
    final p = _contactPhone;
    if (p.length == 10 && p.startsWith('0')) {
      return '${p.substring(0, 3)} ${p.substring(3, 6)} ${p.substring(6)}';
    }
    return p;
  }

  void _shareProperty() {
    final p = widget.property;
    final shareText = "🏠 *${p.title}*\n"
        "📍 Location: ${p.location}\n"
        "💰 Price: GH₵ ${p.price.toStringAsFixed(0)} / ${p.pricePeriod}\n"
        "🔗 Check it out on HO Rentals: ${p.shareUrl}";
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Listing details & link copied to clipboard!'),
        backgroundColor: AppTheme.primaryRed,
        action: SnackBarAction(
          label: 'Open WhatsApp',
          textColor: Colors.white,
          onPressed: () {
            final waUrl = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(shareText)}");
            launchUrl(waUrl, mode: LaunchMode.externalApplication);
          },
        ),
      ),
    );
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
                color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Contact Agent / Landlord',
              style: TextStyle(
                fontSize: responsiveFontSize(context, 20),
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Property: "${widget.property.title}"',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: responsiveFontSize(context, 14),
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
            const SizedBox(height: 20),
            _buildContactOption(
              icon: Icons.chat_rounded,
              title: 'WhatsApp Direct',
              subtitle: 'Send instant message with listing specs',
              color: const Color(0xFF25D366),
              onTap: () {
                Navigator.pop(context);
                _openWhatsApp();
              },
            ),
            const SizedBox(height: 12),
            _buildContactOption(
              icon: Icons.call_rounded,
              title: 'Call Agent',
              subtitle: _displayContactPhone,
              color: Colors.green,
              onTap: () => _makePhoneCall(_contactPhone),
            ),
            const SizedBox(height: 12),
            _buildContactOption(
              icon: Icons.message_rounded,
              title: 'Send SMS',
              subtitle: 'Regular text message',
              color: Colors.blue,
              onTap: () => _sendSms(_contactPhone),
            ),
            const SizedBox(height: 12),
            _buildContactOption(
              icon: Icons.directions_car_rounded,
              title: 'Request Yuyu Ride 🚗',
              subtitle: 'Book an inspection ride with driver',
              color: const Color(0xFF10B981),
              onTap: () {
                Navigator.pop(context);
                _openYuyuRideWhatsApp();
              },
            ),
            const SizedBox(height: 12),
            _buildContactOption(
              icon: Icons.share_rounded,
              title: 'Share Listing',
              subtitle: 'Copy link or share to friends & family',
              color: const Color(0xFF8B5CF6),
              onTap: () {
                Navigator.pop(context);
                _shareProperty();
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondaryColor(context),
                side: BorderSide(color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    final targetPhone = (phoneNumber != null && phoneNumber.isNotEmpty) ? phoneNumber : _contactPhone;
    final Uri url = Uri(scheme: 'tel', path: targetPhone);

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot make call to $targetPhone'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendSms(String? phoneNumber) async {
    final targetPhone = (phoneNumber != null && phoneNumber.isNotEmpty) ? phoneNumber : _contactPhone;
    final Uri url = Uri(scheme: 'sms', path: targetPhone);

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot send SMS to $targetPhone'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openWhatsApp([String? phoneNumber]) async {
    final p = widget.property;
    final targetPhone = (phoneNumber != null && phoneNumber.isNotEmpty)
        ? phoneNumber
        : _contactPhone;
    final digits = targetPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final cleanNumber = digits.startsWith('0')
        ? '233${digits.substring(1)}'
        : digits.startsWith('233')
            ? digits
            : (digits.isNotEmpty ? '233$digits' : '233204940602');

    final text = "Hello, I am interested in your property listed on HO Rentals:\n\n"
        "📌 *${p.title}*\n"
        "📍 Location: ${p.location}\n"
        "💰 Price: GH₵ ${p.price.toStringAsFixed(0)} / ${p.pricePeriod}\n"
        "${p.id != null ? '🆔 Listing ID: #${p.id}\n\n' : '\n'}"
        "I would like to arrange a viewing.";

    final Uri url = Uri.parse("https://wa.me/$cleanNumber?text=${Uri.encodeComponent(text)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot open WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openYuyuRideWhatsApp() async {
    final prefs = await SharedPreferences.getInstance();
    final userToken = prefs.getString('user_token');
    final isLoggedIn = userToken != null && userToken.isNotEmpty;

    if (!isLoggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in or sign up to book a ride with Yuyu Rides'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final propertyTitle = widget.property.title;
    final propertyLocation = widget.property.location;
    const yuyuNumber = "233538792644"; // Verified official Yuyu Rides partnership line

    final text = "Hi Yuyu Rides! 🚗 I'd like to request an inspection ride for a property listed on HO Rentals:\n\n"
        "🏠 Property: $propertyTitle\n"
        "📍 Location: $propertyLocation";
    final Uri url = Uri.parse("https://wa.me/$yuyuNumber?text=${Uri.encodeComponent(text)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot launch Yuyu Rides WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
              AppTheme.primaryRed.withValues(alpha: 0.1),
              AppTheme.gold.withValues(alpha: 0.1),
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
                color: AppTheme.primaryRed.withValues(alpha: 0.5),
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
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: images.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentImageIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
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
              if (images.length > 1)
                Positioned(
                  bottom: 12,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentImageIndex + 1} / ${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
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
                      : AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
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
        color: AppTheme.primaryRed.withValues(alpha: 0.1),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: AppTheme.primaryRed.withValues(alpha: 0.1),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image_rounded,
                color: AppTheme.primaryRed.withValues(alpha: 0.5),
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
                  fontSize: responsiveFontSize(context, 22),
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textColor(context),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (property.status?.toLowerCase() == 'rented' ? Colors.grey : AppTheme.primaryRed).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: property.status?.toLowerCase() == 'rented' ? Colors.grey : AppTheme.primaryRed),
              ),
              child: Text(
                (property.status ?? 'available').toUpperCase(),
                style: TextStyle(
                  fontSize: responsiveFontSize(context, 11),
                  fontWeight: FontWeight.w700,
                  color: property.status?.toLowerCase() == 'rented' ? Colors.grey : AppTheme.primaryRed,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'GH₵ ${property.price.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: responsiveFontSize(context, 26),
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryRed,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '/ ${property.pricePeriod}',
              style: TextStyle(
                fontSize: responsiveFontSize(context, 14),
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(
              Icons.location_on_rounded,
              color: AppTheme.primaryRed,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                property.location,
                style: TextStyle(
                  fontSize: responsiveFontSize(context, 15),
                  color: AppTheme.textColor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Quick Specs Badges
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.home_work_rounded, size: 14, color: AppTheme.primaryRed),
                  const SizedBox(width: 5),
                  Text(
                    property.type,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryRed),
                  ),
                ],
              ),
            ),
            if (property.advancePeriod != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_top_rounded, size: 14, color: Color(0xFFB45309)),
                    const SizedBox(width: 5),
                    Text(
                      property.advancePeriod!,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            if (property.meterType != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.electric_bolt_rounded, size: 14, color: Color(0xFF1D4ED8)),
                    const SizedBox(width: 5),
                    Text(
                      property.meterType!,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                    ),
                  ],
                ),
              ),
            if (property.waterSupply != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.water_drop_rounded, size: 14, color: Color(0xFF0369A1)),
                    const SizedBox(width: 5),
                    Text(
                      property.waterSupply!,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0369A1)),
                    ),
                  ],
                ),
              ),
            if (property.roomsAvailable != null && property.roomsAvailable!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bed_rounded, size: 14, color: Color(0xFF047857)),
                    const SizedBox(width: 5),
                    Text(
                      '${property.roomsAvailable} Rooms',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
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
                        color: AppTheme.primaryRed.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primaryRed.withValues(alpha: 0.25),
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
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
              ),
              onPressed: _shareProperty,
              tooltip: 'Share Listing',
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _isSaved ? AppTheme.primaryRed : Colors.white,
                  size: 20,
                ),
              ),
              onPressed: _toggleFavorite,
              tooltip: _isSaved ? 'Saved' : 'Save',
            ),
            const SizedBox(width: 4),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: responsivePadding(context, horizontal: 20, vertical: 20),
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
                              color: Colors.black.withValues(alpha: 0.1),
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
                  color: AppTheme.cardColor(context).withValues(alpha: 0.5),
                  border: Border(left: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
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
      padding: responsivePadding(context, horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        boxShadow: [
          if (!Responsive.isDesktop(context))
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
        ],
        borderRadius: Responsive.isDesktop(context) 
            ? BorderRadius.circular(16) 
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Yuyu Rides Button
            IconButton(
              onPressed: _openYuyuRideWhatsApp,
              tooltip: 'Book Yuyu Ride 🚗',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 8),
            // WhatsApp Direct Action Button (Hero CTA)
            Expanded(
              flex: 4,
              child: ElevatedButton.icon(
                onPressed: () => _openWhatsApp(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: const Text(
                  'WhatsApp',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Call / Options Button
            Expanded(
              flex: 3,
              child: OutlinedButton(
                onPressed: _showContactOptions,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textColor(context),
                  side: BorderSide(color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Call / More',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Favorite Button
            IconButton(
              onPressed: _isSaving ? null : _toggleFavorite,
              tooltip: _isSaved ? 'Saved' : 'Save to Favorites',
              style: IconButton.styleFrom(
                backgroundColor: _isSaved ? AppTheme.primaryRed.withValues(alpha: 0.1) : AppTheme.cardColor(context),
                side: BorderSide(
                  color: _isSaved ? AppTheme.primaryRed : AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
                ),
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                _isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isSaved ? AppTheme.primaryRed : AppTheme.textColor(context),
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}