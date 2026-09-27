import 'package:flutter/material.dart';
import 'package:kifdamari/database/entity/tab_entity.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/snackbars/show_error_snackbar.dart';

class KifFormContent extends StatefulWidget {
  final KifEntity? initialKif;
  final List<TabEntity> tabs;
  final int initialTabId;
  final String confirmButtonText;
  final String? errorMessage;
  final Function(String? error) onErrorMessageChanged;
  final Future<void> Function({
    required int tabId,
    required String title,
    required String detail,
    required String? kifPath,
    required int color,
  }) onSubmit;

  const KifFormContent({
    super.key,
    this.initialKif,
    required this.tabs,
    required this.initialTabId,
    required this.confirmButtonText,
    required this.errorMessage,
    required this.onErrorMessageChanged,
    required this.onSubmit,
  });

  @override
  State<KifFormContent> createState() => _KifFormContentState();
}

class _KifFormContentState extends State<KifFormContent> {
  late final TextEditingController _titleController;
  late final TextEditingController _detailController;

  final FocusNode _tabFocusNode = FocusNode();
  final FocusNode _colorFocusNode = FocusNode();

  late int _selectedTabId;
  late int _selectedColor;
  String? _kfilePath;

  static const List<Map<String, dynamic>> _colorData = [
    {'value': 0xFFFFFFFF, 'label': 'white', 'textColor': Colors.black87},
    {'value': 0xFFF7D6D3, 'label': 'red', 'textColor': Colors.black87},
    {'value': 0xFFFFE6C7, 'label': 'orange', 'textColor': Colors.black87},
    {'value': 0xFFFFF6CC, 'label': 'yellow', 'textColor': Colors.black87},
    {'value': 0xFFE6F5D6, 'label': 'green', 'textColor': Colors.black87},
    {'value': 0xFFDFF5EE, 'label': 'teal', 'textColor': Colors.black87},
    {'value': 0xFFE3F1F8, 'label': 'blue', 'textColor': Colors.black87},
    {'value': 0xFFE0E9FB, 'label': 'dark_blue', 'textColor': Colors.black87},
    {'value': 0xFFE9DDF8, 'label': 'violet', 'textColor': Colors.black87},
    {'value': 0xFFF9DDEA, 'label': 'pink', 'textColor': Colors.black87},
    {'value': 0xFFEEE4D6, 'label': 'brown', 'textColor': Colors.black87},
    {'value': 0xFFEFF1F4, 'label': 'gray', 'textColor': Colors.black87},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialKif?.title ?? '');
    _detailController = TextEditingController(text: widget.initialKif?.detail ?? '');

    final tabExists = widget.tabs.any((t) => t.id == widget.initialTabId);
    _selectedTabId = (tabExists && widget.tabs.isNotEmpty)
        ? widget.initialTabId
        : (widget.tabs.isNotEmpty ? widget.tabs.first.id! : 0);

    final initialColor = widget.initialKif?.color ?? 0xFFFFFFFF;
    final colorExists = _colorData.any((c) => c['value'] == initialColor);
    _selectedColor = colorExists ? initialColor : 0xFFFFFFFF;

    _kfilePath = widget.initialKif?.kifPath;

    _tabFocusNode.addListener(() => setState(() {}));
    _colorFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailController.dispose();
    _tabFocusNode.dispose();
    _colorFocusNode.dispose();
    super.dispose();
  }

  void _showThumbnailInfoSnackBar() {
    ShowErrorSnackbar.show(context, '盤面サムネイルは棋譜再生画面から変更してください');
  }

  Color _getLabelColor(FocusNode focusNode) {
    if (widget.errorMessage != null) {
      return Colors.redAccent;
    }
    if (focusNode.hasFocus) {
      return const Color(0xFF222222);
    }
    return const Color(0xFF888888);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0), // 16.0 -> 32.0 に調整
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.0),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.initialKif == null ? '棋譜を追加' : '棋譜を編集',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // プレビューカード
                      Container(
                        decoration: BoxDecoration(
                          color: Color(_selectedColor),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCCCCCC), width: 1.0),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: _showThumbnailInfoSnackBar,
                              child: SizedBox(
                                width: 100,
                                height: 100,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.asset('assets/images/initial.png', fit: BoxFit.contain),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: SizedBox(
                                height: 100,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(0, 6, 8, 6),
                                  child: Column(
                                    children: [
                                      TextField(
                                        controller: _titleController,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                        onChanged: (_) => setState(() {}),
                                        decoration: InputDecoration(
                                          hintText: 'タイトルを入力',
                                          hintStyle: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                                          filled: true,
                                          fillColor: Colors.black.withOpacity(0.03),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                          border: InputBorder.none,
                                          enabledBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(color: Colors.black.withOpacity(0.2), width: 1),
                                          ),
                                          focusedBorder: const UnderlineInputBorder(
                                            borderSide: BorderSide(color: Color(0xFF222222), width: 1.5),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Expanded(
                                        child: TextField(
                                          controller: _detailController,
                                          style: const TextStyle(fontSize: 11, color: Colors.black87),
                                          maxLines: null,
                                          expands: true,
                                          textAlignVertical: TextAlignVertical.top,
                                          onChanged: (_) => setState(() {}),
                                          decoration: InputDecoration(
                                            hintText: '詳細を入力',
                                            hintStyle: const TextStyle(color: Color(0xFF888888), fontSize: 11),
                                            filled: true,
                                            fillColor: Colors.black.withOpacity(0.03),
                                            isDense: true,
                                            contentPadding: const EdgeInsets.all(4),
                                            border: InputBorder.none,
                                            enabledBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(color: Colors.black.withOpacity(0.2), width: 1),
                                            ),
                                            focusedBorder: const UnderlineInputBorder(
                                              borderSide: BorderSide(color: Color(0xFF222222), width: 1.5),
                                            ),
                                          ),
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
                      const SizedBox(height: 14),

                      // タブ選択プルダウン（横幅を適正に絞りコンパクトに）
                      if (widget.tabs.isNotEmpty)
                        DropdownButtonFormField<int>(
                          focusNode: _tabFocusNode,
                          value: _selectedTabId,
                          borderRadius: BorderRadius.circular(16),
                          dropdownColor: Colors.white,
                          focusColor: Colors.transparent,
                          menuMaxHeight: 320,
                          itemHeight: 48,
                          decoration: InputDecoration(
                            labelText: 'タブ',
                            labelStyle: TextStyle(
                              color: _getLabelColor(_tabFocusNode),
                              fontSize: 13,
                              fontWeight: (_tabFocusNode.hasFocus || widget.errorMessage != null)
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFFAFAFA),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCCCCCC), width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF222222), width: 1.5),
                            ),
                          ),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedTabId = value);
                            }
                          },
                          // 選択済みの表示（入力枠内）
                          selectedItemBuilder: (context) {
                            return widget.tabs.map((t) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  t.title,
                                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                                ),
                              );
                            }).toList();
                          },
                          // ポップアップリストの各項目
                          items: widget.tabs.asMap().entries.map((entry) {
                            final index = entry.key;
                            final t = entry.value;
                            final isSelected = t.id == _selectedTabId;

                            return DropdownMenuItem<int>(
                              value: t.id!,
                              child: Container(
                                height: 48,
                                alignment: Alignment.centerLeft,
                                decoration: BoxDecoration(
                                  border: index < widget.tabs.length - 1
                                      ? const Border(
                                          bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1.0),
                                        )
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        t.title,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isSelected ? const Color(0xFF222222) : Colors.black87,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.check,
                                        size: 18,
                                        color: Color(0xFF222222),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 12),

                      // カラー選択プルダウン
// カラー選択プルダウン（タブと同様の仕切り線＆スッキリデザイン）
                      DropdownButtonFormField<int>(
                        focusNode: _colorFocusNode,
                        value: _selectedColor,
                        borderRadius: BorderRadius.circular(16),
                        dropdownColor: Colors.white, // ポップアップ背景を純白に統一
                        focusColor: Colors.transparent, // タップ時の標準灰色背景を無効化
                        menuMaxHeight: 320,
                        itemHeight: 48,
                        decoration: InputDecoration(
                          labelText: '色',
                          labelStyle: TextStyle(
                            color: _getLabelColor(_colorFocusNode),
                            fontSize: 13,
                            fontWeight: (_colorFocusNode.hasFocus || widget.errorMessage != null)
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFFAFAFA),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCCCCCC), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF222222), width: 1.5),
                          ),
                        ),
                        // 選択済みの表示（入力枠内）
                        selectedItemBuilder: (context) {
                          return _colorData.map((data) {
                            final colorVal = data['value'] as int;
                            final label = data['label'] as String;

                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 入力枠内にも色の丸を表示
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: Color(colorVal),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black26, width: 0.8),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    label,
                                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                                  ),
                                ],
                              ),
                            );
                          }).toList();
                        },
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedColor = val);
                          }
                        },
                        // メニュー項目（仕切り線＋カラーチップ＋チェックマーク）
                        items: _colorData.asMap().entries.map((entry) {
                          final index = entry.key;
                          final data = entry.value;
                          final colorVal = data['value'] as int;
                          final label = data['label'] as String;
                          final isSelected = colorVal == _selectedColor;

                          return DropdownMenuItem<int>(
                            value: colorVal,
                            child: Container(
                              height: 48,
                              alignment: Alignment.centerLeft,
                              decoration: BoxDecoration(
                                // 最後の項目以外に薄い仕切り線を引く
                                border: index < _colorData.length - 1
                                    ? const Border(
                                        bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1.0),
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  // カラープレビュー用の円
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: Color(colorVal),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black26, width: 0.8),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isSelected ? const Color(0xFF222222) : Colors.black87,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  // 選択中項目の右側にチェックマークを表示
                                  if (isSelected)
                                    const Icon(
                                      Icons.check,
                                      size: 18,
                                      color: Color(0xFF222222),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      if (widget.errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ボタンエリア
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: const BorderSide(color: Color(0xFFCCCCCC), width: 1.5),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      'キャンセル',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      widget.onSubmit(
                        tabId: _selectedTabId,
                        title: _titleController.text,
                        detail: _detailController.text,
                        kifPath: _kfilePath,
                        color: _selectedColor,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF222222),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      widget.confirmButtonText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
