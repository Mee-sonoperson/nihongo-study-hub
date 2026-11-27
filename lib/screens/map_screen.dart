// =============================================================================
// map_screen.dart - 学習マップ / 今日はここまで / ログアウト / ポートフォリオ作成
//
//   LearningMapScreen : Lesson を道のように並べた地図。最後が Goal。
//   HomeMapCard       : ホームに出す「学習マップ」のカード
//   showAccountSheet  : ホーム右上の人のマーク → 保存状況・今日はここまで・ログアウト
//   makePortfolio     : ポートフォリオを1つのファイルにまとめる
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_data.dart';
import '../helpers.dart';
import '../portfolio_export.dart';
import 'file_saver.dart';
import 'lessons_screen.dart';

// -----------------------------------------------------------------------------
// Lesson の状態
// -----------------------------------------------------------------------------
enum _LState { upcoming, open, overdue, inProgress, doneOnTime, doneLate }

_LState _stateOf(AppData d, Lesson l) {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  if (d.lessonCompleted(l.id)) {
    return d.lessonOnTime(l) ? _LState.doneOnTime : _LState.doneLate;
  }
  if (d.lessonStarted(l.id)) return _LState.inProgress;
  if (l.publishedAt.isNotEmpty && today.compareTo(l.publishedAt) < 0) {
    return _LState.upcoming;
  }
  if (l.availableUntil.isNotEmpty && today.compareTo(l.availableUntil) > 0) {
    return _LState.overdue;
  }
  return _LState.open;
}

Color _colorOf(_LState s) {
  switch (s) {
    case _LState.doneOnTime:
      return kGreen;
    case _LState.doneLate:
      return kOrange;
    case _LState.inProgress:
      return kPrimary;
    case _LState.open:
      return kTeal;
    case _LState.overdue:
      return kRed;
    case _LState.upcoming:
      return Colors.grey;
  }
}

String _labelOf(AppData d, Lesson l, _LState s) {
  switch (s) {
    case _LState.doneOnTime:
      return 'Completed (on time)';
    case _LState.doneLate:
      return 'Completed (late)';
    case _LState.inProgress:
      final steps = d.stepsFor(l.id);
      final done = steps.where(d.isStepDone).length;
      return steps.isEmpty ? 'In progress' : 'In progress · $done / ${steps.length} steps';
    case _LState.open:
      return 'Ready to start';
    case _LState.overdue:
      return 'Not started · period ended';
    case _LState.upcoming:
      return 'Opens on ${l.publishedAt}';
  }
}

List<Lesson> _course(AppData d) =>
    List.of(d.lessons)..sort((a, b) => a.number.compareTo(b.number));

// =============================================================================
// 学習マップ
// =============================================================================
class LearningMapScreen extends StatelessWidget {
  const LearningMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = context.watch<AppData>();
    final course = _course(d);
    final doneCount = course.where((l) => d.lessonCompleted(l.id)).length;
    final allDone = course.isNotEmpty && doneCount == course.length;

    return Scaffold(
      appBar: AppBar(title: const Text('My learning map')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text('$doneCount / ${course.length} lessons completed',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: course.isEmpty ? 0 : doneCount / course.length,
                minHeight: 10,
                color: kGreen,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < course.length; i++)
              _MapNode(
                lesson: course[i],
                state: _stateOf(d, course[i]),
                label: _labelOf(d, course[i], _stateOf(d, course[i])),
                isFirst: i == 0,
              ),
            _GoalNode(allDone: allDone, left: course.length - doneCount),
          ],
        ),
      ),
    );
  }
}

class _MapNode extends StatelessWidget {
  final Lesson lesson;
  final _LState state;
  final String label;
  final bool isFirst;
  const _MapNode(
      {required this.lesson,
      required this.state,
      required this.label,
      required this.isFirst});

  @override
  Widget build(BuildContext context) {
    final c = _colorOf(state);
    final done = state == _LState.doneOnTime || state == _LState.doneLate;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 道(縦の線)と丸
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Container(
                    width: 4,
                    height: 14,
                    color: isFirst ? Colors.transparent : Colors.grey.shade300),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: c,
                  child: done
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 28)
                      : (state == _LState.upcoming
                          ? const Icon(Icons.lock_outline,
                              color: Colors.white, size: 22)
                          : Text('${lesson.number}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800))),
                ),
                Expanded(
                    child: Container(width: 4, color: Colors.grey.shade300)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => LessonDetailScreen(lesson.id)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Lesson ${lesson.number}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600)),
                              Text(lesson.title,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(label,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: c,
                                      fontWeight: FontWeight.w700)),
                              if (lesson.publishedAt.isNotEmpty ||
                                  lesson.availableUntil.isNotEmpty)
                                Text(
                                    '${lesson.publishedAt} – ${lesson.availableUntil}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalNode extends StatelessWidget {
  final bool allDone;
  final int left;
  const _GoalNode({required this.allDone, required this.left});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: CircleAvatar(
            radius: 26,
            backgroundColor: allDone ? kFlame : Colors.grey.shade300,
            child: const Icon(Icons.flag_rounded, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            color: allDone ? kFlame.withValues(alpha: 0.12) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(allDone ? 'Goal! Course complete 🎉' : 'Goal',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    allDone
                        ? 'You finished all the lessons. Make your portfolio and keep it as a record of your study.'
                        : '$left more lesson${left == 1 ? '' : 's'} to the goal.',
                    style: TextStyle(color: Colors.grey.shade800, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => makePortfolio(context),
                      icon: const Icon(Icons.auto_stories_rounded),
                      label: Text(allDone
                          ? 'Make my portfolio'
                          : 'Make my portfolio (so far)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// ホームに出す学習マップのカード
// =============================================================================
class HomeMapCard extends StatelessWidget {
  const HomeMapCard({super.key});

  @override
  Widget build(BuildContext context) {
    final d = context.watch<AppData>();
    final course = _course(d);
    if (course.isEmpty) return const SizedBox.shrink();
    final doneCount = course.where((l) => d.lessonCompleted(l.id)).length;
    Lesson? next;
    for (final l in course) {
      if (!d.lessonCompleted(l.id)) {
        next = l;
        break;
      }
    }
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const LearningMapScreen())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.map_rounded, color: kPrimary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('My learning map',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  Text('$doneCount / ${course.length}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: kGreen)),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: doneCount / course.length,
                  minHeight: 8,
                  color: kGreen,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                next == null
                    ? 'All lessons completed! Tap to make your portfolio.'
                    : 'Next: Lesson ${next.number} · ${next.title} — ${_labelOf(d, next, _stateOf(d, next))}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ポートフォリオを1つのファイルにまとめる
// =============================================================================
Future<void> makePortfolio(BuildContext context) async {
  final d = context.read<AppData>();
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('Making your portfolio…')),
        ],
      ),
    ),
  );
  final bytes = await buildPortfolioHtml(d);
  final name = portfolioFileName(d);
  final savedOnline = await d.savePortfolioOnline(name, bytes);
  if (!context.mounted) return;
  Navigator.pop(context); // 「作っています」を閉じる
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Your portfolio is ready'),
      content: Text(
        'All your essays, recordings, pictures and lesson records are in one file:\n\n$name\n\n'
        '${savedOnline ? 'A copy was saved to your school folder (your teacher can see it).\n\n' : ''}'
        'Open it in a browser. To make a PDF, use Print → Save as PDF.',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            openOrSaveFile(context, name, bytes);
          },
          icon: const Icon(Icons.download_rounded),
          label: const Text('Download'),
        ),
      ],
    ),
  );
}

// =============================================================================
// ホーム右上: 保存状況・今日はここまで・ログアウト
// =============================================================================
void showAccountSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => const _AccountSheet(),
  );
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context) {
    final d = context.watch<AppData>();
    final t = d.todaySummary();
    final offline = d.syncStatus == 'offline';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d.userName,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text('ID: ${d.studentId}${d.className.isEmpty ? '' : ' · ${d.className}'}',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (offline ? kOrange : kGreen).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(offline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                      color: offline ? kOrange : kGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      offline
                          ? 'Not saved online yet (no connection). Your work is safe on this phone.'
                          : (d.lastSavedAt.isEmpty
                              ? 'Your work is saved to your school account.'
                              : 'Saved to your school account at ${d.lastSavedAt}.'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text('Today',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              Tag('${t['steps']} steps done', color: kPrimary),
              Tag('${t['minutes']} min studied', color: kFlame),
              Tag('${t['drafts']} drafts saved', color: kSecondary),
              Tag('${t['files']} files submitted', color: kTeal),
            ]),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: kGreen),
                icon: const Icon(Icons.bedtime_outlined),
                label: const Text('Finish for today',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () async {
                  final ok = await d.pushState();
                  final files = await d.uploadPendingFiles();
                  if (!context.mounted) return;
                  await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(ok && files ? 'All saved 👋' : 'Saved on this phone'),
                      content: Text(ok && files
                          ? 'Everything you did today is saved to your school account. See you next time!'
                          : 'You are offline now. Your work will be saved online the next time you open the app with internet.'),
                      actions: [
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK')),
                      ],
                    ),
                  );
                  if (context.mounted) Navigator.pop(context); // シートを閉じる
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: kRed),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log out'),
                onPressed: () async {
                  await confirmLogout(context, d);
                  // ログアウトできたらシートを閉じる(ログイン画面に戻る)
                  if (context.mounted && !d.loggedIn) Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ログアウト(先に保存。保存できないときは確認)
Future<void> confirmLogout(BuildContext context, AppData data) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text(
          'Your work will be saved to your school account, then removed from this phone. '
          'You can log in again on any phone.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out')),
      ],
    ),
  );
  if (yes != true) return;
  final ok = await data.logout();
  if (ok || !context.mounted) return;
  final force = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Not saved online'),
      content: const Text(
          'Your latest work could not be saved (no connection). '
          'If you log out now, it will be lost. Try again when you are online.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay logged in')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out anyway', style: TextStyle(color: kRed))),
      ],
    ),
  );
  if (force == true) await data.logout(force: true);
}
