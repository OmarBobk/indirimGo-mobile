class MobileUser {
  const MobileUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.phone,
    required this.countryCode,
    required this.locale,
    required this.preferredCurrency,
    required this.timezone,
    required this.profilePhotoUrl,
    required this.emailVerifiedAt,
  });

  factory MobileUser.fromJson(Map<String, Object?> json) {
    for (final field in _requiredFields) {
      if (!json.containsKey(field)) {
        throw FormatException('Missing required user field: $field');
      }
    }

    final locale = _requiredString(json, 'locale');
    if (locale != 'ar' && locale != 'en') {
      throw const FormatException('User locale must be ar or en.');
    }

    return MobileUser(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      username: _requiredString(json, 'username'),
      email: _requiredString(json, 'email'),
      phone: _nullableString(json, 'phone'),
      countryCode: _nullableString(json, 'country_code'),
      locale: locale,
      preferredCurrency: _requiredString(json, 'preferred_currency'),
      timezone: _nullableString(json, 'timezone'),
      profilePhotoUrl: _nullableUri(json, 'profile_photo_url'),
      emailVerifiedAt: _nullableDateTime(json, 'email_verified_at'),
    );
  }

  static const _requiredFields = {
    'id',
    'name',
    'username',
    'email',
    'phone',
    'country_code',
    'locale',
    'preferred_currency',
    'timezone',
    'profile_photo_url',
    'email_verified_at',
  };

  final int id;
  final String name;
  final String username;
  final String email;
  final String? phone;
  final String? countryCode;
  final String locale;
  final String preferredCurrency;
  final String? timezone;
  final Uri? profilePhotoUrl;
  final DateTime? emailVerifiedAt;
}

class AuthToken {
  const AuthToken({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
  });

  factory AuthToken.fromJson(Map<String, Object?> json) {
    final tokenType = _requiredString(json, 'token_type');
    if (tokenType != 'Bearer') {
      throw const FormatException('Unsupported token type.');
    }
    return AuthToken(
      accessToken: _requiredString(json, 'access_token'),
      tokenType: tokenType,
      expiresAt: _requiredDateTime(json, 'expires_at'),
    );
  }

  final String accessToken;
  final String tokenType;
  final DateTime expiresAt;
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  factory AuthSession.fromJson(Map<String, Object?> json) {
    final data = _requiredMap(json, 'data');
    return AuthSession(
      token: AuthToken.fromJson(_requiredMap(data, 'token')),
      user: MobileUser.fromJson(_requiredMap(data, 'user')),
    );
  }

  final AuthToken token;
  final MobileUser user;
}

class TwoFactorChallenge {
  const TwoFactorChallenge({required this.token, required this.expiresAt});

  factory TwoFactorChallenge.fromJson(Map<String, Object?> json) {
    final data = _requiredMap(json, 'data');
    if (data['two_factor_required'] != true) {
      throw const FormatException('Expected a two-factor challenge.');
    }
    return TwoFactorChallenge(
      token: _requiredString(data, 'challenge_token'),
      expiresAt: _requiredDateTime(data, 'expires_at'),
    );
  }

  final String token;
  final DateTime expiresAt;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());
}

sealed class LoginOutcome {
  const LoginOutcome();
}

class LoginAuthenticated extends LoginOutcome {
  const LoginAuthenticated(this.session);

  final AuthSession session;
}

class LoginTwoFactorRequired extends LoginOutcome {
  const LoginTwoFactorRequired(this.challenge);

  final TwoFactorChallenge challenge;
}

Map<String, Object?> _requiredMap(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((mapKey, mapValue) => MapEntry('$mapKey', mapValue));
  }
  throw FormatException('$key must be an object.');
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('$key must be a non-empty string.');
}

String? _nullableString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw FormatException('$key must be a string or null.');
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('$key must be an integer.');
}

DateTime _requiredDateTime(Map<String, Object?> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('$key must be an ISO-8601 date-time.');
  }
  return parsed.toUtc();
}

DateTime? _nullableDateTime(Map<String, Object?> json, String key) {
  if (json[key] == null) {
    return null;
  }
  return _requiredDateTime(json, key);
}

Uri? _nullableUri(Map<String, Object?> json, String key) {
  final value = _nullableString(json, key);
  if (value == null) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.isAbsolute ||
      !const {'http', 'https'}.contains(uri.scheme)) {
    throw FormatException('$key must be an absolute HTTP(S) URL.');
  }
  return uri;
}
