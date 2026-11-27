// =============================================================================
// portfolio_export.dart - ポートフォリオを「1つのファイル」にまとめる
//
//   作文・録音・写真・PDF・受講記録・学習時間を 1 つの HTML ファイルにする。
//   ブラウザで開くと読めて、録音もその場で再生できる。
//   ブラウザの「印刷」→「PDF に保存」で PDF にもできる。
// =============================================================================

import 'dart:convert';
import 'dart:typed_data';
import 'app_data.dart';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _mime(String name) {
  final ext = name.split('.').last.toLowerCase();
  const m = {
    'pdf': 'application/pdf',
    'm4a': 'audio/mp4',
    'mp3': 'audio/mpeg',
    'webm': 'audio/webm',
    'wav': 'audio/wav',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'txt': 'text/plain',
  };
  return m[ext] ?? 'application/octet-stream';
}

/// ファイル名: Portfolio_S2026-0142_2026-12-20.html
String portfolioFileName(AppData d) {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final id = d.studentId.isEmpty ? 'student' : d.studentId;
  return 'Portfolio_${id}_$today.html';
}

Future<Uint8List> buildPortfolioHtml(AppData d) async {
  final b = StringBuffer();
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final lessons = List.of(d.lessons)
    ..sort((a, c) => a.number.compareTo(c.number));
  final totalMin = d.logs.fold<int>(0, (a, l) => a + l.minutes);
  final days = d.logs.map((l) => l.date.split(' ').first).toSet().length;
  final completed = lessons.where((l) => d.lessonCompleted(l.id)).length;

  b.write('''<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Portfolio - ${_esc(d.userName)}</title>
<style>
body{font-family:-apple-system,"Hiragino Sans","Noto Sans JP",Arial,sans-serif;max-width:860px;margin:0 auto;padding:24px;color:#1a1c2e;line-height:1.6}
h1{color:#3F51B5;margin-bottom:0}h2{border-bottom:3px solid #3F51B5;padding-bottom:4px;margin-top:36px}
.sub{color:#666}.stats{display:flex;gap:12px;flex-wrap:wrap;margin:16px 0}
.stat{background:#eef0fb;border-radius:12px;padding:12px 16px;min-width:120px}
.stat b{display:block;font-size:24px;color:#3F51B5}
table{border-collapse:collapse;width:100%}td,th{border:1px solid #ddd;padding:6px 8px;text-align:left;font-size:14px}
th{background:#3F51B5;color:#fff}.ok{color:#2e7d32;font-weight:700}.late{color:#e65100;font-weight:700}
.item{border:1px solid #ddd;border-radius:12px;padding:14px;margin:14px 0;page-break-inside:avoid}
.item h3{margin:0 0 4px}.meta{color:#666;font-size:13px}
pre{white-space:pre-wrap;font-family:inherit;font-size:17px;background:#fafafa;padding:12px;border-radius:8px}
img{max-width:100%;border-radius:8px}audio{width:100%;margin-top:8px}
.note{background:#fff8e1;padding:8px 12px;border-radius:8px;margin-top:8px}
@media print{audio{display:none}}
</style></head><body>
<h1>My Japanese Portfolio</h1>
<div class="sub">${_esc(d.userName)} &nbsp;·&nbsp; ID: ${_esc(d.studentId)}${d.className.isEmpty ? '' : ' &nbsp;·&nbsp; ${_esc(d.className)}'} &nbsp;·&nbsp; Created: $today</div>
<div class="stats">
<div class="stat"><b>$completed / ${lessons.length}</b>Lessons completed</div>
<div class="stat"><b>$totalMin</b>Minutes studied</div>
<div class="stat"><b>$days</b>Study days</div>
<div class="stat"><b>${d.submissions.length}</b>Works submitted</div>
</div>
''');

  // ---- 受講記録 ----
  b.write('<h2>Lessons</h2><table><tr><th>Lesson</th><th>Study period</th><th>Started</th><th>Completed</th><th>Result</th></tr>');
  for (final l in lessons) {
    final r = d.lessonRecord(l.id);
    final done = d.lessonCompleted(l.id);
    final result = !done
        ? (d.lessonStarted(l.id) ? 'In progress' : '-')
        : (d.lessonOnTime(l) ? '<span class="ok">On time</span>' : '<span class="late">Late</span>');
    b.write('<tr><td>${l.number}. ${_esc(l.title)}</td>'
        '<td>${_esc(l.publishedAt)} – ${_esc(l.availableUntil)}</td>'
        '<td>${_esc('${r?['startedAt'] ?? ''}')}</td>'
        '<td>${_esc('${r?['completedAt'] ?? ''}')}</td><td>$result</td></tr>');
  }
  b.write('</table>');

  // ---- 作文(最後の下書き)----
  final essayIds = d.drafts.map((x) => x.assignmentId).toSet();
  if (essayIds.isNotEmpty) {
    b.write('<h2>Essays</h2>');
    for (final id in essayIds) {
      final list = d.draftsFor(id);
      if (list.isEmpty) continue;
      final last = list.first; // いちばん新しい版
      final title = d.assignment(id)?.title ?? id;
      b.write('<div class="item"><h3>${_esc(title)}</h3>'
          '<div class="meta">${list.length} drafts · last saved ${_esc(last.savedAt.replaceFirst('T', ' ').split('.').first)} · '
          '${last.charCount} characters · ${last.usedVocabIds.length} textbook words used</div>'
          '<pre>${_esc(last.text)}</pre></div>');
    }
  }

  // ---- 提出物(ファイルは中に埋め込む)----
  final subs = List.of(d.submissions)
    ..sort((a, c) => a.dateTime.compareTo(c.dateTime));
  if (subs.isNotEmpty) {
    b.write('<h2>Submitted work</h2>');
    for (final s in subs) {
      final bytes = await d.fetchFile(s.id);
      final when = s.submittedAt.replaceFirst('T', ' ').split('.').first;
      final task = d.assignment(s.assignmentId)?.title ?? '';
      b.write('<div class="item"><h3>${_esc(s.title)}</h3>'
          '<div class="meta">${_esc(when)}${task.isEmpty || task == s.title ? '' : ' · ${_esc(task)}'} · ${_esc(s.fileName)}</div>');
      if (bytes == null) {
        b.write('<p class="meta">(The file could not be loaded.)</p>');
      } else {
        final uri = 'data:${_mime(s.fileName)};base64,${base64Encode(bytes)}';
        switch (s.fileType) {
          case 'text':
            b.write('<pre>${_esc(utf8.decode(bytes, allowMalformed: true))}</pre>');
            break;
          case 'image':
            b.write('<img src="$uri" alt="">');
            break;
          case 'audio':
            b.write('<audio controls src="$uri"></audio>');
            break;
          default:
            b.write('<p><a download="${_esc(s.fileName)}" href="$uri">Download ${_esc(s.fileName)}</a></p>');
        }
      }
      if (s.note.isNotEmpty) {
        b.write('<div class="note"><b>My note:</b> ${_esc(s.note)}</div>');
      }
      if (s.teacherComment.isNotEmpty) {
        b.write('<div class="note"><b>Teacher:</b> ${_esc(s.teacherComment)}</div>');
      }
      b.write('</div>');
    }
  }

  // ---- 学習記録 ----
  if (d.logs.isNotEmpty) {
    b.write('<h2>Study log</h2><table><tr><th>Date</th><th>Minutes</th><th>Category</th><th>Note</th></tr>');
    final logs = List.of(d.logs)..sort((a, c) => a.date.compareTo(c.date));
    for (final l in logs) {
      b.write('<tr><td>${_esc(l.date)}</td><td>${l.minutes}</td>'
          '<td>${_esc(l.category)}</td><td>${_esc(l.note)}</td></tr>');
    }
    b.write('</table>');
  }

  b.write('<p class="sub" style="margin-top:40px">Made with Nihongo Study Hub</p></body></html>');
  return Uint8List.fromList(utf8.encode(b.toString()));
}
