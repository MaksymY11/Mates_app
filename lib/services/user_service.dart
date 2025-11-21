import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class User {
  final String id;
  final String email;
  final String name;
  final int? age;
  final String? state;
  final String? city;
  final int? budget;
  final DateTime? move_in_date;
  final String? bio;
  final List<String>? lifestyle;
  final List<String>? activities;
  final List<String>? prefs;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.age,
    this.state,
    this.city,
    this.budget,
    this.move_in_date,
    this.bio,
    this.lifestyle,
    this.activities,
    this.prefs,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'].toString(),
    email: j['email'] ?? '',
    name: j['name'] ?? '',
    age: j['age'],
    state: j['state'],
    city: j['city'],
    budget: j['budget'],
    move_in_date:
        j['move_in_date'] != null ? DateTime.parse(j['move_in_date']) : null,
    bio: j['bio'],
    lifestyle: (j['lifestyle'] as List?)?.map((e) => e.toString()).toList(),
    activities: (j['activities'] as List?)?.map((e) => e.toString()).toList(),
    prefs: (j['prefs'] as List?)?.map((e) => e.toString()).toList(),
  );

  Map<String, dynamic> toUpdatePayload() => {
    'name': name,
    if (age != null) 'age': age,
    if (state != null) 'state': state,
    if (city != null) 'city': city,
    if (budget != null) 'budget': budget,
    if (move_in_date != null) 'move_in_date': move_in_date!.toIso8601String(),
    if (bio != null) 'bio': bio,
    if (lifestyle != null) 'lifestyle': lifestyle,
    if (activities != null) 'activities': activities,
    if (prefs != null) 'prefs': prefs,
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
    String? state,
    String? city,
    int? budget,
    DateTime? move_in_date,
    String? bio,
    List<String>? lifestyle,
    List<String>? activities,
    List<String>? prefs,
  }) async {
    final token = await _token();
    final body = {
      'name': name,
      if (age != null) 'age': age,
      if (state != null) 'state': state,
      if (city != null) 'city': city,
      if (budget != null) 'budget': budget,
      if (move_in_date != null) 'move_in_date': move_in_date.toIso8601String(),
      if (bio != null) 'bio': bio,
      if (lifestyle != null) 'lifestyle': lifestyle,
      if (activities != null) 'activities': activities,
      if (prefs != null) 'prefs': prefs,
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
