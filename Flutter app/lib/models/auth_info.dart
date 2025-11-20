// lib/models/auth_info.dart

enum ApiProvider { openRouter, vseGPT }

class AuthInfo {
  final int id;
  final String apiKey;
  final ApiProvider provider;
  final String pinHash; // храним не сам PIN, а хэш
  final DateTime createdAt;

  AuthInfo({
    required this.id,
    required this.apiKey,
    required this.provider,
    required this.pinHash,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'api_key': apiKey,
      'provider': provider == ApiProvider.openRouter ? 'openrouter' : 'vsegpt',
      'pin_hash': pinHash,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AuthInfo.fromMap(Map<String, dynamic> map) {
    return AuthInfo(
      id: map['id'] as int,
      apiKey: map['api_key'] as String,
      provider: (map['provider'] as String) == 'openrouter'
          ? ApiProvider.openRouter
          : ApiProvider.vseGPT,
      pinHash: map['pin_hash'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
