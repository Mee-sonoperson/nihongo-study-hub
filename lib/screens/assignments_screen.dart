// =============================================================================
// assignments_screen.dart - 宿題・テスト
//   AssignmentsScreen      : 一覧(To do / Done タブ)
//   AssignmentDetailScreen : 詳細 + ファイル提出(PDF・音声・画像)+ 点数入力
//   AssignmentTile         : 一覧の1行(ホーム画面でも使う)
//   pickAndSubmitFile      : ファイルを選んで提出する共通関数
// =============================================================================

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_data.dart';
import '../helpers.dart';
import 'essay_screen.dart';
import 'flow_screens.dart' show openLink, ExampleImages;
import 'lessons_screen.dart';
import 'notices_screen.dart';
import 'portfolio_screen.dart';

// -----------------------------------------------------------------------------
// 一覧
// -----------------------------------------------------------------------------
class AssignmentsScreen extends StatelessWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final todo = data.pendingAssignments;
    final done = data.doneAssignments;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Homework & Tests'),
          actions: [
            IconButton(
              tooltip: 'Portfolio',
              icon: const Icon(Icons.folder_special_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PortfolioScreen()),
              ),
            ),
          ],
          bottom: TabBar(
            labelColor: kPrimary,
            indicatorColor: kPrimary,
            tabs: [
              Tab(text: 'To do (${todo.length})'),
              Tab(text: 'Done (${done.length})'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _list(todo, 'Nothing to do. Enjoy your free time!'),
              _list(done, 'No completed tasks yet.'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddDialog(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add my task',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _list(List<Assignment> items, String emptyText) {
    if (items.isEmpty) return EmptyMessage(Icons.task_alt_rounded, emptyText);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => Card(child: AssignmentTile(items[i])),
    );
  }

  /// 学習者が自分でタスクを追加する簡単なダイアログ
  void _showAddDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    String type = 'Homework';
    DateTime due = DateTime.now().add(const Duration(days: 3));
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add my own task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Title'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Homework', label: Text('Homework')),
                  ButtonSegment(value: 'Test', label: Text('Test')),
                ],
                selected: {type},
                onSelectionChanged: (s) => setState(() => type = s.first),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text('Due: ${fmtDate(due)}'),
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: due,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (p != null) {
                    setState(() => due = DateTime(p.year, p.month, p.day, 23, 59));
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                context.read<AppData>().addAssignment(Assignment(
                      id: 'my_${DateTime.now().microsecondsSinceEpoch}',
                      title: titleCtrl.text.trim(),
                      type: type,
                      subject: 'My task',
                      dueDate: due.toIso8601String(),
                    ));
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 一覧の1行
// -----------------------------------------------------------------------------
class AssignmentTile extends StatelessWidget {
  final Assignment a;
  const AssignmentTile(this.a, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = assignmentColor(a.isTest);
    final data = context.read<AppData>();
    final hasFile = data.submissionsFor(a.id).isNotEmpty;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Checkbox(
        value: a.done,
        shape: const CircleBorder(),
        activeColor: kGreen,
        onChanged: (_) => data.toggleDone(a),
      ),
      title: Text(
        a.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          decoration: a.done ? TextDecoration.lineThrough : null,
          color: a.done ? Colors.grey : kTextDark,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Tag(a.type, color: color),
            if (a.subject.isNotEmpty) Tag(a.subject, color: Colors.grey.shade700),
            if (hasFile)
              const Tag('Submitted', color: kGreen, icon: Icons.attach_file),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_rounded,
                    size: 13, color: dueColor(a.due, a.done)),
                const SizedBox(width: 3),
                Text(
                  a.done && a.isTest && a.score >= 0
                      ? 'Score ${a.score}/${a.maxScore}'
                      : dueText(a.due),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: dueColor(a.due, a.done),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AssignmentDetailScreen(a.id)),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ファイルを選んで提出する(PDF / 音声 / 画像)
//   assignmentId が空なら「自由提出」としてポートフォリオにだけ入る
// -----------------------------------------------------------------------------
Future<void> pickAndSubmitFile(
  BuildContext context, {
  String assignmentId = '',
  String title = 'Free upload',
  String submitType = 'any',
}) async {
  // 課題の種類に合わせて選べるファイルを絞る
  FileType type = FileType.any;
  List<String>? ext;
  if (submitType == 'pdf') {
    type = FileType.custom;
    ext = ['pdf'];
  } else if (submitType == 'audio') {
    type = FileType.custom;
    ext = ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'webm'];
  } else if (submitType == 'image') {
    type = FileType.image;
  }

  final result = await FilePicker.platform.pickFiles(
    type: type,
    allowedExtensions: ext,
    withData: true, // ← ファイルの中身を読み込む(Webでも動く)
  );
  if (result == null || result.files.isEmpty) return;
  final f = result.files.first;
  if (f.bytes == null) {
    if (context.mounted) showMessage(context, 'Could not read the file');
    return;
  }
  if (f.bytes!.length > 25 * 1024 * 1024) {
    if (context.mounted) showMessage(context, 'File is too large (max 25 MB)');
    return;
  }
  if (!context.mounted) return;

  // メモ(振り返り)を入力してもらう
  final noteCtrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Submit this file?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(fileIcon(AppData.fileTypeOf(f.name)),
                  color: fileColor(AppData.fileTypeOf(f.name))),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${f.name}  (${fmtBytes(f.bytes!.length)})',
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Reflection note (optional)\ne.g. "Keigo was difficult"',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  await context.read<AppData>().addSubmission(
        assignmentId: assignmentId,
        title: title,
        fileName: f.name,
        bytes: f.bytes!,
        note: noteCtrl.text.trim(),
      );
  if (context.mounted) {
    showMessage(context, 'Submitted! Saved to your Portfolio.');
  }
}

// -----------------------------------------------------------------------------
// 詳細画面
// -----------------------------------------------------------------------------
class AssignmentDetailScreen extends StatelessWidget {
  final String assignmentId;
  const AssignmentDetailScreen(this.assignmentId, {super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final a = data.assignment(assignmentId);
    if (a == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const EmptyMessage(Icons.search_off, 'Task not found'));
    }
    final color = assignmentColor(a.isTest);
    final files = data.submissionsFor(a.id);
    final lesson = data.lesson(a.relatedLessonId);
    final relatedNotices =
        data.notices.where((n) => n.relatedAssignmentId == a.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(a.type),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await confirmDelete(context, a.title) && context.mounted) {
                await data.deleteAssignment(a.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- 基本情報 ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconBox(assignmentIcon(a.isTest), color: color, size: 48),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(spacing: 6, children: [
                                Tag(a.type, color: color),
                                if (a.subject.isNotEmpty)
                                  Tag(a.subject, color: Colors.grey.shade700),
                              ]),
                              const SizedBox(height: 6),
                              Text(a.title,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _row(Icons.schedule_rounded, a.isTest ? 'Date' : 'Due',
                        fmtDateTime(a.due), dueColor(a.due, a.done),
                        right: dueText(a.due)),
                    const SizedBox(height: 10),
                    _row(
                      a.done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      'Status',
                      a.done
                          ? (a.isTest ? 'Taken' : 'Submitted')
                          : (a.isTest ? 'Not taken' : 'Not submitted'),
                      a.done ? kGreen : Colors.grey.shade700,
                      right: a.doneAt.isNotEmpty
                          ? fmtDateTime(DateTime.parse(a.doneAt))
                          : null,
                    ),
                    if (a.submitType != 'none') ...[
                      const SizedBox(height: 10),
                      _row(Icons.upload_file_rounded, 'Upload',
                          submitTypeLabel(a.submitType), kPrimary),
                    ],
                    if (a.description.isNotEmpty) ...[
                      const Divider(height: 28),
                      Text(a.description,
                          style: TextStyle(
                              height: 1.6, color: Colors.grey.shade800)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ---- やり方の動画・手順・評価のポイント・資料 ----
            if (a.videoUrl.isNotEmpty) ...[
              BigButton(
                text: 'How to do this homework (video)',
                icon: Icons.smart_display_rounded,
                color: kFlame,
                onPressed: () => openLink(context, a.videoUrl),
              ),
              const SizedBox(height: 14),
            ],
            if (_split(a.instructions).isNotEmpty) ...[
              const SectionTitle('What to do'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      for (final (i, t) in _split(a.instructions).indexed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: color,
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(t,
                                      style: const TextStyle(height: 1.5))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (_split(a.criteria).isNotEmpty) ...[
              const SectionTitle('How it is checked'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      for (final t in _split(a.criteria))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 18, color: kFlame),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(t,
                                      style: const TextStyle(height: 1.5))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (a.exampleImages.isNotEmpty) ...[
              ExampleImages(a.exampleImages),
              const SizedBox(height: 14),
            ],
            if (a.materials.isNotEmpty) ...[
              const SectionTitle('Materials'),
              for (final m in a.materials)
                Card(
                  child: ListTile(
                    leading: const IconBox(Icons.description_outlined,
                        color: kTeal),
                    title: Text(m['title'] ?? 'Material'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => openLink(context, m['url'] ?? ''),
                  ),
                ),
              const SizedBox(height: 14),
            ],

            // ---- テストの点数 ----
            if (a.isTest) ...[
              _ScoreCard(a, color),
              const SizedBox(height: 14),
            ],

            // ---- 作文課題: ワークスペースへ ----
            if (a.submitType == 'essay') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                      colors: [kPrimary, kSecondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Essay workspace',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      'Write → recall textbook words → record your reading. Everything you do here is saved.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _miniStat(Icons.edit_note_rounded,
                            '${data.draftsFor(a.id).length} drafts'),
                        const SizedBox(width: 8),
                        _miniStat(Icons.lightbulb_outline,
                            '${data.helperLogsFor(a.id).where((h) => h.action == 'remembered').length} remembered'),
                        const SizedBox(width: 8),
                        _miniStat(Icons.mic_rounded,
                            '${files.where((s) => s.fileType == 'audio').length} rec'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => EssayScreen(a.id)),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: kPrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Open workspace',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ---- 提出ファイル ----
            if (a.submitType != 'none') ...[
              SectionTitle('My submission${files.length > 1 ? 's' : ''}'),
              if (files.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_upload_outlined,
                            color: Colors.grey.shade500),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('No file submitted yet',
                              style: TextStyle(color: Colors.grey.shade600)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...files.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(child: SubmissionTile(s)),
                    )),
              const SizedBox(height: 8),
              if (a.submitType != 'essay')
              BigButton(
                text: files.isEmpty ? 'Upload & submit' : 'Upload another file',
                icon: Icons.upload_file_rounded,
                color: color,
                onPressed: () => pickAndSubmitFile(
                  context,
                  assignmentId: a.id,
                  title: a.title,
                  submitType: a.submitType,
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ---- 関連する授業 ----
            if (lesson != null) ...[
              const SectionTitle('Related lesson'),
              Card(
                child: ListTile(
                  leading: IconBox(Icons.play_circle_fill_rounded,
                      color: categoryColor(lesson.category)),
                  title: Text('Lesson ${lesson.number}: ${lesson.title}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(lesson.watched
                      ? 'Watched'
                      : '${(lesson.progress * 100).round()}% watched'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => LessonDetailScreen(lesson.id)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ---- 関連するお知らせ ----
            if (relatedNotices.isNotEmpty) ...[
              const SectionTitle('Related notices'),
              ...relatedNotices.map((n) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(child: NoticeTile(n)),
                  )),
              const SizedBox(height: 6),
            ],

            // ---- 完了/未完了ボタン ----
            BigButton(
              text: a.done
                  ? 'Mark as not done'
                  : (a.isTest ? 'Mark as taken' : 'Mark as done'),
              icon: a.done ? Icons.undo_rounded : Icons.check_rounded,
              outlined: a.done,
              onPressed: () => data.toggleDone(a),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, Color color,
      {String? right}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        SizedBox(
            width: 56,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600))),
        Expanded(
          child: Text(value,
              style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        ),
        if (right != null)
          Text(right,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}

/// テストの点数カード
class _ScoreCard extends StatelessWidget {
  final Assignment a;
  final Color color;
  const _ScoreCard(this.a, this.color);

  @override
  Widget build(BuildContext context) {
    final hasScore = a.score >= 0 && a.maxScore > 0;
    final pct = hasScore ? a.score / a.maxScore : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Test result',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _editScore(context),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(hasScore ? 'Edit' : 'Enter score'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (hasScore) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${a.score}',
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: color,
                          height: 1)),
                  Text(' / ${a.maxScore}',
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey.shade600)),
                  const Spacer(),
                  Text('${(pct * 100).round()}%',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: pct >= 0.8
                              ? kGreen
                              : pct >= 0.6
                                  ? kOrange
                                  : kRed)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 10,
                  backgroundColor: color.withValues(alpha: 0.12),
                  color: color,
                ),
              ),
            ] else
              Text(
                a.maxScore > 0
                    ? 'Max score: ${a.maxScore}. No result yet.'
                    : 'No result yet.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }

  void _editScore(BuildContext context) {
    final scoreCtrl =
        TextEditingController(text: a.score >= 0 ? '${a.score}' : '');
    final maxCtrl =
        TextEditingController(text: '${a.maxScore > 0 ? a.maxScore : 100}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter test result'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: scoreCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Score'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('/', style: TextStyle(fontSize: 20)),
            ),
            Expanded(
              child: TextField(
                controller: maxCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final s = int.tryParse(scoreCtrl.text);
              final m = int.tryParse(maxCtrl.text);
              if (s == null || m == null || m <= 0 || s < 0 || s > m) {
                showMessage(context, 'Please enter a valid score');
                return;
              }
              context.read<AppData>().setScore(a, s, m);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}


/// "A;B;C" → ["A", "B", "C"](空は除く)
List<String> _split(String s) =>
    s.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
