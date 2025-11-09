import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class User {
  final String id;
  final String email;
  final String name;
  final int? age;
  final String? city;
  final String? bio;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.age,
    this.city,
    this.bio,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'].toString(),
    email: j['email'] ?? '',
    name: j['name'] ?? '',
    age: j['age'],
    city: j['city'],
    bio: j['bio'],
  );

  Map<String, dynamic> toUpdatePayload() => {
    'name': name,
    if (age != null) 'age': age,
    if (city != null) 'city': city,
    if (bio != null) 'bio': bio,
  };
}

class UserService {
  static const String baseUrl =
      'https://mates-backend-dxma.onrender.com'; // keep in sync with AuthService

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<User> getMe() async {
    final token = await _token();
    final res = await http.get(
      Uri.parse('$baseUrl/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      return User.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load profile: ${res.body}');
  }

  static Future<User> updateMe({
    required String name,
    int? age,
    String? city,
    String? bio,
  }) async {
    final token = await _token();
    final body = {
      'name': name,
      if (age != null) 'age': age,
      if (city != null) 'city': city,
      if (bio != null) 'bio': bio,
    };
    final res = await http.post(
      Uri.parse('$baseUrl/updateUser'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      return User.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to update profile: ${res.body}');
  }
}
