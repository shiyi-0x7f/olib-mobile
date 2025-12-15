import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/zlibrary_provider.dart';
import '../../models/book.dart';
import '../../widgets/book_card.dart';
import '../../widgets/book_list_tile.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../routes/app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';

/// Arguments for SimilarBooksScreen
class SimilarBooksArgs {
  final int bookId;
  final String hashId;
  final String bookTitle;

  const SimilarBooksArgs({
    required this.bookId,
    required this.hashId,
    required this.bookTitle,
  });
}

class SimilarBooksScreen extends ConsumerStatefulWidget {
  const SimilarBooksScreen({super.key});

  @override
  ConsumerState<SimilarBooksScreen> createState() => _SimilarBooksScreenState();
}

class _SimilarBooksScreenState extends ConsumerState<SimilarBooksScreen> {
  List<Book> _books = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isListView = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading && _books.isEmpty) {
      _loadSimilarBooks();
    }
  }

  Future<void> _loadSimilarBooks() async {
    final args = ModalRoute.of(context)!.settings.arguments as SimilarBooksArgs;
    final api = ref.read(zlibraryApiProvider);
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      final response = await api.Similar(args.bookId.toString(), args.hashId);
      final success = response['success'];
      
      if ((success == true || success == 1) && response.containsKey('books')) {
        final booksData = response['books'] as List<dynamic>;
        final books = booksData.map((json) => Book.fromJson(json)).toList();
        
        setState(() {
          _books = books;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = response['error']?.toString() ?? 'Failed to load similar books';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as SimilarBooksArgs;
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: GradientAppBar(
        title: l10n.get('similar_books'),
      ),
      body: Column(
        children: [
          // Book context header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.book_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    args.bookTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          // Results
          Expanded(
            child: _isLoading
                ? LoadingWidget(message: l10n.get('loading_similar_books'))
                : _hasError
                    ? EmptyState(
                        icon: Icons.error_outline,
                        title: l10n.get('error'),
                        message: _errorMessage,
                      )
                    : _books.isEmpty
                        ? EmptyState(
                            icon: Icons.search_off,
                            title: l10n.get('no_similar_books'),
                            message: l10n.get('no_similar_books_message'),
                          )
                        : Column(
                            children: [
                              // Results info and view toggle
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${_books.length} ${l10n.get('books_found')}',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
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
                              ),
                              // Books Grid/List
                              Expanded(
                                child: _isListView
                                    ? ListView.builder(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        itemCount: _books.length,
                                        itemBuilder: (context, index) {
                                          final book = _books[index];
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
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          childAspectRatio: 0.65,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                        ),
                                        itemCount: _books.length,
                                        itemBuilder: (context, index) {
                                          final book = _books[index];
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
}
