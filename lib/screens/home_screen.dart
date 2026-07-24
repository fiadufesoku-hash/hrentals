import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../themes.dart';
import '../services/graphql_service.dart';
import 'property_details_screen.dart';
import '../models/property_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/logger.dart';
import '../utils/responsive.dart';



// Helper functions delegated to AppTheme
double responsiveFontSize(BuildContext context, double baseFontSize) => AppTheme.responsiveFontSize(context, baseFontSize);
EdgeInsets responsivePadding(BuildContext context, {double horizontal = 24.0, double vertical = 0.0}) => AppTheme.responsivePadding(context, horizontal: horizontal, vertical: vertical);

class HomeScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  const HomeScreen({super.key, required this.toggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ---------- STATE ----------
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Local state for properties and filtering
  List<Property> _allProperties = [];
  List<Property> _filteredProperties = [];
  bool _isLoading = true;
  String? _error;

  // Local state for filter criteria
  String _searchQuery = '';
  String _activeTypeFilter = 'All';

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  // Local UI state
  bool _showSearchBar = false;
  bool _showSelfContainedDropdown = false;

  // Filters
  double _minPrice = 300, _maxPrice = 1500;
  final Set<String> _selectedPropTypes = {}, _selectedLocs = {};

  // User data
  Map<String, dynamic>? _currentUser;

  // ---------- CHIP DATA ----------
  final List<Map<String, dynamic>> _typeChips = [
    {'label': 'All', 'icon': Icons.all_inclusive_rounded, 'type': 'All'},
    {'label': 'Filters', 'icon': Icons.filter_alt_rounded, 'type': 'filters'},
    {'label': 'Student Hostel', 'icon': Icons.school_rounded, 'type': 'Student Hostel'},
    {'label': 'Single Room', 'icon': Icons.single_bed_rounded, 'type': 'Single Room'},
    {'label': 'Chamber & Hall', 'icon': Icons.apartment_rounded, 'type': 'Chamber & Hall'},
    {'label': 'Self-Contained', 'icon': Icons.arrow_drop_down_rounded, 'type': 'self-contained'},
    {'label': 'Furnitures', 'icon': Icons.chair_rounded, 'type': 'Furnitures'},
    {'label': 'Lands', 'icon': Icons.landscape_rounded, 'type': 'Lands'},
    {'label': 'Shops', 'icon': Icons.store_rounded, 'type': 'Shops'},
    {'label': 'Short Stay', 'icon': Icons.hotel_rounded, 'type': 'Short Stay'},
  ];

  final List<Map<String, dynamic>> _selfContainedOptions = [
    {'label': 'Single Room SC', 'icon': Icons.single_bed_rounded, 'type': 'Single Room SC'},
    {'label': 'Chamber and Hall SC', 'icon': Icons.meeting_room_rounded, 'type': 'Chamber and Hall SC'},
    {'label': 'Two Bedroom SC', 'icon': Icons.bed_rounded, 'type': 'Two Bedroom SC'},
    {'label': 'Three Bedroom SC', 'icon': Icons.bed_rounded, 'type': 'Three Bedroom SC'},
    {'label': 'Four Bedroom SC', 'icon': Icons.bed_rounded, 'type': 'Four Bedroom SC'},
  ];

  // ---------- LIFECYCLE ----------
  @override
  void initState() {
    super.initState();
    _minPriceController.text = _minPrice.toInt().toString();
    _maxPriceController.text = _maxPrice.toInt().toString();
    _loadUserData();
    _fetchProperties();
  }

  @override
  Future<void> dispose() async {
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final data = await _storage.read(key: 'user_data');
      if (data != null && mounted) {
        setState(() => _currentUser = json.decode(data));
        AppLogger.info('👤 Loaded user data: ${_currentUser?['name']}');
      }
    } catch (e) {
      AppLogger.error('❌ Error loading user data: $e');
    }
  }

  String _getInitials() {
    if (_currentUser == null) return '...';
    final name = _currentUser?['name'] as String? ?? _currentUser?['email'] as String? ?? 'User';
    final parts = name.split(' ');
    if (name.isEmpty) return 'U';
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  // ---------- DATA FETCHING & FILTERING ----------
  Future<void> _fetchProperties() async {
    setState(() {
      _isLoading = true;
      _error = null;

    });

    try {
      AppLogger.info('🔄 Fetching properties from GraphQL...');
      final propertiesData = await GraphQLService.getProperties();
      AppLogger.info('✅ Received ${propertiesData.length} properties from backend');

      final List<Property> properties = [];

      for (var propertyData in propertiesData) {
        try {
          final property = Property.fromJson(propertyData);
          properties.add(property);
        } catch (e, stackTrace) {
          AppLogger.error('❌ Error parsing property: $e');
          AppLogger.error('   Stack trace: $stackTrace');
        }
      }

      // 🚨 MOVE DEBUG CODE HERE - AFTER ALL PROPERTIES ARE PARSED
      AppLogger.debug('🔍 CHECKING IMAGE URLS:');
      AppLogger.debug('📊 Total properties parsed: ${properties.length}');

      for (var property in properties) {
        AppLogger.debug('   =================================');
        AppLogger.debug('   Property: ${property.title}');
        AppLogger.debug('   Type: ${property.type}');
        AppLogger.debug('   displayImage: ${property.displayImage}');
        AppLogger.debug('   Has images: ${property.hasImages}');
        AppLogger.debug('   All URLs: ${property.allImageUrls}');
        AppLogger.debug('   Gallery items: ${property.gallery?.length ?? 0}');
        AppLogger.debug('   ImageUrl: ${property.imageUrl}');
        AppLogger.debug('   Images array: ${property.images.length}');
        AppLogger.debug('   =================================');
      }

      setState(() {
        _allProperties = properties;
        _isLoading = false;
      });

      _applyFilters();

      AppLogger.info('🎯 Total properties loaded: ${_allProperties.length}');
      if (properties.isNotEmpty) {
        AppLogger.info('📊 Sample property: ${properties.first.title} - ${properties.first.type} - ${properties.first.images.length} images');
      }

    } catch (e) {
      AppLogger.error('❌ Error fetching properties: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _allProperties = [];
        _filteredProperties = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load properties: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      List<Property> filtered = _allProperties;

      if (_selectedPropTypes.isNotEmpty || _selectedLocs.isNotEmpty || _minPrice != 300 || _maxPrice != 1500) {
        filtered = filtered.where((p) => p.price >= _minPrice && p.price <= _maxPrice).toList();
        if (_selectedPropTypes.isNotEmpty) {
          filtered = filtered.where((p) => _selectedPropTypes.contains(p.type)).toList();
        }
        if (_selectedLocs.isNotEmpty) {
          filtered = filtered.where((p) => _selectedLocs.any((loc) => p.location.toLowerCase().contains(loc.toLowerCase()))).toList();
        }
      } else if (_activeTypeFilter != 'All') {
        if (_activeTypeFilter == 'self-contained') {
          filtered = filtered.where((p) {
            final type = p.type.toLowerCase();
            return type.contains('sc') || type.contains('self contained') || type.contains('self-contained');
          }).toList();
        } else {
          filtered = filtered.where((p) => p.type == _activeTypeFilter).toList();
        }
      }

      if (_searchQuery.isNotEmpty) {
        filtered = filtered.where((p) =>
        p.title.toLowerCase().contains(_searchQuery) ||
            p.location.toLowerCase().contains(_searchQuery)
        ).toList();
      }

      // Always keep featured properties at the top
      filtered.sort((a, b) {
        if (a.isFeatured == b.isFeatured) return 0;
        return a.isFeatured ? -1 : 1;
      });

      _filteredProperties = filtered;
    });
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Stack(

        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: AppTheme.cardColor(context),
                pinned: true,
                floating: true,
                title: _showSearchBar
                    ? null
                    : Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: const DecorationImage(
                          image: AssetImage('assets/logo.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'HO Rentals',
                      style: TextStyle(
                        fontSize: responsiveFontSize(context, 18),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                actions: [
                  if (_showSearchBar)
                    Expanded(
                      child: Padding(
                        padding: responsivePadding(context, horizontal: 16),
                        child: _searchField(),
                      ),
                    )
                  else
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.search_rounded, color: AppTheme.primaryRed),
                          onPressed: () => setState(() => _showSearchBar = true),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/profile'),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppTheme.primaryGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryRed.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.transparent,
                                child: Text(
                                  _getInitials(),
                                  style: TextStyle(
                                    fontSize: responsiveFontSize(context, 12),
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
                bottom: _showSearchBar
                    ? null
                    : PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(
                    color: Colors.grey.withOpacity(0.2),
                    height: 1,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: Responsive.isMobile(context)
                      ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                      : responsivePadding(context, horizontal: 16, vertical: 16),
                  child: Container(
                    padding: Responsive.isMobile(context)
                        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                        : responsivePadding(context, horizontal: 24, vertical: 24),
                    decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.all(
                          Radius.circular(Responsive.isMobile(context) ? 16 : 24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryRed.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                    ),
                    child: Responsive.isDesktop(context) || Responsive.isTablet(context)
                      ? Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Find Your Perfect Student Accommodation',
                                    style: TextStyle(fontSize: responsiveFontSize(context, 28), fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Quality hostels, rooms & self-contained apartments near Ho Polytechnic, UHAS & Trafalgar Campus',
                                    style: TextStyle(color: Colors.white70, fontSize: responsiveFontSize(context, 15)),
                                  ),
                                ],
                              ),
                            ),
                            const Expanded(
                              flex: 2,
                              child: Icon(Icons.home_work_rounded, size: 100, color: Colors.white24),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Find Your Perfect\nStudent Home',
                                    style: TextStyle(
                                      fontSize: responsiveFontSize(context, 15),
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Ho Polytechnic · UHAS · Trafalgar',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: responsiveFontSize(context, 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.home_work_rounded, size: 36, color: Colors.white24),
                          ],
                        ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: responsivePadding(context, horizontal: 16),
                  child: SizedBox(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _typeChips.map((c) {
                        final selected = _activeTypeFilter == c['type'];
                        if (c['type'] == 'filters') return _filterChip(c, selected);
                        if (c['type'] == 'self-contained') return _selfContainedChip(c, selected);
                        return _typeChip(c, selected);
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverPadding(
                padding: responsivePadding(context, horizontal: 16, vertical: 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoading ? 'Loading...' : 'Available Properties (${_filteredProperties.length})',
                        style: TextStyle(fontSize: responsiveFontSize(context, 18), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                SliverToBoxAdapter(child: Center(child: Text('Error: $_error')))
              else if (_filteredProperties.isEmpty)
                  SliverToBoxAdapter(child: _emptyState())
                else
                  Responsive.isMobile(context)
                      ? SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: responsivePadding(context, horizontal: 16, vertical: 12),
                              child: _propertyCard(_filteredProperties[index]),
                            ),
                            childCount: _filteredProperties.length,
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: Responsive.isDesktop(context) ? 4 : (Responsive.isTablet(context) ? 3 : 2),
                              childAspectRatio: Responsive.isDesktop(context) ? 0.75 : 0.8,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _propertyCard(_filteredProperties[index]),
                              childCount: _filteredProperties.length,
                            ),
                          ),
                        ),
            ],
          ),
          if (_showSelfContainedDropdown)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showSelfContainedDropdown = false),
                behavior: HitTestBehavior.translucent,
              ),
            ),
          if (_showSelfContainedDropdown)
            _selfContainedDropdownOverlay(),
        ],
      ),
    ),
  ),
  bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) Navigator.pushNamed(context, '/chat');
          if (i == 2) Navigator.pushNamed(context, '/profile');
        },
        selectedItemColor: AppTheme.primaryRed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_rounded), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _searchField() => Container(
    height: 40,
    decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(20)
    ),
    child: TextField(
      controller: _searchController,
      autofocus: true,
      onChanged: (value) {
        setState(() => _searchQuery = value.toLowerCase());
        _applyFilters();
      },
      decoration: InputDecoration(
        hintText: 'Search properties by title or location...',
        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryRed),
        suffixIcon: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _showSearchBar = false;
                _searchController.clear();
                _searchQuery = '';
              });
              _applyFilters();
            }
        ),
        border: InputBorder.none,
      ),
    ),
  );

  Widget _typeChip(Map<String, dynamic> c, bool sel) => GestureDetector(
    onTap: () {
      setState(() => _activeTypeFilter = c['type'] as String);
      _applyFilters();
    },
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: responsivePadding(context, horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: sel ? AppTheme.primaryRed : AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sel ? AppTheme.primaryRed : Colors.transparent),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(c['icon'], size: 16, color: sel ? Colors.white : AppTheme.primaryRed),
        const SizedBox(width: 6),
        Text(c['label'] as String, style: TextStyle(
          color: sel ? Colors.white : AppTheme.textColor(context),
          fontSize: responsiveFontSize(context, 12),
        )),
      ]),
    ),
  );

  Widget _filterChip(Map<String, dynamic> c, bool sel) => GestureDetector(
    onTap: _showAdvancedFilterModal,
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: responsivePadding(context, horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: sel ? AppTheme.primaryRed : AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(c['icon'], size: 16, color: sel ? Colors.white : AppTheme.primaryRed),
        const SizedBox(width: 6),
        Text(c['label'] as String, style: TextStyle(
          color: sel ? Colors.white : AppTheme.textColor(context),
          fontSize: responsiveFontSize(context, 12),
        )),
      ]),
    ),
  );

  Widget _selfContainedChip(Map<String, dynamic> c, bool sel) {
    final isAnySCOptionSelected = _selfContainedOptions.any((opt) => opt['type'] == _activeTypeFilter);
    final isSelected = _showSelfContainedDropdown || isAnySCOptionSelected;

    return GestureDetector(
      onTap: () => setState(() => _showSelfContainedDropdown = !_showSelfContainedDropdown),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: responsivePadding(context, horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryRed : AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isSelected ? Icons.arrow_drop_up : c['icon'], size: 18, color: isSelected ? Colors.white : AppTheme.primaryRed),
          const SizedBox(width: 6),
          Text(c['label'] as String,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textColor(context),
                fontSize: responsiveFontSize(context, 12),
              )),
        ]),
      ),
    ).animate().fade(duration: 300.ms).scale(duration: 300.ms);
  }

  Widget _selfContainedDropdownOverlay() {
    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: Material(
        color: AppTheme.cardColor(context),
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _selfContainedOptions.map((option) {
            final isSelected = _activeTypeFilter == option['type'];
            return ListTile(
              selected: isSelected,
              selectedColor: AppTheme.textColor(context),
              leading: Icon(option['icon'], color: isSelected ? AppTheme.primaryRed : AppTheme.textSecondaryColor(context)),
              title: Text(option['label'], style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              onTap: () {
                setState(() {
                  _activeTypeFilter = option['type'];
                  _showSelfContainedDropdown = false;
                  _applyFilters();
                });
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _emptyState() => Container(
    padding: const EdgeInsets.all(40),
    margin: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16)
    ),
    child: Column(children: [
      const Icon(Icons.search_off_rounded, size: 50, color: Colors.grey),
      const SizedBox(height: 16),
      Text('No properties found', style: TextStyle(fontSize: responsiveFontSize(context, 16), fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('Try adjusting your filters', style: TextStyle(color: Colors.grey)),
    ]),
  ).animate().fade(duration: 500.ms).scaleXY(begin: 0.9, end: 1.0, duration: 500.ms);

  Widget _propertyCard(Property p) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PropertyDetailsScreen(property: p))
      ),
      child: Container(
        decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: p.isFeatured
                    ? AppTheme.primaryRed.withOpacity(0.18)
                    : Colors.black.withOpacity(0.04),
                blurRadius: p.isFeatured ? 28 : 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: p.isFeatured
                ? Border.all(color: AppTheme.primaryRed.withOpacity(0.35), width: 1.5)
                : null,
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _showImageGallery(p),
                        behavior: HitTestBehavior.opaque,
                        child: Hero(
                          tag: 'property_image_${p.id}',
                          child: _buildPropertyImage(p),
                        ),
                      ),
                      if (p.isFeatured)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryRed.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'FEATURED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: responsiveFontSize(context, 10),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _PropertyCardDetails(p: p),
            ]
        ),
      ),
    ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms);
  }

  Widget _buildPropertyImage(Property p) {
    final imageUrl = p.displayImage;

    AppLogger.debug('🖼️ BUILDING IMAGE FOR: ${p.title}');
    AppLogger.debug('   displayImage: $imageUrl');
    AppLogger.debug('   Is Cloudinary: ${imageUrl?.contains('cloudinary.com') ?? false}');
    AppLogger.debug('   Is HTTP URL: ${imageUrl?.startsWith('http') ?? false}');

    if (imageUrl != null && imageUrl.isNotEmpty) {
      // Test URL accessibility in background
      Future(() async {
        try {
          final response = await http.get(Uri.parse(imageUrl));
          AppLogger.debug('   ✅ URL test for "${p.title}": ${response.statusCode}');
        } catch (error) {
          AppLogger.error('   ❌ URL test failed for "${p.title}": $error');
        }
      });

      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) {
          AppLogger.error('❌ IMAGE LOAD FAILED for "${p.title}": $url');
          AppLogger.error('   Error type: ${error.runtimeType}');
          AppLogger.error('   Error message: $error');
          return _buildPlaceholderImage();
        },
      );
    }

    AppLogger.warning('⚠️ No image URL for property: ${p.title}');
    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home_work_rounded, size: 60, color: AppTheme.primaryRed.withOpacity(0.5)),
          const SizedBox(height: 8),
          Text('No Image', style: TextStyle(color: AppTheme.primaryRed.withOpacity(0.7))),
        ],
      ),
    );
  }

  void _showImageGallery(Property property) {
    final images = property.allImageUrls;
    if (images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No images available for this property'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          imageUrls: images,
          initialIndex: 0,
        ),
      ),
    );
  }

  void _showAdvancedFilterModal() {
    _minPriceController.text = _minPrice.toInt().toString();
    _maxPriceController.text = _maxPrice.toInt().toString();

    if (Responsive.isDesktop(context)) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor(context),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Text(
                          'Set Your Preferences',
                          style: TextStyle(
                            fontSize: responsiveFontSize(context, 20),
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textColor(context),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 22),
                          onPressed: () => Navigator.pop(context),
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _buildFilterContent(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondaryColor(context).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: responsivePadding(context, horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'Set Your Preferences',
                        style: TextStyle(
                          fontSize: responsiveFontSize(context, 20),
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        onPressed: () => Navigator.pop(context),
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    physics: const ClampingScrollPhysics(),
                    padding: responsivePadding(context, horizontal: 20, vertical: 20),
                    child: _buildFilterContent(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBudgetSection(),
        const SizedBox(height: 24),
        const Divider(height: 1),
        const SizedBox(height: 20),
        _buildPropertyTypesSection(),
        const SizedBox(height: 24),
        const Divider(height: 1),
        const SizedBox(height: 20),
        _buildLocationsSection(),
        const SizedBox(height: 32),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildBudgetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Budget Range (GHC/month)',
          style: TextStyle(
            fontSize: responsiveFontSize(context, 16),
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor(context),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildPriceChip('Min', _minPrice),
            const SizedBox(width: 12),
            _buildPriceChip('Max', _maxPrice),
          ],
        ),
        const SizedBox(height: 16),
        RangeSlider(
          values: RangeValues(_minPrice, _maxPrice),
          min: 0,
          max: 3000,
          divisions: 30,
          onChanged: (RangeValues values) {
            setState(() {
              _minPrice = values.start;
              _maxPrice = values.end;
              _minPriceController.text = _minPrice.toInt().toString();
              _maxPriceController.text = _maxPrice.toInt().toString();
            });
          },
          activeColor: AppTheme.primaryRed,
          inactiveColor: AppTheme.textSecondaryColor(context).withOpacity(0.2),
        ),
        Center(
          child: Text(
            'GHC${_minPrice.toInt()} - GHC${_maxPrice.toInt()}',
            style: TextStyle(
              fontSize: responsiveFontSize(context, 14),
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceChip(String label, double value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label Price',
            style: TextStyle(
              fontSize: responsiveFontSize(context, 14),
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.textSecondaryColor(context).withOpacity(0.3),
              ),
            ),
            child: TextField(
              controller: label == 'Min' ? _minPriceController : _maxPriceController,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: AppTheme.textColor(context),
                fontSize: responsiveFontSize(context, 16),
              ),
              decoration: InputDecoration(
                hintText: label == 'Min' ? '300' : '1500',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondaryColor(context),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                prefix: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    'GHC',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ),
              ),
              onChanged: (valueText) {
                if (valueText.isNotEmpty) {
                  final newValue = double.tryParse(valueText);
                  if (newValue != null && newValue >= 0 && newValue <= 3000) {
                    setState(() {
                      if (label == 'Min') {
                        _minPrice = newValue;
                        if (_minPrice > _maxPrice) {
                          _maxPrice = _minPrice;
                          _maxPriceController.text = _maxPrice.toInt().toString();
                        }
                      } else {
                        _maxPrice = newValue;
                        if (_maxPrice < _minPrice) {
                          _minPrice = _maxPrice;
                          _minPriceController.text = _minPrice.toInt().toString();
                        }
                      }
                    });
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyTypesSection() {
    final propertyTypes = [
      "Student Hostel",
      "Single Room",
      "Chamber & Hall",
      "Single Room SC",
      "Two Bedroom SC",
      "Three Bedroom SC",
      "Four Bedroom SC",
      "Furnitures",
      "Lands",
      "Shops",
      "Short Stay"
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Property Types',
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
          children: propertyTypes.map((type) {
            final isSelected = _selectedPropTypes.contains(type);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedPropTypes.remove(type);
                  } else {
                    _selectedPropTypes.add(type);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryRed : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryRed : AppTheme.textSecondaryColor(context).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: responsiveFontSize(context, 13),
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.textColor(context),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLocationsSection() {
    final cities = [
      "Ho",
      "Hohoe",
      "Aflao",
      "Keta",
      "Sokode",
      "Adaklu",
      "Anyako",
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Locations',
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
          children: cities.map((city) {
            final isSelected = _selectedLocs.contains(city);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedLocs.remove(city);
                  } else {
                    _selectedLocs.add(city);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryRed : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryRed : AppTheme.textSecondaryColor(context).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  city,
                  style: TextStyle(
                    fontSize: responsiveFontSize(context, 13),
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.textColor(context),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _selectedPropTypes.clear();
                _selectedLocs.clear();
                _minPrice = 300;
                _maxPrice = 1500;
                _minPriceController.text = _minPrice.toInt().toString();
                _maxPriceController.text = _maxPrice.toInt().toString();
                _activeTypeFilter = 'All';
              });
              _applyFilters();
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(
                color: AppTheme.textSecondaryColor(context).withOpacity(0.3),
              ),
            ),
            child: Text(
              'Reset All',
              style: TextStyle(
                color: AppTheme.textColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _activeTypeFilter = 'All';
              });
              _applyFilters();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Apply Filters',
              style: TextStyle(
                fontSize: responsiveFontSize(context, 14),
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showContactInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('HO Rentals Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildContactItem(
              context,
              Icons.business_rounded,
              'HO Rentals',
              'Property Management',
            ),
            const SizedBox(height: 12),
            _buildContactItem(
              context,
              Icons.phone_rounded,
              '+233 55 792 2593',
              'Official Contact',
            ),
            const SizedBox(height: 12),
            _buildContactItem(
              context,
              Icons.location_on_rounded,
              'HO Polytechnic, Ho',
              'Office Location',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: '+233557922593')),
            child: const Text('Call Office'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(BuildContext context, IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryRed, size: 28),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: responsiveFontSize(context, 12))),
          ],
        ),
      ],
    );
  }
}

class _PropertyCardDetails extends StatelessWidget {
  const _PropertyCardDetails({required this.p});

  final Property p;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : responsivePadding(context, horizontal: 12).horizontal / 2,
        vertical: isMobile ? 10 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.title,
            style: TextStyle(
              fontSize: responsiveFontSize(context, isMobile ? 14 : 16),
              fontWeight: FontWeight.w700,
              color: AppTheme.textColor(context),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          SizedBox(height: isMobile ? 4 : 8),
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 13,
                color: AppTheme.textSecondaryColor(context),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  p.location,
                  style: TextStyle(
                    fontSize: responsiveFontSize(context, isMobile ? 12 : 13),
                    color: AppTheme.textSecondaryColor(context),
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 4 : 8),
          Text(
            'GHC ${p.price.toInt()} / month',
            style: TextStyle(
              fontSize: responsiveFontSize(context, isMobile ? 15 : 18),
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryRed,
            ),
          ),
          SizedBox(height: isMobile ? 6 : 10),
          // Amenity chips
          if (p.amenities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: p.amenities.take(isMobile ? 3 : 5).map((key) {
                  final amenity = kAmenities.firstWhere(
                    (a) => a['key'] == key,
                    orElse: () => {'key': key, 'label': key, 'icon': 0xe1a5},
                  );
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryRed.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          IconData(amenity['icon'] as int, fontFamily: 'MaterialIcons'),
                          size: 10,
                          color: AppTheme.primaryRed,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          amenity['label'] as String,
                          style: TextStyle(
                            fontSize: responsiveFontSize(context, 9.5),
                            color: AppTheme.primaryRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          SizedBox(height: isMobile ? 2 : 4),
          Row(
            children: [
              _buildStatusBadge(context),
              const Spacer(),
              SizedBox(
                height: isMobile ? 32 : 38,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PropertyDetailsScreen(property: p)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRed,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 20,
                      vertical: 0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View',
                    style: TextStyle(
                      fontSize: responsiveFontSize(context, isMobile ? 12 : 12),
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Container _buildStatusBadge(BuildContext context) {
    final status = p.status?.toLowerCase() ?? 'available';
    final color = status == 'available' ? Colors.green : (status == 'taken' ? Colors.red : Colors.orange);
    final text = status.toUpperCase();

    return Container(
      padding: responsivePadding(context, horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: responsiveFontSize(context, 11),
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// Full-screen image viewer for property gallery
class FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            itemBuilder: (context, index) {
              return InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrls[index],
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image_rounded, color: Colors.white70, size: 60),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.imageUrls.length, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index
                          ? AppTheme.primaryRed
                          : Colors.white.withOpacity(0.5),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}