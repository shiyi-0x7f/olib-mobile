import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../providers/domain_provider.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String _statusText = '';
  bool _networkOk = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Step 1: Check network
    setState(() => _statusText = 'Checking network...');
    _networkOk = await _checkNetwork();
    
    if (!_networkOk) {
      setState(() => _statusText = 'Network unavailable, retrying...');
      await Future.delayed(const Duration(seconds: 2));
      _networkOk = await _checkNetwork();
    }

    // Step 2: Wait for auth state
    setState(() => _statusText = 'Loading...');
    await _waitForAuth();
  }

  Future<bool> _checkNetwork() async {
    try {
      final domain = ref.read(domainProvider);
      final uri = Uri.parse('https://$domain/');
      
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      
      try {
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(
          const Duration(seconds: 8),
        );
        await response.drain();
        return response.statusCode >= 200 && response.statusCode < 400;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Network check failed: $e');
      return false;
    }
  }

  Future<void> _waitForAuth() async {
    // Wait for auth state to finish loading (max 10 seconds)
    int attempts = 0;
    while (mounted && attempts < 20) {
      final authState = ref.read(authProvider);
      if (!authState.isLoading) {
        // Auth finished loading
        if (authState.isAuthenticated) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        } else {
          Navigator.of(context).pushReplacementNamed(AppRoutes.login);
        }
        return;
      }
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
    }

    // Timeout - go to login
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.primary,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.book,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              Text(
                'Olib',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 16),
              // Status indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _networkOk ? Colors.greenAccent : Colors.white54,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _statusText,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
