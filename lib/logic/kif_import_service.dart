import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/logic/kif_file_reader.dart';
import 'package:kifdamari/logic/kif_parser.dart';
import 'package:kifdamari/models/kif_tree.dart';
import 'package:kifdamari/widgets/app_settings.dart';
import 'package:kifdamari/widgets/kif_colors.dart';

/// 他のアプリから受け取った棋譜ファイルを、現在のタブへ新規棋譜として登録する。
class KifImportService {
  const KifImportService();

  /// [uri] のファイルを解析して [tabId] のタブへ登録し、登録した棋譜を返す。
  ///
  /// 解析できない場合は例外を投げ、DB には登録しない。
  Future<KifEntity> importFromUri({
    required String uri,
    required int tabId,
  }) async {
    final content = await KifFileReader.readText(uri);
    if (content == null) {
      throw Exception('棋譜ファイルを読み込めません');
    }

    final tree = KifParser.decode(content);

    final dao = KifDao();
    final settings = AppSettings();
    final maxKifId = await dao.getMaxKifId(tabId);
    final values = _templateValues(tree);

    final kif = KifEntity(
      tabId: tabId,
      kifId: maxKifId + 1,
      title: _applyTemplate(settings.get<String>('kifTitle'), values),
      detail: _applyTemplate(settings.get<String>('kifDetail'), values),
      kifOrder: maxKifId + 1,
      kifPath: uri,
      color: KifColors.resolveDefaultColor(settings),
    );

    final insertedId = await dao.insertKif(kif);

    return KifEntity(
      id: insertedId,
      tabId: kif.tabId,
      kifId: kif.kifId,
      title: kif.title,
      detail: kif.detail,
      kifOrder: kif.kifOrder,
      kifPath: kif.kifPath,
      color: kif.color,
    );
  }

  Map<String, String> _templateValues(KifTree tree) {
    final info = tree.info;
    final values = <String, String>{
      '先手': info['先手'] ?? '先手',
      '後手': info['後手'] ?? '後手',
      '棋戦': info['棋戦'] ?? info['イベント'] ?? '',
      '戦型': info['戦型'] ?? '',
      '対局日': info['対局日'] ??
          info['開始日時'] ??
          info['対局日時'] ??
          info['日付'] ??
          '',
    };
    info.forEach((key, value) {
      values[key] = value;
    });
    return values;
  }

  String _applyTemplate(String template, Map<String, String> values) {
    return template.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (match) {
      final key = match.group(1)!;
      return values[key] ?? '';
    });
  }
}
