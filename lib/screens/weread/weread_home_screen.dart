import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/weread_provider.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../widgets/empty_state.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/weread/weread_models.dart';
import 'widgets/weread_stats_card.dart';

/// 微信读书主页 — 统计 / 书架 / 笔记
class WereadHomeScreen extends ConsumerWidget {
  const WereadHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final isConfigured = ref.watch(isWereadConfiguredProvider);

    if (!isConfigured) {
      return Scaffold(
        appBar: GradientAppBar(title: t.get('weread')),
        body: EmptyState(
          icon: Icons.key_off_rounded,
          title: t.get('weread_not_configured_title'),
          message: t.get('weread_not_configured_msg'),
          action: FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            icon: const Icon(Icons.settings, size: 18),
            label: Text(t.get('weread_go_settings')),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: GradientAppBar(title: t.get('weread')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(wereadStatsProvider);
          ref.invalidate(wereadNotebooksProvider);
        },
        child: CustomScrollView(
          slivers: [
            _StatsSection(),
            _NotesSection(),
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Stats Section
// ═══════════════════════════════════════════════════════════════════
class _StatsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final statsAsync = ref.watch(wereadStatsProvider);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, Icons.bar_chart_rounded,
                t.get('weread_reading_stats')),
            const SizedBox(height: 12),
            statsAsync.when(
              data: (stats) {
                if (stats == null) return const SizedBox.shrink();
                final readDays = stats.readDays ?? 0;
                return WereadStatsCard(
                  totalReadTime: stats.totalReadTime,
                  readDays: readDays,
                  dailyAvg: stats.dayAverageReadTime ?? 0,
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (e, _) => _errorChip(context, e.toString()),
            ),
          ],
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════
// Notes Section — all notes with load more
// ═══════════════════════════════════════════════════════════════════
class _NotesSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends ConsumerState<_NotesSection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final notesAsync = ref.watch(wereadNotebooksProvider);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: notesAsync.when(
          data: (notes) {
            if (notes == null || notes.books.isEmpty) {
              return const SizedBox.shrink();
            }

            final allBooks = notes.books;
            final previewCount = allBooks.length > 8 ? 8 : allBooks.length;
            final displayBooks =
                _showAll ? allBooks : allBooks.take(previewCount).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitleWithCount(
                  context,
                  Icons.edit_note_rounded,
                  t.get('weread_notes'),
                  t.get('weread_notes_count')
                      .replaceAll('%d', '${notes.totalNoteCount}'),
                ),
                const SizedBox(height: 12),
                ...displayBooks.map((nb) => _noteTile(context, cs, t, nb)),
                // Show more / Show less
                if (allBooks.length > previewCount) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _showAll = !_showAll),
                      icon: Icon(
                        _showAll
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                      ),
                      label: Text(
                        _showAll
                            ? t.get('weread_show_less')
                            : '${t.get('weread_view_all')} (${allBooks.length})',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _noteTile(BuildContext context, ColorScheme cs,
      AppLocalizations t, NotebookBook nb) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).pushNamed(
              AppRoutes.wereadBookDetail,
              arguments: nb.bookId,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Cover thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    nb.book.cover ?? '',
                    width: 42,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 42,
                      height: 56,
                      color: cs.surfaceContainerHighest,
                      child: const Icon(Icons.book, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nb.book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _noteChip(
                            t.get('weread_highlights'),
                            nb.noteCount,
                            cs,
                          ),
                          const SizedBox(width: 8),
                          _noteChip(
                            t.get('weread_thoughts'),
                            nb.reviewCount,
                            cs,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Reading progress
                if ((nb.readingProgress ?? 0) > 0)
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            value: (nb.readingProgress ?? 0) / 100,
                            strokeWidth: 3,
                            backgroundColor: cs.outlineVariant
                                .withValues(alpha: 0.3),
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          '${nb.readingProgress ?? 0}%',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _noteChip(String label, int count, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          fontSize: 11,
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Shared Helpers
// ═══════════════════════════════════════════════════════════════════

Widget _sectionTitle(BuildContext context, IconData icon, String title) {
  final cs = Theme.of(context).colorScheme;
  return Row(
    children: [
      Icon(icon, size: 20, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),
    ],
  );
}

Widget _sectionTitleWithCount(
    BuildContext context, IconData icon, String title, String count) {
  final cs = Theme.of(context).colorScheme;
  return Row(
    children: [
      Icon(icon, size: 20, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          count,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    ],
  );
}

Widget _errorChip(BuildContext context, String msg) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline, size: 16, color: AppColors.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            msg,
            style: TextStyle(fontSize: 12, color: AppColors.error),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
