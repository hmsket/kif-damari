import 'package:flutter/material.dart';
import '../database/dao/kif_dao.dart';
import '../database/entity/kif_entity.dart';
import '../main.dart';
import 'kif_list_item.dart';

class KifListWidget extends StatelessWidget {
  final int tabId;
  final AppMode mode;
  final VoidCallback onRefresh;

  const KifListWidget({
    super.key,
    required this.tabId,
    required this.mode,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<KifEntity>>(
      future: KifDao().getKifsByTab(tabId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final kifs = snapshot.data ?? [];
        if (kifs.isEmpty) {
          return const Center(child: Text('棋譜がまだありません'));
        }

        return ListView.builder(
          itemCount: kifs.length,
          itemBuilder: (context, index) {
            return KifListItem(
              kif: kifs[index],
              mode: mode,
              onRefresh: onRefresh,
            );
          },
        );
      },
    );
  }
}
