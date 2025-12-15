import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import '../../providers/books_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/update_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/book_card.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state.dart';
import '../../routes/app_routes.dart';
import '../../models/book.dart';
import '../../l10n/app_localizations.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const _HomeTab(),
    // These are placeholders as navigation is handled via pushNamed
    const SizedBox(),
    const SizedBox(),
    const SizedBox(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          elevation: 0,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
          showUnselectedLabels: true,
          onTap: (index) {
            if (index == 1) {
              Navigator.of(context).pushNamed(AppRoutes.search);
            } else if (index == 2) {
              Navigator.of(context).pushNamed(AppRoutes.favorites);
            } else if (index == 3) {
              Navigator.of(context).pushNamed(AppRoutes.downloads); // Local downloads
            } else {
              setState(() => _selectedIndex = index);
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: AppLocalizations.of(context).get('home'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.search_outlined),
              activeIcon: const Icon(Icons.search),
              label: AppLocalizations.of(context).get('search'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.favorite_border),
              activeIcon: const Icon(Icons.favorite),
              label: AppLocalizations.of(context).get('favorites'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.cloud_download_outlined),
              activeIcon: const Icon(Icons.cloud_download),
              label: AppLocalizations.of(context).get('downloads'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Get time-based greeting message
String _getGreeting(BuildContext context) {
  final hour = DateTime.now().hour;
  final locale = Localizations.localeOf(context).languageCode;
  final isZh = locale == 'zh';

  if (hour < 6) {
    return isZh ? '夜深了，' : 'Late night,';
  } else if (hour < 12) {
    return isZh ? '早上好，' : 'Good morning,';
  } else if (hour < 14) {
    return isZh ? '中午好，' : 'Good afternoon,';
  } else if (hour < 18) {
    return isZh ? '下午好，' : 'Good afternoon,';
  } else if (hour < 22) {
    return isZh ? '晚上好，' : 'Good evening,';
  } else {
    return isZh ? '夜深了，' : 'Late night,';
  }
}

class _HomeTab extends ConsumerStatefulWidget {
  const _HomeTab();

  @override
  ConsumerState<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<_HomeTab> {
  @override
  void initState() {
    super.initState();
    // Check for updates after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    final hasUpdate = await UpdateService.checkForUpdate();

    if (!hasUpdate || !mounted) return;

    final locale = Localizations.localeOf(context).languageCode;
    final isZh = locale == 'zh';
    final changelog = UpdateService.getChangelog(isZh ? 'zh' : 'en');

    if (UpdateService.forceUpdate) {
      // Set blocked flag to disable features
      UpdateService.isBlocked = true;

      // Force update - show dismissable dialog that just redirects
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
    } else if (!UpdateService.isVersionDismissed()) {
      // Normal update - show snackbar (non-intrusive)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.system_update, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isZh
                      ? '发现新版本 ${UpdateService.latestVersion}'
                      : 'New version ${UpdateService.latestVersion} available',
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: isZh ? '更新' : 'Update',
            textColor: Colors.white,
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
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 6),
          dismissDirection: DismissDirection.horizontal,
        ),
      );

      // Mark as shown (will show again next day)
      UpdateService.dismissUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        // Modern Hero Section
        SliverToBoxAdapter(
          child: Stack(
            children: [
              // Background Gradient
              Container(
                height: 380, // Taller hero
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withOpacity(0.05),
                      theme.scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),

              // Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getGreeting(context),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.name ?? "Book Lover",
                                style: theme.textTheme.displaySmall?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.settings_outlined),
                              onPressed: () {
                                Navigator.of(context).pushNamed(AppRoutes.settings);
                              },
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Search Bar Trigger
                      GestureDetector(
                        onTap: () => Navigator.of(context).pushNamed(AppRoutes.search),
                        child: Container(
                          height: 60,
                          padding: const EdgeInsets.only(left: 20, right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: AppColors.textSecondary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context).get('search_for_books'),
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              // Blue Search Button
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Icon(Icons.arrow_forward, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Segmented Control (Visual Header)
                      Row(
                        children: [
                          _buildSegmentChip(context, 'Trending', isActive: true),
                          const SizedBox(width: 12),
                          _buildSegmentChip(context, 'New Releases', isActive: false),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 16)),

        _buildBookGrid(ref.watch(recommendedBooksProvider)),

        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  Widget _buildBookGrid(AsyncValue<List<Book>> booksAsync) {
    return booksAsync.when(
      data: (books) {
        if (books.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: EmptyState(
                icon: Icons.book_outlined,
                title: 'No books found',
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.62, // Taller cards
              crossAxisSpacing: 16,
              mainAxisSpacing: 20,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final book = books[index];
                return BookCard(
                  book: book,
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.bookDetail,
                      arguments: book,
                    );
                  },
                );
              },
              childCount: books.length > 20 ? 20 : books.length,
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: LoadingWidget(message: 'Loading trending books...'),
        ),
      ),
      error: (error, stack) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load books',
            message: 'Please check your connection',
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentChip(BuildContext context, String label, {required bool isActive}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: isActive
            ? [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}