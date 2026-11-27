import 'package:flutter/material.dart';

/// 模型选择底部弹层：服务商模型常有上百个，带搜索。返回选中的模型名，取消返回 null。
Future<String?> showAiModelPicker(
  BuildContext context, {
  required List<String> models,
  required String current,
  required bool isZh,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _AiModelPicker(models: models, current: current, isZh: isZh),
  );
}

class _AiModelPicker extends StatefulWidget {
  final List<String> models;
  final String current;
  final bool isZh;

  const _AiModelPicker({
    required this.models,
    required this.current,
    required this.isZh,
  });

  @override
  State<_AiModelPicker> createState() => _AiModelPickerState();
}

class _AiModelPickerState extends State<_AiModelPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.models
        : widget.models.where((m) => m.toLowerCase().contains(q)).toList();
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: widget.models.length > 10,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: widget.isZh
                      ? '搜索 ${widget.models.length} 个模型'
                      : 'Search ${widget.models.length} models',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        widget.isZh ? '没有匹配的模型' : 'No matching models',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final m = filtered[i];
                        final selected = m == widget.current;
                        return ListTile(
                          title: Text(m, style: const TextStyle(fontSize: 14)),
                          trailing: selected
                              ? Icon(Icons.check, color: cs.primary)
                              : null,
                          selected: selected,
                          onTap: () => Navigator.of(context).pop(m),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
