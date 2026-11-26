// =============================================================================
// study_log_sheet.dart - 「学習を記録する」ための下から出るシート
// ホーム画面・学習画面・授業詳細から呼ばれます: showStudyLogSheet(context)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_data.dart';
import '../helpers.dart';

Future<void> showStudyLogSheet(BuildContext context, {String? category}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => StudyLogSheet(initialCategory: category),
  );
}

class StudyLogSheet extends StatefulWidget {
  final String? initialCategory;
  const StudyLogSheet({super.key, this.initialCategory});

  @override
  State<StudyLogSheet> createState() => _StudyLogSheetState();
}

class _StudyLogSheetState extends State<StudyLogSheet> {
  int minutes = 30;
  late String category = widget.initialCategory ?? 'Vocabulary';
  DateTime date = DateTime.now();
  final noteCtrl = TextEditingController();

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + keyboard),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Log your study',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            Text(
              'Keep your streak alive!',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // ---- 日付 ----
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime.now().subtract(const Duration(days: 90)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => date = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 18, color: kPrimary),
                    const SizedBox(width: 10),
                    Text(fmtDate(date),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: Colors.grey.shade500),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ---- カテゴリ ----
            const Text('Category',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kCategories.map((c) {
                final selected = c == category;
                final color = categoryColor(c);
                return ChoiceChip(
                  label: Text(c),
                  avatar: Icon(categoryIcon(c),
                      size: 16, color: selected ? Colors.white : color),
                  selected: selected,
                  selectedColor: color,
                  backgroundColor: color.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : color,
                    fontWeight: FontWeight.w600,
                  ),
                  showCheckmark: false,
                  side: BorderSide.none,
                  onSelected: (_) => setState(() => category = c),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ---- 時間 ----
            Row(
              children: [
                const Text('Time', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  fmtMinutes(minutes),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: kPrimary,
                  ),
                ),
              ],
            ),
            Slider(
              value: minutes.toDouble(),
              min: 5,
              max: 180,
              divisions: 35,
              activeColor: kPrimary,
              onChanged: (v) => setState(() => minutes = v.round()),
            ),
            Wrap(
              spacing: 8,
              children: [15, 30, 45, 60, 90].map((m) {
                return ActionChip(
                  label: Text('$m min'),
                  side: BorderSide.none,
                  backgroundColor: minutes == m
                      ? kPrimary.withValues(alpha: 0.15)
                      : kBackground,
                  onPressed: () => setState(() => minutes = m),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ---- メモ ----
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                hintText: 'Note (e.g. Reviewed kanji from Lesson 5)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              minLines: 1,
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // ---- 保存 ----
            SizedBox(
              width: double.infinity,
              child: BigButton(
                text: 'Save',
                icon: Icons.check_rounded,
                onPressed: () async {
                  final data = context.read<AppData>();
                  final before = data.streak;
                  await data.addLog(minutes, category, noteCtrl.text.trim(),
                      date: DateTime(date.year, date.month, date.day,
                          DateTime.now().hour, DateTime.now().minute));
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  showMessage(
                    context,
                    data.streak > before
                        ? 'Saved! Streak: ${data.streak} days 🔥'
                        : 'Study log saved',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
