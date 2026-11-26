// =============================================================================
// main.dart - アプリの入口。起動 → データ読み込み → 5つのタブ画面を表示
//
// ファイル構成(全部で 10 ファイル程度):
//   lib/app_data.dart               データの形 + 保存/読み込み(ここが中心)
//   lib/helpers.dart                色・日付・共通パーツ
//   lib/screens/home_screen.dart    ホーム(ストリーク・今日のタスク・授業・お知らせ)
//   lib/screens/study_screen.dart   学習記録(カレンダー・統計)
//   lib/screens/assignments_screen.dart  宿題・テスト一覧 + 詳細 + ファイル提出
//   lib/screens/portfolio_screen.dart    提出物ポートフォリオ
//   lib/screens/lessons_screen.dart      オンデマンド授業一覧 + 詳細
//   lib/screens/notices_screen.dart      お知らせ一覧 + 詳細
//   lib/screens/settings_screen.dart     設定(名前・目標・Content URL・管理者ガイド)
//   assets/data/content.json        ★管理者が編集するコンテンツ
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';
import 'helpers.dart';
import 'screens/home_screen.dart';
import 'screens/study_screen.dart';
import 'screens/assignments_screen.dart';
import 'screens/lessons_screen.dart';
import 'screens/notices_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppData()..init(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nihongo Study Hub',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const RootPage(),
    );
  }
}

/// 学生に最初に ID・名前・クラスを入力してもらうダイアログ
void _showRegistrationDialog(BuildContext context, AppData data) {
  final nameCtrl = TextEditingController();
  final idCtrl = TextEditingController();
  final classCtrl = TextEditingController();
  showDialog(
    context: context,
    barrierDismissible: false, // 必ず入力してもらう
    builder: (ctx) => AlertDialog(
      title: const Text('Welcome!'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please register with the Student ID your teacher gave you. '
              'This ID connects your submissions to your school record.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Your name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: idCtrl,
              decoration: const InputDecoration(
                labelText: 'Student ID (from your teacher)',
                hintText: 'e.g. S2026-0142',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: classCtrl,
              decoration: const InputDecoration(
                labelText: 'Class / Course',
                hintText: 'e.g. N3 Evening 2026',
                prefixIcon: Icon(Icons.school_outlined),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            if (idCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Name and Student ID are required'),
                ),
              );
              return;
            }
            data.saveSettings(
              name: nameCtrl.text,
              studentIdValue: idCtrl.text,
              classNameValue: classCtrl.text,
            );
            Navigator.pop(ctx);
          },
          child: const Text('Start'),
        ),
      ],
    ),
  );
}

/// 下のタブバー付きのメイン画面
class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _tab = 0;
  bool _registrationChecked = false;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();

    // データ読み込み中はローディング表示
    if (!data.ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 初回起動: 学籍番号が未登録なら登録画面を見せる
    if (!_registrationChecked) {
      _registrationChecked = true;
      if (data.studentId.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showRegistrationDialog(context, data);
        });
      }
    }

    final pages = [
      HomeScreen(goToTab: (i) => setState(() => _tab = i)),
      const StudyScreen(),
      const AssignmentsScreen(),
      const LessonsScreen(),
      const NoticesScreen(),
    ];

    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department_rounded),
            label: 'Study',
          ),
          const NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Tasks',
          ),
          const NavigationDestination(
            icon: Icon(Icons.ondemand_video_outlined),
            selectedIcon: Icon(Icons.ondemand_video_rounded),
            label: 'Lessons',
          ),
          NavigationDestination(
            // 未読があれば赤いバッジを付ける
            icon: Badge(
              isLabelVisible: data.unreadCount > 0,
              label: Text('${data.unreadCount}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: data.unreadCount > 0,
              label: Text('${data.unreadCount}'),
              child: const Icon(Icons.notifications_rounded),
            ),
            label: 'Notices',
          ),
        ],
      ),
    );
  }
}
