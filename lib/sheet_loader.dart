// =============================================================================
// sheet_loader.dart - Google スプレッドシート(教材入力シート)を読み込む
//
//   シートの4つのタブ lessons / assignments / notices / vocabulary を
//   CSV としてダウンロードし、content.json と同じ形の Map に変換します。
//   1行目 = 列の名前、2行目 = 書き方の説明(読み飛ばす)、3行目から = データ
// =============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

const _tabs = ['lessons', 'assignments', 'notices', 'vocabulary'];

/// シートを読み込んで {lessons: [...], assignments: [...], ...} を返す。
/// どれか1つでも読めなければ例外を投げる(→ 呼び出し側で前回の内容を使う)。
Future<Map<String, dynamic>> loadContentFromSheet(String sheetId) async {
  final result = <String, dynamic>{};
  for (final tab in _tabs) {
    final url = Uri.parse(
        'https://docs.google.com/spreadsheets/d/$sheetId/gviz/tq'
        '?tqx=out:csv&headers=1&sheet=$tab');
    final res = await http.get(url).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Sheet "$tab": HTTP ${res.statusCode}');
    }
    final text = utf8.decode(res.bodyBytes);
    if (text.trimLeft().startsWith('<')) {
      // HTML が返ってきた = シートが共有されていない
      throw Exception('Sheet "$tab" is not shared (anyone with the link)');
    }
    final rows = _parseCsv(text);
    result[tab] = _rowsToMaps(tab, rows);
  }
  return result;
}

/// CSV の行 → Map のリストに変換(タブごとの決まりもここで処理)
List<Map<String, dynamic>> _rowsToMaps(String tab, List<List<String>> rows) {
  if (rows.isEmpty) return [];
  final header = rows.first.map((h) => h.trim()).toList();
  final idOk = RegExp(r'^[A-Za-z0-9_\-]+$');
  final out = <Map<String, dynamic>>[];

  for (final r in rows.skip(1)) {
    final m = <String, dynamic>{};
    for (var i = 0; i < header.length && i < r.length; i++) {
      if (header[i].isEmpty) continue;
      m[header[i]] = r[i].trim();
    }
    final id = '${m['id'] ?? ''}';
    // 空行・説明の行(2行目)は読み飛ばす
    if (!idOk.hasMatch(id)) continue;

    // 日付: "2026/12/10" → "2026-12-10"
    for (final k in ['publishedAt', 'availableUntil', 'dueDate', 'date']) {
      if (m[k] != null) m[k] = _normDate('${m[k]}');
    }
    // 数字の列
    for (final k in ['number', 'minutes', 'maxScore']) {
      if (m.containsKey(k)) m[k] = _toInt('${m[k]}');
    }
    // lessons.materials: "タイトル|URL;タイトル|URL"
    if (tab == 'lessons') {
      m['materials'] = _split('${m['materials'] ?? ''}')
          .where((s) => s.contains('|'))
          .map((s) {
        final i = s.indexOf('|');
        return {
          'title': s.substring(0, i).trim(),
          'url': s.substring(i + 1).trim(),
        };
      }).toList();
    }
    // vocabulary.tags: "Writing;time"
    if (tab == 'vocabulary') {
      m['tags'] = _split('${m['tags'] ?? ''}');
    }
    out.add(m);
  }
  return out;
}

List<String> _split(String s) =>
    s.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

int _toInt(String s) => double.tryParse(s.trim())?.round() ?? 0;

/// いろいろな日付の書き方を "YYYY-MM-DD" / "YYYY-MM-DD HH:MM" にそろえる
String _normDate(String s) {
  final t = s.trim();
  final m = RegExp(r'^(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})(?:[ T](\d{1,2}):(\d{2}))?')
      .firstMatch(t);
  if (m == null) return t;
  String two(String? x) => (x ?? '').padLeft(2, '0');
  final date = '${m[1]}-${two(m[2])}-${two(m[3])}';
  return m[4] == null ? date : '$date ${two(m[4])}:${m[5]}';
}

/// シンプルな CSV 読み取り("..." の中のカンマ・改行・"" に対応)
List<List<String>> _parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(c);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}
