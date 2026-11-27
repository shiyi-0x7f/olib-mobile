import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/ai_settings_provider.dart';
import '../../services/ai/ai_providers.dart';
import '../../services/ai/ai_settings.dart';
import '../../widgets/app_toast.dart';
import 'widgets/ai_model_picker.dart';

/// AI 寻书设置（BYOK + 寻书偏好），与 OlibTauri `AiConfigDialog.tsx` 一致。
/// 保存并测试通过后 `pop(true)`，调用方据此继续被中断的寻书。
class AiConfigScreen extends ConsumerStatefulWidget {
  const AiConfigScreen({super.key});

  @override
  ConsumerState<AiConfigScreen> createState() => _AiConfigScreenState();
}

class _AiConfigScreenState extends ConsumerState<AiConfigScreen> {
  late String _provider;
  late int _tipCount;
  late bool _hasKey;
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _model = TextEditingController();
  final _extra = TextEditingController();

  bool _obscureKey = true;
  bool _loadingModels = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(aiSettingsProvider);
    final s = saved ?? AiSettings.initial();
    _provider = s.provider;
    _tipCount = s.tipCount;
    _hasKey = saved?.hasKey ?? false;
    _baseUrl.text = s.baseUrl;
    _model.text = s.model;
    _extra.text = s.extraPrompt;
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    _extra.dispose();
    super.dispose();
  }

  /// 切换服务商：换地址、清空模型（不同服务商模型名不通用）
  void _selectProvider(String id) {
    final preset = findAiProvider(id);
    setState(() {
      _provider = id;
      if (preset != null) _baseUrl.text = preset.baseUrl;
      _model.clear();
      _error = null;
    });
  }

  Future<void> _fetchModels(bool isZh) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loadingModels = true;
      _error = null;
    });
    try {
      final list = await ref
          .read(aiSettingsProvider.notifier)
          .listModels(_baseUrl.text, _apiKey.text);
      if (!mounted) return;
      if (list.isEmpty) {
        setState(
          () => _error = isZh
              ? '该服务商没有返回模型列表，请手动填写模型名'
              : 'No models returned; please type the model name',
        );
        return;
      }
      final picked = await showAiModelPicker(
        context,
        models: list,
        current: _model.text,
        isZh: isZh,
      );
      if (picked != null && mounted) setState(() => _model.text = picked);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = isZh
            ? '获取模型列表失败（可手动填写模型名）：$e'
            : 'Failed to load models (you can type one): $e',
      );
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  Future<void> _save(bool isZh) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(aiSettingsProvider.notifier)
          .saveAndTest(
            AiSettings(
              provider: _provider,
              baseUrl: _baseUrl.text,
              model: _model.text,
              apiKey: _apiKey.text,
              tipCount: _tipCount,
              extraPrompt: _extra.text,
            ),
          );
      if (!mounted) return;
      AppToast.success(isZh ? '已保存，AI 服务可用' : 'Saved. AI service is ready');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      // 保存成功但测试失败时 Key 已入库，提示改为「已保存」
      setState(() {
        _hasKey = ref.read(aiSettingsProvider)?.hasKey ?? _hasKey;
        if (_hasKey) _apiKey.clear();
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openSignup(String url, bool isZh) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } on PlatformException catch (e) {
      debugPrint('[AiConfig] open signup page failed: $e');
    }
    if (!opened) {
      await Clipboard.setData(ClipboardData(text: url));
      AppToast.success(isZh ? '打不开浏览器，链接已复制' : 'Link copied');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final cs = Theme.of(context).colorScheme;
    final preset = findAiProvider(_provider);

    return Scaffold(
      appBar: AppBar(title: Text(isZh ? 'AI 寻书设置' : 'AI Finder Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _Label(isZh ? 'AI 服务' : 'Provider'),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _provider,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final p in aiProviders)
                      DropdownMenuItem(value: p.id, child: Text(p.name)),
                    DropdownMenuItem(
                      value: customProviderId,
                      child: Text(
                        isZh ? '自定义（兼容 OpenAI）' : 'Custom (OpenAI-compatible)',
                      ),
                    ),
                  ],
                  onChanged: (id) {
                    if (id != null && id != _provider) _selectProvider(id);
                  },
                ),
              ),
              if (preset != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _openSignup(preset.signupUrl, isZh),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: Text(isZh ? '注册' : 'Sign up'),
                ),
              ],
            ],
          ),
          // 智谱 Coding Plan 套餐 Key 条款禁止第三方应用调用，填了会报错，提前提醒
          if (_provider == 'zhipu') ...[
            const SizedBox(height: 6),
            Text(
              isZh
                  ? 'Coding Plan 套餐 Key 不通用'
                  : 'Coding Plan keys are not supported',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 16),

          _Label(isZh ? '接口地址' : 'Base URL'),
          TextField(
            controller: _baseUrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'https://…/v1',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),

          _Label('API Key'),
          TextField(
            controller: _apiKey,
            obscureText: _obscureKey,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: _hasKey
                  ? (isZh ? '已保存，留空不改' : 'Saved, leave blank to keep')
                  : (isZh ? '仅保存在本机' : 'Stored on this device only'),
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 16),

          _Label(isZh ? '模型' : 'Model'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _model,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: isZh ? '获取或手填' : 'Fetch or type',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ListenableBuilder(
                listenable: _apiKey,
                builder: (context, _) => FilledButton.tonalIcon(
                  onPressed:
                      _loadingModels ||
                          (_apiKey.text.trim().isEmpty && !_hasKey)
                      ? null
                      : () => _fetchModels(isZh),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  icon: _loadingModels
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.list_alt_rounded, size: 18),
                  label: Text(isZh ? '获取模型' : 'Fetch'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _Label(isZh ? '每次推荐' : 'Books per search'),
          SegmentedButton<int>(
            segments: [
              for (final n in tipCountOptions)
                ButtonSegment(value: n, label: Text(isZh ? '$n 本' : '$n')),
            ],
            selected: {_tipCount},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _tipCount = s.first),
          ),
          const SizedBox(height: 16),

          _Label(isZh ? '补充要求' : 'Extra instructions'),
          TextField(
            controller: _extra,
            minLines: 1,
            maxLines: 3,
            maxLength: maxExtraPromptChars,
            decoration: InputDecoration(
              hintText: isZh
                  ? '可选，如：只推荐中文书'
                  : 'Optional, e.g. Chinese books only',
              border: const OutlineInputBorder(),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                _error!,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: cs.onErrorContainer,
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : () => _save(isZh),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(isZh ? '保存并测试' : 'Save & test'),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  );
}
