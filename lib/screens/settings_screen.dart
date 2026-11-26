// =============================================================================
// settings_screen.dart - 設定
//   名前 / 1日の目標 / 週の目標 / Content URL(管理者が置いた content.json の場所)
//   + 管理者向けガイド(どこに何をアップすればいいか)
// =============================================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_data.dart';
import '../helpers.dart';
import 'file_saver.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final nameCtrl =
      TextEditingController(text: context.read<AppData>().userName);
  late final idCtrl =
      TextEditingController(text: context.read<AppData>().studentId);
  late final classCtrl =
      TextEditingController(text: context.read<AppData>().className);
  late final urlCtrl =
      TextEditingController(text: context.read<AppData>().contentUrl);

  @override
  void dispose() {
    nameCtrl.dispose();
    idCtrl.dispose();
    classCtrl.dispose();
    urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- プロフィール ----
            const SectionTitle('Profile'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      onChanged: (v) => data.saveSettings(name: v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: idCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Student ID (required)',
                        hintText: 'e.g. S2026-0142',
                        prefixIcon: Icon(Icons.badge_outlined),
                        helperText:
                            'Your teacher assigns this ID. Needed to link your submissions.',
                      ),
                      onChanged: (v) => data.saveSettings(studentIdValue: v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: classCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Class / Course',
                        hintText: 'e.g. N3 Evening 2026',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      onChanged: (v) =>
                          data.saveSettings(classNameValue: v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---- 目標 ----
            const SectionTitle('Goals'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily goal: ${data.dailyGoalMinutes} min',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Slider(
                      value: data.dailyGoalMinutes.toDouble(),
                      min: 10,
                      max: 180,
                      divisions: 17,
                      activeColor: kPrimary,
                      onChanged: (v) =>
                          data.saveSettings(dailyGoal: v.round()),
                    ),
                    Text('Weekly goal: ${data.weeklyGoalDays} days',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Slider(
                      value: data.weeklyGoalDays.toDouble(),
                      min: 1,
                      max: 7,
                      divisions: 6,
                      activeColor: kPrimary,
                      onChanged: (v) =>
                          data.saveSettings(weeklyDays: v.round()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---- コンテンツURL ----
            const SectionTitle('School content'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your school can give you a link to a content.json file. Lessons, homework, tests and notices are downloaded from it each time the app starts.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Content URL (optional)',
                        hintText: 'https://.../content.json',
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              await data.saveSettings(url: urlCtrl.text.trim());
                              await data.syncContent();
                              if (context.mounted) {
                                showMessage(context, data.lastSyncMessage);
                              }
                            },
                            icon: const Icon(Icons.sync),
                            label: const Text('Save & refresh'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Last: ${data.lastSyncMessage}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---- 学習データの書き出し ----
            const SectionTitle('My learning data'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export everything you did in this app (study logs, drafts, recall history, submissions) as one JSON file. '
                      'You can share it with your teacher or use it for your own review.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.5),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      Tag('${data.logs.length} study logs', color: kFlame),
                      Tag('${data.drafts.length} drafts', color: kPrimary),
                      Tag('${data.helperLogs.length} recall actions',
                          color: kSecondary),
                      Tag('${data.submissions.length} submissions',
                          color: kGreen),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final json = data.exportAllAsJson();
                          final name =
                              'nihongo_data_${DateTime.now().toIso8601String().substring(0, 10)}.json';
                          openOrSaveFile(context, name,
                              Uint8List.fromList(utf8.encode(json)));
                        },
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Export my data (JSON)'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---- 管理者ガイド ----
            const SectionTitle('For teachers / admins'),
            Card(
              child: ExpansionTile(
                leading: const IconBox(Icons.admin_panel_settings_outlined,
                    color: kSecondary),
                title: const Text('How to publish lessons & notices',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Where to upload content'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: const [AdminGuide()],
              ),
            ),
            const SizedBox(height: 16),

            // ---- リセット ----
            Card(
              child: ListTile(
                leading: const Icon(Icons.restart_alt, color: kRed),
                title: const Text('Reset all my data'),
                subtitle: const Text(
                    'Deletes study logs, submissions and progress'),
                onTap: () async {
                  if (await confirmDelete(context, 'all my data') &&
                      context.mounted) {
                    await data.resetAll();
                    if (context.mounted) showMessage(context, 'Data reset');
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text('Nihongo Study Hub v1.0',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 管理者向けの説明(アプリ内に表示)
class AdminGuide extends StatelessWidget {
  const AdminGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 13, height: 1.6, color: Colors.grey.shade800);
    final bold = style.copyWith(fontWeight: FontWeight.w700, color: kTextDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('1. Where is the content?', style: bold),
        Text(
          'Everything students see (lessons, homework, tests, notices) comes from ONE file: content.json. '
          'A sample is inside the app at assets/data/content.json.',
          style: style,
        ),
        const SizedBox(height: 10),
        Text('2. How to add an on-demand lesson', style: bold),
        Text(
          '• Upload your video to YouTube (Unlisted), Vimeo or Google Drive and copy the share link.\n'
          '• Open content.json, copy one lesson block, change "id" and "number", paste the link in "videoUrl".\n'
          '• Add a notice block with "relatedLessonId" so students get a notification.',
          style: style,
        ),
        const SizedBox(height: 10),
        Text('3. How to add homework / a test', style: bold),
        Text(
          '• Copy an assignment block. Set "type" to Homework or Test.\n'
          '• "submitType" tells students what to do: pdf, audio, image, any, none, or essay.\n'
          '• essay = students write in the app, recall textbook words, record their own reading.\n'
          '• Students upload files inside the app; they are saved to their Portfolio.',
          style: style,
        ),
        const SizedBox(height: 10),
        Text('3b. Study Helper vocabulary (no AI)', style: bold),
        Text(
          'The Recall tab shows ONLY the items you list in "vocabulary" in content.json. '
          'It never generates examples or reads aloud. Add words from your textbook with: '
          'word, reading, meaning (English), type (word/expression/grammar), lessonId, textbookRef, tags, hint. '
          'The hint should help students remember - do not write the meaning or an example in it.',
          style: style,
        ),
        const SizedBox(height: 10),
        Text('3c. Lesson materials (PDF / slides)', style: bold),
        Text(
          'Put files on Google Drive (link sharing: anyone with the link), then add links to the lesson\'s "materials": '
          '[{"title": "Slides", "url": "https://..."}]. Do not put files inside content.json.',
          style: style,
        ),
        const SizedBox(height: 10),
        Text('3d. Recommended: edit in a spreadsheet', style: bold),
        Text(
          'Teachers can keep 4 sheets (lessons / assignments / notices / vocabulary) in Google Sheets, export CSV, '
          'and run tools/build_content.py to generate content.json with error checking. See TEACHER_GUIDE.md.',
          style: style,
        ),
        const SizedBox(height: 10),
        Text('4. Where to upload content.json', style: bold),
        Text(
          'Option A (simple): replace assets/data/content.json and rebuild the app.\n'
          'Option B (no rebuild): put content.json on the web and share the URL with students '
          '(Settings > Content URL). Good places: GitHub (raw link), Google Drive direct link, Dropbox (dl=1), or your school server. '
          'The app re-downloads it every time it starts.',
          style: style,
        ),
        const SizedBox(height: 10),
        Text('5. Rules', style: bold),
        Text(
          '• "id" must be unique and never change.\n'
          '• Dates: YYYY-MM-DD or YYYY-MM-DD HH:MM.\n'
          '• Check your JSON with a validator (e.g. jsonlint.com) before uploading.',
          style: style,
        ),
      ],
    );
  }
}
