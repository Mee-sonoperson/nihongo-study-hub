# Nihongo Study Hub

日本語学習管理アプリ(英語UI・外国人学習者向け)。

- 教材(授業・課題・お知らせ・単語帳)は **Google スプレッドシート「NihongoStudyHub_教材入力シート」** から自動で読み込みます。
  シートの場所は `lib/config.dart` の `kSheetId` で指定します。
- `main` ブランチに変更を送ると、GitHub Actions が自動でビルドし、`gh-pages` ブランチ(GitHub Pages)に公開します。
- 先生向けガイド・運用ガイドは Google ドライブのフォルダにあります。
