// =============================================================================
// portfolio_screen.dart - ポートフォリオ
//   学習者が提出した PDF・録音・画像 を時系列でまとめて見られる画面。
//   PortfolioScreen        : 一覧(種類で絞り込み)+ 統計
//   SubmissionTile         : 1件分の行(課題詳細画面でも使う)
//   SubmissionDetailScreen : 詳細(画像プレビュー / 音声・PDFはダウンロード)
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_data.dart';
import '../helpers.dart';
import 'assignments_screen.dart';
import 'file_saver.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  String filter = 'all'; // all / pdf / audio / image

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final all = data.submissions;
    final items =
        filter == 'all' ? all : all.where((s) => s.fileType == filter).toList();

    int count(String t) => all.where((s) => s.fileType == t).length;

    return Scaffold(
      appBar: AppBar(title: const Text('My Portfolio')),
      body: SafeArea(
        child: Column(
          children: [
            // ---- 統計カード ----
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [kPrimary, kSecondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your work collection',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('${all.length} items',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(
                            'All your submitted homework, recordings and essays are kept here so you can see your progress.',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        _mini(Icons.picture_as_pdf_rounded, count('pdf')),
                        const SizedBox(height: 6),
                        _mini(Icons.mic_rounded, count('audio')),
                        const SizedBox(height: 6),
                        _mini(Icons.image_rounded, count('image')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // ---- 絞り込み ----
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('all', 'All', Icons.apps_rounded),
                    _chip('pdf', 'PDF', Icons.picture_as_pdf_rounded),
                    _chip('audio', 'Audio', Icons.mic_rounded),
                    _chip('image', 'Images', Icons.image_rounded),
                    _chip('text', 'Essays', Icons.article_rounded),
                  ],
                ),
              ),
            ),
            // ---- 一覧 ----
            Expanded(
              child: items.isEmpty
                  ? const EmptyMessage(Icons.folder_open_rounded,
                      'No submissions yet.\nUpload homework from a task, or tap + to add a file.')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          Card(child: SubmissionTile(items[i])),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => pickAndSubmitFile(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add file',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _mini(IconData icon, int n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text('$n',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _chip(String value, String label, IconData icon) {
    final selected = filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        avatar: Icon(icon, size: 16, color: selected ? Colors.white : kPrimary),
        selected: selected,
        selectedColor: kPrimary,
        backgroundColor: Colors.white,
        showCheckmark: false,
        labelStyle: TextStyle(
            color: selected ? Colors.white : kTextDark,
            fontWeight: FontWeight.w600),
        onSelected: (_) => setState(() => filter = value),
      ),
    );
  }
}

/// 提出物1件の行
class SubmissionTile extends StatelessWidget {
  final Submission s;
  const SubmissionTile(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = fileColor(s.fileType);
    return ListTile(
      leading: IconBox(fileIcon(s.fileType), color: color),
      title: Text(s.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(
        '${s.fileName} · ${fmtBytes(s.sizeBytes)}\n${fmtDateTime(s.dateTime)}',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      isThreeLine: true,
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SubmissionDetailScreen(s.id)),
      ),
    );
  }
}

/// 提出物の詳細
class SubmissionDetailScreen extends StatelessWidget {
  final String submissionId;
  const SubmissionDetailScreen(this.submissionId, {super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    Submission? s;
    for (final x in data.submissions) {
      if (x.id == submissionId) s = x;
    }
    if (s == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const EmptyMessage(Icons.search_off, 'File not found'));
    }
    final sub = s;
    final color = fileColor(sub.fileType);
    final bytes = data.fileBytes(sub.id);
    // 別のスマホで提出したファイルは、先生のドライブから取ってくる
    final loading = bytes == null && data.loggedIn && !data.fetchFailed.contains(sub.id);
    if (loading) data.fetchFile(sub.id);
    final a = data.assignment(sub.assignmentId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submission'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await confirmDelete(context, sub.fileName) &&
                  context.mounted) {
                await data.deleteSubmission(sub.id);
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
            // ---- プレビュー ----
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 220,
                color: color.withValues(alpha: 0.1),
                alignment: Alignment.center,
                child: sub.fileType == 'image' && bytes != null
                    ? Image.memory(bytes, fit: BoxFit.contain)
                    : sub.fileType == 'text' && bytes != null
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Text(utf8.decode(bytes, allowMalformed: true),
                                style: const TextStyle(
                                    fontSize: 15, height: 1.8)),
                          )
                    : loading
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 10),
                              Text('Loading your file…'),
                            ],
                          )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(fileIcon(sub.fileType), size: 72, color: color),
                          const SizedBox(height: 10),
                          Text(sub.fileName,
                              style: TextStyle(
                                  color: color, fontWeight: FontWeight.w700)),
                          Text(fmtBytes(sub.sizeBytes),
                              style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(sub.title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Tag(sub.fileType.toUpperCase(), color: color),
                Tag('Submitted ${fmtDateTime(sub.dateTime)}',
                    color: Colors.grey.shade700, icon: Icons.schedule),
              ],
            ),
            const SizedBox(height: 16),
            if (bytes != null)
              BigButton(
                text: sub.fileType == 'audio' ? 'Open / play audio' : 'Open / download',
                icon: sub.fileType == 'audio'
                    ? Icons.play_arrow_rounded
                    : Icons.download_rounded,
                color: color,
                onPressed: () => openOrSaveFile(context, sub.fileName, bytes),
              ),
            const SizedBox(height: 16),

            // ---- 振り返りメモ ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('My reflection',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _editNote(context, sub),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit'),
                        ),
                      ],
                    ),
                    Text(
                      sub.note.isEmpty
                          ? 'No note yet. Write what you learned or found difficult.'
                          : sub.note,
                      style: TextStyle(
                          height: 1.6,
                          color: sub.note.isEmpty
                              ? Colors.grey.shade500
                              : Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
            ),
            if (sub.teacherComment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Teacher comment',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(sub.teacherComment,
                          style: const TextStyle(height: 1.6)),
                    ],
                  ),
                ),
              ),
            ],
            if (a != null) ...[
              const SizedBox(height: 16),
              const SectionTitle('Related task'),
              Card(child: AssignmentTile(a)),
            ],
          ],
        ),
      ),
    );
  }

  void _editNote(BuildContext context, Submission s) {
    final ctrl = TextEditingController(text: s.note);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('My reflection'),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'What did you learn?'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              context.read<AppData>().updateSubmissionNote(s, ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
