import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../services/update_service.dart';
import '../../widgets/domain_selector.dart';
import '../../l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Check for updates after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    final hasUpdate = await UpdateService.checkForUpdate(force: true);
    
    if (!hasUpdate || !mounted) return;
    
    final locale = Localizations.localeOf(context).languageCode;
    final isZh = locale == 'zh';
    final changelog = UpdateService.getChangelog(isZh ? 'zh' : 'en');
    
    if (UpdateService.forceUpdate) {
      // Set blocked flag
      UpdateService.isBlocked = true;
      
      // Force update - show warning dialog
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        animType: AnimType.bottomSlide,
        dismissOnTouchOutside: false,
        dismissOnBackKeyPress: false,
        title: isZh ? '必须更新' : 'Update Required',
        desc: isZh 
            ? '发现新版本 ${UpdateService.latestVersion}\n\n$changelog\n\n当前版本已不可用，搜索和下载功能已禁用。'
            : 'New version ${UpdateService.latestVersion}\n\n$changelog\n\nThis version is no longer supported. Search and download are disabled.',
        btnOkText: isZh ? '立即更新' : 'Update Now',
        btnOkColor: AppColors.primary,
        btnOkOnPress: () {
          if (UpdateService.downloadUrl != null) {
            launchUrl(
              Uri.parse(UpdateService.downloadUrl!),
              mode: LaunchMode.externalApplication,
            );
          }
        },
      ).show();
    } else {
      // Normal update - just show info snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isZh 
                ? '发现新版本 ${UpdateService.latestVersion}' 
                : 'New version ${UpdateService.latestVersion} available',
          ),
          action: SnackBarAction(
            label: isZh ? '更新' : 'Update',
            onPressed: () {
              if (UpdateService.downloadUrl != null) {
                launchUrl(
                  Uri.parse(UpdateService.downloadUrl!),
                  mode: LaunchMode.externalApplication,
                );
              }
            },
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } else if (mounted) {
      final error = ref.read(authProvider).error;
      final locale = Localizations.localeOf(context).languageCode;
      final isZh = locale == 'zh';
      
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.bottomSlide,
        title: isZh ? '登录失败' : 'Login Failed',
        desc: isZh ? '用户未注册或账号密码错误' : 'User not registered or incorrect credentials',
        btnOkText: isZh ? '确定' : 'OK',
        btnOkColor: AppColors.primary,
        btnOkOnPress: () {},
      ).show();
    }
  }

  void _showSavedAccounts() async {
    final accounts = await ref.read(authProvider.notifier).getSavedAccounts();
    
    if (!mounted) return;
    
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved accounts found')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Switch Account',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: accounts.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  final name = account['name'] ?? 'Unknown';
                  final email = account['email'] ?? 'No Email';
                  
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(name[0].toUpperCase()),
                    ),
                    title: Text(name),
                    subtitle: Text(email),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () {
                         ref.read(authProvider.notifier).removeAccount(account['userId'].toString());
                         Navigator.pop(context);
                         _showSavedAccounts(); // Refresh
                      },
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _switchAccount(Map<String, dynamic>.from(account));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchAccount(Map<String, dynamic> account) async {
    setState(() => _isLoading = true);
    
    final success = await ref.read(authProvider.notifier).switchAccount(account);
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to switch account')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.isAuthenticated && !next.isLoading) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline, color: Colors.white),
            onPressed: _showSavedAccounts,
            tooltip: 'Switch Account',
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: DomainSelector(compact: true, color: Colors.white),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.primary,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.book,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Text(
                    AppLocalizations.of(context).get('welcome_back'),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    AppLocalizations.of(context).get('login_to_continue'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Open Source & Free badges
                  _buildBadges(context),
                  
                  const SizedBox(height: 32),
                  
                  // Login Form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context).get('email'),
                              prefixIcon: const Icon(Icons.email_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context).get('password'),
                              prefixIcon: const Icon(Icons.lock_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 32),
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(AppLocalizations.of(context).get('login')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Hint: Use Z-Library official account
                  _buildAccountHint(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAccountHint(BuildContext context) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.white.withOpacity(0.8),
                size: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isZh 
                      ? '请使用 Z-Library 官网账号登录'
                      : 'Please login with your Z-Library account',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isZh 
                ? '没有账号？请自行前往官网注册，本软件不提供注册方式。'
                : "No account? Please register on official site. This app doesn't provide registration.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildBadges(BuildContext context) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildBadge(
          icon: Icons.code,
          text: isZh ? '开源' : 'Open Source',
          color: Colors.green,
        ),
        _buildBadge(
          icon: Icons.money_off,
          text: isZh ? '免费' : 'Free',
          color: Colors.blue,
        ),
        _buildBadge(
          icon: Icons.smart_toy_outlined,
          text: isZh ? 'AI构建' : 'AI-Built',
          color: Colors.purple,
        ),
      ],
    );
  }
  
  Widget _buildBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
