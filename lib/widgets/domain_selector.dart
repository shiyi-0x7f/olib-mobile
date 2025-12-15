import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io';
import '../providers/domain_provider.dart';
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
    final domainList = ref.watch(domainListProvider);

    // Find label for current domain
    String currentLabel = 'Custom';
    for (final entry in domainList.entries) {
      if (entry.value == currentDomain) {
        currentLabel = entry.key;
        break;
      }
    }

    if (compact) {
      return IconButton(
        icon: const Icon(Icons.dns_outlined),
        color: color ?? AppColors.textPrimary,
        tooltip: 'Switch Network ($currentLabel)',
        onPressed: () => _showDialog(context),
      );
    }

    return InkWell(
      onTap: () => _showDialog(context),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: (color ?? AppColors.primary).withOpacity(0.3),
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
              currentLabel,
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

class DomainSelectionDialog extends ConsumerStatefulWidget {
  const DomainSelectionDialog({super.key});

  @override
  ConsumerState<DomainSelectionDialog> createState() => _DomainSelectionDialogState();
}

class _DomainSelectionDialogState extends ConsumerState<DomainSelectionDialog> {
  final Map<String, bool?> _statusMap = {};

  @override
  void initState() {
    super.initState();
    // Start checking immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAllDomains();
    });
  }

  Future<void> _checkAllDomains() async {
    final domainList = ref.read(domainListProvider);
    for (final domain in domainList.values) {
      _checkDomain(domain);
    }
  }

  Future<void> _checkDomain(String domain) async {
    try {
      // Check API endpoint - returns {"success":1,...} when working
      final uri = Uri.parse('https://$domain/eapi/info/languages');
      
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      
      try {
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(
          const Duration(seconds: 10),
        );
        
        // Read response body
        final bodyBytes = await response.expand((chunk) => chunk).toList();
        final body = String.fromCharCodes(bodyBytes);
        
        debugPrint('Domain $domain: status=${response.statusCode}, body=${body.substring(0, body.length > 100 ? 100 : body.length)}...');
        
        if (mounted) {
          setState(() {
            // Check if response contains "success":1 or HTTP 2xx
            final isSuccess = body.contains('"success":1') || 
                              body.contains('"success": 1') ||
                              (response.statusCode >= 200 && response.statusCode < 300);
            _statusMap[domain] = isSuccess;
          });
        }
      } catch (e) {
        debugPrint('Domain check failed for $domain: $e');
        if (mounted) setState(() => _statusMap[domain] = false);
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Domain check error for $domain: $e');
      if (mounted) setState(() => _statusMap[domain] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentDomain = ref.watch(domainProvider);
    final domainList = ref.watch(domainListProvider);
    final locale = Localizations.localeOf(context).languageCode;
    final isZh = locale == 'zh';

    return AlertDialog(
      title: Text(isZh ? '选择线路' : 'Select Network'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            ...domainList.entries.map((entry) {
              final status = _statusMap[entry.value];
              Color statusColor = Colors.grey.withOpacity(0.3);
              if (status == true) statusColor = Colors.green;
              if (status == false) statusColor = Colors.red;

              return RadioListTile<String>(
                title: Row(
                  children: [
                    Expanded(child: Text(entry.key)),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                // Domain hidden - only show name
                value: entry.value,
                groupValue: currentDomain,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(domainProvider.notifier).setDomain(value);
                    Navigator.pop(context);
                  }
                },
              );
            }),
            // Custom Domain Item
            Builder(
              builder: (context) {
                final isCustom = !domainList.containsValue(currentDomain);
                final status = isCustom ? _statusMap[currentDomain] : null;
                
                Color statusColor = Colors.grey.withOpacity(0.3);
                if (status == true) statusColor = Colors.green;
                if (status == false) statusColor = Colors.red;

                // Trigger check if custom and unknown
                if (isCustom && !_statusMap.containsKey(currentDomain)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _checkDomain(currentDomain);
                  });
                }

                return RadioListTile<String>(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isCustom ? 'Custom' : 'Custom Domain',
                          style: TextStyle(
                            color: isCustom ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight: isCustom ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isCustom)
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  // Domain hidden - only show status
                  subtitle: isCustom 
                      ? Text(isZh ? '自定义代理' : 'Custom Proxy') 
                      : Text(isZh ? '点击设置自定义线路' : 'Tap to set custom domain'),
                  value: isCustom ? currentDomain : 'CUSTOM_PLACEHOLDER_KEY',
                  groupValue: currentDomain,
                  secondary: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
                      _showCustomDomainDialog(context, ref);
                    },
                  ),
                  onChanged: (value) {
                    _showCustomDomainDialog(context, ref);
                  },
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() => _statusMap.clear());
            _checkAllDomains();
          },
          child: Text(isZh ? '重新检测' : 'Re-check'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isZh ? '关闭' : 'Close'),
        ),
      ],
    );
  }

  void _showCustomDomainDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(); // Empty - don't show current domain
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
            hintText: 'e.g., z-library.sk',
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
                ref.read(domainProvider.notifier).setCustomDomain(controller.text);
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
