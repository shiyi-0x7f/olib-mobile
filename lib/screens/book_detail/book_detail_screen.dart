import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import '../../models/display_book.dart';
import '../../providers/books_provider.dart';
import '../../providers/download_provider.dart';
import '../../theme/app_colors.dart';
import 'book_detail_args.dart';
import 'widgets/book_hero_section.dart';
import 'widgets/book_info_section.dart';
import 'widgets/book_action_bar.dart';

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 兼容两种 arg：BookDetailArgs（带 fromAi）和直接的 Book（旧调用方）。
    final raw = ModalRoute.of(context)!.settings.arguments;
    final BookDetailArgs args = raw is BookDetailArgs
        ? raw
        : BookDetailArgs(book: raw as Book);
    final book = args.book;
    final fromAi = args.fromAi;
    final tasks = ref.watch(downloadProvider);

    DownloadTask? downloadTask;
    try {
      downloadTask = tasks.firstWhere((t) => t.id == book.id.toString());
    } catch (_) {}

    final isDownloading = downloadTask?.status == DownloadStatus.downloading;
    final isCompleted = downloadTask?.status == DownloadStatus.completed;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Watch favorite state
    final favAsync = ref.watch(isBookFavoritedProvider(book.id.toString()));
    final isFavorited = favAsync.valueOrNull ?? false;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.background,
      // ── Sticky Bottom Action Bar ──
      bottomNavigationBar: BookActionBar(
        book: book,
        downloadTask: downloadTask,
        isDownloading: isDownloading,
        isCompleted: isCompleted,
        isDark: isDark,
        fromAi: fromAi,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 1. Hero Section with Glassmorphism ──
          BookHeroSection(
            book: book.toDisplay(),
            isDark: isDark,
            isFavorited: isFavorited,
          ),

          // ── 2. Content Body ──
          BookInfoSection(
            book: book,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}
