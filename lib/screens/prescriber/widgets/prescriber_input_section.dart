import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/prescription.dart';
import '../../../providers/prescriber_provider.dart';
import '../../../theme/app_colors.dart';
import 'theme_card.dart';

/// Per-theme short labels + accent color. Keeps the data model untouched and
/// lives next to the card grid that consumes it.
class _ThemeMeta {
  final String shortZh;
  final String shortEn;
  final Color tint;
  const _ThemeMeta(this.shortZh, this.shortEn, this.tint);
}

const Map<String, _ThemeMeta> _themeMetaById = {
  'relax': _ThemeMeta('放松', 'Relax', AppColors.info),
  'direction': _ThemeMeta('找方向', 'Direction', AppColors.primary),
  'learn': _ThemeMeta('学习', 'Learn', AppColors.success),
  'bedtime': _ThemeMeta('助眠', 'Sleep', Color(0xFF8B7AB8)),
  'heal': _ThemeMeta('治愈', 'Heal', AppColors.accent),
  'thinking': _ThemeMeta('思考', 'Think', AppColors.warning),
};

class PrescriberInputSection extends ConsumerWidget {
  final TextEditingController inputController;
  final VoidCallback onDiagnoseWithInput;
  final void Function(String themeId) onDiagnoseWithTheme;
  final VoidCallback onRetry;
  final bool isZh;

  const PrescriberInputSection({
    super.key,
    required this.inputController,
    required this.onDiagnoseWithInput,
    required this.onDiagnoseWithTheme,
    required this.onRetry,
    required this.isZh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 配额耗尽时锁定所有 AI 触发入口；UI 仍可滚动浏览。
    final state = ref.watch(prescriberProvider);
    final lockedByQuota = state.status == PrescriberStatus.error &&
        state.errorKind == PrescriberErrorKind.quota;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.list(
        children: [
          const SizedBox(height: 8),
          _ErrorBanner(
            isZh: isZh,
            onRetry: onRetry,
            inputController: inputController,
          ),
          _HeroCard(isZh: isZh),
          const SizedBox(height: 24),
          _ThemeGrid(
            isZh: isZh,
            onTap: onDiagnoseWithTheme,
            disabled: lockedByQuota,
          ),
          const SizedBox(height: 28),
          _OrDivider(label: isZh ? '或者自己描述' : 'Or describe it yourself'),
          const SizedBox(height: 16),
          _InputField(
            controller: inputController,
            isZh: isZh,
            enabled: !lockedByQuota,
          ),
          const SizedBox(height: 14),
          _FormatPicker(isZh: isZh),
          const SizedBox(height: 18),
          _DiagnoseButton(
            controller: inputController,
            isZh: isZh,
            onPressed: onDiagnoseWithInput,
            forceDisabled: lockedByQuota,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Hero card ──────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final bool isZh;

  const _HeroCard({required this.isZh});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: isDark ? 0.32 : 0.18),
            cs.secondary.withValues(alpha: isDark ? 0.22 : 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.primary.withValues(alpha: isDark ? 0.35 : 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.25),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.auto_stories_rounded,
                size: 28, color: cs.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isZh ? 'AI 为你找一本书' : 'AI finds you a book',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isZh
                      ? '选一个状态，或者说说你在想什么'
                      : 'Pick a mood or tell us what you need',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    height: 1.35,
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

// ─── Theme grid ─────────────────────────────────────────────────────

class _ThemeGrid extends StatelessWidget {
  final bool isZh;
  final void Function(String themeId) onTap;
  /// 配额耗尽时整片网格 IgnorePointer + Opacity 灰掉
  final bool disabled;

  const _ThemeGrid({
    required this.isZh,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final grid = GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: prescriberThemes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, i) {
        final theme = prescriberThemes[i];
        final meta = _themeMetaById[theme.id] ??
            const _ThemeMeta('', '', AppColors.primary);
        return ThemeCard(
          emoji: theme.emoji,
          shortLabel: isZh ? meta.shortZh : meta.shortEn,
          tooltip: isZh ? theme.labelZh : theme.labelEn,
          tint: meta.tint,
          onTap: () => onTap(theme.id),
        );
      },
    );
    if (!disabled) return grid;
    return IgnorePointer(
      ignoring: true,
      child: Opacity(opacity: 0.4, child: grid),
    );
  }
}

// ─── "Or describe..." divider ──────────────────────────────────────

class _OrDivider extends StatelessWidget {
  final String label;

  const _OrDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: cs.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: cs.outlineVariant)),
      ],
    );
  }
}

// ─── Input field ────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final bool isZh;
  /// 配额耗尽时 enabled=false → TextField 内置禁用样式 + readOnly
  final bool enabled;

  const _InputField({
    required this.controller,
    required this.isZh,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      maxLines: 3,
      enabled: enabled,
      style: TextStyle(color: cs.onSurface, fontSize: 14),
      decoration: InputDecoration(
        hintText: enabled
            ? (isZh
                ? '描述一下你最近的状态或困惑…'
                : 'Describe how you feel lately…')
            : (isZh ? '今日字符已尽…' : 'Until tomorrow…'),
        hintStyle: TextStyle(
          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          fontSize: 14,
        ),
        filled: true,
        fillColor: cs.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }
}

// ─── Format picker (dropdown) ───────────────────────────────────────

/// 单行：标签居左，下拉胶囊居右。下拉项走系统 PopupMenu，长按/点击都行。
class _FormatPicker extends ConsumerWidget {
  final bool isZh;

  const _FormatPicker({required this.isZh});

  static const _formats = <_FormatOption>[
    _FormatOption(value: null, zh: '不限', en: 'Any'),
    _FormatOption(value: 'pdf', zh: 'PDF', en: 'PDF'),
    _FormatOption(value: 'epub', zh: 'EPUB', en: 'EPUB'),
    _FormatOption(value: 'mobi', zh: 'MOBI', en: 'MOBI'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final currentFormat = ref.watch(prescriberProvider).preferredFormat;
    final currentLabel = _formats
        .firstWhere(
          (o) => o.value == currentFormat,
          orElse: () => _formats.first,
        )
        .labelFor(isZh);

    return Row(
      children: [
        Icon(Icons.tune_rounded, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          isZh ? '偏好格式' : 'Format',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const Spacer(),
        PopupMenuButton<String?>(
          initialValue: currentFormat,
          tooltip: isZh ? '选择格式' : 'Choose format',
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (fmt) {
            ref.read(prescriberProvider.notifier).setFormat(fmt);
          },
          itemBuilder: (context) => _formats
              .map(
                (o) => PopupMenuItem<String?>(
                  value: o.value,
                  child: Row(
                    children: [
                      Text(
                        o.labelFor(isZh),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: o.value == currentFormat
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: o.value == currentFormat
                              ? cs.primary
                              : cs.onSurface,
                        ),
                      ),
                      if (o.value == currentFormat) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.check_rounded, size: 16, color: cs.primary),
                      ],
                    ],
                  ),
                ),
              )
              .toList(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentLabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down_rounded,
                    size: 18, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FormatOption {
  final String? value;
  final String zh;
  final String en;
  const _FormatOption({required this.value, required this.zh, required this.en});

  String labelFor(bool isZh) => isZh ? zh : en;
}

// ─── Error banner ───────────────────────────────────────────────────

class _ErrorBanner extends ConsumerWidget {
  final bool isZh;
  final VoidCallback onRetry;
  final TextEditingController inputController;

  const _ErrorBanner({
    required this.isZh,
    required this.onRetry,
    required this.inputController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(prescriberProvider);
    if (state.status != PrescriberStatus.error || state.errorMessage == null) {
      return const SizedBox.shrink();
    }
    // 配额耗尽 → 由 dialog + 禁用输入承担反馈，行内 banner 不再显示
    // （避免三处同时说同一件事）
    if (state.errorKind == PrescriberErrorKind.quota) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;

    // 真错误 → 原有 "寻书失败" 样式 + 重试入口
    final canRetry = inputController.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: cs.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isZh ? '寻书失败' : 'Failed to find',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.errorMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: cs.onErrorContainer.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            if (canRetry)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: cs.error,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(isZh ? '重试' : 'Retry'),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── "Find books" button ────────────────────────────────────────────

class _DiagnoseButton extends StatelessWidget {
  final TextEditingController controller;
  final bool isZh;
  final VoidCallback onPressed;
  /// 配额耗尽时 forceDisabled=true 强制置灰，无视输入框内容
  final bool forceDisabled;

  const _DiagnoseButton({
    required this.controller,
    required this.isZh,
    required this.onPressed,
    this.forceDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final enabled =
            !forceDisabled && controller.text.trim().isNotEmpty;
        final label = forceDisabled
            ? (isZh ? '今日已尽' : 'Until tomorrow')
            : (isZh ? '开始寻书' : 'Find Books');
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              disabledBackgroundColor:
                  cs.onSurface.withValues(alpha: 0.12),
              disabledForegroundColor:
                  cs.onSurface.withValues(alpha: 0.38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: enabled ? 2 : 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(forceDisabled ? Icons.nightlight_round : Icons.auto_awesome,
                    size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
