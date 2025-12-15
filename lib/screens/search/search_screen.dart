import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/books_provider.dart';
import '../../providers/zlibrary_provider.dart';
import '../../models/book.dart';
import '../../widgets/book_card.dart';
import '../../widgets/book_list_tile.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../routes/app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../constants/search_filters.dart';
import '../../theme/app_colors.dart';
import '../../services/update_service.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  SearchParams? _currentSearch;
  
  // Filter states
  bool _showFilters = false;
  String _selectedLanguage = 'all';
  String _selectedOrder = 'default';
  String _selectedExtension = 'all';
  
  // Pagination states
  List<Book> _allBooks = [];
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingMore = false;
  bool _hasSearched = false;
  bool _isListView = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreResults();
    }
  }
  
  void _loadMoreResults() {
    if (_isLoadingMore || _currentPage >= _totalPages || _currentSearch == null) return;
    
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    
    _fetchPage(_currentPage);
  }
  
  Future<void> _fetchPage(int page) async {
    final api = ref.read(zlibraryApiProvider);
    
    try {
      final response = await api.search(
        message: _searchController.text.trim(),
        languages: searchLanguages[_selectedLanguage] != null 
            ? [searchLanguages[_selectedLanguage]!] 
            : null,
        extensions: searchExtensions[_selectedExtension] != null 
            ? [searchExtensions[_selectedExtension]!] 
            : null,
        order: searchOrders[_selectedOrder],
        page: page,
        limit: 20,
      );
      
      final success = response['success'];
      if ((success == true || success == 1) && response.containsKey('books')) {
        final booksData = response['books'] as List<dynamic>;
        final newBooks = booksData.map((json) => Book.fromJson(json)).toList();
        
        // Update pagination info
        if (response.containsKey('pagination')) {
          final pagination = response['pagination'] as Map<String, dynamic>;
          _totalPages = pagination['total_pages'] ?? 1;
        }
        
        setState(() {
          if (page == 1) {
            _allBooks = newBooks;
          } else {
            _allBooks.addAll(newBooks);
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _performSearch() {
    if (_searchController.text.trim().isEmpty) return;
    
    // Check if app is blocked due to force update
    if (UpdateService.isBlocked) {
      final locale = Localizations.localeOf(context).languageCode;
      final isZh = locale == 'zh';
      
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        animType: AnimType.bottomSlide,
        title: isZh ? '功能已禁用' : 'Feature Disabled',
        desc: isZh 
            ? '当前版本已过期，请更新到最新版本后使用搜索功能。'
            : 'This version is outdated. Please update to use search.',
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
      return;
    }
    
    setState(() {
      _currentSearch = SearchParams(
        query: _searchController.text.trim(),
        languages: searchLanguages[_selectedLanguage] != null 
            ? [searchLanguages[_selectedLanguage]!] 
            : null,
        extensions: searchExtensions[_selectedExtension] != null 
            ? [searchExtensions[_selectedExtension]!] 
            : null,
        order: searchOrders[_selectedOrder],
        limit: 20,
      );
      // Reset pagination
      _allBooks = [];
      _currentPage = 1;
      _totalPages = 1;
      _hasSearched = true;
    });
    
    // Fetch first page
    _fetchPage(1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final languageNames = getLanguageDisplayNames(locale);
    final orderNames = getOrderDisplayNames(locale);
    final extensionNames = getExtensionDisplayNames(locale);
    
    return Scaffold(
      appBar: GradientAppBar(title: l10n.get('search_books')),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.get('search_for_books'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Filter toggle button
                    IconButton(
                      icon: Icon(
                        Icons.tune,
                        color: _showFilters ? AppColors.primary : null,
                      ),
                      onPressed: () {
                        setState(() {
                          _showFilters = !_showFilters;
                        });
                      },
                    ),
                    // Clear button
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _currentSearch = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          
          // Filter Panel
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildFilterPanel(languageNames, orderNames, extensionNames),
            crossFadeState: _showFilters 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),

          // Search Results
          Expanded(
            child: !_hasSearched
                ? EmptyState(
                    icon: Icons.search,
                    title: l10n.get('start_searching'),
                    message: l10n.get('enter_search_hint'),
                  )
                : _allBooks.isEmpty && !_isLoadingMore
                    ? (_currentSearch != null 
                        ? LoadingWidget(message: l10n.get('searching_books'))
                        : EmptyState(
                            icon: Icons.search_off,
                            title: l10n.get('no_results'),
                            message: l10n.get('try_different_keywords'),
                          ))
                    : _allBooks.isEmpty
                        ? EmptyState(
                            icon: Icons.search_off,
                            title: l10n.get('no_results'),
                            message: l10n.get('try_different_keywords'),
                          )
                        : Column(
                            children: [
                              // Pagination info and view toggle
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${_allBooks.length} ${l10n.get('books_found')}',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          ' $_currentPage / $_totalPages${l10n.get('page')}',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // View mode toggle button
                                        IconButton(
                                          icon: Icon(
                                            _isListView ? Icons.grid_view_rounded : Icons.view_list_rounded,
                                            color: AppColors.primary,
                                            size: 22,
                                          ),
                                          tooltip: _isListView ? l10n.get('grid_view') : l10n.get('list_view'),
                                          onPressed: () {
                                            setState(() {
                                              _isListView = !_isListView;
                                            });
                                          },
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Results - Grid or List view
                              Expanded(
                                child: _isListView
                                    ? ListView.builder(
                                        controller: _scrollController,
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        itemCount: _allBooks.length + (_isLoadingMore ? 1 : 0),
                                        itemBuilder: (context, index) {
                                          if (index >= _allBooks.length) {
                                            return const Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(16),
                                                child: CircularProgressIndicator(),
                                              ),
                                            );
                                          }
                                          final book = _allBooks[index];
                                          return BookListTile(
                                            book: book,
                                            onTap: () {
                                              Navigator.of(context).pushNamed(
                                                AppRoutes.bookDetail,
                                                arguments: book,
                                              );
                                            },
                                          );
                                        },
                                      )
                                    : GridView.builder(
                                        controller: _scrollController,
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          childAspectRatio: 0.65,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                        ),
                                        itemCount: _allBooks.length + (_isLoadingMore ? 1 : 0),
                                        itemBuilder: (context, index) {
                                          // Loading indicator at the end
                                          if (index >= _allBooks.length) {
                                            return const Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(16),
                                                child: CircularProgressIndicator(),
                                              ),
                                            );
                                          }
                                          
                                          final book = _allBooks[index];
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
                                      ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterPanel(
    Map<String, String> languageNames,
    Map<String, String> orderNames,
    Map<String, String> extensionNames,
  ) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context).languageCode;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First row: Language and Order dropdowns
          Row(
            children: [
              Expanded(
                child: _buildDropdown2(
                  hint: l10n.get('language'),
                  value: _selectedLanguage,
                  items: languageNames.entries.map((e) => 
                    DropdownMenuItem<String>(
                      value: e.key, 
                      child: Text(
                        e.value, 
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    )
                  ).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedLanguage = value);
                    }
                  },
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown2(
                  hint: locale.startsWith('zh') ? '排序' : 'Sort',
                  value: _selectedOrder,
                  items: orderNames.entries.map((e) => 
                    DropdownMenuItem<String>(
                      value: e.key, 
                      child: Text(
                        e.value,
                        style: const TextStyle(fontSize: 14),
                      ),
                    )
                  ).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedOrder = value);
                    }
                  },
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Second row: Format chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: extensionNames.entries.map((entry) => 
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: _selectedExtension == entry.key,
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: _selectedExtension == entry.key 
                          ? AppColors.primary 
                          : null,
                      fontWeight: _selectedExtension == entry.key 
                          ? FontWeight.bold 
                          : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedExtension = entry.key);
                      }
                    },
                  ),
                ),
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDropdown2({
    required String hint,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButton2<String>(
        isExpanded: true,
        hint: Text(
          hint,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).hintColor,
          ),
        ),
        items: items,
        value: value,
        onChanged: onChanged,
        buttonStyleData: ButtonStyleData(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
            color: isDark ? Colors.grey[850] : Colors.white,
          ),
        ),
        iconStyleData: IconStyleData(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          iconSize: 20,
          iconEnabledColor: AppColors.primary,
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isDark ? Colors.grey[900] : Colors.white,
          ),
          scrollbarTheme: ScrollbarThemeData(
            radius: const Radius.circular(40),
            thickness: WidgetStateProperty.all(6),
            thumbVisibility: WidgetStateProperty.all(true),
          ),
        ),
        menuItemStyleData: const MenuItemStyleData(
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
  }
}
