
/// All amenities the app knows about.
const List<Map<String, dynamic>> kAmenities = [
  {'key': 'wifi',        'label': 'WiFi',          'icon': 0xe63b}, // wifi_rounded
  {'key': 'water',       'label': 'Water',          'icon': 0xe798}, // water_drop_rounded
  {'key': 'electricity', 'label': 'Electricity',    'icon': 0xe1a5}, // bolt_rounded
  {'key': 'security',    'label': 'Security',       'icon': 0xe32a}, // security_rounded
  {'key': 'parking',     'label': 'Parking',        'icon': 0xe54f}, // local_parking_rounded
  {'key': 'bathroom',    'label': 'Bathroom',       'icon': 0xe0fa}, // bathroom_rounded
  {'key': 'kitchen',     'label': 'Kitchen',        'icon': 0xe56c}, // kitchen_rounded
  {'key': 'furnished',   'label': 'Furnished',      'icon': 0xe1c4}, // chair_rounded
  {'key': 'ac',          'label': 'Air Condition',  'icon': 0xe059}, // ac_unit_rounded
  {'key': 'cctv',        'label': 'CCTV',           'icon': 0xe32c}, // videocam_rounded
];

// Delimiter used to separate amenities from the human-readable description.
const String _kAmenityDelimiter = '||amenities:';
const String _kAmenityEnd = '||';

class Property {
  final String? id;
  final String title;
  final String? description;
  final double price;
  final String location;
  final String type;
  final String? status;
  final String? contact;
  final List<String> images;
  final String? imageUrl;
  final List<Map<String, dynamic>>? gallery;
  final String? createdAt;
  final Map<String, dynamic>? owner;
  final Map<String, dynamic>? company;
  final bool isFeatured;

  Property({
    this.id,
    required this.title,
    this.description,
    required this.price,
    required this.location,
    required this.type,
    this.status,
    this.contact,
    List<String>? images,
    this.imageUrl,
    this.gallery,
    this.createdAt,
    this.owner,
    this.company,
    this.isFeatured = false,
  }) : images = images ?? [];

  factory Property.fromJson(Map<String, dynamic> json) {
    print('🖼️ [Property Model] Parsing property: ${json['title']}');

    // ==================== IMAGE EXTRACTION ====================
    List<String> imageUrls = [];

    // 1. Check GALLERY field (GraphQL format - MOST IMPORTANT!)
    if (json['gallery'] != null && json['gallery'] is List) {
      print('   📁 Found GALLERY field with ${json['gallery'].length} items');
      for (var galleryItem in json['gallery']) {
        if (galleryItem is Map) {
          // Extract URL from gallery object
          final url = galleryItem['url']?.toString();
          if (url != null && url.isNotEmpty) {
            final processedUrl = _processImageUrl(url);
            imageUrls.add(processedUrl);
            print('   🖼️ Gallery URL: $processedUrl');
          }
        }
      }
    }

    // 2. Check imageUrl field (GraphQL single image)
    if (json['imageUrl'] != null && json['imageUrl'].toString().isNotEmpty) {
      final url = json['imageUrl'].toString();
      final processedUrl = _processImageUrl(url);
      if (!imageUrls.contains(processedUrl)) {
        imageUrls.add(processedUrl);
        print('   🖼️ Main imageUrl: $processedUrl');
      }
    }

    // 3. Check images array (backward compatibility)
    if (json['images'] != null && json['images'] is List) {
      print('   📁 Found IMAGES array with ${json['images'].length} items');
      for (var img in json['images']) {
        if (img != null && img.toString().isNotEmpty) {
          final url = img.toString();
          final processedUrl = _processImageUrl(url);
          if (!imageUrls.contains(processedUrl)) {
            imageUrls.add(processedUrl);
            print('   🖼️ Images array: $processedUrl');
          }
        }
      }
    }

    print('   ✅ Final images count: ${imageUrls.length}');
    if (imageUrls.isEmpty) {
      print('   ⚠️ WARNING: No images found for this property!');
    }

    // ==================== DATA EXTRACTION ====================
    // Parse owner data safely
    Map<String, dynamic>? ownerData;
    if (json['owner'] != null && json['owner'] is Map) {
      try {
        ownerData = Map<String, dynamic>.from(json['owner'] as Map);
      } catch (e) {
        print('   ❌ Error parsing owner: $e');
        ownerData = {
          'id': json['owner']?['id']?.toString(),
          'name': json['owner']?['name']?.toString() ?? 'Unknown',
          'email': json['owner']?['email']?.toString(),
        };
      }
    }

    // Parse company data safely
    Map<String, dynamic>? companyData;
    if (json['company'] != null && json['company'] is Map) {
      try {
        companyData = Map<String, dynamic>.from(json['company'] as Map);
      } catch (e) {
        print('   ❌ Error parsing company: $e');
        companyData = {
          'id': json['company']?['id']?.toString(),
          'name': json['company']?['name']?.toString() ?? 'Unknown',
        };
      }
    }

    // Parse gallery data safely
    List<Map<String, dynamic>>? galleryData;
    if (json['gallery'] != null && json['gallery'] is List) {
      try {
        galleryData = List<Map<String, dynamic>>.from(
            json['gallery'].map((item) {
              if (item is Map) {
                final map = Map<String, dynamic>.from(item);
                // Process the URL in gallery items too
                if (map['url'] != null) {
                  map['url'] = _processImageUrl(map['url'].toString());
                }
                return map;
              } else {
                return {'url': _processImageUrl(item?.toString() ?? '')};
              }
            }).toList()
        );
      } catch (e) {
        print('   ❌ Error parsing gallery: $e');
        galleryData = [];
      }
    }

    // ==================== CREATE PROPERTY ====================
    return Property(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? 'No Title',
      description: json['description']?.toString(),
      price: (json['price'] is int ? json['price'].toDouble() : json['price'] as double?) ?? 0.0,
      location: json['location']?.toString() ?? 'Unknown Location',
      type: json['type']?.toString() ?? 'Property',
      status: json['status']?.toString() ?? 'available',
      contact: json['contact']?.toString(),
      images: imageUrls,
      imageUrl: json['imageUrl'] != null ? _processImageUrl(json['imageUrl'].toString()) : null,
      gallery: galleryData,
      createdAt: json['createdAt']?.toString(),
      owner: ownerData,
      company: companyData,
      isFeatured: json['isFeatured'] == true,
    );
  }

  // 🚨 CRITICAL: Process image URLs for Cloudinary
  static const String _railwayBaseUrl = 'https://hrentals-backend-production.up.railway.app';

  static String _processImageUrl(String url) {
    if (url.isEmpty) return url;

    print('   🔍 Processing URL: $url');

    // Case 1: Already a full Cloudinary URL
    if (url.startsWith('http') && url.contains('cloudinary.com')) {
      print('   ✅ Already full Cloudinary URL');
      return url;
    }

    // Case 2: Cloudinary path without protocol (common issue)
    if (url.contains('cloudinary.com') && !url.startsWith('http')) {
      final fullUrl = 'https:$url';
      print('   🔧 Fixed Cloudinary URL: $fullUrl');
      return fullUrl;
    }

    // Case 3: Relative path (from local storage)
    if (!url.startsWith('http')) {
      // If it's a Cloudinary path stored as relative
      if (url.contains('res.cloudinary.com')) {
        final fullUrl = 'https:$url';
        print('   🔧 Fixed relative Cloudinary URL: $fullUrl');
        return fullUrl;
      }

      // For local uploads, prepend your Railway URL
      final fullUrl = url.startsWith('/') ? '$_railwayBaseUrl$url' : '$_railwayBaseUrl/$url';
      print('   🔧 Fixed local URL: $fullUrl');
      return fullUrl;
    }

    // Case 4: localhost URL — rewrite to Railway (images uploaded during local dev)
    if (url.contains('localhost') || url.contains('127.0.0.1')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final path = uri.path; // e.g. /uploads/filename.jpg
        final fullUrl = '$_railwayBaseUrl$path';
        print('   🔧 Rewrote localhost URL to Railway: $fullUrl');
        return fullUrl;
      }
    }

    // Case 5: Already a valid full URL (Railway or other)
    print('   ✅ Valid full URL');
    return url;
  }

  // ✅ Helper method to get the best available image
  String? get displayImage {
    // Priority 1: Check gallery first (Cloudinary URLs are usually here)
    if (gallery != null && gallery!.isNotEmpty) {
      for (var item in gallery!) {
        final url = item['url']?.toString();
        if (url != null && url.isNotEmpty) {
          print('🖼️ Using gallery image: $url');
          return url;
        }
      }
    }

    // Priority 2: Check imageUrl
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      print('🖼️ Using imageUrl: $imageUrl');
      return imageUrl;
    }

    // Priority 3: Check images array
    if (images.isNotEmpty) {
      print('🖼️ Using images array: ${images.first}');
      return images.first;
    }

    print('⚠️ No images found for property: $title');
    return null;
  }

  // ✅ Check if property has any images
  bool get hasImages =>
      images.isNotEmpty ||
          (imageUrl != null && imageUrl!.isNotEmpty) ||
          (gallery != null && gallery!.isNotEmpty);

  // ✅ Get all image URLs combined
  List<String> get allImageUrls {
    final allUrls = <String>[];

    if (images.isNotEmpty) allUrls.addAll(images);

    if (imageUrl != null && imageUrl!.isNotEmpty && !allUrls.contains(imageUrl)) {
      allUrls.add(imageUrl!);
    }

    if (gallery != null) {
      for (var item in gallery!) {
        if (item['url'] != null && item['url'].toString().isNotEmpty) {
          final url = item['url'].toString();
          if (!allUrls.contains(url)) {
            allUrls.add(url);
          }
        }
      }
    }

    return allUrls;
  }

  // ─── Amenity helpers ────────────────────────────────────────────────────────

  /// Formats advance payment period into readable string (e.g. "1 Year", "6 Months", "2 Years").
  static String formatAdvanceLabel(String? advanceStr) {
    if (advanceStr == null || advanceStr.trim().isEmpty) return '1 Year';
    var cleaned = advanceStr.trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s*\((?:per|for)\s+[^)]+\)', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+per\s+(?:year|month|semester|academic year|day|plot|acre)', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+(?:advance|payment|required)\b', caseSensitive: false), '');

    // Capitalize words
    cleaned = cleaned.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');

    return cleaned.trim().isEmpty ? '1 Year' : cleaned.trim();
  }

  /// Encode a list of amenity keys + a plain description into one string.
  static String encodeDescription(String plainDescription, List<String> amenityKeys) {
    final desc = plainDescription.trim();
    if (amenityKeys.isEmpty) return desc;
    final encoded = amenityKeys.join(',');
    return '$desc$_kAmenityDelimiter$encoded$_kAmenityEnd';
  }

  /// Extract the human-readable description (without the amenity/features suffix).
  static String decodeDescription(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    var text = raw;
    final idx = text.indexOf(_kAmenityDelimiter);
    if (idx != -1) {
      text = text.substring(0, idx);
    }
    final featIdx = text.toLowerCase().indexOf('\n\nfeatures:');
    if (featIdx != -1) {
      text = text.substring(0, featIdx);
    } else {
      final featIdx2 = text.toLowerCase().indexOf('features:');
      if (featIdx2 != -1) {
        text = text.substring(0, featIdx2);
      }
    }
    return text.trim();
  }

  /// Extract the list of amenity keys stored in the description.
  static List<String> decodeAmenities(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final amenities = <String>{};

    // Check delimiter format
    final start = raw.indexOf(_kAmenityDelimiter);
    if (start != -1) {
      final after = raw.substring(start + _kAmenityDelimiter.length);
      final end = after.indexOf(_kAmenityEnd);
      final encoded = end == -1 ? after : after.substring(0, end);
      if (encoded.trim().isNotEmpty) {
        amenities.addAll(encoded.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty));
      }
    }

    // Check features text in description
    final lower = raw.toLowerCase();
    if (lower.contains('wifi') || lower.contains('wi-fi')) amenities.add('wifi');
    if (lower.contains('water') || lower.contains('polytank') || lower.contains('borehole')) amenities.add('water');
    if (lower.contains('electricity') || lower.contains('meter')) amenities.add('electricity');
    if (lower.contains('security') || lower.contains('gated') || lower.contains('fenced')) amenities.add('security');
    if (lower.contains('parking')) amenities.add('parking');
    if (lower.contains('bathroom') || lower.contains('self contain') || lower.contains('self-contain')) amenities.add('bathroom');
    if (lower.contains('kitchen')) amenities.add('kitchen');
    if (lower.contains('furnished')) amenities.add('furnished');
    if (lower.contains('ac') || lower.contains('air condition')) amenities.add('ac');
    if (lower.contains('cctv')) amenities.add('cctv');

    return amenities.toList();
  }

  /// Convenience getter — amenity keys for this property.
  List<String> get amenities => decodeAmenities(description);

  /// Convenience getter — plain description without amenity data.
  String get plainDescription => decodeDescription(description);

  /// Advance payment requirement (e.g. "1 Year", "6 Months", "2 Years")
  String? get advancePeriod {
    final raw = description ?? '';
    final match = RegExp(r'(?:Advance Required|Advance period|Advance Payment|Advance):\s*([^.\n|]+)', caseSensitive: false).firstMatch(raw);
    if (match != null && match.group(1) != null) {
      return formatAdvanceLabel(match.group(1));
    }
    return null;
  }

  /// Price billing period (e.g. "month", "semester", "year")
  String get pricePeriod {
    final raw = (description ?? '').toLowerCase();
    if (raw.contains('priceperiod: per year') || raw.contains('priceperiod: year') || raw.contains('per year') || raw.contains('/year') || raw.contains('/yr')) {
      return 'year';
    }
    if (raw.contains('priceperiod: per month') || raw.contains('priceperiod: month') || raw.contains('per month') || raw.contains('/month')) {
      return 'month';
    }
    if (raw.contains('per semester') || raw.contains('semester') || raw.contains('/sem')) {
      return 'semester';
    }
    return 'month';
  }

  /// Number of rooms available if specified
  String? get roomsAvailable {
    final raw = description ?? '';
    final match = RegExp(r'(?:Rooms Available|Rooms):\s*([^.\n|]+)', caseSensitive: false).firstMatch(raw);
    return match?.group(1)?.trim();
  }

  /// Electricity meter type (e.g. "Prepaid", "Separate Meter", "Shared Meter")
  String? get meterType {
    final raw = (description ?? '').toLowerCase();
    if (raw.contains('ecg separate meter') || raw.contains('separate meter')) return 'Separate Meter';
    if (raw.contains('ecg prepaid') || raw.contains('prepaid')) return 'Prepaid';
    if (raw.contains('ecg shared meter') || raw.contains('shared meter')) return 'Shared Meter';
    return null;
  }

  /// Water supply type (e.g. "Polytank", "Ghana Water", "Borehole")
  String? get waterSupply {
    final raw = (description ?? '').toLowerCase();
    if (raw.contains('polytank')) return 'Polytank';
    if (raw.contains('ghana water')) return 'Ghana Water';
    if (raw.contains('borehole')) return 'Borehole';
    if (raw.contains('well')) return 'Well Water';
    return null;
  }

  /// Formatted contact phone for WhatsApp (Ghanaian international format 233...)
  String get whatsappNumber {
    final raw = (contact != null && contact!.isNotEmpty)
        ? contact!
        : (owner?['phone']?.toString() ?? '0204940602');
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      return '233${digits.substring(1)}';
    }
    if (digits.startsWith('233')) {
      return digits;
    }
    return digits.isNotEmpty ? '233$digits' : '233204940602';
  }

  /// Official share URL
  String get shareUrl => 'https://horentals.com/properties/${id ?? ''}';

  // ────────────────────────────────────────────────────────────────────────────

  Property copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    String? location,
    String? type,
    String? status,
    String? contact,
    List<String>? images,
    String? imageUrl,
    List<Map<String, dynamic>>? gallery,
    String? createdAt,
    Map<String, dynamic>? owner,
    Map<String, dynamic>? company,
    bool? isFeatured,
  }) {
    return Property(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      location: location ?? this.location,
      type: type ?? this.type,
      status: status ?? this.status,
      contact: contact ?? this.contact,
      images: images ?? this.images,
      imageUrl: imageUrl ?? this.imageUrl,
      gallery: gallery ?? this.gallery,
      createdAt: createdAt ?? this.createdAt,
      owner: owner ?? this.owner,
      company: company ?? this.company,
      isFeatured: isFeatured ?? this.isFeatured,
    );
  }

  @override
  String toString() {
    return 'Property(id: $id, title: $title, type: $type, images: ${images.length}, hasGallery: ${gallery != null ? gallery!.length : 0}, hasImageUrl: ${imageUrl != null}, displayImage: $displayImage)';
  }
}
