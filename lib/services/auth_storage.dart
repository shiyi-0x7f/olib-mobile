import '../services/hive_service.dart';

class AuthStorage {
  static const String _keyUserId = 'remix_userid';
  static const String _keyUserKey = 'remix_userkey';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserName = 'user_name';
  static const String _keyUserPassword = 'user_password';

  static const String _keyAccounts = 'saved_accounts';

  /// Save authentication credentials
  Future<void> saveCredentials({
    required String userId,
    required String userKey,
    String? email,
    String? name,
    String? password,
  }) async {
    final box = HiveService.authBox;
    await box.put(_keyUserId, userId);
    await box.put(_keyUserKey, userKey);
    if (email != null) await box.put(_keyUserEmail, email);
    if (name != null) await box.put(_keyUserName, name);
    if (password != null) await box.put(_keyUserPassword, password);

    // Also save to accounts list
    await saveAccount({
      'userId': userId,
      'userKey': userKey,
      'email': email,
      'name': name,
      'password': password,
    });
  }

  /// Retrieve stored credentials
  Future<Map<String, String?>> getCredentials() async {
    final box = HiveService.authBox;
    return {
      'userId': box.get(_keyUserId),
      'userKey': box.get(_keyUserKey),
      'email': box.get(_keyUserEmail),
      'name': box.get(_keyUserName),
      'password': box.get(_keyUserPassword),
    };
  }

  /// Check if credentials are stored
  Future<bool> hasStoredCredentials() async {
    final box = HiveService.authBox;
    return box.containsKey(_keyUserId) && box.containsKey(_keyUserKey);
  }

  /// Clear all stored credentials
  Future<void> clearCredentials() async {
    final box = HiveService.authBox;
    await box.delete(_keyUserId);
    await box.delete(_keyUserKey);
    await box.delete(_keyUserEmail);
    await box.delete(_keyUserName);
    await box.delete(_keyUserPassword);
  }

  /// Save an account to the list
  Future<void> saveAccount(Map<String, dynamic> account) async {
    final box = HiveService.authBox;
    final List<dynamic> accounts = box.get(_keyAccounts, defaultValue: []);
    final existingIndex = accounts.indexWhere((a) => a['userId'] == account['userId']);
    
    if (existingIndex != -1) {
      accounts[existingIndex] = account;
    } else {
      accounts.add(account);
    }
    await box.put(_keyAccounts, accounts);
  }

  /// Get all stored accounts
  Future<List<Map<dynamic, dynamic>>> getStoredAccounts() async {
    final box = HiveService.authBox;
    final List<dynamic> rawList = box.get(_keyAccounts, defaultValue: []);
    // Cast to List<Map> safely
    return rawList.map((e) => Map<dynamic, dynamic>.from(e as Map)).toList();
  }

  /// Remove an account
  Future<void> removeAccount(String userId) async {
    final box = HiveService.authBox;
    final List<dynamic> accounts = box.get(_keyAccounts, defaultValue: []);
    accounts.removeWhere((a) => a['userId'] == userId);
    await box.put(_keyAccounts, accounts);
  }
}
