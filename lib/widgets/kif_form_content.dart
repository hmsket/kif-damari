import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:kifdamari/database/entity/tab_entity.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';

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

  late int _selectedTabId;
  late int _selectedColor;
  String? _kfilePath;
  late String _fileNameDisplay;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialKif?.title ?? '');
    _detailController = TextEditingController(text: widget.initialKif?.detail ?? '');
    _selectedTabId = widget.initialTabId;
    _selectedColor = widget.initialKif?.color ?? 0xFFFFFFFF;
    _kfilePath = widget.initialKif?.kifPath;

    _fileNameDisplay = Uri.parse(widget.initialKif?.kifPath ?? "").pathSegments.isNotEmpty
        ? Uri.parse(widget.initialKif!.kifPath!).pathSegments.last
        : "未選択";
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Text(widget.initialKif == null ? '棋譜を追加' : '棋譜を編集'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Color(_selectedColor), 
                  borderRadius: BorderRadius.circular(8),
                ),
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
                            children: [
                              TextField(
                                controller: _titleController,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'タイトルを入力',
                                  filled: true,
                                  fillColor: Colors.grey.withOpacity(0.1),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                  enabledBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey, width: 1),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: TextField(
                                  controller: _detailController,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText: '詳細を入力',
                                    filled: true,
                                    fillColor: Colors.grey.withOpacity(0.1),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.all(2),
                                    enabledBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(color: Colors.grey, width: 1),
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
              const SizedBox(height: 20),
              DropdownMenu<int>(
                label: const Text('タブ'),
                expandedInsets: EdgeInsets.zero,
                inputDecorationTheme: const InputDecorationTheme(
                  border: UnderlineInputBorder(),
                ),
                menuStyle: MenuStyle(
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                initialSelection: _selectedTabId,
                onSelected: (value) => setState(() => _selectedTabId = value!),
                dropdownMenuEntries: widget.tabs.map((t) {
                  return DropdownMenuEntry<int>(value: t.id!, label: t.title);
                }).toList(),
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: _pickKifFile,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'kifファイル',
                    suffixIcon: const Icon(Icons.upload_file),
                    errorText: widget.errorMessage,
                  ),
                  child: Text(
                    _fileNameDisplay,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              DropdownMenu<int>(
                label: const Text('色'),
                menuHeight: 300,
                expandedInsets: EdgeInsets.zero, 
                inputDecorationTheme: const InputDecorationTheme(
                  border: UnderlineInputBorder(),
                ),
                menuStyle: MenuStyle(
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                initialSelection: _selectedColor,
                onSelected: (val) => setState(() => _selectedColor = val!),
                dropdownMenuEntries: _buildColorEntries(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        TextButton(
          onPressed: (widget.initialKif == null && _kfilePath == null) || widget.errorMessage != null
              ? null
              : () => widget.onSubmit(
                    tabId: _selectedTabId,
                    title: _titleController.text,
                    detail: _detailController.text,
                    kifPath: _kfilePath,
                    color: _selectedColor,
                  ),
          child: Text(widget.confirmButtonText, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Future<void> _pickKifFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null) {
        final file = result.files.single;
        final fileName = file.name;

        if (fileName.toLowerCase().endsWith('.kif')) {
          setState(() {
            _kfilePath = file.path;
            _fileNameDisplay = fileName;
          });
          widget.onErrorMessageChanged(null);
        } else {
          widget.onErrorMessageChanged("拡張子が .kif のファイルを選択してください");
        }
      }
    } catch (e) {
      widget.onErrorMessageChanged("ファイルの取得に失敗しました");
    }
  }

  List<DropdownMenuEntry<int>> _buildColorEntries() {
    final colorData = [
      {'value': 0xFFFFFFFF, 'label': 'white'},
      {'value': 0xFFF7D6D3, 'label': 'red'},
      {'value': 0xFFFFE6C7, 'label': 'orange'},
      {'value': 0xFFFFF6CC, 'label': 'yellow'},
      {'value': 0xFFE6F5D6, 'label': 'green'},
      {'value': 0xFFDFF5EE, 'label': 'teal'},
      {'value': 0xFFE3F1F8, 'label': 'blue'},
      {'value': 0xFFE0E9FB, 'label': 'dark_blue'},
      {'value': 0xFFE9DDF8, 'label': 'violet'},
      {'value': 0xFFF9DDEA, 'label': 'pink'},
      {'value': 0xFFEEE4D6, 'label': 'brown'},
      {'value': 0xFFEFF1F4, 'label': 'gray'},
    ];
    return colorData.map((data) => DropdownMenuEntry<int>(
      value: data['value'] as int,
      label: data['label'] as String,
      style: MenuItemButton.styleFrom(
        backgroundColor: Color(data['value'] as int),
      ),
    )).toList();
  }
}
