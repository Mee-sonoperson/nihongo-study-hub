// =============================================================================
// lessons_screen.dart - オンデマンド授業
//   LessonsScreen      : 一覧(New / All / Watched)
//   LessonCard         : ホーム画面の横スクロール用カード
//   LessonDetailScreen : 詳細。「Watch video」で videoUrl を開く
//
//   ★授業を追加するのは assets/data/content.json の "lessons" です(管理者)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_data.dart';
import '../helpers.dart';
import 'assignments_screen.dart';
import 'flow_screens.dart';
import 'notices_screen.dart';
import 'study_log_sheet.dart';

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  String filter = 'all'; // all / new / watched

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    var items = data.lessons;
    if (filter == 'new') items = items.where((l) => !l.watched).toList();
    if (filter == 'watched') items = items.where((l) => l.watched).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('On-demand Lessons'),
        actions: [
          IconButton(
            tooltip: 'Check for new lessons',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              await data.syncContent();
              if (context.mounted) showMessage(context, data.lastSyncMessage);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  _chip('all', 'All (${data.lessons.length})'),
                  _chip('new', 'Not watched (${data.unwatchedLessons.length})'),
                  _chip('watched', 'Watched'),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const EmptyMessage(
                      Icons.ondemand_video_rounded, 'No lessons here.')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => LessonRow(items[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String value, String label) {
    final selected = filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: kPrimary,
        backgroundColor: Colors.white,
        showCheckmark: false,
        labelStyle: TextStyle(
            color: selected ? Colors.white : kTextDark,
            fontWeight: FontWeight.w600,
            fontSize: 12),
        onSelected: (_) => setState(() => filter = value),
      ),
    );
  }
}

/// 一覧用(横長)
class LessonRow extends StatelessWidget {
  final Lesson l;
  const LessonRow(this.l, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(l.category);
    final until = DateTime.tryParse(l.availableUntil);
    final expired = until != null && until.isBefore(DateTime.now());
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => LessonDetailScreen(l.id))),
        child: Row(
          children: [
            _Thumb(l, color, width: 120, height: 96),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      Tag(l.category, color: color),
                      if (l.watched)
                        const Tag('Watched', color: kGreen, icon: Icons.check)
                      else if (expired)
                        const Tag('Expired', color: kRed)
                      else if (until != null)
                        Tag(dueText(until).replaceAll('Due ', ''),
                            color: dueColor(until, false),
                            icon: Icons.timer_outlined),
                    ]),
                    const SizedBox(height: 6),
                    Text('Lesson ${l.number}: ${l.title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('${l.teacher} · ${l.minutes} min',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ホーム画面用(縦長カード)
class LessonCard extends StatelessWidget {
  final Lesson l;
  const LessonCard(this.l, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(l.category);
    return SizedBox(
      width: 230,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => LessonDetailScreen(l.id))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(l, color, width: double.infinity, height: 100),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lesson ${l.number}: ${l.title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 1.3)),
                    const SizedBox(height: 6),
                    Text('${l.teacher} · ${l.minutes} min',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// サムネイル(グラデーション + 再生ボタン + 進捗バー)
class _Thumb extends StatelessWidget {
  final Lesson l;
  final Color color;
  final double width, height;
  const _Thumb(this.l, this.color, {required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -16,
            child: Icon(categoryIcon(l.category),
                size: height * 0.9,
                color: Colors.white.withValues(alpha: 0.15)),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6)),
              child: Text('#${l.number}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const Center(
              child: Icon(Icons.play_circle_fill_rounded,
                  color: Colors.white, size: 40)),
          if (l.progress > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: l.progress,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 詳細
// -----------------------------------------------------------------------------
class LessonDetailScreen extends StatelessWidget {
  final String lessonId;
  const LessonDetailScreen(this.lessonId, {super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final l = data.lesson(lessonId);
    if (l == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const EmptyMessage(Icons.search_off, 'Lesson not found'));
    }
    final color = categoryColor(l.category);
    final until = DateTime.tryParse(l.availableUntil);
    final expired = until != null && until.isBefore(DateTime.now());
    final relatedTasks =
        data.assignments.where((a) => a.relatedLessonId == l.id).toList();
    final relatedNotices =
        data.notices.where((n) => n.relatedLessonId == l.id).toList();

    return Scaffold(
      appBar: AppBar(title: Text('Lesson ${l.number}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- 大きなサムネイル(タップで動画を開く)----
            GestureDetector(
              onTap: () => _openVideo(context, l),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _Thumb(l, color,
                        width: double.infinity, height: 200)),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Tag(l.category, color: color, icon: categoryIcon(l.category)),
              Tag('${l.minutes} min',
                  color: Colors.grey.shade700, icon: Icons.schedule),
              if (l.watched)
                const Tag('Watched', color: kGreen, icon: Icons.check)
              else if (expired)
                const Tag('Expired', color: kRed),
            ]),
            const SizedBox(height: 10),
            Text(l.title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: kPrimary.withValues(alpha: 0.15),
                  child: Text(
                      l.teacher.isNotEmpty ? l.teacher.substring(0, 1) : '?',
                      style: const TextStyle(
                          fontSize: 11,
                          color: kPrimary,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Text(l.teacher, style: TextStyle(color: Colors.grey.shade700)),
                const Spacer(),
                if (l.publishedAt.isNotEmpty)
                  Text('Published ${l.publishedAt}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
            if (until != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (expired ? kRed : kOrange).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 18, color: expired ? kRed : kOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        expired
                            ? 'This lesson expired on ${l.availableUntil}'
                            : 'Available until ${l.availableUntil} (${dueText(until).replaceAll('Due ', '')})',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: expired ? kRed : kOrange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // ---- 1課の流れ(シートの steps タブ)----
            LessonStepsCard(l.id),
            BigButton(
              text: 'Watch video',
              icon: Icons.play_arrow_rounded,
              color: color,
              onPressed: () => _openVideo(context, l),
            ),
            const SizedBox(height: 16),

            // ---- 内容 ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('About this lesson',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(l.description,
                        style: TextStyle(
                            height: 1.6, color: Colors.grey.shade800)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ---- 授業資料(PDF・スライドなどのリンク)----
            if (l.materials.isNotEmpty) ...[
              const SectionTitle('Lesson materials'),
              Card(
                child: Column(
                  children: [
                    for (int i = 0; i < l.materials.length; i++) ...[
                      ListTile(
                        leading: IconBox(
                            _materialIcon(l.materials[i]['url'] ?? ''),
                            color: kTeal),
                        title: Text(l.materials[i]['title'] ?? 'Material',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          Uri.tryParse(l.materials[i]['url'] ?? '')?.host ?? '',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: () async {
                          final uri =
                              Uri.tryParse(l.materials[i]['url'] ?? '');
                          if (uri == null ||
                              !await launchUrl(uri,
                                  mode: LaunchMode.externalApplication)) {
                            if (context.mounted) {
                              showMessage(context, 'Could not open the link.');
                            }
                          }
                        },
                      ),
                      if (i < l.materials.length - 1)
                        const Divider(height: 1, indent: 70),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ---- 進捗 ----
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('My progress',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text('${(l.progress * 100).round()}%',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, color: color)),
                      ],
                    ),
                    Slider(
                      value: l.progress,
                      activeColor: color,
                      onChanged: (v) => data.setLessonProgress(l, v),
                    ),
                    Text('Drag to record how far you watched (100% = watched)',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ---- 関連する課題 ----
            if (relatedTasks.isNotEmpty) ...[
              const SectionTitle('Homework for this lesson'),
              ...relatedTasks.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(child: AssignmentTile(a)),
                  )),
              const SizedBox(height: 6),
            ],
            if (relatedNotices.isNotEmpty) ...[
              const SectionTitle('Related notices'),
              ...relatedNotices.map((n) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(child: NoticeTile(n)),
                  )),
              const SizedBox(height: 6),
            ],

            Row(
              children: [
                Expanded(
                  child: BigButton(
                    text: l.watched ? 'Mark as not watched' : 'Mark as watched',
                    icon: l.watched ? Icons.undo_rounded : Icons.check_rounded,
                    outlined: l.watched,
                    onPressed: () async {
                      await data.setWatched(l, !l.watched);
                      if (l.watched && context.mounted) {
                        showMessage(context,
                            'Marked as watched. Log your study time too!');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                BigButton(
                  text: 'Log',
                  icon: Icons.add_rounded,
                  outlined: true,
                  onPressed: () =>
                      showStudyLogSheet(context, category: l.category),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _materialIcon(String url) {
    final u = url.toLowerCase();
    if (u.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (u.contains('docs.google.com/presentation') || u.contains('slides')) {
      return Icons.slideshow_rounded;
    }
    if (u.contains('docs.google.com/spreadsheets')) return Icons.table_chart;
    if (u.endsWith('.mp3') || u.endsWith('.m4a')) return Icons.headphones;
    return Icons.description_outlined;
  }

  /// 動画URLをブラウザ / YouTubeアプリで開く
  Future<void> _openVideo(BuildContext context, Lesson l) async {
    if (l.videoUrl.trim().isEmpty) {
      showMessage(context, 'No video link has been set for this lesson yet.');
      return;
    }
    final uri = Uri.tryParse(l.videoUrl.trim());
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) showMessage(context, 'Could not open the video link.');
      return;
    }
    // 開いたら少なくとも10%進んだことにする
    if (context.mounted && l.progress < 0.1) {
      context.read<AppData>().setLessonProgress(l, 0.1);
    }
  }
}
