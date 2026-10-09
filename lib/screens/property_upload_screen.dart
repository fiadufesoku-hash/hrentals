import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart'; // ✅ ADD THIS
import '../models/property_model.dart';
import '../services/graphql_service.dart';
import '../themes.dart';
import 'package:file_picker/file_picker.dart';

class PropertyUploadScreen extends StatefulWidget {
  final Property? propertyToEdit;
  final String? preselectedType;

  const PropertyUploadScreen({
    super.key,
    this.propertyToEdit,
    this.preselectedType,
  });

  @override
  State<PropertyUploadScreen> createState() => _PropertyUploadScreenState();
}

class _PropertyUploadScreenState extends State<PropertyUploadScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // Controllers for form fields
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  // State variables
  String _selectedType = 'Student Hostel';
  String _selectedStatus = 'available';
  final List<PlatformFile> _selectedWebFiles = []; // For web uploads (before upload)
  final List<File> _selectedImageFiles = [];        // For mobile uploads (before upload)
  List<String> _uploadedImageUrls = [];       // Already uploaded images
  bool _isUploading = false;
  final bool _isLoading = false;

  // Student & Ghanaian rental specifications
  String _selectedAdvance = '1 Year';
  String _selectedPricePeriod = 'month';
  String _selectedMeterType = 'ECG Prepaid';
  String _selectedWaterSupply = 'Polytank';
  final TextEditingController _roomsController = TextEditingController();

  final List<String> _advanceOptions = [
    '1 Year',
    '6 Months',
    '2 Years',
    'Monthly / No Adv.',
  ];

  final List<String> _pricePeriodOptions = [
    'month',
    'semester',
    'year',
  ];

  final List<String> _meterOptions = [
    'ECG Prepaid',
    'ECG Separate Meter',
    'ECG Shared Meter',
  ];

  final List<String> _waterOptions = [
    'Polytank',
    'Ghana Water',
    'Borehole',
    'Well Water',
  ];

  // Amenities
  final Set<String> _selectedAmenities = {};

  // Property types
  final List<String> _propertyTypes = [
    'Student Hostel',
    'Single Room',
    'Chamber & Hall',
    'Self Contained',
    'Lands',
    'Furnitures',
    'Shops',
    'Short Stay',
  ];

  @override
  void initState() {
    super.initState();

    if (widget.preselectedType != null) {
      _selectedType = widget.preselectedType!;
    }

    if (widget.propertyToEdit != null) {
      _populateEditFields();
    }
  }

  void _populateEditFields() {
    final property = widget.propertyToEdit!;

    _titleController.text = property.title;
    _descriptionController.text = property.plainDescription; // plain text only
    _locationController.text = property.location;
    _priceController.text = property.price.toString();
    _contactController.text = property.contact ?? '';
    _selectedType = property.type;
    _selectedStatus = property.status ?? 'available';

    // Parse specs if available
    if (property.advancePeriod != null) {
      if (property.advancePeriod!.contains('6 Month')) {
        _selectedAdvance = '6 Months';
      } else if (property.advancePeriod!.contains('2 Year')) {
        _selectedAdvance = '2 Years';
      } else if (property.advancePeriod!.toLowerCase().contains('month')) {
        _selectedAdvance = 'Monthly / No Adv.';
      } else {
        _selectedAdvance = '1 Year';
      }
    }
    _selectedPricePeriod = property.pricePeriod;
    if (property.meterType != null) {
      _selectedMeterType = property.meterType!.contains('Separate')
          ? 'ECG Separate Meter'
          : (property.meterType!.contains('Shared') ? 'ECG Shared Meter' : 'ECG Prepaid');
    }
    if (property.waterSupply != null) {
      _selectedWaterSupply = property.waterSupply!;
    }
    if (property.roomsAvailable != null) {
      _roomsController.text = property.roomsAvailable!;
    }

    // Load amenities from encoded description
    _selectedAmenities.addAll(property.amenities);

    // Set images from existing images array
    if (property.images.isNotEmpty) {
      _uploadedImageUrls = List<String>.from(property.images);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _contactController.dispose();
    _roomsController.dispose();
    super.dispose();
  }

  void _moveImage(int fromIndex, int toIndex) {
    if (fromIndex < 0 || fromIndex >= _uploadedImageUrls.length ||
        toIndex < 0 || toIndex >= _uploadedImageUrls.length) {
      return;
    }
    setState(() {
      final item = _uploadedImageUrls.removeAt(fromIndex);
      _uploadedImageUrls.insert(toIndex, item);
    });
  }

  void _setAsCover(int index) {
    if (index <= 0 || index >= _uploadedImageUrls.length) {
      return;
    }
    setState(() {
      final item = _uploadedImageUrls.removeAt(index);
      _uploadedImageUrls.insert(0, item);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⭐ Image set as primary cover photo'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // UPDATED: Save property with new image upload system
  Future<void> _saveProperty() async {
    if (!_formKey.currentState!.validate()) return;

    // On web, images are uploaded immediately, so we just check _uploadedImageUrls.
    // On mobile, they might still be in _selectedImageFiles before saving.
    final hasImages = _uploadedImageUrls.isNotEmpty || _selectedImageFiles.isNotEmpty || _selectedWebFiles.isNotEmpty;
    if (!hasImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one image')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Upload any remaining selected files
      await _uploadSelectedImages();

      // Construct student specs features string compatible with web app:
      final featureList = <String>[];
      if (_roomsController.text.trim().isNotEmpty) {
        featureList.add('Rooms Available: ${_roomsController.text.trim()}');
      }
      featureList.add('Advance Required: $_selectedAdvance');
      featureList.add('PricePeriod: per $_selectedPricePeriod');
      featureList.add('Electricity: $_selectedMeterType');
      featureList.add('Water: $_selectedWaterSupply');

      final baseDesc = _descriptionController.text.trim();
      final fullDescWithFeatures = featureList.isNotEmpty
          ? '$baseDesc\n\nFeatures: ${featureList.join(' | ')}'
          : baseDesc;

      // Encode amenities into description
      final encodedDescription = Property.encodeDescription(
        fullDescWithFeatures,
        _selectedAmenities.toList(),
      );

      if (widget.propertyToEdit == null) {
        // CREATE NEW PROPERTY
        await GraphQLService.createProperty(
          title: _titleController.text.trim(),
          location: _locationController.text.trim(),
          price: double.parse(_priceController.text.trim()),
          type: _selectedType,
          description: encodedDescription,
          contact: _contactController.text.trim(),
          status: _selectedStatus,
          imageUrls: _uploadedImageUrls,
        );
      } else {
        // UPDATE EXISTING PROPERTY
        await GraphQLService.updateProperty(
          id: widget.propertyToEdit!.id!,
          title: _titleController.text.trim(),
          location: _locationController.text.trim(),
          price: double.parse(_priceController.text.trim()),
          type: _selectedType,
          description: encodedDescription,
          contact: _contactController.text.trim(),
          status: _selectedStatus,
          existingImageUrls: _uploadedImageUrls,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Property saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Save error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save property: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // UPDATED: Pick images method
  Future<void> _pickImages() async {
    final currentCount = _selectedImageFiles.length + _uploadedImageUrls.length + _selectedWebFiles.length;

    // Prevent picking more than 10 images
    if (currentCount >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 10 images allowed')),
      );
      return;
    }

    try {
      if (kIsWeb) {
        // ✅ PROPER WEB IMPLEMENTATION
        print('🌐 Web: Opening file picker...');
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.image,
        );

        if (result != null && result.files.isNotEmpty) {
          print('✅ Web: Selected ${result.files.length} files');

          for (var platformFile in result.files) {
            // Combine counts for total limit check
            if (currentCount + _selectedWebFiles.length < 10) {
              if (platformFile.bytes != null) {
                // Store the PlatformFile directly for web
                _selectedWebFiles.add(platformFile);
                print('   📸 ${platformFile.name} (${platformFile.size} bytes)');
              }
            }
          }

          // Upload immediately
          await _uploadSelectedImages();
        } else {
          print('ℹ️ User cancelled file picker');
        }
      } else {
        // Mobile implementation
        final pickedImages = await _picker.pickMultiImage(
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 85,
        );

        if (pickedImages.isNotEmpty) {
          // Convert XFile to File and store
          for (var image in pickedImages) {
            if (currentCount + _selectedImageFiles.length < 10) {
              _selectedImageFiles.add(File(image.path));
            }
          }

          // Upload images immediately
          await _uploadSelectedImages();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick images: $e')),
      );
    }
  }

  // UPDATED: Upload selected images directly using REST endpoint
  Future<void> _uploadSelectedImages() async {
    if (_selectedImageFiles.isEmpty && _selectedWebFiles.isEmpty) return;

    setState(() => _isUploading = true);

    try {
      print('🖼️ Uploading images...');

      final uri = Uri.parse('https://hrentals-backend-production.up.railway.app/api/upload-multiple');
      final request = http.MultipartRequest('POST', uri);

      // --- MOBILE FILES ---
      for (var file in _selectedImageFiles) {
        final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
        request.files.add(await http.MultipartFile.fromPath(
          'images',
          file.path,
          contentType: MediaType.parse(mimeType),
        ));
      }

      // --- WEB FILES (Uint8List) ---
      for (var webFile in _selectedWebFiles) {
        final mimeType = lookupMimeType(webFile.name) ?? 'application/octet-stream';
        request.files.add(http.MultipartFile.fromBytes(
          'images',
          webFile.bytes!,
          filename: webFile.name,
          contentType: MediaType.parse(mimeType),
        ));
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = jsonDecode(body);
        final uploadedUrls = List<String>.from(data['imageUrls']);

        setState(() {
          _uploadedImageUrls.addAll(uploadedUrls);
          _selectedImageFiles.clear();
          _selectedWebFiles.clear();
        });

        print('✅ Uploaded ${uploadedUrls.length} images successfully!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${uploadedUrls.length} images uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Upload failed with status code: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Image upload failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }
  // REMOVED: Old upload methods (_uploadImageGraphQLWeb and _uploadImageGraphQLMobile)

  void _removeImage(int index) {
    if (index >= 0 && index < _uploadedImageUrls.length) {
      setState(() {
        _uploadedImageUrls.removeAt(index);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image removed'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _removeSelectedFile(int index) {
    if (index >= 0 && index < _selectedImageFiles.length) {
      setState(() {
        _selectedImageFiles.removeAt(index);
      });
    }
  }

  void _removeWebFile(int index) {
    if (index >= 0 && index < _selectedWebFiles.length) {
      setState(() {
        _selectedWebFiles.removeAt(index);
      });
    }
  }

  Widget _buildImageWidget(String imageUrl, int index) {
    print('🖼️ Building image widget for: $imageUrl at index: $index');

    try {
      if (imageUrl.startsWith('http')) {
        // Network image
        return Image.network(
          imageUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorPlaceholder('Failed to load');
          },
        );
      } else {
        return _buildErrorPlaceholder('Invalid URL');
      }
    } catch (e) {
      print('💥 Exception in _buildImageWidget: $e');
      return _buildErrorPlaceholder('Error: $e');
    }
  }

  Widget _buildSelectedFileWidget(File file, int index) {
    if (kIsWeb) {
      // This case is now handled by _buildSelectedWebFileWidget
      return _buildErrorPlaceholder('Invalid state');
    } else {
      return Image.file(
        file,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder('Invalid file');
        },
      );
    }
  }

  Widget _buildSelectedWebFileWidget(PlatformFile file, int index) {
    return Image.memory(
      file.bytes!,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder('Invalid data'),
    );
  }

  Widget _buildErrorPlaceholder(String message) {
    return Container(
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image, color: Colors.grey, size: 40),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.grey, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Enhanced image carousel widget with reordering & cover photo badges
  Widget _buildImageCarousel() {
    final totalImages = _uploadedImageUrls.length + _selectedImageFiles.length + _selectedWebFiles.length;

    if (totalImages == 0) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[50],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, color: Colors.grey, size: 40),
            SizedBox(height: 8),
            Text('No images selected', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Photos: $totalImages / 10', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
            const Text('⭐ Image 1 is Cover Photo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: totalImages,
            itemBuilder: (context, index) {
              Widget imageWidget;
              final isCover = index == 0;
              final isUploaded = index < _uploadedImageUrls.length;

              if (index < _uploadedImageUrls.length) {
                imageWidget = _buildImageWidget(_uploadedImageUrls[index], index);
              } else if (index < _uploadedImageUrls.length + _selectedImageFiles.length) {
                final fileIndex = index - _uploadedImageUrls.length;
                imageWidget = _buildSelectedFileWidget(_selectedImageFiles[fileIndex], fileIndex);
              } else {
                final webIndex = index - _uploadedImageUrls.length - _selectedImageFiles.length;
                imageWidget = _buildSelectedWebFileWidget(_selectedWebFiles[webIndex], webIndex);
              }

              return Container(
                width: 170,
                margin: EdgeInsets.only(right: index < totalImages - 1 ? 12 : 0),
                child: Card(
                  elevation: isCover ? 4 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isCover
                        ? const BorderSide(color: Color(0xFFF59E0B), width: 2)
                        : BorderSide.none,
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(12), child: imageWidget),
                      // Cover Badge or Number
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCover ? const Color(0xFFF59E0B) : Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isCover ? '⭐ Cover' : '#${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      // Close / Remove button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 16),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              if (index < _uploadedImageUrls.length) {
                                _removeImage(index);
                              } else if (index < _uploadedImageUrls.length + _selectedImageFiles.length) {
                                final fileIndex = index - _uploadedImageUrls.length;
                                _removeSelectedFile(fileIndex);
                              } else {
                                final webIndex = index - _uploadedImageUrls.length - _selectedImageFiles.length;
                                _removeWebFile(webIndex);
                              }
                            },
                          ),
                        ),
                      ),
                      // Bottom Controls: Reorder arrows & Set Cover
                      Positioned(
                        bottom: 6,
                        left: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Shift Left
                              if (index > 0 && isUploaded)
                                InkWell(
                                  onTap: () => _moveImage(index, index - 1),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.arrow_back_ios_rounded, size: 14, color: Colors.white),
                                  ),
                                )
                              else
                                const SizedBox(width: 22),
                              // Make Cover Button
                              if (!isCover && isUploaded)
                                InkWell(
                                  onTap: () => _setAsCover(index),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Text(
                                      'Set Cover',
                                      style: TextStyle(color: Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  isCover ? 'Primary' : 'Photo',
                                  style: TextStyle(
                                    color: isCover ? const Color(0xFFFBBF24) : Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              // Shift Right
                              if (index < _uploadedImageUrls.length - 1 && isUploaded)
                                InkWell(
                                  onTap: () => _moveImage(index, index + 1),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white),
                                  ),
                                )
                              else
                                const SizedBox(width: 22),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }


  // Add this method
  Future<void> _debugTest() async {
    print('=== DEBUG TEST ===');
    print('1. Testing backend connection...');

    try {
      // Test 1: Backend health
      final healthResponse = await http.get(Uri.parse('https://hrentals-backend-production.up.railway.app/health'));
      print('   ✅ Backend health: ${healthResponse.statusCode}');

      // Test 2: GraphQL
      print('2. Testing GraphQL connection...');
      await GraphQLService.testConnection();

      // Test 3: Upload endpoint
      print('3. Testing upload endpoint...');
      final uploadTest = await http.get(Uri.parse('https://hrentals-backend-production.up.railway.app/api/upload'));
      print('   ✅ Upload endpoint: ${uploadTest.statusCode}');

      // Test 4: Check login
      print('4. Checking authentication...');
      final isLoggedIn = await GraphQLService.isLoggedIn();
      print('   ✅ Logged in: $isLoggedIn');

      if (isLoggedIn) {
        final user = await GraphQLService.getCurrentUser();
        print('   👤 User: ${user?['name']}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ All systems ready!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      print('❌ Debug test failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Test failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildAmenitiesSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kAmenities.map((amenity) {
        final key = amenity['key'] as String;
        final label = amenity['label'] as String;
        final iconCode = amenity['icon'] as int;
        final selected = _selectedAmenities.contains(key);

        return GestureDetector(
          onTap: () => setState(() {
            if (selected) {
              _selectedAmenities.remove(key);
            } else {
              _selectedAmenities.add(key);
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primaryRed : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? AppTheme.primaryRed
                    : Colors.grey.withOpacity(0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  IconData(iconCode, fontFamily: 'MaterialIcons'),
                  size: 16,
                  color: selected ? Colors.white : AppTheme.primaryRed,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 15,
                  color: selected ? Colors.white : Colors.grey,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // CARD STYLE WIDGETS
  Widget _buildCardSection({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.propertyToEdit != null ? 'Edit Property' : 'Add New Property'),
        backgroundColor: AppTheme.primaryRed,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: Colors.white),
            )
        ],
      ),
      body: _isUploading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: ListView(
            children: [
              // BASIC INFORMATION CARD
              _buildCardSection(
                title: 'Basic Information',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Property Type *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),

              // LOCATION & PRICE CARD
              _buildCardSection(
                title: 'Location & Pricing',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a location';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price (GHC) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a price';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              // CONTACT INFORMATION CARD
              _buildCardSection(
                title: 'Contact Information',
                child: TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Phone Number (Ghana) *',
                    hintText: 'e.g. 024 123 4567',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a contact phone number';
                    }
                    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
                    if (clean.length < 9) {
                      return 'Please enter a valid phone number (e.g. 0241234567)';
                    }
                    return null;
                  },
                ),
              ),

              // RENTAL TERMS & STUDENT SPECIFICATIONS CARD
              _buildCardSection(
                title: 'Rental Terms & Specifications',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedAdvance,
                            decoration: const InputDecoration(
                              labelText: 'Advance Required *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.hourglass_top_rounded),
                            ),
                            items: _advanceOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (val) => setState(() => _selectedAdvance = val!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedPricePeriod,
                            decoration: const InputDecoration(
                              labelText: 'Billing Period *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_month_rounded),
                            ),
                            items: _pricePeriodOptions.map((opt) => DropdownMenuItem(value: opt, child: Text('per $opt', style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (val) => setState(() => _selectedPricePeriod = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedMeterType,
                            decoration: const InputDecoration(
                              labelText: 'Electricity Meter',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.electric_bolt_rounded),
                            ),
                            items: _meterOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 12)))).toList(),
                            onChanged: (val) => setState(() => _selectedMeterType = val!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedWaterSupply,
                            decoration: const InputDecoration(
                              labelText: 'Water Supply',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.water_drop_rounded),
                            ),
                            items: _waterOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (val) => setState(() => _selectedWaterSupply = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _roomsController,
                      decoration: const InputDecoration(
                        labelText: 'Rooms Available (Optional)',
                        hintText: 'e.g. 1 Room or 2 Rooms',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.bed_rounded),
                      ),
                    ),
                  ],
                ),
              ),

              // AMENITIES CARD
              _buildCardSection(
                title: 'Amenities & Features',
                child: _buildAmenitiesSection(),
              ),

              // PROPERTY DETAILS CARD
              _buildCardSection(
                title: 'Property Details',
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Property Type *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: _propertyTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedType = newValue!;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a property type';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.circle, color: Colors.grey),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'available',
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Available'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'taken',
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Taken'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedStatus = newValue!;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a status';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              // IMAGES CARD
              _buildCardSection(
                title: 'Property Images (Max 10)',
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isUploading ? null : _pickImages,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Pick Images from Gallery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_isUploading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: LinearProgressIndicator(),
                      ),

                    // Display image count and carousel
                    _buildImageCarousel(),

                  ],
                ),
              ),

              const SizedBox(height: 24),

              // SAVE BUTTON
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _saveProperty,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      widget.propertyToEdit != null ? 'Update Property' : 'Save Property',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),

              // TEST BUTTON SECTION
              Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Testing Tools',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _debugTest,
                            icon: const Icon(Icons.bug_report, size: 16),
                            label: const Text('Debug Test'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              // Add mock images for quick testing
                              setState(() {
                                _uploadedImageUrls.addAll([
                                  'https://picsum.photos/600/400?mock=1',
                                  'https://picsum.photos/600/400?mock=2',
                                ]);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('✅ Added mock images for testing')),
                              );
                            },
                            icon: const Icon(Icons.add_photo_alternate, size: 16),
                            label: const Text('Add Test Images'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              print('🧪 Testing Flutter upload...');

                              // Create a test file
                              final tempDir = await getTemporaryDirectory();
                              final testFile = File('${tempDir.path}/test_flutter.png');

                              // Write some test data
                              await testFile.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]); // PNG header

                              try {
                                final urls = await GraphQLService.uploadMultipleImages([testFile]);
                                print('✅ Flutter upload test: $urls');
                              } catch (e) {
                                print('❌ Flutter upload failed: $e');
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal,),
                            child: const Text('Test Flutter Upload'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
}
}