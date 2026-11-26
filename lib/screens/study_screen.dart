// =============================================================================
// study_screen.dart - 学習記録
//   統計カード / 月カレンダー(学習した日は色付き)/ カテゴリ別時間 / 記録一覧
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_data.dart';
import '../helpers.dart';
import 'study_log_sheet.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? selectedDay;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final logs = selectedDay == null
        ? data.logs.take(10).toList()
        : data.logs.where((l) {
            final d = l.dateTime;
            return d.year == selectedDay!.year &&
                d.month == selectedDay!.month &&
                d.day == selectedDay!.day;
          }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Study Log')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            // ---- 統計 ----
            Row(
              children: [
                _stat(Icons.local_fire_department_rounded, kFlame,
                    '${data.streak} d', 'Streak'),
                const SizedBox(width: 10),
                _stat(Icons.calendar_month_rounded, kPrimary,
                    '${data.weekStudyDays}/${data.weeklyGoalDays}', 'This week'),
                const SizedBox(width: 10),
                _stat(Icons.timer_outlined, kSecondary,
                    fmtMinutes(data.totalMinutes), 'Total'),
              ],
            ),
            const SizedBox(height: 16),

            // ---- カレンダー ----
            _calendar(data),
            const SizedBox(height: 20),

            // ---- カテゴリ別 ----
            const SectionTitle('Time by category'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: kCategories.map((c) {
                    final m = data.minutesByCategory[c] ?? 0;
                    final total = data.totalMinutes == 0 ? 1 : data.totalMinutes;
                    final color = categoryColor(c);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Icon(categoryIcon(c), size: 18, color: color),
                          const SizedBox(width: 8),
                          SizedBox(
                              width: 78,
                              child: Text(c,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600))),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                value: m / total,
                                minHeight: 9,
                                backgroundColor: color.withValues(alpha: 0.1),
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 64,
                            child: Text(fmtMinutes(m),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ---- 記録一覧 ----
            SectionTitle(
              selectedDay == null ? 'Recent logs' : 'Logs on ${fmtDate(selectedDay!)}',
              action: selectedDay != null ? 'Clear' : null,
              onAction: () => setState(() => selectedDay = null),
            ),
            if (logs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('No logs')),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (int i = 0; i < logs.length; i++) ...[
                      _logTile(context, logs[i]),
                      if (i < logs.length - 1)
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

  Widget _stat(IconData icon, Color color, String value, String label) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              FittedBox(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  /// 月のカレンダー。学習した日は青く塗る(時間が長いほど濃い)
  Widget _calendar(AppData data) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = first.weekday - 1; // 月曜始まり
    final today = DateTime.now();
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final cells = <Widget>[
      for (int i = 0; i < leadingBlanks; i++) const SizedBox(),
    ];
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(month.year, month.month, d);
      final minutes = data.minutesOn(date);
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final isSelected = selectedDay == date;
      final strength =
          minutes == 0 ? 0.0 : 0.3 + (minutes / 90).clamp(0, 1) * 0.7;
      cells.add(
        InkWell(
          onTap: () =>
              setState(() => selectedDay = isSelected ? null : date),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.all(2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: minutes > 0
                  ? kPrimary.withValues(alpha: strength)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: kOrange, width: 2)
                  : isToday
                      ? Border.all(color: kPrimary, width: 1.5)
                      : null,
            ),
            child: Text('$d',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                    color: strength > 0.55 ? Colors.white : kTextDark)),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(
                      () => month = DateTime(month.year, month.month - 1)),
                ),
                Expanded(
                  child: Text(fmtMonth(month),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(
                      () => month = DateTime(month.year, month.month + 1)),
                ),
              ],
            ),
            Row(
              children: labels
                  .map((l) => Expanded(
                        child: Center(
                          child: Text(l,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: cells,
            ),
          ],
        ),
      ),
    );
  }

  Widget _logTile(BuildContext context, StudyLog log) {
    final color = categoryColor(log.category);
    return ListTile(
      leading: IconBox(categoryIcon(log.category), color: color),
      title: Text('${log.category} · ${fmtMinutes(log.minutes)}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(
        log.note.isNotEmpty
            ? '${fmtDate(log.dateTime)} · ${log.note}'
            : fmtDate(log.dateTime),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: Colors.grey.shade400, size: 20),
        onPressed: () async {
          if (await confirmDelete(context, 'this log') && context.mounted) {
            context.read<AppData>().deleteLog(log.id);
          }
        },
      ),
    );
  }
}
