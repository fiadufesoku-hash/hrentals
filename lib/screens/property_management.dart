import 'package:flutter/material.dart';
import '../models/property_model.dart';
import '../themes.dart';
import 'property_upload_screen.dart';
import '../services/graphql_service.dart';
import '../utils/responsive.dart';


// Helper functions delegated to AppTheme
double responsiveFontSize(BuildContext context, double baseFontSize) => AppTheme.responsiveFontSize(context, baseFontSize);
EdgeInsets responsivePadding(BuildContext context, {double horizontal = 24.0, double vertical = 0.0}) => AppTheme.responsivePadding(context, horizontal: horizontal, vertical: vertical);

class GalleryScreen extends StatelessWidget {
  final Property property;

  const GalleryScreen({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Images (${property.images.length})"),
        backgroundColor: AppTheme.primaryRed,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: property.images.length,
        itemBuilder: (_, i) {
          return GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) {
                return FullScreenImageViewer(imageUrls: property.images, initialIndex: i);
              }));
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Hero(
                tag: '${property.id!}_$i',
                child: Image.network(property.images[i], fit: BoxFit.cover),
              ),
            ),
          );
        },
      ),
    );
  }
}

class FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullScreenImageViewer({super.key, required this.imageUrls, this.initialIndex = 0});

  @override
  _FullScreenImageViewerState createState() => _FullScreenImageViewerState();
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
                child: Image.network(
                  widget.imageUrls[index],
                  fit: BoxFit.contain,
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
                    color: _currentIndex == index ? AppTheme.primaryRed : Colors.white.withOpacity(0.5),
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

class PropertyManagement extends StatefulWidget {
  final String? categoryFilter;
  final List<Property> initialProperties;

  const PropertyManagement({
    super.key,
    this.categoryFilter,
    this.initialProperties = const [],
  });

  @override
  _PropertyManagementState createState() => _PropertyManagementState();
}

class _PropertyManagementState extends State<PropertyManagement> {
  String _selectedFilter = 'All';
  String? _selectedSelfContained;
  bool _showSelfContainedDropdown = false;

  final Map<String, String> selfContainedTypes = {
    'Single Room SC': 'Single Room',
    'Chamber & Hall SC': 'Chamber & Hall',
    '2 Bedroom SC': '2 Bedroom SC',
    '3 Bedroom SC': '3 Bedroom SC',
    '4 Bedroom SC': '4 Bedroom SC',
  };

  List<Property> _properties = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _properties = widget.initialProperties;
    // Set initial filter based on categoryFilter
    if (widget.categoryFilter != null && widget.categoryFilter != 'dashboard') {
      _selectedFilter = widget.categoryFilter!;

      // Check if it's a self-contained type
      if (widget.categoryFilter == 'Self Contained' ||
          selfContainedTypes.containsValue(widget.categoryFilter)) {
        _selectedFilter = 'self-contained';
        // Find the matching key in selfContainedTypes
        for (var entry in selfContainedTypes.entries) {
          if (entry.value == widget.categoryFilter) {
            _selectedSelfContained = entry.key;
            break;
          }
        }
      }
    }
  }

  Future<void> _fetchProperties() async {
    print('🔄 FORCE refreshing properties list from SERVER...');

    setState(() => _isLoading = true);

    try {
      // Clear cache before fetching
      await GraphQLService.forceRefreshProperties();

      // Small delay to ensure cache is cleared
      await Future.delayed(const Duration(milliseconds: 100));

      // Fetch fresh data with NO CACHE
      final propertiesData = await GraphQLService.getProperties();
      final properties = propertiesData.map((data) => Property.fromJson(data)).toList();

      setState(() {
        _properties = properties;
        _isLoading = false;
      });

      print('✅ Refreshed: ${properties.length} properties from SERVER');
    } catch (e) {
      print('❌ Refresh failed: $e');
      setState(() => _isLoading = false);

      // Show error
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

  List<Property> _filterProperties() {
    List<Property> filtered = _properties;

    // Apply category filter from AdminDashboard if provided
    if (widget.categoryFilter != null && widget.categoryFilter != 'dashboard') {
      filtered = filtered.where((property) {
        if (widget.categoryFilter == 'Self Contained') {
          return property.type.contains('SC') == true ||
              property.type == 'Self Contained';
        }
        return property.type == widget.categoryFilter;
      }).toList();
    }

    // Then apply the local filter selection
    if (_selectedFilter == 'All') return filtered;

    if (_selectedFilter == 'self-contained') {
      if (_selectedSelfContained == null) return filtered;
      final typeValue = selfContainedTypes[_selectedSelfContained!];
      return filtered.where((property) => property.type == typeValue).toList();
    }

    return filtered.where((property) => property.type == _selectedFilter).toList();
  }

  void _editProperty(Property property) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PropertyUploadScreen(
          propertyToEdit: property,
        ),
      ),
    );

    // Only refresh if property was actually updated
    if (updated == true && mounted) {
      await _fetchProperties();
    }
  }

  Future<void> _deleteProperty(Property property) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Property'),
        content: Text('Are you sure you want to delete "${property.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleting "${property.title}"...'),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      // Call delete and wait for result
      final success = await GraphQLService.deleteProperty(
        property.id!,
      );

      if (!success) {
        throw Exception('Delete failed on server');
      }

      // Remove from local list immediately
      setState(() {
        _properties.removeWhere((p) => p.id == property.id);
      });

      // Force refresh from server to confirm
      await GraphQLService.forceRefreshProperties();
      await _fetchProperties();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${property.title}" deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Delete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete property: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        // Refresh to get correct state
        await _fetchProperties();
      }
    }
  }

  Future<void> _toggleFeatured(Property property) async {
    try {
      final success = await GraphQLService.toggleFeatured(
        property.id!,
        onSuccess: (updatedId, newFeatured) {
          setState(() {
            final index = _properties.indexWhere((p) => p.id == updatedId);
            if (index != -1) {
              _properties[index] = property.copyWith(isFeatured: newFeatured);
            }
          });
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (property.isFeatured
                      ? '"${property.title}" removed from featured'
                      : '"${property.title}" is now featured')
                  : 'Failed to update featured status',
            ),
            backgroundColor: success
                ? (property.isFeatured ? Colors.orange : Colors.green)
                : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating featured: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleAvailability(Property property) async {
    final newStatus = property.status == 'available' ? 'taken' : 'available';

    try {
      final success = await GraphQLService.updatePropertyStatus(property.id!, newStatus);

      if (success) {
        setState(() {
          final index = _properties.indexWhere((p) => p.id == property.id);
          if (index != -1) {
            _properties[index] = property.copyWith(status: newStatus);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(

            content: Text('Property marked as $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================== WIDGETS ==================

  Widget _typeChip(String label, IconData icon, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: responsivePadding(context, horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryRed : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : AppTheme.primaryRed),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: responsiveFontSize(context, 14),
                color: selected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selfContainedDropdown() {
    if (!_showSelfContainedDropdown) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.primaryRed.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: selfContainedTypes.entries.map((entry) {
          final selected = entry.key == _selectedSelfContained;
          return ListTile(
            dense: true,
            title: Text(entry.key, style: TextStyle(fontSize: responsiveFontSize(context, 14))),
            tileColor: selected ? AppTheme.primaryRed.withOpacity(0.1) : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onTap: () {
              setState(() {
                _selectedSelfContained = entry.key;
                _selectedFilter = 'self-contained';
                _showSelfContainedDropdown = false;
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPropertyCard(BuildContext context, Property property) {
    final hasImage = property.hasImages;
    final displayImage = property.displayImage;
    final status = property.status ?? 'available';

    return GestureDetector(
      onTap: () => _showPropertyDetails(property),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: property.isFeatured
              ? Border.all(color: AppTheme.primaryRed.withOpacity(0.4), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: property.isFeatured
                  ? AppTheme.primaryRed.withOpacity(0.15)
                  : Colors.black.withOpacity(0.05),
              blurRadius: property.isFeatured ? 16 : 10,
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
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                color: hasImage ? Colors.transparent : AppTheme.primaryRed.withOpacity(0.1),
              ),
              child: hasImage && displayImage != null
                  ? ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: Stack(
                  children: [
                    Hero(
                      tag: property.id!,
                      child: Image.network(
                        displayImage,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          print('❌ Image load error: $error');
                          return _buildPlaceholderImage();
                        },
                      ),
                    ),
                    if (property.isFeatured)
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
              )
                  : _buildPlaceholderImage(),
            ),

            // Property Details
            Padding(
              padding: responsivePadding(context, horizontal: 16, vertical: 16),
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
                            fontSize: responsiveFontSize(context, 18),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Image count badge
                      if (property.images.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryRed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '+${property.images.length - 1}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: responsiveFontSize(context, 12),
                              fontWeight: FontWeight.bold,
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
                        color: Colors.grey[600],
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.location,
                          style: TextStyle(
                            fontSize: responsiveFontSize(context, 14),
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Status and Price Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'GHC ${property.price.toStringAsFixed(0)}/month',
                        style: TextStyle(
                          fontSize: responsiveFontSize(context, 18),
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryRed,
                        ),
                      ),
                      // Status Chip
                      Chip(
                        label: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: responsiveFontSize(context, 12),
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: status == 'available' ? Colors.green : Colors.red,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit'),
                          onPressed: () => _editProperty(property),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            side: const BorderSide(color: Colors.blue),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(
                            property.isFeatured
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 16,
                            color: property.isFeatured
                                ? AppTheme.primaryRed
                                : Colors.amber[700],
                          ),
                          label: Text(
                            property.isFeatured ? 'Unfeature' : 'Feature',
                            style: TextStyle(
                              color: property.isFeatured
                                  ? AppTheme.primaryRed
                                  : Colors.amber[700],
                            ),
                          ),
                          onPressed: () => _toggleFeatured(property),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            side: BorderSide(
                              color: property.isFeatured
                                  ? AppTheme.primaryRed
                                  : Colors.amber[700]!,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.delete, size: 16),
                          label: const Text('Delete'),
                          onPressed: () => _deleteProperty(property),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            side: const BorderSide(color: Colors.red),
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

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryRed.withOpacity(0.1),
            AppTheme.gold.withOpacity(0.1)
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
              size: 60,
            ),
            const SizedBox(height: 8),
            Text(
              'No Image',
              style: TextStyle(
                color: AppTheme.primaryRed.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPropertyDetails(Property property) {
    print("Tapped on property: ${property.title}");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryScreen(property: property),
      ),
    );
  }

  Widget _buildPropertyList(List<Property> properties) {
    if (properties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_work, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No properties found',
              style: TextStyle(color: Colors.grey, fontSize: responsiveFontSize(context, 16)),
            ),
            if (widget.categoryFilter != null && widget.categoryFilter != 'dashboard')
              Text(
                'in ${widget.categoryFilter} category',
                style: TextStyle(color: Colors.grey, fontSize: responsiveFontSize(context, 14)),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchProperties,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (Responsive.isDesktop(context) || Responsive.isTablet(context)) {
      return GridView.builder(
        padding: responsivePadding(context, horizontal: 16, vertical: 16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: Responsive.isDesktop(context) ? 3 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75, // Adjusted for card content
        ),
        itemCount: properties.length,
        itemBuilder: (_, i) => _buildPropertyCard(context, properties[i]),
      );
    }

    return ListView.builder(
      padding: responsivePadding(context, horizontal: 16, vertical: 16),
      itemCount: properties.length,
      itemBuilder: (_, i) => _buildPropertyCard(context, properties[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredProperties = _filterProperties();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: RefreshIndicator(
            onRefresh: _fetchProperties,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            // Filter Section - only show when not filtered by AdminDashboard
            if (widget.categoryFilter == null || widget.categoryFilter == 'dashboard')
              Container(
                padding: responsivePadding(context, horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 50,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _typeChip(
                            'All',
                            Icons.all_inclusive_rounded,
                            _selectedFilter == 'All',
                                () {
                              setState(() {
                                _selectedFilter = 'All';
                                _selectedSelfContained = null;
                                _showSelfContainedDropdown = false;
                              });
                            },
                          ),
                          _typeChip(
                            'Student Hostel',
                            Icons.school_rounded,
                            _selectedFilter == 'Student Hostel',
                                () {
                              setState(() {
                                _selectedFilter = 'Student Hostel';
                                _selectedSelfContained = null;
                                _showSelfContainedDropdown = false;
                              });
                            },
                          ),
                          _typeChip(
                            'Single Room',
                            Icons.single_bed_rounded,
                            _selectedFilter == 'Single Room',
                                () {
                              setState(() {
                                _selectedFilter = 'Single Room';
                                _selectedSelfContained = null;
                                _showSelfContainedDropdown = false;
                              });
                            },
                          ),
                          _typeChip(
                            'Chamber & Hall',
                            Icons.apartment_rounded,
                            _selectedFilter == 'Chamber & Hall',
                                () {
                              setState(() {
                                _selectedFilter = 'Chamber & Hall';
                                _selectedSelfContained = null;
                                _showSelfContainedDropdown = false;
                              });
                            },
                          ),
                          _typeChip(
                            'Self-Contained',
                            Icons.arrow_drop_down_rounded,
                            _selectedFilter == 'self-contained',
                                () => setState(() => _showSelfContainedDropdown = !_showSelfContainedDropdown),
                          ),
                        ],
                      ),
                    ),
                    _selfContainedDropdown(),
                  ],
                ),
              ),
            Expanded(child: _buildPropertyList(filteredProperties)),
          ],
        ),
      ),
    ),
    );
  }
}
