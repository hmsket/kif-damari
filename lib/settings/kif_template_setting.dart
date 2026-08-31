import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kifdamari/logic/kif_parser.dart';
import 'package:kifdamari/widgets/app_settings.dart';

class KifTemplateSetting extends StatelessWidget {
  final AppSettings settings;

  const KifTemplateSetting({
    super.key,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: const Text(
          'フォーマットを変更する',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
        ),
        subtitle: const Text(
          '棋譜カードのタイトルや詳細の形式を設定',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => _KifTemplateEditPage(settings: settings),
            ),
          );
        },
      ),
    );
  }
}

class _KifTemplateEditPage extends StatefulWidget {
  final AppSettings settings;

  const _KifTemplateEditPage({required this.settings});

  @override
  State<_KifTemplateEditPage> createState() => _KifTemplateEditPageState();
}

class _KifTemplateEditPageState extends State<_KifTemplateEditPage> {
  late TextEditingController _titleController;
  late TextEditingController _detailController;
  late TextEditingController _kifTestController;

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _detailFocusNode = FocusNode();

  String _savedTitle = '';
  String _savedDetail = '';
  bool _isSaved = true;

  // 初回表示時のテスト用サンプルテキスト（初期値としてのみ使用）
  static const String _sampleKifText = '''対局日：2026/01/01
棋戦：第67期王位戦
戦型：四間飛車
先手：先手太郎
後手：後手花子''';

  // 現在プレビューに適用中のヘッダーマップ
  Map<String, String> _activeHeaderMap = {};

  @override
  void initState() {
    super.initState();
    _savedTitle = widget.settings.get('kifTitle') ?? '{先手} vs {後手}';
    _savedDetail = widget.settings.get('kifDetail') ?? '{棋戦} / {戦型} / {対局日}';

    _titleController = TextEditingController(text: _savedTitle);
    _detailController = TextEditingController(text: _savedDetail);

    // 初期入力値としてサンプルテキストを設定
    _kifTestController = TextEditingController(text: _sampleKifText);

    // 初回のパースを実行
    _parseTestKif(_sampleKifText);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailController.dispose();
    _kifTestController.dispose();
    _titleFocusNode.dispose();
    _detailFocusNode.dispose();
    super.dispose();
  }

  /// テスト用テキストからヘッダー情報を解析する（入力値のみを純粋に解析）
  void _parseTestKif(String text) {
    final Map<String, String> parsedMap = {};

    // 空文字ならプレビュー用マップも空にして終了
    if (text.trim().isEmpty) {
      setState(() {
        _activeHeaderMap = {};
      });
      return;
    }

    // 1. 行ごとに読み込み、「項目名：値」を抽出
    final lines = text.split('\n');
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.contains('：')) {
        final parts = trimmed.split('：');
        if (parts.length >= 2) {
          parsedMap[parts[0].trim()] = parts.sublist(1).join('：').trim();
        }
      } else if (trimmed.contains(':')) {
        final parts = trimmed.split(':');
        if (parts.length >= 2) {
          parsedMap[parts[0].trim()] = parts.sublist(1).join(':').trim();
        }
      }
    }

    // 2. KifParser での解析（補完用）
    try {
      final tree = KifParser.decode(text);
      tree.info.forEach((key, value) {
        if (value.isNotEmpty) {
          parsedMap[key] = value;
        }
      });
    } catch (_) {}

    setState(() {
      _activeHeaderMap = parsedMap;
    });
  }

  /// クリップボードからテスト用テキストエリアに貼り付ける
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _kifTestController.text = data.text!;
      _parseTestKif(data.text!);
    }
  }

  /// 現在フォーカスのある（または直前に操作していた）テキストフィールドに `{}` を挿入する
  void _insertBracesToActiveField() {
    final controller = _detailFocusNode.hasFocus ? _detailController : _titleController;

    final text = controller.text;
    final selection = controller.selection;

    int start = selection.start;
    int end = selection.end;

    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

    final newText = text.replaceRange(start, end, '{}');
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + 1),
    );

    _checkSaveStatus();
  }

  /// 保存状態の更新判定
  void _checkSaveStatus() {
    final currentTitle = _titleController.text.trim();
    final currentDetail = _detailController.text.trim();

    setState(() {
      _isSaved = (currentTitle == _savedTitle) && (currentDetail == _savedDetail);
    });
  }

  /// テンプレート文字列内の `{キー名}` を解析結果で置換する
  String _generatePreviewText(String template) {
    return template.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (match) {
      final key = match.group(1)!;
      return _activeHeaderMap[key] ?? '';
    });
  }

  /// 設定の保存処理
  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final title = _titleController.text.trim();
    final detail = _detailController.text.trim();

    final newTitle = title.isNotEmpty ? title : '{先手} vs {後手}';
    final newDetail = detail.isNotEmpty ? detail : '{棋戦} / {戦型} / {対局日}';

    await widget.settings.set('kifTitle', newTitle);
    await widget.settings.set('kifDetail', newDetail);

    setState(() {
      _savedTitle = newTitle;
      _savedDetail = newDetail;
      _isSaved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final previewTitle = _generatePreviewText(_titleController.text);
    final previewDetail = _generatePreviewText(_detailController.text);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isSaved ? Colors.green[600] : Colors.red[600],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _isSaved ? '保存済み' : '未保存',
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _save,
              child: const Text('保存', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        backgroundColor: const Color(0XFFF1F1F5),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. プレビューカード
                const Text(
                  '棋譜カードのプレビュー',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Card(
                  color: Colors.white,
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: EdgeInsets.zero,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset('assets/images/initial.png', fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 120,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  previewTitle.isNotEmpty ? previewTitle : 'タイトル未設定',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: Text(
                                    previewDetail.isNotEmpty ? previewDetail : '詳細未設定',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. フォーマット入力欄ヘッダー
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'フォーマット入力欄',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54),
                    ),
                    InkWell(
                      onTap: _insertBracesToActiveField,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black26),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          ' { } を追加',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 3. 入力フォームエリア
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleController,
                        focusNode: _titleFocusNode,
                        onChanged: (_) => _checkSaveStatus(),
                        decoration: const InputDecoration(
                          labelText: 'タイトル用フォーマット',
                          hintText: '例: {先手} vs {後手}',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _detailController,
                        focusNode: _detailFocusNode,
                        keyboardType: TextInputType.multiline,
                        minLines: 1,
                        maxLines: 4,
                        onChanged: (_) => _checkSaveStatus(),
                        decoration: const InputDecoration(
                          labelText: '詳細用フォーマット',
                          hintText: '例: {棋戦} / {戦型} / {対局日}',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

// 4 & 5. テスト用 KIF データ（アコーディオン式）
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  color: Colors.white,
                  clipBehavior: Clip.antiAlias, // 💡 追加：波紋が角からはみ出さないようにクリップする
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      // 💡 閉じた時と開いた時の形に角丸を指定する
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide.none,
                      ),
                      collapsedShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide.none,
                      ),
                      title: const Text(
                        'KIF データ（確認用）',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
                      ),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            InkWell(
                              onTap: _pasteFromClipboard,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.black26),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.content_paste, size: 14, color: Colors.black87),
                                    SizedBox(width: 4),
                                    Text(
                                      '貼り付け',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _kifTestController,
                          builder: (context, value, child) {
                            return TextField(
                              controller: _kifTestController,
                              keyboardType: TextInputType.multiline,
                              minLines: 4,
                              maxLines: 7,
                              onChanged: _parseTestKif,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'ここにKIFデータを貼り付けるとプレビューに反映されます',
                                hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.all(10),
                                suffixIcon: value.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _kifTestController.clear();
                                          _parseTestKif('');
                                        },
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '「：」の前の項目名を {先手} や {棋戦} のように { } で囲むと自動置換されます。',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
