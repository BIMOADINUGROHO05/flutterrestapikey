import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'usermodel.dart';

/// Error dari API dengan pesan yang mudah dipahami pengguna.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class UserService {
  static const String _baseUrl = 'https://reqres.in/api';

  /// Isi dengan API key dari https://reqres.in bila server menolak (403).
  static const String apiKey = '';
  static const Duration _timeout = Duration(seconds: 15);

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (apiKey.isNotEmpty) 'x-api-key': apiKey,
  };

  /// READ - GET /users
  Future<List<UserModel>> getUsers({int page = 1}) async {
    final response = await _send(
          () => http.get(
        Uri.parse('$_baseUrl/users?page=$page&per_page=12'),
        headers: _headers,
      ),
    );
    _ensureStatus(response, const [200]);

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['data'] as List)
          .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw ApiException('Format data dari server tidak dikenali.');
    }
  }

  /// CREATE - POST /users
  Future<UserModel> createUser({
    required String firstName,
    required String lastName,
    required String email,
    required String job,
  }) async {
    final response = await _send(
          () => http.post(
        Uri.parse('$_baseUrl/users'),
        headers: _headers,
        body: jsonEncode({
          'name': '$firstName $lastName'.trim(),
          'job': job,
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
        }),
      ),
    );
    _ensureStatus(response, const [200, 201]);

    int? id;
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      id = int.tryParse('${json['id']}');
    } catch (_) {}

    return UserModel(
      id: id,
      email: email,
      firstName: firstName,
      lastName: lastName,
    );
  }

  /// UPDATE - PUT /users/{id}
  Future<void> updateUser(UserModel user, {String job = ''}) async {
    final response = await _send(
          () => http.put(
        Uri.parse('$_baseUrl/users/${user.id}'),
        headers: _headers,
        body: jsonEncode({
          'name': user.fullName,
          'job': job,
          'first_name': user.firstName,
          'last_name': user.lastName,
          'email': user.email,
        }),
      ),
    );
    _ensureStatus(response, const [200]);
  }

  /// DELETE - DELETE /users/{id}
  Future<void> deleteUser(int id) async {
    final response = await _send(
          () => http.delete(Uri.parse('$_baseUrl/users/$id'), headers: _headers),
    );
    _ensureStatus(response, const [200, 204]);
  }

  // ------------------------------------------------------------ helper
  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('Server tidak merespons. Coba lagi sebentar lagi.');
    } catch (_) {
      throw ApiException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet kamu.',
      );
    }
  }

  void _ensureStatus(http.Response response, List<int> okCodes) {
    if (okCodes.contains(response.statusCode)) return;
    final code = response.statusCode;
    if (code == 401 || code == 403) {
      throw ApiException(
        'Akses ditolak server (kode $code). Isi API key reqres.in pada '
            'konstanta apiKey di userservice.dart.',
        statusCode: code,
      );
    }
    throw ApiException(
      'Permintaan gagal (kode $code).',
      statusCode: code,
    );
  }
}
