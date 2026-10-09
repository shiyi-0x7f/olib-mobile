import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import '../screens/lan/lan_connect.dart';
import '../services/booklist_share_codec.dart';
import '../utils/booklist_file_utils.dart';
import '../utils/share_utils.dart';
import '../theme/app_colors.dart';
import 'share_snapshot_widget.dart';

class SharePreviewSheet extends StatefulWidget {
  final List<Book> books;

  const SharePreviewSheet({super.key, required this.books});

  @override
  State<SharePreviewSheet> createState() => _SharePreviewSheetState();
}

class _SharePreviewSheetState extends State<SharePreviewSheet> {
  final GlobalKey _snapshotKey = GlobalKey();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  ShareStyle _selectedStyle = ShareStyle.museum;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String? _generateQrData() {
    final ids = widget.books.map((b) => b.id.toString());
    return BooklistShareCodec.encodeIdsUri(ids);
  }

  BooklistShareData _buildShareData() {
    return BooklistShareData(
      entries: widget.books.map(BooklistEntry.fromBook).toList(),
      name: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      exportedAt: DateTime.now(),
    );
  }

  Future<void> _copyToken() async {
    final uri = BooklistShareCodec.encodeFullUri(_buildShareData());
    await Clipboard.setData(ClipboardData(text: uri));
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.get('token_copied'))),
    );
  }

  Future<void> _exportJson() async {
    try {
      await BooklistFileUtils.exportAndShare(_buildShareData());
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l.get('error')}: $e')),
      );
    }
  }

  /// 推送书单到桌面端（LAN，POST /api/booklist，codec v1 结构原样）。
  Future<void> _sendToComputer() async {
    final client = await connectToDesktop(context);
    if (client == null || !mounted) return;

    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json =
          jsonDecode(BooklistShareCodec.encodeJsonFile(_buildShareData()))
              as Map<String, dynamic>;
      final r = await client.pushBooklist(json);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l
                .get('lan_booklist_sent')
                .replaceAll('%i', '${r.imported}')
                .replaceAll('%s', '${r.skipped}'),
          ),
          backgroundColor: r.imported > 0 ? Colors.green : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(lanErrorMessage(l, e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final qrData = _generateQrData();

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Text(
              l.get('share_booklist'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // Style Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                _buildStyleChip('Museum', ShareStyle.museum),
                const SizedBox(width: 12),
                _buildStyleChip('Magazine', ShareStyle.magazine),
                const SizedBox(width: 12),
                _buildStyleChip('Glass', ShareStyle.glass),
              ],
            ),
          ),

          // Input Fields
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                // Title Input
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: l.get('title_optional'),
                    hintText: l.get('enter_title'),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                // Content Input
                TextField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    labelText: l.get('recommendation_optional'),
                    hintText: l.get('enter_content'),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 2,
                  minLines: 1,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),

          // Preview
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Center(
                child: RepaintBoundary(
                  key: _snapshotKey,
                  child: ShareSnapshotWidget(
                    books: widget.books,
                    style: _selectedStyle,
                    customTitle: _titleController.text,
                    customContent: _contentController.text,
                    qrData: qrData,
                  ),
                ),
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Row(
              children: [
                _buildIconAction(
                  icon: Icons.link_rounded,
                  tooltip: l.get('copy_token'),
                  onTap: _copyToken,
                ),
                const SizedBox(width: 8),
                _buildIconAction(
                  icon: Icons.file_download_outlined,
                  tooltip: l.get('export_json'),
                  onTap: _exportJson,
                ),
                const SizedBox(width: 8),
                _buildIconAction(
                  icon: Icons.computer_outlined,
                  tooltip: l.get('lan_send_to_computer'),
                  onTap: _sendToComputer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(l.get('close')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await ShareUtils.captureAndShare(_snapshotKey);
                    },
                    icon: const Icon(Icons.share_rounded, size: 20),
                    label: Text(l.get('share_image')),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Icon(icon, size: 20, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildStyleChip(String label, ShareStyle style) {
    final isSelected = style == _selectedStyle;
    final cs = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedStyle = style),
      selectedColor: AppColors.primary.withValues(alpha:0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : cs.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary : cs.outlineVariant,
        ),
      ),
    );
  }
}
