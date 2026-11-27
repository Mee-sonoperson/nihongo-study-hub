// =============================================================================
// home_screen.dart - ホーム画面
//   上から: あいさつ / ストリークカード / 今日のタスク / オンデマンド授業 / お知らせ
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_data.dart';
import '../helpers.dart';
import 'assignments_screen.dart';
import 'lessons_screen.dart';
import 'map_screen.dart';
import 'notices_screen.dart';
import 'portfolio_screen.dart';
import 'settings_screen.dart';
import 'study_log_sheet.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int tabIndex) goToTab; // 下のタブを切り替える
  const HomeScreen({super.key, required this.goToTab});

  String greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final tasks = data.upcoming;
    final lessons = data.unwatchedLessons.take(4).toList();
    final notices = data.notices.take(3).toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            // ---------- ヘッダー ----------
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(greeting(),
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600)),
                      Text(
                        data.userName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: kTextDark,
                        ),
                      ),
                      if (data.studentId.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            data.className.isEmpty
                                ? 'ID: ${data.studentId}'
                                : 'ID: ${data.studentId} · ${data.className}',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Portfolio',
                  icon: const Icon(Icons.folder_special_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PortfolioScreen()),
                  ),
                ),
                IconButton(
                  tooltip: 'Notices',
                  icon: Badge(
                    isLabelVisible: data.unreadCount > 0,
                    label: Text('${data.unreadCount}'),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  onPressed: () => goToTab(4),
                ),
                // 保存状況・今日はここまで・ログアウト
                IconButton(
                  tooltip: 'My account',
                  icon: Icon(
                    data.syncStatus == 'offline'
                        ? Icons.cloud_off_rounded
                        : Icons.account_circle_rounded,
                    color: data.syncStatus == 'offline' ? kOrange : kPrimary,
                    size: 30,
                  ),
                  onPressed: () => showAccountSheet(context),
                ),
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ---------- ストリークカード ----------
            StreakCard(data: data),
            const SizedBox(height: 14),

            // ---------- 学習マップ ----------
            const HomeMapCard(),
            const SizedBox(height: 20),

            // ---------- 今日のタスク ----------
            SectionTitle("Today's tasks",
                action: 'See all', onAction: () => goToTab(2)),
            if (tasks.isEmpty)
              const _InfoCard(Icons.task_alt_rounded,
                  'No tasks due soon. Great job!')
            else
              Card(
                child: Column(
                  children: [
                    for (int i = 0; i < tasks.length; i++) ...[
                      AssignmentTile(tasks[i]),
                      if (i < tasks.length - 1)
                        const Divider(height: 1, indent: 60),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // ---------- オンデマンド授業 ----------
            SectionTitle('On-demand lessons',
                action: 'See all', onAction: () => goToTab(3)),
            if (lessons.isEmpty)
              const _InfoCard(Icons.ondemand_video_rounded,
                  'You have watched all lessons!')
            else
              SizedBox(
                height: 196,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: lessons.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => LessonCard(lessons[i]),
                ),
              ),
            const SizedBox(height: 20),

            // ---------- お知らせ ----------
            SectionTitle('Notices',
                action: 'See all', onAction: () => goToTab(4)),
            Card(
              child: Column(
                children: [
                  for (int i = 0; i < notices.length; i++) ...[
                    NoticeTile(notices[i]),
                    if (i < notices.length - 1)
                      const Divider(height: 1, indent: 60),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showStudyLogSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log study',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// 連続学習日数と今日の進捗を表示する紫のカード
class StreakCard extends StatelessWidget {
  final AppData data;
  const StreakCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final monday = data.thisMonday;
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final progress = (data.todayMinutes / data.dailyGoalMinutes).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kPrimary, kSecondary],
        ),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded,
                            color: kFlame, size: 22),
                        const SizedBox(width: 6),
                        Text('Study streak',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${data.streak}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                height: 1.1)),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8, left: 6),
                          child: Text('days',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.studiedToday
                          ? 'You studied today. Keep it up!'
                          : 'Not logged yet today. Log study to continue!',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 今日の目標の円グラフ
              SizedBox(
                width: 86,
                height: 86,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        color: Colors.white,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${data.todayMinutes}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1)),
                        Text('/${data.dailyGoalMinutes} min',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // 今週の7日
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (i) {
                final d = monday.add(Duration(days: i));
                final studied = data.minutesOn(d) > 0;
                final isToday = d.day == today.day && d.month == today.month;
                final future = d.isAfter(today);
                return Column(
                  children: [
                    Text(labels[i],
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight:
                                isToday ? FontWeight.w800 : FontWeight.w500)),
                    const SizedBox(height: 6),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: studied
                            ? Colors.white
                            : Colors.white
                                .withValues(alpha: future ? 0.08 : 0.2),
                        border: isToday
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                      child: studied
                          ? const Icon(Icons.check_rounded,
                              size: 16, color: kPrimary)
                          : null,
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'This week ${data.weekStudyDays}/${data.weeklyGoalDays} days · ${fmtMinutes(data.weekMinutes)}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text('Best ${data.longestStreak} days',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoCard(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: kGreen),
            const SizedBox(width: 12),
            Expanded(
                child:
                    Text(text, style: TextStyle(color: Colors.grey.shade700))),
          ],
        ),
      ),
    );
  }
}
