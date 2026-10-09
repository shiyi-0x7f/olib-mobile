# 📚 Olib

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![AI Built](https://img.shields.io/badge/AI%20構築-🤖-purple?style=for-the-badge)
![Open Source](https://img.shields.io/badge/オープンソース-❤️-green?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

**🤖 AIアシスタンスで完全に構築されたオープンソース電子書籍リーダー**

**サードパーティクライアント • フロントエンドインターフェースのみ • 外部ソースからのデータ**

[APKをダウンロード](https://bookbook.space) • [バグを報告](../../issues) • [機能をリクエスト](../../issues)

**[English](README.md)** | **[简体中文](README_ZH.md)** | **日本語** | **[한국어](README_KO.md)**

</div>

---

> ⚠️ **免責事項**: Olibは独立したオープンソースのサードパーティクライアントです。公式クライアントではなく、いかなる公式サービスとも関連していません。このプロジェクトはフロントエンドインターフェースのみを提供し、すべての書籍データは外部ソースから取得されます。ご自身の判断でお使いください。

## ✨ 機能

| 機能 | 説明 |
|------|------|
| 📖 **書籍検索** | タイトル、著者、ISBN、キーワードで書籍を検索 |
| 💾 **オフライン読書** | インターネットなしで読書するために書籍をダウンロード |
| 🌙 **ダークモード** | 目に優しい読書体験 |
| 🌍 **多言語対応** | 英語、中文、日本語、한국어など16以上の言語をサポート |
| 🔐 **マルチアカウント** | 複数のアカウントをシームレスに切り替え |
| 🔗 **マルチドメイン** | 複数のサーバーラインから選択 |
| 🆓 **完全無料** | 広告なし、サブスクリプションなし、隠れたコストなし |

## 🤖 AI構築プロジェクト

このプロジェクトは**完全にAIアシスタンスで構築**されました：
- AIによるアーキテクチャ設計
- AIによるコード実装
- AIによるUI/UXデザイン
- AIによるドキュメント作成

## 📱 スクリーンショット

<div align="center">
<i>近日公開予定...</i>
</div>

## 🚀 クイックスタート

### 前提条件

- Flutter SDK 3.8+
- Android Studio / VS Code
- Androidデバイスまたはエミュレータ

### インストール

```bash
# リポジトリをクローン
git clone https://github.com/shiyi-0x7f/olib-mobile.git

# プロジェクトディレクトリに移動
cd olib-mobile

# 依存関係をインストール
flutter pub get

# アプリを実行
flutter run
```

### APKをビルド

```bash
flutter build apk --release
```

## 🏗️ プロジェクト構成

```
lib/
├── l10n/           # ローカライゼーションファイル (16以上の言語)
├── models/         # データモデル
├── providers/      # 状態管理 (Riverpod)
├── routes/         # アプリナビゲーション
├── screens/        # UI画面
├── services/       # API & ストレージサービス
├── theme/          # アプリテーマ設定
└── widgets/        # 再利用可能なコンポーネント
```

## 🛠️ 技術スタック

- **フレームワーク**: Flutter
- **状態管理**: Riverpod
- **ローカルストレージ**: Hive
- **HTTPクライアント**: http パッケージ
- **多言語**: 16以上の言語

## 🤝 コントリビューション

コントリビューションを歓迎します！お気軽にPull Requestを提出してください。

1. プロジェクトをフォーク
2. 機能ブランチを作成 (`git checkout -b feature/AmazingFeature`)
3. 変更をコミット (`git commit -m 'Add some AmazingFeature'`)
4. ブランチにプッシュ (`git push origin feature/AmazingFeature`)
5. Pull Requestを開く

## 📄 ライセンス

このプロジェクトはMITライセンスの下でライセンスされています - 詳細は[LICENSE](LICENSE)ファイルをご覧ください。

> ⚠️ **法的通知**: 
> - これは独立したサードパーティクライアントであり、公式アプリケーションではありません
> - すべての書籍データは外部ソースから取得され、このプロジェクトはフロントエンドのみを提供します
> - ユーザーは適用法への準拠を確認する責任があります
> - このソフトウェアを使用することで、これらの条件を認めたことになります

## 💖 謝辞

- 🤖 AIアシスタンスで構築
- 💙 Flutterフレームワーク
- ❤️ オープンソースコミュニティ

---

<div align="center">

**[⬆ トップに戻る](#-olib)**

🤖 AI構築 • オープンソース • 永久に無料

</div>
