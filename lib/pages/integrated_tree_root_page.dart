import 'package:flutter/material.dart';
import 'package:kifdamari/database/entity/position_entity.dart';
import 'package:kifdamari/logic/integrated_tree_service.dart';
import 'package:kifdamari/logic/sfen_generator.dart';
import 'package:kifdamari/pages/integrated_tree_page.dart';
import 'package:kifdamari/widgets/kif_board.dart';

/// 統合ツリーの根（開始局面）を選ぶ画面（仕様 F.2）
class IntegratedTreeRootPage extends StatefulWidget {
  const IntegratedTreeRootPage({super.key});

  @override
  State<IntegratedTreeRootPage> createState() => _IntegratedTreeRootPageState();
}

class _IntegratedTreeRootPageState extends State<IntegratedTreeRootPage> {
  bool _isLoading = true;
  List<IntegratedTreeRootSummary> _rootSummaries = const [];
  final Map<int, BoardState> _stateByRootId = {};

  @override
  void initState() {
    super.initState();
    _loadRoots();
  }

  Future<void> _loadRoots() async {
    final summaries = await IntegratedTreeService.listRoots();
    if (!mounted) return;
    setState(() {
      _rootSummaries = summaries;
      for (final summary in summaries) {
        try {
          _stateByRootId[summary.position.id!] =
              SfenGenerator.stateFromKey(summary.position.positionKey);
        } catch (_) {
          // 復元できない根は文字盤サムネイル無しで表示する
        }
      }
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFFF1F1F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('統合ツリー'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _rootSummaries.isEmpty
                ? const Center(
                    child: Text(
                      'まだ統合ツリーに登録された棋譜がありません\n（棋譜を開くと自動で登録されます）',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      setState(() => _isLoading = true);
                      await _loadRoots();
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _rootSummaries.length,
                      itemBuilder: (context, index) {
                        final summary = _rootSummaries[index];
                        return _buildRootRow(summary);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildRootRow(IntegratedTreeRootSummary summary) {
    final PositionEntity root = summary.position;
    final BoardState? state = _stateByRootId[root.id];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IntegratedTreePage(rootPosition: root),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // 開始局面のミニ盤サムネイル
              SizedBox(
                width: 92,
                height: 96,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: state != null ? KifBoard(state: state) : const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.kindLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'この根の棋譜 ${summary.kifuCount} 件・局面 ${summary.positionCount}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
