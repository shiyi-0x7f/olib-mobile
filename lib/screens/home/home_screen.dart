import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import '../../providers/books_provider.dart';
import '../../providers/weread_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/backend_auth_provider.dart';
import '../../services/update_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/book_card.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/domain_selector.dart';
import '../../models/display_book.dart';
import '../../routes/app_routes.dart';
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          elevation: 0,
          backgroundColor: cs.surface,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: cs.primary,
          unselectedItemColor: cs.onSurfaceVariant,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
          showUnselectedLabels: true,
          onTap: (index) {
            if (index == 1) {
              Navigator.of(context).pushNamed(AppRoutes.search);
            } else if (index == 2) {
              Navigator.of(context).pushNamed(AppRoutes.wereadHome);
            } else if (index == 3) {
              Navigator.of(context).pushNamed(AppRoutes.favorites);
            } else if (index == 4) {
              Navigator.of(context).pushNamed(AppRoutes.downloads);
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
              icon: const Icon(Icons.menu_book_outlined),
              activeIcon: const Icon(Icons.menu_book),
              label: AppLocalizations.of(context).get('weread'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.library_books_outlined),
              activeIcon: const Icon(Icons.library_books),
              label: AppLocalizations.of(context).get('bookshelf'),
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

  /// 寻书入口：未授权先弹扫码授权页，授权成功才允许进寻书页。
  /// 把校验放在入口（而非进入寻书页后）的好处：
  /// 1) 用户路径更清晰——授权 ≡ 进入功能；
  /// 2) 寻书页内部的防御性 _ensureAuthorized 是兜底，正常路径不会再触发；
  /// 3) 避免未授权状态下泄露任何 UI 引诱用户点击。
  Future<void> _openPrescriber() async {
    final isAuthorized = ref.read(backendAuthProvider).isAuthorized;
    if (isAuthorized) {
      Navigator.of(context).pushNamed(AppRoutes.prescriber);
      return;
    }

    final result = await Navigator.of(context).pushNamed(AppRoutes.qrAuth);
    if (!mounted) return;
    if (result == true) {
      Navigator.of(context).pushNamed(AppRoutes.prescriber);
    }
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
    final cs = theme.colorScheme;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';

    return Column(
      children: [
        if (authState.lineUnavailable) _buildLineUnavailableBanner(context, isZh),
        // ========== 固定头部区域 ==========
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withValues(alpha:0.05),
                theme.scaffoldBackgroundColor,
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
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
                              color: cs.onSurfaceVariant,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.name ?? (isZh ? '读者' : 'Reader'),
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: cs.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha:0.05),
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
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Search Bar Trigger
                  GestureDetector(
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.search),
                    child: Container(
                      height: 54,
                      padding: const EdgeInsets.only(left: 20, right: 8),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha:0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: cs.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context).get('search_for_books'),
                              style: TextStyle(
                                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 寻书入口（AI 推荐）— 入口处先校验授权，未授权直接走扫码
                  GestureDetector(
                    onTap: _openPrescriber,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha:0.9),
                            AppColors.primary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha:0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha:0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  Localizations.localeOf(context).languageCode == 'zh'
                                      ? '不知道读什么？'
                                      : "Don't know what to read?",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  Localizations.localeOf(context).languageCode == 'zh'
                                      ? '让 AI 帮你寻书 ✨'
                                      : 'Let AI find books for you ✨',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha:0.85),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white.withValues(alpha:0.7),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 推荐书籍标题
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: AppColors.primary, size: 22),
                      const SizedBox(width: 6),
                      Text(
                        Localizations.localeOf(context).languageCode == 'zh'
                            ? '为你推荐'
                            : 'Recommended',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ========== 可滚动书籍网格 ==========
        Expanded(
          child: _buildBookGrid(ref.watch(homeRecommendedProvider)),
        ),
      ],
    );
  }

  Widget _buildLineUnavailableBanner(BuildContext context, bool isZh) {
    return Material(
      color: Colors.orange.shade50,
      child: InkWell(
        // DomainNotifier.setDomain handles reverify + cache invalidation
        // internally, so just opening the picker is enough.
        onTap: () => showDialog(
          context: context,
          builder: (_) => const DomainSelectionDialog(),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.cloud_off_outlined,
                    color: Colors.orange.shade800, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isZh ? '当前线路不可用' : 'Current line unavailable',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        isZh
                            ? '已使用缓存登录信息，点此切换线路'
                            : 'Using cached login. Tap to switch line.',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: Colors.orange.shade700, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookGrid(AsyncValue<List<DisplayBook>> booksAsync) {
    return booksAsync.when(
      data: (books) {
        if (books.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(40.0),
            child: EmptyState(
              icon: Icons.book_outlined,
              title: 'No books found',
            ),
          );
        }

        final notifier = ref.read(wereadRecommendProvider.notifier);
        final hasMore = notifier.hasMore;
        // +1 for loading indicator at bottom
        final itemCount = books.length + (hasMore ? 1 : 0);

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            childAspectRatio: 0.62,
            crossAxisSpacing: 16,
            mainAxisSpacing: 20,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            // 预加载：距底部 6 个时触发
            if (index >= books.length - 6 && hasMore) {
              notifier.loadMore();
            }

            // 加载指示器
            if (index >= books.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final book = books[index];
            return BookCard(
              book: book,
              onTap: () {
                if (book.isWeread) {
                  Navigator.of(context).pushNamed(
                    AppRoutes.wereadBookDetail,
                    arguments: book.id,
                  );
                } else {
                  Navigator.of(context).pushNamed(
                    AppRoutes.bookDetail,
                    arguments: book.asZLibBook,
                  );
                }
              },
            );
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: LoadingWidget(message: 'Loading trending books...'),
      ),
      error: (error, stack) => const Padding(
        padding: EdgeInsets.all(20),
        child: EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load books',
          message: 'Please check your connection',
        ),
      ),
    );
  }

}