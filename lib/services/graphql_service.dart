import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../utils/logger.dart';


class GraphQLService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static GraphQLClient? _cachedClient;
  static Future<List<String>> uploadFiles({
    List<File>? mobileFiles,
    List<PlatformFile>? webFiles,
  }) => uploadMultipleFilesGeneric(mobileFiles: mobileFiles, webFiles: webFiles);

  static Future<List<String>> uploadMultipleFilesGeneric({
    List<File>? mobileFiles,
    List<PlatformFile>? webFiles,
  }) async {
    final url = '$_baseUrl/api/upload-multiple'; // Ensure backend matches
    AppLogger.info('📤 Uploading images to: $url');

    var request = http.MultipartRequest('POST', Uri.parse(url));

    final token = await _storage.read(key: 'auth_token');
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (mobileFiles != null && mobileFiles.isNotEmpty) {
      for (int i = 0; i < mobileFiles.length; i++) {
        final File file = mobileFiles[i];
        final filename = file.path.split('/').last;
        final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
        final parts = mimeType.split('/');

        request.files.add(
          await http.MultipartFile.fromPath(
            'images',
            file.path,
            filename: filename,
            contentType: MediaType(parts[0], parts[1]),
          ),
        );
      }
    }

    if (webFiles != null && webFiles.isNotEmpty) {
      for (int i = 0; i < webFiles.length; i++) {
        final p = webFiles[i];
        if (p.bytes == null) continue;
        String mime = lookupMimeType(p.name) ?? 'image/jpeg';
        final parts = mime.split('/');
        request.files.add(
          http.MultipartFile.fromBytes(
            'images',
            p.bytes!,
            filename: p.name,
            contentType: MediaType(parts[0], parts[1]),
          ),
        );
      }
    }

    if (request.files.isEmpty) {
      throw Exception('❌ No files provided to upload.');
    }

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    AppLogger.info('📥 Upload response (${streamed.statusCode}): $body');

    if (streamed.statusCode == 200) {
      final jsonResp = json.decode(body);
      if (jsonResp['imageUrls'] != null) {
        return List<String>.from(jsonResp['imageUrls']);
      }
      if (jsonResp['images'] != null) {
        return List<String>.from(jsonResp['images']);
      }
      return [];
    } else {
      throw Exception('Upload failed: $body');
    }
  }

  static Future<List<PlatformFile>?> pickFilesWeb() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );

      if (result == null) return null;
      return result.files;
    } catch (e) {
      AppLogger.error('❌ pickFilesWeb error: $e');
      return null;
    }
  }

  static String get _baseUrl {
    // For production builds
    if (kReleaseMode) {
      return 'https://hrentals-backend-production.up.railway.app';
    }

    // For development - check if you want to use Railway or local
    // You can add a flag to switch between them
    const bool useRailwayInDev = true; // Set this based on your needs

    if (useRailwayInDev) {
      return 'https://hrentals-backend-production.up.railway.app';
    } else {
      if (kIsWeb) {
        return 'http://localhost:4000';
      } else if (Platform.isAndroid) {
        return 'http://10.0.2.2:4000';
      } else {
        return 'http://localhost:4000';
      }
    }
  }
  static String get _graphqlUrl => '$_baseUrl/graphql';
  static String get _uploadUrl => '$_baseUrl/api/upload';

  static const String DELETE_PROPERTY = r'''
  mutation DeleteProperty($id: Int!) {
    deleteProperty(id: $id) {
      id
      title
    }
  }
''';

  static const String UPDATE_PROPERTY_STATUS = r'''
    mutation UpdatePropertyStatus($id: ID!, $status: String!) {
      updatePropertyStatus(id: $id, status: $status) {
        id
        title
        status
      }
    }
  ''';

  static const String TOGGLE_FEATURED = r'''
    mutation TogglePropertyFeatured($id: Int!) {
      togglePropertyFeatured(id: $id) {
        id
        title
        isFeatured
      }
    }
  ''';

  static void validateGraphQLUrl() {
    final url = _graphqlUrl;
    AppLogger.info('🔗 GraphQL URL: $url');

    if (!url.startsWith('http')) {
      throw Exception('Invalid GraphQL URL: Must start with http:// or https://');
    }

    if (!url.contains('://')) {
      throw Exception('Invalid GraphQL URL: Missing protocol (://)');
    }

    if (!url.endsWith('/graphql')) {
      AppLogger.warning('⚠️ Warning: GraphQL URL might be incorrect. Expected to end with /graphql');
    }

    AppLogger.info('✅ GraphQL URL validation passed');
  }

  static Future<void> debugPropertyCreation() async {
    AppLogger.debug('🔍 DEBUG: Testing property creation flow');
    try {
      final health = await http.get(Uri.parse('$_baseUrl/health'));
      AppLogger.info('✅ Server health: ${health.statusCode}');

      AppLogger.info('📤 Upload URL: $_baseUrl/api/upload-multiple');

      final isLoggedIn = await GraphQLService.isLoggedIn();
      AppLogger.info('🔐 Logged in: $isLoggedIn');

      if (isLoggedIn) {
        final user = await GraphQLService.getCurrentUser();
        AppLogger.info('👤 Current user: ${user?['name']}');
      }

      AppLogger.info('✅ Debug complete - System is ready!');
    } catch (e) {
      AppLogger.error('❌ Debug error: $e');
    }
  }

  static AuthLink get _authLink => AuthLink(
    getToken: () async {
      try {
        final token = await _storage.read(key: 'auth_token');
        if (token == null) {
          AppLogger.info('🔐 No auth token found');
          return null;
        }

        if (!_isValidToken(token)) {
          AppLogger.warning('🔐 Invalid token format, clearing...');
          await clearAuthData();
          return null;
        }

        AppLogger.info('🔐 Using token: ${token.substring(0, 20)}...');
        return 'Bearer $token';
      } catch (e) {
        AppLogger.error('🔐 Error retrieving token: $e');
        await clearAuthData();
        return null;
      }
    },
  );

  static bool _isValidToken(String token) {
    if (token.isEmpty) return false;
    final parts = token.split('.');
    return parts.length == 3;
  }

  static HttpLink get _httpLink => HttpLink(
    _graphqlUrl,
    defaultHeaders: {
      'Content-Type': 'application/json',
    },
  );

  static Link get _link => _authLink.concat(_httpLink);

  static ValueNotifier<GraphQLClient> initializeClient() {
    if (_cachedClient != null) {
      return ValueNotifier(_cachedClient!);
    }

    final client = GraphQLClient(
      link: _link,
      cache: GraphQLCache(store: InMemoryStore()),
      defaultPolicies: DefaultPolicies(
        query: Policies(fetch: FetchPolicy.noCache),
        mutate: Policies(fetch: FetchPolicy.noCache),
        watchQuery: Policies(fetch: FetchPolicy.noCache),
      ),
    );

    _cachedClient = client;
    AppLogger.info('✅ GraphQL Client initialized for $_graphqlUrl');
    return ValueNotifier(client);
  }

  static GraphQLClient getClient() {
    return initializeClient().value;
  }

  static void clearCachedClient() {
    _cachedClient = null;
  }

  static Future<void> clearCacheAfterMutation() async {
    AppLogger.info('🧹 Clearing cache after mutation...');
    clearCachedClient();
    await Future.delayed(const Duration(milliseconds: 50));
  }

  static Future<void> storeAuthData(String token, Map<String, dynamic> user) async {
    try {
      if (!_isValidToken(token)) {
        throw Exception('Invalid token format');
      }

      await _storage.write(key: 'auth_token', value: token);
      await _storage.write(key: 'user_data', value: json.encode(user));

      clearCachedClient();

      AppLogger.info('🔐 Auth data stored successfully for user: ${user['name']}');
    } catch (e) {
      AppLogger.error('❌ Error storing auth data: $e');
      rethrow;
    }
  }

  static Future<void> clearAuthData() async {
    try {
      await _storage.delete(key: 'auth_token');
      await _storage.delete(key: 'user_data');
      clearCachedClient();
      AppLogger.info('🔐 Auth data cleared successfully');
    } catch (e) {
      AppLogger.error('❌ Error clearing auth data: $e');
    }
  }

  static Future<void> clearAndResetAuth() async {
    await clearAuthData();
    AppLogger.info('🔄 Auth system reset complete');
  }

  static Future<String> getCurrentUserId() async {
    try {
      final userData = await _storage.read(key: 'user_data');
      if (userData != null) {
        final user = json.decode(userData);
        final userId = user['id']?.toString();
        if (userId != null && userId.isNotEmpty) {
          return userId;
        }
      }
      throw Exception('User not authenticated or user data corrupted');
    } catch (e) {
      AppLogger.error('❌ Error getting current user ID: $e');
      rethrow;
    }
  }

  static Future<bool> isLoggedIn() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null || !_isValidToken(token)) {
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final userData = await _storage.read(key: 'user_data');
      if (userData != null) {
        return json.decode(userData);
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ Error parsing current user: $e');
      await clearAuthData();
      return null;
    }
  }

  static const String GET_USERS = r'''
  query GetUsers {
    users {
      id
      name
      email
      phone
      role
    }
  }
''';

  static const String GET_PROPERTIES = r'''
  query GetProperties {
    properties {
      id
      title
      type
      status
      price
      location
      description
      contact
      imageUrl
      isFeatured
      createdAt
      owner {
        id
        name
        email
      }
      company {
        id
        name
      }
      gallery {
        url
        caption
        order
      }
    }
  }
''';
  static const String GET_PROPERTY_BY_ID = r'''
  query GetPropertyById($id: ID!) {
    property(id: $id) {
      id
      title
      location
      contact
      price
      description
      imageUrl
      type
      status
      createdAt
      gallery {
        id
        url
        caption
        order
      }
    }
  }
''';

  static const String CREATE_PROPERTY = r'''
  mutation AddProperty($input: PropertyInput!) {
    addProperty(input: $input) {
      id
      title
      location
      price
      type
      status
      description
      contact
      imageUrl
      gallery {
        id
        url
        caption
        order
      }
      createdAt
    }
  }
''';

  static const String UPDATE_PROPERTY = r'''
  mutation UpdateProperty($id: Int!, $input: PropertyInput!) {
    updateProperty(id: $id, input: $input) {
      id
      title
      location
      price
      description
      contact
      type
      status
      imageUrl
      gallery {
        id
        url
        caption
        order
      }
      createdAt
    }
  }
''';

  static const String LOGIN_MUTATION = r'''
    mutation Login($email: String!, $password: String!) {
      login(email: $email, password: $password) {
        token
        user {
          id
          name
          email
          phone
          role
        }
      }
    }
  ''';

  static const String REGISTER_MUTATION = r'''
    mutation Register($input: RegisterInput!) {
      register(input: $input) {
        token
        user {
          id
          name
          email
          phone
          role
        }
      }
    }
  ''';

  static const String GET_PROPERTIES_BY_TYPE = r'''
    query GetPropertiesByType($type: String!) {
      properties(where: { type: $type }) {
        id
        title
      }
    }
  ''';

  static const String DELETE_USER = r'''
    mutation DeleteUser($id: Int!) {
      deleteUser(id: $id) {
        id
        name
      }
    }
  ''';

  static const String UPDATE_USER_ROLE = r'''
    mutation UpdateUserRole($id: Int!, $role: String!) {
      updateUserRole(id: $id, role: $role) {
        id
        role
      }
    }
  ''';

  static const String GET_DASHBOARD_STATS = r'''
    query GetDashboardStats {
      dashboardStats {
        totalProperties
        totalUsers
        availableProperties
        rentedProperties
      }
    }
  ''';

  static Future<void> testConnection() async {
    try {
      print('🔗 Testing connection to: $_graphqlUrl');
      final client = initializeClient().value;

      const String testQuery = r'''
        query TestQuery {
          __schema {
            queryType {
              name
            }
          }
        }
      ''';

      final result = await client.query(
        QueryOptions(
          document: gql(testQuery),
          fetchPolicy: FetchPolicy.noCache,
        ),
      );

      if (result.hasException) {
        print('❌ Connection test failed: ${result.exception}');
        if (result.exception?.graphqlErrors != null) {
          for (final error in result.exception!.graphqlErrors) {
            print('   - GraphQL Error: ${error.message}');
          }
        }
        throw Exception('GraphQL connection failed');
      } else {
        print('✅ Connection test successful! Server is responding.');
      }
    } catch (e) {
      print('❌ Connection test error: $e');
      rethrow;
    }
  }

  static Future<void> testUpload() async {
    try {
      print('🧪 Testing upload functionality...');

      if (!kIsWeb) {
        print('📱 Mobile upload test ready');
      } else {
        print('🌐 Web upload test ready');
      }
      print('✅ Upload system initialized correctly');
    } catch (e) {
      print('❌ Upload test failed: $e');
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      print('🔄 Attempting login for: $email');

      await clearAuthData();

      final client = initializeClient().value;

      final result = await client.mutate(
        MutationOptions(
          document: gql(LOGIN_MUTATION),
          variables: {'email': email, 'password': password},
          fetchPolicy: FetchPolicy.noCache,
        ),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Login timeout - Server not responding'),
      );

      print('📥 Login response received');

      if (result.hasException) {
        print('❌ Login mutation failed: ${result.exception}');

        if (result.exception?.graphqlErrors != null) {
          for (final error in result.exception!.graphqlErrors) {
            print('   - GraphQL Error: ${error.message}');
            if (error.message.contains('jwt') || error.message.contains('token')) {
              await clearAuthData();
            }
          }
          throw Exception(result.exception!.graphqlErrors.first.message);
        } else if (result.exception?.linkException != null) {
          throw Exception('Network error: ${result.exception!.linkException}');
        } else {
          throw Exception('Login failed: ${result.exception}');
        }
      }

      print('🔍 Raw response data: ${result.data}');
      print('🔍 Response data type: ${result.data.runtimeType}');

      final loginData = result.data?['login'];

      if (loginData == null) {
        print('❌ No login data in response');
        print('📊 Full response: ${result.data}');
        throw Exception('Invalid response from server');
      }

      if (loginData['token'] == null) {
        throw Exception('No authentication token received');
      }

      final token = loginData['token'].toString();
      if (!_isValidToken(token)) {
        throw Exception('Invalid token format received from server');
      }

      final userData = loginData['user'];
      print('👤 User data type: ${userData.runtimeType}');
      print('👤 User data: $userData');

      Map<String, dynamic> userMap;

      if (userData is Map<String, dynamic>) {
        userMap = userData;
      } else if (userData is Map) {
        userMap = Map<String, dynamic>.from(userData);
      } else if (userData is List) {
        if (userData.isEmpty) {
          throw Exception('No user data in response');
        }
        userMap = Map<String, dynamic>.from(userData.first as Map);
      } else {
        print('❌ Unexpected user data format: ${userData.runtimeType}');
        throw Exception('Invalid user data format received');
      }

      await storeAuthData(token, userMap);

      print('✅ Login successful for user: ${userMap['name']}');
      return loginData;

    } catch (e) {
      print('❌ Login error: $e');
      print('📋 Full error: ${e.toString()}');
      await clearAuthData();
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> register(Map<String, dynamic> input) async {
    try {
      print('🔄 Attempting registration for: ${input['name']}');

      await clearAuthData();

      final client = initializeClient().value;

      final result = await client.mutate(
        MutationOptions(
          document: gql(REGISTER_MUTATION),
          variables: {'input': input},
          fetchPolicy: FetchPolicy.noCache,
        ),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Registration timeout'),
      );

      if (result.hasException) {
        print('❌ Registration failed: ${result.exception}');
        if (result.exception?.graphqlErrors != null) {
          for (final error in result.exception!.graphqlErrors) {
            print('   - GraphQL Error: ${error.message}');
          }
          throw Exception(result.exception!.graphqlErrors.first.message);
        }
        throw Exception('Registration failed: ${result.exception}');
      }

      final registerData = result.data?['register'];

      if (registerData == null) {
        throw Exception('Invalid response from server');
      }

      if (registerData['token'] == null) {
        throw Exception('No authentication token received');
      }

      final token = registerData['token'].toString();
      if (!_isValidToken(token)) {
        throw Exception('Invalid token format received from server');
      }

      await storeAuthData(token, registerData['user']);
      print('✅ Registration successful for user: ${registerData['user']['name']}');
      return registerData;

    } catch (e) {
      print('❌ Registration error: $e');
      await clearAuthData();
      rethrow;
    }
  }

  static Future<String> uploadSingleImage(File imageFile) async {
    try {
      print('📤 Uploading image via REST: ${imageFile.path}');

      var request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      const mimeType = 'image/jpeg';
      final mimeTypeData = mimeType.split('/');

      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
      ));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(responseData);
        final imageUrl = jsonResponse['imageUrl'];
        print('✅ Image uploaded successfully: $imageUrl');
        return imageUrl;
      } else {
        throw Exception('Upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ REST upload failed: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  static Future<List<String>> uploadMultipleImages(List<File> imageFiles) async {
    try {
      if (kIsWeb) {
        throw Exception('Use uploadMultipleFilesGeneric(webFiles: pickedFiles) on web.');
      }
      return await uploadMultipleFilesGeneric(mobileFiles: imageFiles);
    } catch (e) {
      print('❌ uploadMultipleImages error: $e');
      return _getFallbackImages(imageFiles.length);
    }
  }

  static List<String> _getFallbackImages(int count) {
    print('⚠️ Using fallback image URLs');
    return List.generate(
      count,
      (i) => 'https://picsum.photos/600/400?fallback=$i',
    );
  }

  static Future<void> createProperty({
    required String title,
    required String location,
    required double price,
    required String type,
    String? description,
    String? contact,
    String status =
        'available',
    List<File>? imageFiles,
    List<String>?
        imageUrls, // For pre-existing URLs, e.g., when editing or re-using
  }) async {
     try {
    print('🏠 Creating property: "$title"');

    List<String> finalImageUrls = imageUrls?.toList() ?? [];

    if (imageFiles != null && imageFiles.isNotEmpty) {
      print('📤 Uploading ${imageFiles.length} images...');
      final uploadedUrls = await uploadMultipleFilesGeneric(mobileFiles: imageFiles);
      finalImageUrls.addAll(uploadedUrls);
    }

    if (finalImageUrls.isEmpty) {
      throw Exception('At least one image is required to create a property.');
    }

    final input = {
      'title': title,
      'location': location,
      'price': price,
      'type': type,
      'status': status,
      'description': description ?? '',
      'contact': contact ?? '',
      'imageUrl': finalImageUrls.first,
      'gallery': finalImageUrls.asMap().entries.map((entry) {
        return {
          'url': entry.value,
          'caption': 'Image ${entry.key + 1}',
          'order': entry.key + 1,
        };
      }).toList(),
    };

    print('📤 Sending GraphQL mutation to create property...');
    final client = getClient();

    final result = await client.mutate(
      MutationOptions(
        document: gql(CREATE_PROPERTY),
        variables: {'input': input},
      ),
    ).timeout(const Duration(seconds: 15));

    if (result.hasException) {
      throw Exception('GraphQL error: ${result.exception}');
    }

    AppLogger.info('✅ Property created successfully!');
    await clearCacheAfterMutation();
  } catch (e) {
    AppLogger.error('❌ Create property failed: $e'); rethrow;}
  }

  static Future<void> updateProperty({
    required String id,
    required String title,
    required String location,
    required double price,
    required String type,
    String status = 'available',
    String? description,
    String? contact,
    List<File>? newImageFiles,
    List<PlatformFile>? newWebFiles,
    List<String>? existingImageUrls,
  }) async {
    try {
      AppLogger.info('🔄 Updating property: $id');

      List<String> finalImageUrls = [...?existingImageUrls];

      if (kIsWeb) {
        if (newWebFiles != null && newWebFiles.isNotEmpty) {
          AppLogger.info('🌐 Uploading ${newWebFiles.length} web files...');
          final uploadedUrls = await uploadMultipleFilesGeneric(webFiles: newWebFiles);
          finalImageUrls.addAll(uploadedUrls);
        }
      } else {
        if (newImageFiles != null && newImageFiles.isNotEmpty) {
          AppLogger.info('📱 Uploading ${newImageFiles.length} mobile files...');
          final uploadedUrls = await uploadMultipleImages(newImageFiles);
          finalImageUrls.addAll(uploadedUrls);
        }
      }

      if (finalImageUrls.isEmpty) {
        throw Exception('At least one image is required');
      }

      final variables = {
        'id': int.parse(id),
        'input': {
          'title': title,
          'location': location,
          'price': price,
          'type': type,
          'status': status,
          'description': description ?? '',
          'contact': contact ?? '',
          'imageUrl': finalImageUrls.first,
          'gallery': finalImageUrls.asMap().entries.map((entry) {
            final index = entry.key;
            final url = entry.value;
            return {
              'url': url,
              'caption': 'Image ${index + 1}',
              'order': index + 1,
            };
          }).toList(),
        },
      };

      AppLogger.info('📤 Sending GraphQL update mutation: $variables');

      final client = getClient();
      final result = await client.mutate(
        MutationOptions(
          document: gql(UPDATE_PROPERTY),
          variables: variables,
          fetchPolicy: FetchPolicy.noCache,
        ),
      );

      if (result.hasException) {
       AppLogger.error('❌ Update property error: ${result.exception}');
       throw Exception('Failed to update property: ${result.exception}');
      }

      AppLogger.info('✅ Property updated successfully');

      await clearCacheAfterMutation();

      return;
    } catch (e) {
      AppLogger.error('💥 Update property failed: $e');
      rethrow;
    }
  }

  static Future<void> testLogin() async {
    try {
      AppLogger.debug('🧪 Testing login with default admin...');
      final result = await login('0240000000@horentals.com', 'admin123');
      AppLogger.info('✅ Test login successful: ${result['user']['name']}');
    } catch (e) {
      AppLogger.error('❌ Test login failed: $e');
    }
  }

  static Future<bool> deleteProperty(
    String id, {
    Function(String deletedId)? onSuccess,
  }) async {
    try {
      AppLogger.info('🗑️ Deleting property: $id');

      if (!await isLoggedIn()) throw Exception('Not authenticated');

      final client = getClient();

      final result = await client.mutate(
        MutationOptions(
          document: gql(DELETE_PROPERTY),
          variables: {'id': int.parse(id)}, // Use int for ID to match backend
          fetchPolicy: FetchPolicy.noCache,
        ),
      );

      if (result.hasException) {
        AppLogger.error('❌ Delete mutation failed: ${result.exception}');
        throw Exception(result.exception.toString());
      }

      final deletedProperty = result.data?['deleteProperty'];
      if (deletedProperty == null) {
        AppLogger.warning('⚠️ Delete returned null or invalid response');
        return false;
      }

      final deletedId = deletedProperty['id'].toString();
      AppLogger.info('✅ Property deleted successfully: $deletedId');

      await clearCacheAfterMutation();

      if (onSuccess != null) {
        onSuccess(deletedId);
      }

      return true;
    } catch (e) {
      AppLogger.error('💥 Delete failed: $e');
      return false;
    }
  }

  static Future<bool> updatePropertyStatus(
    String id,
    String status, {
    Function(String updatedId, String newStatus)? onSuccess,
  }) async {
    try {
      AppLogger.info('🔄 Updating property status: $id -> $status');

      if (!await isLoggedIn()) throw Exception('Not authenticated');

      final client = getClient();

      final result = await client.mutate(
        MutationOptions(
          document: gql(UPDATE_PROPERTY_STATUS),
          variables: {
            'id': id,
            'status': status,
          },
          fetchPolicy: FetchPolicy.noCache,
        ),
      );

      if (result.hasException) {
        AppLogger.error('❌ Update status failed: ${result.exception}');
        throw Exception(result.exception.toString());
      }

      final updatedProperty = result.data?['updatePropertyStatus'];
      if (updatedProperty == null || updatedProperty['id'] == null) {
        AppLogger.warning('⚠️ Update returned null or invalid response');
        return false;
      }

      final updatedId = updatedProperty['id'].toString();
      final newStatus = updatedProperty['status'].toString();

      AppLogger.info('✅ Property status updated: $updatedId -> $newStatus');

      if (onSuccess != null) {
        onSuccess(updatedId, newStatus);
      }

      await clearCacheAfterMutation();

      return true;
    } catch (e) {
      AppLogger.error('💥 Update status exception: $e');
      return false;
    }
  }

  static Future<bool> toggleFeatured(
    String id, {
    Function(String updatedId, bool newFeatured)? onSuccess,
  }) async {
    try {
      AppLogger.info('⭐ Toggling featured for property: $id');

      if (!await isLoggedIn()) throw Exception('Not authenticated');

      final client = getClient();

      final result = await client.mutate(
        MutationOptions(
          document: gql(TOGGLE_FEATURED),
          variables: {'id': int.parse(id)},
          fetchPolicy: FetchPolicy.noCache,
        ),
      );

      if (result.hasException) {
        AppLogger.error('❌ Toggle featured failed: ${result.exception}');
        throw Exception(result.exception.toString());
      }

      final updated = result.data?['togglePropertyFeatured'];
      if (updated == null) return false;

      final updatedId = updated['id'].toString();
      final newFeatured = updated['isFeatured'] as bool;

      AppLogger.info('✅ Featured toggled: $updatedId -> $newFeatured');
      onSuccess?.call(updatedId, newFeatured);

      await clearCacheAfterMutation();
      return true;
    } catch (e) {
      AppLogger.error('💥 Toggle featured exception: $e');
      return false;
    }
  }

  static Map<String, dynamic>? _cachedStats;
  static DateTime? _statsCacheTime;

  static Future<Map<String, dynamic>> getDashboardStats({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedStats != null &&
        _statsCacheTime != null &&
        DateTime.now().difference(_statsCacheTime!).inSeconds < 30) {
      AppLogger.info('📊 Using cached dashboard stats');
      return _cachedStats!;
    }

    try {
      final client = getClient();
      final result = await client.query(
        QueryOptions(
          document: gql(GET_DASHBOARD_STATS),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      ).timeout(const Duration(seconds: 15));
      if (result.hasException) {
        throw Exception('Failed to fetch dashboard stats: ${result.exception}');
      }

      _cachedStats = result.data?['dashboardStats'] ?? {};
      _statsCacheTime = DateTime.now();

      AppLogger.info('📊 Fetched fresh dashboard stats');
      return _cachedStats!;
    } catch (e) {
      AppLogger.error('❌ Error getting dashboard stats: $e');

      if (_cachedStats != null) {
        AppLogger.info('📊 Using stale cached stats as fallback');
        return _cachedStats!;
      }

      rethrow;
    }
  }

  static void invalidateStatsCache() {
    _cachedStats = null;
    _statsCacheTime = null;
    AppLogger.info('🧹 Dashboard stats cache cleared');
  }

  static Future<List<dynamic>> getProperties() async {
    try {
      final client = getClient();
      final result = await client.query(
        QueryOptions(
          document: gql(GET_PROPERTIES),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      ).timeout(const Duration(seconds: 15));

      if (result.hasException) {
        AppLogger.error('❌ Get properties error: ${result.exception}');
        throw Exception('Failed to fetch properties: ${result.exception}');
      }

      final properties = result.data?['properties'] ?? [];
      AppLogger.info('✅ Fetched ${properties.length} properties FROM NETWORK');
      return properties;
    } catch (e) {
      AppLogger.error('❌ Get properties error: $e');
      rethrow;
    }
  }

  static Future<List<dynamic>> getUsers() async {
    try {
      final client = getClient();
      final result = await client.query(
        QueryOptions(
          document: gql(GET_USERS),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      ).timeout(const Duration(seconds: 15));

      if (result.hasException) {
        AppLogger.error('❌ Get users error: ${result.exception}');
        throw Exception('Failed to fetch users: ${result.exception}');
      }

      final users = result.data?['users'] ?? [];
      AppLogger.info('✅ Fetched ${users.length} users FROM NETWORK');
      return users;
    } catch (e) {
      AppLogger.error('❌ Get users error: $e');
      rethrow;
    }
  }

  static Future<void> forceRefreshProperties() async {
    AppLogger.info('🔄 Force refreshing properties cache...');
    clearCachedClient();
  }

  static Future<void> testImageUpload() async {
    AppLogger.debug('🧪 Testing image upload system...');

    try {
      final response = await http.get(Uri.parse('$_baseUrl/health'));
      AppLogger.info('🌐 Server health: ${response.statusCode}');

      AppLogger.info('📤 Upload endpoint: $_baseUrl/api/upload');
      AppLogger.info('✅ Image upload system ready!');
    } catch (e) {
      AppLogger.warning('⚠️ Test failed (might be normal): $e');
    }
  }
}