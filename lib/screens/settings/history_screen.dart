import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/books_provider.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state.dart';
import '../../routes/app_routes.dart';
import '../../l10n/app_localizations.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // This provider gets "downloaded" books from account (Cloud history)
    final downloadedBooksAsync = ref.watch(downloadedBooksProvider);

    return Scaffold(
      appBar: GradientAppBar(title: l10n.get('download_history')),
      body: downloadedBooksAsync.when(
        data: (books) {
          if (books.isEmpty) {
            return EmptyState(
              icon: Icons.history,
              title: l10n.get('no_history'),
              message: l10n.get('history_empty_message'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: book.cover != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            book.cover!,
                            width: 50,
                            height: 70,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.book, size: 50),
                  title: Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (book.author != null) Text(book.author!),
                      if (book.filesizeString != null)
                        Text(
                          '${book.extension?.toUpperCase()} • ${book.filesizeString}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.bookDetail,
                      arguments: book,
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => LoadingWidget(message: l10n.get('loading_downloads')),
        error: (error, stack) => EmptyState(
          icon: Icons.error_outline,
          title: l10n.get('error'),
          message: error.toString(),
        ),
      ),
    );
  }
}
