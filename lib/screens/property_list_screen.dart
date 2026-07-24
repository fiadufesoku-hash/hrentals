import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../models/property_model.dart';
import '../services/graphql_service.dart';
import '../themes.dart';
import 'property_upload_screen.dart';
import '../utils/responsive.dart';
import 'dart:developer';

class PropertyListScreen extends StatefulWidget {
  const PropertyListScreen({super.key});

  @override
  State<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Map<String, dynamic>? _currentUser;

  final TextEditingController _searchController = TextEditingController();
  late TextEditingController _minPriceController;
  late TextEditingController _maxPriceController;

  String _selectedFilter = 'All';
  String _selectedLocation = 'All Locations';

  double _minPrice = 100;
  double _maxPrice = 1000;
  final Set<String> _selectedPropertyTypes = {};
  final Set<String> _selectedLocations = {};

  final List<String> _filters = ['All', 'Student Hostel', 'Single Room', 'Self-Contained', 'Chamber & Hall'];
  final List<String> _locations = [
    'All Locations', 'HO Poly', 'Mirage', 'Barracks', 'Ahove', 'UHAS', 'NTC', 'New Town', 'Deme'
  ];

  final List<String> _propertyTypes = [
    'Student Hostel', 'Single Room', 'Self-Contained', 'Chamber & Hall', 'Furnished', 'Land', 'Shop'
  ];

  final List<String> _cities = ['Accra', 'Ho', 'Kpando', 'Hohoe', 'Sogakope'];

  List<Property> _properties = [];
  bool _isLoading = true;

  List<Property> get _filteredProperties {
    return _properties.where((property) {
      final matchesFilter = _selectedFilter == 'All' || property.type == _selectedFilter;
      final matchesLocation = _selectedLocation == 'All Locations' || property.location == _selectedLocation;
      final matchesPrice = property.price >= _minPrice && property.price <= _maxPrice;

      final matchesPropertyTypes = _selectedPropertyTypes.isEmpty ||
          _selectedPropertyTypes.contains(property.type);
      final matchesLocations = _selectedLocations.isEmpty ||
          _selectedLocations.contains(property.location);

      return matchesFilter && matchesLocation && matchesPrice &&
          matchesPropertyTypes && matchesLocations;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchProperties();
    _minPriceController = TextEditingController(text: _minPrice.toInt().toString());
    _maxPriceController = TextEditingController(text: _maxPrice.toInt().toString());
  }

  Future<void> _loadUserData() async {
    try {
      final data = await _storage.read(key: 'user_data');
      if (data != null && mounted) {
        setState(() {
          _currentUser = json.decode(data);
        });
        log('👤 [Property List] Loaded user data: ${_currentUser?['name']}');
      }
    } catch (e) {
      log('❌ Error loading user data: $e');
    }
  }

  String _getUserName() {
    if (_currentUser == null) return 'Guest';
    return _currentUser!['name'] ?? _currentUser!['email']?.split('@').first ?? 'Guest';
  }

  String _getUserInitials() {
    if (_currentUser == null) return 'G';
    final name = _currentUser!['name'] ?? _currentUser!['email'] ?? 'Guest';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'G';
  }

  Future<void> _fetchProperties() async {
    if (_properties.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      print('🔄 Fetching properties from GraphQL...');
      final propertiesData = await GraphQLService.getProperties();

      final List<Property> properties = [];
      for (final propertyData in propertiesData) {
        try {
          properties.add(Property.fromJson(propertyData));
        } catch (e) {
          print('❌ Error parsing property: $e');
          print('   Problematic data: $propertyData');
        }
      }

      setState(() {
        _properties = properties;
        _isLoading = false;
      });

      print('✅ Successfully loaded ${properties.length} properties');

    } catch (e) {
      log('❌ Failed to fetch properties: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch properties: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _resetAllFilters() {
    setState(() {
      _selectedFilter = 'All';
      _selectedLocation = 'All Locations';
      _minPrice = 100;
      _maxPrice = 1000;
      _selectedPropertyTypes.clear();
      _selectedLocations.clear();
      _minPriceController.text = _minPrice.toInt().toString();
      _maxPriceController.text = _maxPrice.toInt().toString();
    });
  }

  void _showAdvancedFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: _buildFilterContent(),
      ),
    );
  }

  Widget _buildFilterContent() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondaryColor(context).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Set Your Preferences',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textColor(context),
                ),
              ),
              const SizedBox(height: 30),

              // Budget Range
              Text(
                'Budget Range (GHC/month)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor(context),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text(
                        'Min',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                      Text(
                        'GHC ${_minPrice.toInt()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryRed,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        'Max',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                      Text(
                        'GHC ${_maxPrice.toInt()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              RangeSlider(
                values: RangeValues(_minPrice, _maxPrice),
                min: 0,
                max: 3000,
                divisions: 30,
                onChanged: (RangeValues values) {
                  setModalState(() {
                    _minPrice = values.start;
                    _maxPrice = values.end;
                  });
                },
                activeColor: AppTheme.primaryRed,
                inactiveColor: AppTheme.textSecondaryColor(context).withOpacity(0.3),
              ),

              Center(
                child: Text(
                  'GHC ${_minPrice.toInt()} - GHC ${_maxPrice.toInt()}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
              ),

              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 20),

              // Property Types
              Text(
                'Preferred Property Types',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor(context),
                ),
              ),
              const SizedBox(height: 16),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _propertyTypes.map((type) {
                  final isSelected = _selectedPropertyTypes.contains(type);
                  return FilterChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      setModalState(() {
                        if (selected) {
                          _selectedPropertyTypes.add(type);
                        } else {
                          _selectedPropertyTypes.remove(type);
                        }
                      });
                    },
                    backgroundColor: AppTheme.cardColor(context),
                    selectedColor: AppTheme.primaryRed.withOpacity(0.2),
                    checkmarkColor: AppTheme.primaryRed,
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.primaryRed
                            : AppTheme.textSecondaryColor(context).withOpacity(0.3),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 30),

              // Locations
              Text(
                'Preferred Locations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor(context),
                ),
              ),
              const SizedBox(height: 16),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _cities.map((city) {
                  final isSelected = _selectedLocations.contains(city);
                  return FilterChip(
                    label: Text(city),
                    selected: isSelected,
                    onSelected: (selected) {
                      setModalState(() {
                        if (selected) {
                          _selectedLocations.add(city);
                        } else {
                          _selectedLocations.remove(city);
                        }
                      });
                    },
                    backgroundColor: AppTheme.cardColor(context),
                    selectedColor: AppTheme.primaryRed.withOpacity(0.2),
                    checkmarkColor: AppTheme.primaryRed,
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.primaryRed
                            : AppTheme.textSecondaryColor(context).withOpacity(0.3),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const Spacer(),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
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
                        'Cancel',
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
                        setState(() {});
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(
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
      },
    );
  }

  void _showPropertyDetails(Property property) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Property Image
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  image: property.displayImage != null
                      ? DecorationImage(
                    image: NetworkImage(property.displayImage!),
                    fit: BoxFit.cover,
                  )
                      : null,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryRed.withOpacity(0.2),
                      AppTheme.gold.withOpacity(0.2)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: property.displayImage == null ? Center(
                  child: Icon(
                    Icons.home_work_rounded,
                    color: AppTheme.primaryRed.withOpacity(0.6),
                    size: 80,
                  ),
                ) : null,
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Property Title and Rating
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            property.title,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textColor(context),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Location
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppTheme.primaryRed,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          property.location,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondaryColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Property Type
                    Row(
                      children: [
                        Icon(
                          Icons.category_rounded,
                          color: AppTheme.textSecondaryColor(context),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          property.type,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Price in Ghana Cedis
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryRed.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Monthly Rent',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'GHC ${property.price}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryRed,
                            ),
                          ),
                          Text(
                            'Per Month',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryColor(context)
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
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
                              'Close',
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
                              _showContactDialog(property);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryRed,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Contact Landlord',
                              style: TextStyle(
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactDialog(Property property) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Contact Landlord',
          style: TextStyle(
            color: AppTheme.textColor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Would you like to contact the landlord for "${property.title}" in ${property.location}?',
          style: TextStyle(
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Contacting landlord for ${property.title}...'),
                  backgroundColor: AppTheme.primaryRed,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
            ),
            child: const Text('Call Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('selectedType')) {
      _selectedFilter = args['selectedType'];
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: RefreshIndicator(
        onRefresh: _fetchProperties,
        color: AppTheme.primaryRed,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: AppTheme.cardColor(context),
              elevation: 0,
              pinned: true,
              floating: true,
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getUserInitials(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good morning 👋',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                      Text(
                        _getUserName(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor(context),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        color: AppTheme.textColor(context),
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search properties in Ghana...',
                        hintStyle: TextStyle(
                          color: AppTheme.textSecondaryColor(context),
                        ),
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(12),
                          child: const Icon(
                            Icons.search_rounded,
                            color: AppTheme.primaryRed,
                            size: 22,
                          ),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // FILTER CHIP
                  Row(
                    children: [
                      FilterChip(
                        label: Text(
                          'Filters',
                          style: TextStyle(
                            color: (_selectedPropertyTypes.isNotEmpty ||
                                _selectedLocations.isNotEmpty ||
                                _minPrice != 300 ||
                                _maxPrice != 1500)
                                ? Colors.white
                                : AppTheme.primaryRed,
                          ),
                        ),
                        selected: _selectedPropertyTypes.isNotEmpty ||
                            _selectedLocations.isNotEmpty ||
                            _minPrice != 300 ||
                            _maxPrice != 1500,
                        onSelected: (selected) {
                          _showAdvancedFilterModal();
                        },
                        backgroundColor: AppTheme.cardColor(context),
                        selectedColor: AppTheme.primaryRed,
                        checkmarkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: AppTheme.primaryRed),
                        ),
                      ),
                      if (_selectedPropertyTypes.isNotEmpty || _selectedLocations.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Chip(
                            label: Text('${_selectedPropertyTypes.length + _selectedLocations.length}'),
                            backgroundColor: AppTheme.primaryRed,
                            labelStyle: const TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Filter Chips
                  Text(
                    'Property Type',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _filters.map((filter) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              filter,
                              style: TextStyle(
                                fontWeight: _selectedFilter == filter
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: _selectedFilter == filter
                                    ? Colors.white
                                    : AppTheme.textColor(context),
                              ),
                            ),
                            selected: _selectedFilter == filter,
                            onSelected: (selected) {
                              setState(() {
                                _selectedFilter = filter;
                              });
                            },
                            backgroundColor: AppTheme.cardColor(context),
                            selectedColor: AppTheme.primaryRed,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            side: BorderSide(
                              color: _selectedFilter == filter
                                  ? AppTheme.primaryRed
                                  : AppTheme.textSecondaryColor(context).withOpacity(0.3),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Location Chips
                  Text(
                    'Popular Locations in Ghana',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _locations.map((location) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              location,
                              style: TextStyle(
                                fontWeight: _selectedLocation == location
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: _selectedLocation == location
                                    ? Colors.white
                                    : AppTheme.textColor(context),
                              ),
                            ),
                            selected: _selectedLocation == location,
                            onSelected: (selected) {
                              setState(() {
                                _selectedLocation = location;
                              });
                            },
                            backgroundColor: AppTheme.cardColor(context),
                            selectedColor: AppTheme.primaryRed,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            side: BorderSide(
                              color: _selectedLocation == location
                                  ? AppTheme.primaryRed
                                  : AppTheme.textSecondaryColor(context).withOpacity(0.3),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available Properties (${_filteredProperties.length})',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                      if (_filteredProperties.isNotEmpty)
                        const Text(
                          'See all',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.primaryRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_filteredProperties.isEmpty)
                    _buildEmptyState(context)
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredProperties.length,
                      itemBuilder: (context, index) => _buildPropertyCard(context, _filteredProperties[index]),
                    )
                ],
              ),
            ),
          ),
        ],
      ),
    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PropertyUploadScreen()),
          );

          if (result == true) {
            _fetchProperties();
          }
        },
        backgroundColor: AppTheme.primaryRed,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 60,
              color: AppTheme.textSecondaryColor(context).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No properties found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or search terms',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _resetAllFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
              ),
              child: const Text('Reset All Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyCard(BuildContext context, Property property) {
    final displayImage = property.displayImage;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/property/details',
          arguments: property,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Image
            Container(
              height: 180,
              decoration: BoxDecoration(
                image: displayImage != null && displayImage.isNotEmpty
                    ? DecorationImage(
                  image: NetworkImage(displayImage),
                  fit: BoxFit.cover,
                )
                    : null,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryRed.withOpacity(0.1),
                    AppTheme.gold.withOpacity(0.1)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: (displayImage == null || displayImage.isEmpty)
                  ? Center(
                child: Icon(
                  Icons.home_work_rounded,
                  color: AppTheme.primaryRed.withOpacity(0.5),
                  size: 60,
                ),
              )
                  : null,
            ),

            // Property Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          property.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: AppTheme.textSecondaryColor(context),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        property.location,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'GHC ${property.price}/month',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryRed,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}