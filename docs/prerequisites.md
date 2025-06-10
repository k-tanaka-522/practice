# 前提知識と事前準備

このドキュメントでは、AI駆動開発学習プロジェクトを始める前に必要な基礎知識と準備事項をまとめています。

## 目次
1. [必要な前提知識](#必要な前提知識)
2. [Git/GitHubの基礎](#gitgithubの基礎)
3. [コマンドラインの基礎](#コマンドラインの基礎)
4. [開発環境のセットアップ](#開発環境のセットアップ)
5. [学習リソース](#学習リソース)

## 必要な前提知識

### 必須スキル
- ✅ 基本的なプログラミング経験（言語は問わない）
- ✅ コマンドライン（ターミナル）の基本操作
- ✅ テキストエディタの使用経験

### 推奨スキル
- 📝 HTML/CSS/JavaScriptの基礎知識
- 📝 SQLの基本的な理解
- 📝 HTTPとREST APIの概念理解

## Git/GitHubの基礎

### 1. Gitとは
バージョン管理システムで、コードの変更履歴を管理します。

### 2. 基本的なGitコマンド

#### 初期設定
```bash
# ユーザー名とメールアドレスの設定
git config --global user.name "あなたの名前"
git config --global user.email "your.email@example.com"

# 設定確認
git config --list
```

#### リポジトリの操作
```bash
# リポジトリの初期化
git init

# リモートリポジトリのクローン
git clone https://github.com/username/repository.git

# リモートリポジトリの追加
git remote add origin https://github.com/username/repository.git
```

#### 基本的なワークフロー
```bash
# 1. ファイルの変更状態を確認
git status

# 2. 変更をステージングエリアに追加
git add ファイル名
# または全ての変更を追加
git add .

# 3. コミット（変更を記録）
git commit -m "変更内容の説明"

# 4. リモートリポジトリにプッシュ
git push origin main

# 5. リモートの変更を取得
git pull origin main
```

#### ブランチ操作
```bash
# ブランチ一覧を表示
git branch

# 新しいブランチを作成して切り替え
git checkout -b feature/新機能

# ブランチを切り替え
git checkout main

# ブランチをマージ
git merge feature/新機能
```

### 3. GitHubの基本操作

#### アカウントの作成
1. [GitHub](https://github.com)にアクセス
2. "Sign up"をクリック
3. ユーザー名、メールアドレス、パスワードを設定

#### リポジトリの作成
1. GitHubにログイン
2. 右上の「+」→「New repository」
3. リポジトリ名を入力
4. Public/Privateを選択
5. 「Create repository」をクリック

#### 基本的な機能
- **Issues**: バグ報告や機能要望の管理
- **Pull Request**: コードレビューとマージ
- **Actions**: CI/CDワークフロー
- **README.md**: プロジェクトの説明

## コマンドラインの基礎

### Linux/macOS (bash/zsh)
```bash
# ディレクトリ操作
pwd              # 現在のディレクトリを表示
ls               # ファイル一覧を表示
ls -la           # 詳細情報を含む一覧表示
cd ディレクトリ名   # ディレクトリに移動
cd ..            # 親ディレクトリに移動
cd ~             # ホームディレクトリに移動

# ファイル・ディレクトリ操作
mkdir dirname    # ディレクトリ作成
touch filename   # 空ファイル作成
cp source dest   # ファイルをコピー
mv source dest   # ファイルを移動/名前変更
rm filename      # ファイルを削除
rm -rf dirname   # ディレクトリを削除

# ファイル内容の確認
cat filename     # ファイル内容を表示
less filename    # ページング表示
head -n 10 file  # 先頭10行を表示
tail -n 10 file  # 末尾10行を表示

# 検索
grep "text" file # ファイル内のテキスト検索
find . -name "*.txt" # ファイル検索

# 権限
chmod +x script.sh  # 実行権限を付与
```

### Windows (PowerShell/Command Prompt)
```powershell
# ディレクトリ操作
pwd              # 現在のディレクトリを表示
dir              # ファイル一覧を表示
cd ディレクトリ名   # ディレクトリに移動
cd ..            # 親ディレクトリに移動

# ファイル・ディレクトリ操作
mkdir dirname    # ディレクトリ作成
New-Item file    # ファイル作成
copy source dest # ファイルをコピー
move source dest # ファイルを移動
del filename     # ファイルを削除
rmdir /s dirname # ディレクトリを削除

# ファイル内容の確認
type filename    # ファイル内容を表示
more filename    # ページング表示
```

## 開発環境のセットアップ

### 1. 必須ツールのインストール

#### Git
- **Windows**: [Git for Windows](https://gitforwindows.org/)
- **macOS**: `brew install git` または Xcodeコマンドラインツール
- **Linux**: `sudo apt-get install git` (Ubuntu/Debian)

#### Visual Studio Code
1. [VS Code公式サイト](https://code.visualstudio.com/)からダウンロード
2. 推奨拡張機能：
   - GitLens
   - AWS Toolkit
   - Docker
   - YAML

#### AWS CLI
```bash
# macOS/Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Windows
# MSIインストーラーを公式サイトからダウンロード
```

#### Docker Desktop
- [Docker Desktop](https://www.docker.com/products/docker-desktop)からダウンロード

#### Node.js
- [Node.js公式サイト](https://nodejs.org/)からLTS版をダウンロード
- またはnvmを使用：
```bash
# nvm インストール
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Node.js インストール
nvm install --lts
nvm use --lts
```

### 2. アカウントの準備

#### AWS アカウント
1. [AWS](https://aws.amazon.com/)にアクセス
2. 「アカウントを作成」をクリック
3. クレジットカード情報が必要（無料利用枠あり）
4. **重要**: 請求アラートを設定

#### GitHub アカウント
1. [GitHub](https://github.com)でアカウント作成
2. SSH鍵の設定（推奨）：
```bash
# SSH鍵の生成
ssh-keygen -t ed25519 -C "your.email@example.com"

# 公開鍵をコピー
cat ~/.ssh/id_ed25519.pub

# GitHubの Settings > SSH and GPG keys に追加
```

## 学習リソース

### Git/GitHub
- 📚 [Pro Git Book（日本語）](https://git-scm.com/book/ja/v2)
- 🎥 [GitHub Skills](https://skills.github.com/)
- 📝 [サル先生のGit入門](https://backlog.com/ja/git-tutorial/)

### Linux/コマンドライン
- 📚 [Linux標準教科書](https://linuc.org/textbooks/linux/)
- 🎥 [Command Line Crash Course](https://developer.mozilla.org/ja/docs/Learn/Tools_and_testing/Understanding_client-side_tools/Command_line)

### AWS基礎
- 📚 [AWS ドキュメント](https://docs.aws.amazon.com/ja_jp/)
- 🎥 [AWS Skill Builder](https://skillbuilder.aws/)
- 📝 [AWS Well-Architected Framework](https://aws.amazon.com/jp/architecture/well-architected/)

### プログラミング基礎
- 📚 [MDN Web Docs](https://developer.mozilla.org/ja/)
- 🎥 [freeCodeCamp](https://www.freecodecamp.org/)
- 📝 [Qiita](https://qiita.com/)

## チェックリスト

学習を始める前に、以下の項目を確認してください：

### アカウント
- [ ] GitHubアカウントを作成した
- [ ] AWSアカウントを作成した
- [ ] AWSの請求アラートを設定した

### ツール
- [ ] Gitをインストールした
- [ ] VS Code（または好みのエディタ）をインストールした
- [ ] AWS CLIをインストールした
- [ ] Dockerをインストールした
- [ ] Node.jsをインストールした

### 基本操作
- [ ] ターミナル/コマンドプロンプトを開ける
- [ ] 基本的なディレクトリ操作ができる
- [ ] Gitの基本コマンドを理解した
- [ ] GitHubでリポジトリを作成できる

### 環境確認
- [ ] `git --version` が動作する
- [ ] `aws --version` が動作する
- [ ] `docker --version` が動作する
- [ ] `node --version` が動作する

すべてのチェックが完了したら、[01-infrastructure-basics](../01-infrastructure-basics/README.md)から学習を開始できます！

## 困ったときは

- **Git関連**: `git status` で現在の状態を確認
- **権限エラー**: `sudo` を使用（Linux/macOS）または管理者権限で実行（Windows）
- **パスが通らない**: 環境変数PATHの設定を確認
- **コマンドが見つからない**: インストールが正しく完了しているか確認

質問がある場合は、GitHubのIssueに投稿してください。
