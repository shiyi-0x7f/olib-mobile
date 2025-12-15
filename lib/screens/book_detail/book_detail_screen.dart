import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_filex/open_filex.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/book.dart';
import '../../providers/books_provider.dart';
import '../../providers/download_provider.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/update_service.dart';
import '../../routes/app_routes.dart';
import '../similar/similar_books_screen.dart';

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ModalRoute.of(context)!.settings.arguments as Book;

    final tasks = ref.watch(downloadProvider);
    DownloadTask? downloadTask;
    try {
      downloadTask = tasks.firstWhere((t) => t.id == book.id.toString());
    } catch (_) {}

    final isDownloading = downloadTask?.status == DownloadStatus.downloading;
    final isCompleted = downloadTask?.status == DownloadStatus.completed;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: book.cover != null
                  ? CachedNetworkImage(
                      imageUrl: book.cover!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: AppColors.textSecondary.withOpacity(0.2),
                      child: const Icon(Icons.book, size: 100),
                    ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  if (book.author != null)
                    Text(
                      'by ${book.author}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.primary,
                          ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Book Info
                  _buildInfoRow(context, Icons.calendar_today, AppLocalizations.of(context).get('year'), book.year?.toString()),
                  _buildInfoRow(context, Icons.language, AppLocalizations.of(context).get('language'), book.language),
                  _buildInfoRow(context, Icons.description, AppLocalizations.of(context).get('pages'), book.pages?.toString()),
                  _buildInfoRow(context, Icons.business, AppLocalizations.of(context).get('publisher'), book.publisher),
                  _buildInfoRow(context, Icons.folder, 'Format', book.extension?.toUpperCase()),
                  _buildInfoRow(context, Icons.storage, AppLocalizations.of(context).get('file_size'), book.filesizeString),
                  
                  const SizedBox(height: 24),
                  
                  if (book.description != null && book.description!.isNotEmpty) ...[
                    Text(
                      AppLocalizations.of(context).get('description'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      book.description!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isDownloading
                              ? null
                              : () async {
                                  // Check if app is blocked due to force update
                                  if (UpdateService.isBlocked && !isCompleted) {
                                    final locale = Localizations.localeOf(context).languageCode;
                                    final isZh = locale == 'zh';
                                    
                                    AwesomeDialog(
                                      context: context,
                                      dialogType: DialogType.warning,
                                      animType: AnimType.bottomSlide,
                                      title: isZh ? '功能已禁用' : 'Feature Disabled',
                                      desc: isZh 
                                          ? '当前版本已过期，请更新到最新版本后使用下载功能。'
                                          : 'This version is outdated. Please update to use download.',
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
                                  
                                  if (isCompleted && downloadTask?.filePath != null) {
                                    OpenFilex.open(downloadTask!.filePath!);
                                  } else {
                                    // Check if file already exists
                                    final existingPath = await ref
                                        .read(downloadProvider.notifier)
                                        .checkFileExists(book);
                                    
                                    if (existingPath != null && context.mounted) {
                                      final locale = Localizations.localeOf(context).languageCode;
                                      final isZh = locale == 'zh';
                                      
                                      // Show dialog to warn user
                                      AwesomeDialog(
                                        context: context,
                                        dialogType: DialogType.info,
                                        animType: AnimType.bottomSlide,
                                        title: isZh ? '文件已存在' : 'File Already Exists',
                                        desc: isZh 
                                            ? '这本书已经下载过了。\n\n您可以打开现有文件或重新下载。'
                                            : 'This book has already been downloaded.\n\nYou can open the existing file or download again.',
                                        btnCancelText: isZh ? '打开文件' : 'Open File',
                                        btnCancelColor: Colors.green,
                                        btnCancelOnPress: () {
                                          OpenFilex.open(existingPath);
                                        },
                                        btnOkText: isZh ? '重新下载' : 'Download Again',
                                        btnOkColor: AppColors.primary,
                                        btnOkOnPress: () {
                                          ref
                                              .read(downloadProvider.notifier)
                                              .startDownload(book);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                                content: Text(AppLocalizations.of(context).get('downloading'))),
                                          );
                                        },
                                      ).show();
                                      return;
                                    }
                                    
                                    ref
                                        .read(downloadProvider.notifier)
                                        .startDownload(book);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(AppLocalizations.of(context).get('downloading'))),
                                    );
                                  }
                                },
                          icon: Icon(isCompleted
                              ? Icons.folder_open
                              : (isDownloading
                                  ? Icons.downloading
                                  : Icons.download)),
                          label: Text(isCompleted
                              ? AppLocalizations.of(context).get('open_file')
                              : (isDownloading
                                  ? '${AppLocalizations.of(context).get('downloading')} ${(downloadTask!.progress * 100).toStringAsFixed(0)}%'
                                  : AppLocalizations.of(context).get('download'))),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCompleted
                                ? Colors.green
                                : AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      ElevatedButton.icon(
                        onPressed: () async {
                          await ref.read(savedBooksProvider.notifier).saveBook(book.id.toString());
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Added to favorites')),
                            );
                          }
                        },
                        icon: const Icon(Icons.favorite_outline),
                        label: Text(AppLocalizations.of(context).get('like')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  
                  // Similar Books Button
                  if (book.hash != null && book.hash!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.similarBooks,
                            arguments: SimilarBooksArgs(
                              bookId: book.id,
                              hashId: book.hash!,
                              bookTitle: book.title,
                            ),
                          );
                        },
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(AppLocalizations.of(context).get('similar_books')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
