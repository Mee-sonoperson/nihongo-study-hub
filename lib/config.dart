// =============================================================================
// config.dart - 管理者が変える設定はこのファイルだけ
// =============================================================================

/// 教材入力シート(Google スプレッドシート)の ID。
/// シートの URL の  /d/ と /edit の間の文字列です。
///   https://docs.google.com/spreadsheets/d/【ここ】/edit
/// シートは「リンクを知っている全員が閲覧可」にしておく必要があります。
/// 空文字 '' にすると、アプリ内の assets/data/content.json を使います。
const String kSheetId = '1D2RsiQQ-KNOIr36ATEXPAJnuVl5lCCn7yMFIevjLxVs';

/// 初回起動時に「サンプルの学習記録」を入れるか(デモ用)。本番は false。
const bool kSeedSampleLogs = false;
