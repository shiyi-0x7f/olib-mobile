enum LoginFailureKind { credentials, line, unknown }

String safeLoginErrorDetail(String? error, String email, String password) {
  if (error == null || error.trim().isEmpty) {
    return '无错误详情 / No error details returned';
  }

  var detail = error.trim();
  if (password.isNotEmpty) detail = detail.replaceAll(password, '[redacted]');
  if (email.isNotEmpty) detail = detail.replaceAll(email, '[redacted]');
  detail = detail.replaceAll(
    RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
    '[redacted email]',
  );
  detail = detail.replaceAll(
    RegExp(r'\bBearer\s+\S+', caseSensitive: false),
    'Bearer [redacted]',
  );
  detail = detail.replaceAllMapped(
    RegExp(
      r'''((?:password|passwd|token|secret|authorization|cookie|remix_userkey|remix_userid|userkey|userid)["']?\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s,;}\]]+)''',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}[redacted]',
  );
  detail = detail.replaceAll(
    RegExp(r'https?://[^\s]+', caseSensitive: false),
    '[URL redacted]',
  );

  return detail.length > 300 ? '${detail.substring(0, 300)}…' : detail;
}

LoginFailureKind classifyLoginFailure(String? error) {
  if (error == null || error.trim().isEmpty) {
    return LoginFailureKind.unknown;
  }

  final value = error.toLowerCase();
  if (value.contains('cf_blocked') ||
      value.contains('line_error') ||
      value.contains('timeout') ||
      value.contains('socket') ||
      value.contains('connection') ||
      value.contains('network') ||
      value.contains('handshake') ||
      value.contains('unreachable') ||
      value.contains('failed host lookup') ||
      value.contains('request failed')) {
    return LoginFailureKind.line;
  }

  final normalized = value.replaceAll('_', ' ');
  const credentialMessages = [
    'incorrect email or password',
    'invalid email or password',
    'email or password is incorrect',
    'incorrect password',
    'invalid password',
    'wrong password',
    'incorrect credentials',
    'invalid credentials',
    'user not found',
    'user not registered',
    'account not found',
  ];
  if (credentialMessages.any(normalized.contains) ||
      value.contains('账号或密码错误') ||
      value.contains('账号密码错误') ||
      value.contains('邮箱或密码错误') ||
      value.contains('用户未注册')) {
    return LoginFailureKind.credentials;
  }

  return LoginFailureKind.unknown;
}
