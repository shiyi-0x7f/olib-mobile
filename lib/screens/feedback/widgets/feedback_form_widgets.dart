import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/feedback.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_toast.dart';

/// 表单分节标题：「标题 + 必填/选填标签」，让用户一眼看出哪些可以跳过。
class FeedbackSectionLabel extends StatelessWidget {
  final String title;
  final bool required;
  final bool isZh;
  final String? errorText;

  const FeedbackSectionLabel({
    super.key,
    required this.title,
    required this.required,
    required this.isZh,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            required ? (isZh ? '必填' : 'Required') : (isZh ? '选填' : 'Optional'),
            style: TextStyle(
              fontSize: 12,
              color: required ? AppColors.accent : cs.onSurfaceVariant,
            ),
          ),
          if (errorText != null) ...[
            const Spacer(),
            Text(
              errorText!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}

/// 单选标签组（选项 ≤10，平铺比下拉更快）。
class FeedbackOptionChips extends StatelessWidget {
  final List<FeedbackOption> options;
  final String? selected;
  final bool isZh;
  final ValueChanged<String> onSelected;

  const FeedbackOptionChips({
    super.key,
    required this.options,
    required this.selected,
    required this.isZh,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            avatar: Icon(o.icon, size: 18),
            label: Text(o.label(isZh)),
            selected: selected == o.value,
            showCheckmark: false,
            onSelected: (_) => onSelected(o.value),
          ),
      ],
    );
  }
}

/// 影响程度：三张并排卡片，带一句人话解释；再点一次可取消（选填）。
class FeedbackSeveritySelector extends StatelessWidget {
  final String? selected;
  final bool isZh;
  final ValueChanged<String?> onChanged;

  const FeedbackSeveritySelector({
    super.key,
    required this.selected,
    required this.isZh,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 说明文字长短不一会导致换行行数不同，IntrinsicHeight + stretch 让三张卡等高
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, o) in feedbackSeverities.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _SeverityCard(
                option: o,
                isZh: isZh,
                selected: selected == o.value,
                cs: cs,
                onTap: () => onChanged(selected == o.value ? null : o.value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeverityCard extends StatelessWidget {
  final FeedbackOption option;
  final bool isZh;
  final bool selected;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _SeverityCard({
    required this.option,
    required this.isZh,
    required this.selected,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? cs.primary : cs.onSurfaceVariant;
    return Material(
      color: selected ? cs.primaryContainer.withValues(alpha: 0.5) : cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? cs.primary : cs.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            children: [
              Icon(option.icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                option.label(isZh),
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                option.hint(isZh) ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「附带设备信息」勾选框：旁边直接展示将发送的实际值（所见即所发）。
class DiagnosticsConsentTile extends StatelessWidget {
  final bool value;
  final DeviceDiagnostics? diagnostics;
  final bool isZh;
  final ValueChanged<bool> onChanged;

  const DiagnosticsConsentTile({
    super.key,
    required this.value,
    required this.diagnostics,
    required this.isZh,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final summary = diagnostics?.summary ?? '';
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          isZh
              ? '附带设备信息（设备型号、系统版本），帮助我们定位问题'
              : 'Include device info (model, OS version) to help us locate the issue',
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            summary.isEmpty
                ? (isZh ? '将发送：无法读取设备信息' : 'Will send: unavailable')
                : (isZh ? '将发送：$summary' : 'Will send: $summary'),
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// 常驻错误卡片（不一闪而过），可复制详情发给开发者。
class FeedbackErrorBanner extends StatelessWidget {
  final String message;
  final String? detail;
  final bool isZh;
  final VoidCallback onDismiss;

  const FeedbackErrorBanner({
    super.key,
    required this.message,
    required this.detail,
    required this.isZh,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.error_outline, color: AppColors.error, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SelectableText(
                detail == null ? message : '$message\n$detail',
                style: const TextStyle(fontSize: 13, color: AppColors.error),
              ),
            ),
          ),
          IconButton(
            tooltip: isZh ? '复制' : 'Copy',
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: '$message\n${detail ?? ''}'),
              );
              AppToast.success(isZh ? '已复制' : 'Copied');
            },
          ),
          IconButton(
            tooltip: isZh ? '关闭' : 'Dismiss',
            icon: const Icon(Icons.close, size: 18),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
