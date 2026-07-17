import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/domain_provider.dart';
import '../providers/speed_test_provider.dart';
import '../theme/app_colors.dart';

class DomainSelector extends ConsumerWidget {
  final bool compact;
  final Color? color;

  const DomainSelector({
    super.key, 
    this.compact = false,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDomain = ref.watch(domainProvider);
    final domains = ref.watch(domainListProvider);

    // Find line number for current domain
    final idx = domains.indexOf(currentDomain);
    final label = idx >= 0 ? 'Line ${idx + 1}' : 'Custom';

    if (compact) {
      return IconButton(
        icon: const Icon(Icons.dns_outlined),
        color: color ?? Theme.of(context).colorScheme.onSurface,
        tooltip: 'Switch Network ($label)',
        onPressed: () => _showDialog(context),
      );
    }

    return InkWell(
      onTap: () => _showDialog(context),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: (color ?? AppColors.primary).withValues(alpha:0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dns_outlined,
              size: 18,
              color: color ?? AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color ?? AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: color ?? AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const DomainSelectionDialog(),
    );
  }
}

class DomainSelectionDialog extends ConsumerWidget {
  const DomainSelectionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDomain = ref.watch(domainProvider);
    final domains = ref.watch(domainListProvider);
    final speedState = ref.watch(speedTestProvider);
    final locale = Localizations.localeOf(context).languageCode;
    final isZh = locale == 'zh';

    // Build lookup: domain -> DomainTestResult
    final Map<String, DomainTestResult> resultMap = {};
    for (final r in speedState.results) {
      resultMap[r.domain] = r;
    }

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      title: Row(
        children: [
          Expanded(
            child: Text(
              isZh ? '选择线路' : 'Select Network',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          // Progress / count badge
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: speedState.testing
                ? Row(
                    key: const ValueKey('testing'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: speedState.results.isEmpty
                              ? null
                              : speedState.testedCount /
                                  speedState.results.length,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${speedState.testedCount}/${speedState.results.length}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  )
                : Text(
                    key: const ValueKey('done'),
                    '${speedState.onlineCount}/${speedState.results.length} ✓',
                    style: TextStyle(
                      fontSize: 12,
                      color: speedState.onlineCount > 0
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.55,
        child: ListView.builder(
          itemCount: speedState.results.length + 1, // +1 for custom
          itemBuilder: (context, index) {
            if (index < speedState.results.length) {
              final result = speedState.results[index];
              // Find the original index in the domain list for "Line N" label
              final lineIndex = domains.indexOf(result.domain);
              final lineLabel = lineIndex >= 0
                  ? 'Line ${lineIndex + 1}'
                  : result.domain;
              return _buildDomainTile(
                context, ref, result, lineLabel, currentDomain);
            }
            // Last item: custom domain
            return _buildCustomTile(context, ref, currentDomain, domains, isZh);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: speedState.testing
              ? null
              : () => ref.read(speedTestProvider.notifier).runTest(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.speed,
                  size: 16, color: speedState.testing ? Colors.grey : null),
              const SizedBox(width: 4),
              Text(isZh ? '重新测速' : 'Re-test'),
            ],
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isZh ? '关闭' : 'Close'),
        ),
      ],
    );
  }

  Widget _buildDomainTile(
    BuildContext context,
    WidgetRef ref,
    DomainTestResult result,
    String label,
    String currentDomain,
  ) {
    final isSelected = result.domain == currentDomain;
    final latency = result.latencyMs;

    // Status indicator
    Widget trailing;
    if (latency == null) {
      trailing = const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      );
    } else if (latency < 0) {
      trailing = const Icon(Icons.close, size: 16, color: Colors.red);
    } else {
      Color latColor;
      if (latency < 1000) {
        latColor = Colors.green;
      } else if (latency < 3000) {
        latColor = Colors.orange;
      } else {
        latColor = Colors.red;
      }
      trailing = Text(
        '${latency}ms',
        style: TextStyle(
          fontSize: 12,
          color: latColor,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      leading: isSelected
          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
          : const Icon(Icons.circle_outlined, size: 20, color: Colors.grey),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
          color: isSelected ? AppColors.primary : null,
        ),
      ),
      trailing: trailing,
      onTap: () {
        ref.read(domainProvider.notifier).setDomain(result.domain);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildCustomTile(
    BuildContext context,
    WidgetRef ref,
    String currentDomain,
    List<String> domains,
    bool isZh,
  ) {
    final isCustom = !domains.contains(currentDomain);

    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      leading: isCustom
          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
          : const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
      title: Text(
        isCustom
            ? (isZh ? '自定义线路' : 'Custom Line')
            : (isZh ? '自定义线路...' : 'Custom line...'),
        style: TextStyle(
          fontSize: 14,
          fontWeight: isCustom ? FontWeight.w700 : FontWeight.normal,
          color: isCustom ? AppColors.primary : Colors.grey,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => _showCustomDomainDialog(context, ref),
    );
  }

  void _showCustomDomainDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final locale = Localizations.localeOf(context).languageCode;
    final isZh = locale == 'zh';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isZh ? '自定义线路' : 'Custom Domain'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: isZh ? '域名地址' : 'Domain URL',
            hintText: 'e.g., example.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isZh ? '取消' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref
                    .read(domainProvider.notifier)
                    .setCustomDomain(controller.text);
                Navigator.pop(context);
              }
            },
            child: Text(isZh ? '保存' : 'Save'),
          ),
        ],
      ),
    );
  }
}
