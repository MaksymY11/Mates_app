import 'api_service.dart';

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
}

class UserService {
  static Future<User> getMe() async {
    final j = await ApiService.get('/me');
    return User.fromJson(j);
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
    final j = await ApiService.post('/updateUser', body: body);
    return User.fromJson(j);
  }
}
