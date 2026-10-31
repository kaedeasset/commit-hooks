# commit-hooks

コミットメッセージの形と、載せてはいけない物を git のフックで検査する。決まりは [`rules.md`](rules.md)（これ 1 か所が正）。

**このリポジトリが正。** 直すのは主にここ。ほかのリポジトリはこれを `git subtree` で取り込み、更新は `git subtree pull` で受け取る。取り込んだ側で直したときは、その日のうちに `git subtree push` でここへ送り返す（下の「運用マニュアル」）。

**読む人: 取り込む側のリポジトリで働く Claude Code（Codex でも同じ）と人。**

## どこを直すか（3 段）

repo ごとの違いは、取り込んだフォルダの**外**の `commit-hooks.conf` に書く。だから pull しても上書きされない。

| 直したいもの | 直す場所 | pull で |
|---|---|---|
| 全部の repo に効く決まり（メッセージの形・検査の仕組み・既定の値） | このリポジトリの `rules.md`・`hooks/`・`profiles/common.conf` | 全部の repo に入る |
| あるフレームワークの repo 全部に効くもの（生成物のフォルダ・`.meta`・ステージの決まり） | このリポジトリの `profiles/<profile>/`（`unreal`・`unity`・`node`・`plain`） | そのフレームワークの repo に入る |
| その repo だけの違い（種類を足す・字数・生成物を足す） | 取り込んだ repo の直下の `commit-hooks.conf` | 上書きされない |

フレームワークを足すときは `profiles/<名>/profile.conf` と `stage.md` を作り、`test.sh` に場合を足し、「フレームワークごとの運用の違い」の表に列を足す。

## 中身

| ファイル | 役目 |
|---|---|
| `rules.md` | メッセージの形と検査の一覧（M1〜M5・P1〜P7）・値の 3 段 |
| `hooks/commit-msg` | メッセージの形を検査する。外れたらコミットを止め、外れた項目とひな形を出す |
| `hooks/pre-commit` | ステージした中身を検査する（`add -f`・秘密らしい名前・大きさ・生成物と OS が作るファイル・Unity の `.meta`・Unreal のマップの載せ漏れ・LFS の素通り） |
| `hooks/conf.sh` | 値を 3 段で読む |
| `hooks/relay.sh` | 中継のひな形。`install.sh` が `.git/hooks/` に書く |
| `profiles/common.conf` | 全部の値の名前と既定 |
| `profiles/<profile>/profile.conf`・`stage.md` | フレームワーク別の値と、ステージの決まり（人と Claude Code が読む） |
| `commit-hooks.conf.example` | repo の直下に置く設定のひな形（`install.sh` が写す） |
| `install.sh` | 中継を書き、`commit-hooks.conf` が無ければ作る。`core.hooksPath` は変えない |
| `test.sh` | 使い捨ての repo で入れて、本物の `git commit` で 63 の場合を回す |
| `skill/SKILL.md` | Claude Code のコミットスキルのひな形（1 度写す。中身は `rules.md` と `stage.md` を指すだけ） |

sh だけで動く（Windows は Git for Windows の sh・Mac と Linux は標準の sh）。

## 取り込む

取り込み先のルートで。置き場は `Tools/commit-hooks` を既定にする（変えるなら下の全部のパスを替える）。

1. 調べる（結果で分かれる）

   ```sh
   git config --get core.hooksPath                                    # A
   ls "$(git rev-parse --git-common-dir)/hooks" | grep -v '\.sample$'  # B
   git log -50 --format=%s | head -20                                 # C
   ls *.uproject Assets/ ProjectSettings/ package.json 2>/dev/null    # D
   ```

   | 結果 | すること |
   |---|---|
   | A が空 | このまま進む |
   | A に値がある（husky・lefthook など） | 下の「hooksPath を使う repo」 |
   | B に `commit-msg` か `pre-commit` がある | `install.sh` は上書きせず FAIL で止まる。中身を読み、残すものならユーザーに確かめる |
   | C に `feat` 〜 `test` 以外の種類が多い | 5 で `commit-hooks.conf` の `types=` に足す |
   | D | profile を決める: `.uproject` → `unreal`・`Assets/` と `ProjectSettings/` → `unity`・`package.json` → `node`・どれも無い → `plain`。Unity のプロジェクトが repo の 1 段下にあれば、5 で `generated=` を上書きする（`profiles/unity/profile.conf` の注） |

2. 取り込む（取り込み先の作業ツリーが綺麗な状態で）

   ```sh
   git subtree add --prefix=Tools/commit-hooks https://github.com/kaedeasset/commit-hooks.git main --squash
   ```

3. 試す・入れる

   ```sh
   sh Tools/commit-hooks/test.sh               # → HOOKS-TEST PASS cases=63
   sh Tools/commit-hooks/install.sh unreal     # → HOOKS-INSTALL conf=created commit-msg=installed pre-commit=installed others=… verdict=PASS
   sh Tools/commit-hooks/install.sh unreal     # 2 回目 → conf=exists … unchanged
   ```

   `others=` に、1 の B で見たフック（Git LFS の `post-checkout` など）が残っていること。

4. 本物で確かめる

   - `git commit --allow-empty -m "fix: 試し"` → M4・M5 で止まる
   - `rules.md` の形のファイルで `git commit --allow-empty -F <ファイル>` → 通る → `git reset --soft HEAD~1` で取り消す

5. その repo だけの違いを `commit-hooks.conf` に書く（1 の C・D で要ると分かったものだけ）。

6. スキルと規約
   - `skill/SKILL.md` を `.claude/skills/commit/SKILL.md` に写す。既にあるなら、メッセージとステージの決まりのうち `rules.md`・`stage.md` と重なる節を「正は `Tools/commit-hooks/…`」に置き換え、その repo だけの決まりは残す
   - `CLAUDE.md`（Codex なら `AGENTS.md` も）に 1 行: 「**コミットメッセージの形と載せない物はフックが検査する**（形は `Tools/commit-hooks/rules.md`。`--no-verify` を使わない）」
   - 取り込み先の `.gitattributes` に `Tools/commit-hooks/** text eol=lf`（下の「改行」）

7. `commit-hooks.conf` と 6 の変更をコミットする。このコミットがフックの最初の本番になる。push はユーザーに言われたときだけ。

**合格:** `HOOKS-TEST PASS`・`HOOKS-INSTALL … verdict=PASS`（2 回目は `conf=exists`・`unchanged`・元のフックが残る）・4 で旧い形が止まり新しい形が通る・7 のコミットが通る。報告には 1 の結果・選んだ profile・各コマンドの最後の行を書く。

### worktree を使っている repo

`.git/hooks/` は全 worktree で共有なので `install.sh` は 1 回でよい。本体と `commit-hooks.conf` は各 worktree の追跡ファイルを読むので、まだ取り込んでいないブランチの worktree では中継が「無い」と出して検査を飛ばす（取り込んだ main を入れれば効き始める）。

### hooksPath を使う repo

`core.hooksPath` があると `.git/hooks/` は読まれない。仕組みは外さず、その仕組みのフックから本体を呼ぶ（`commit-hooks.conf` はひな形 `commit-hooks.conf.example` を repo の直下に写して `profile=` を書く）。husky なら:

```sh
# .husky/commit-msg
sh Tools/commit-hooks/hooks/commit-msg "$1"
# .husky/pre-commit
sh Tools/commit-hooks/hooks/pre-commit
```

### 改行

sh のファイルは LF でないと落ちる。このリポジトリの `.gitattributes` は subtree では効かないので、取り込み先の `.gitattributes` に足す:

```
Tools/commit-hooks/** text eol=lf
```

## フレームワークごとの運用の違い

取り込み・返し方・受け取り方の流れはどのフレームワークでも同じ（下の「運用マニュアル」）。違うのは次のところだけ。
ステージしない物とコミット前に確かめることの細目は `profiles/<profile>/stage.md`。

| | Unreal（`unreal`） | Unity（`unity`） | Node.js（`node`） |
|---|---|---|---|
| フックの入れ方 | `install.sh unreal`。Git LFS のフックが `.git/hooks/` に並ぶが、そのまま残る | `install.sh unity` | husky・lefthook を使う repo では `install.sh` が止まる → その仕組みのフックから本体を呼ぶ（「hooksPath を使う repo」）。**husky を後から入れると、`npm install` のたびに `core.hooksPath` が書かれて中継が黙って効かなくなる**。入れたら同じ日に `.husky/` へ 2 本を足す |
| 取り込む前の設定 | LFS を使うなら、全部の PC で `git lfs install`（忘れると P7 で止まる） | Project Settings の **Version Control → Mode = Visible Meta Files** と **Editor → Asset Serialization → Mode = Force Text**（新しいプロジェクトの既定はこの 2 つ。古いプロジェクトは確かめる）（バイナリのままだと .meta とシーンの差分が読めない）。LFS を使うなら `git lfs install` | なし |
| 合わせられないファイル | `.uasset`・`.umap` はマージできない。同じアセットを 2 か所で同時に直さない（LFS を使うなら `git lfs lock`）。ぶつかったら片方を選ぶしかない | シーン・プレハブは Force Text なら UnityYAMLMerge（Smart Merge）で合わせられる。git の mergetool に登録しておく。テクスチャ・モデルは合わせられない | ロックファイルはぶつかったら手で合わせず、`package.json` を合わせてから `npm install` で作り直す |
| まとめて変わるコミット | エンジンの版上げ・アセットの一括保存・リダイレクタの整理は、それだけのコミットに分ける（差分が大きく、ほかの変更が埋もれる） | エディタの版上げ（`ProjectSettings/ProjectVersion.txt`）と、それで書き換わるアセットは、それだけのコミットに分ける | 依存の一括更新は、それだけのコミットに分ける |
| `確かめ:` に書くもの | C++ を変えたらビルドの結果（例 `確かめ: UE ビルド Succeeded（Result: Succeeded）`）。アセットだけならエディタで開いて確かめたこと | エディタでコンパイルエラー 0・Play で確かめたこと・テストランナーの結果 | `npm test`・型の検査・lint の結果（例 `確かめ: npm test 120 件 PASS・tsc エラー 0`） |
| worktree | worktree ごとに `Intermediate/`・`DerivedDataCache/` が別にでき、最初のビルドが重い | worktree ごとに `Library/` が別にでき、最初の読み込みが重い | worktree ごとに `npm install` が要る |
| 誰が育てるか | このリポジトリ（Unreal の repo で使いながら） | Unity の repo が育てて返す | Node.js の repo が育てて返す |

フレームワークを足すときは、この表に列を足し、`profiles/<名>/` を作る。

## Windows と Mac の違い

フックは git が自分の sh で動かすので、どちらの OS でもコミットのときの動きは同じ。違うのは、手で回すときと、ファイルの扱い。

| | Windows | Mac | どうする |
|---|---|---|---|
| `install.sh`・`test.sh` を手で回す | PowerShell・cmd では `sh` が見つからない（Git for Windows は `Git\cmd` だけを PATH に足す） | `sh` がある | Windows は Git Bash で回すか、`& "C:\Program Files\Git\bin\sh.exe" Tools/commit-hooks/install.sh unreal` |
| 改行 | Git for Windows の既定は `core.autocrlf=true`。sh のファイルが CRLF で取り出されると落ちる | 既定は変換しない | 取り込み先の `.gitattributes` に `Tools/commit-hooks/** text eol=lf`（「改行」）。人ごとの autocrlf に頼らない |
| 中継の実行の印 | 気にしなくてよい | 実行の印が無いフックは、git が注意を出して**飛ばす** | `install.sh` が `chmod +x` する。手で写したときは `chmod +x .git/hooks/commit-msg .git/hooks/pre-commit` |
| 大文字小文字だけの名前の変更 | 区別しない（NTFS） | 既定は区別しない（APFS） | `git mv -f Foo.cpp foo.cpp` で変える（エクスプローラーや Finder で変えると git が気づかない）。区別する Linux の CI でだけ落ちる |
| 日本語のファイル名 | そのまま | 濁点などが分かれた形（NFD）で保存される | Mac で `git config core.precomposeunicode` が `true`（既定）のままにする。`false` だと同じ名前が別のファイルとして入る |
| パスの長さ | 260 字を超えると取り出せないことがある（`node_modules`・UE のプラグインの奥） | 制限は気にしなくてよい | Windows は `git config --global core.longpaths true` |
| OS が作るファイル | `Thumbs.db`・`desktop.ini` | `.DS_Store`・`._*` | P4 がどの profile でも止める。`.gitignore` にも足しておく |
| LFS | PC ごとに `git lfs install` | 同じ | 忘れると P7 で止まる |

**フックやスクリプトを直して返す人へ:** 本体は POSIX の sh・awk・sed・grep だけで書く。GNU にしか無い書き方（`sed -i`・sed の置き換えの `\t` や `\r`・`grep -P`・`date +%N`・`awk -v` で正規表現を渡す）は Mac で動かないか、黙って違う結果になる。どちらかの OS で `test.sh` が PASS したら、もう一方でも回せるなら回す（返すときの報告にどちらで回したかを書く）。

### Node.js（Windows と Mac の両方で使う repo）

| | 注意 | どうする |
|---|---|---|
| npm scripts | Windows の npm は scripts を cmd.exe で動かす。`rm -rf`・`FOO=1 node …`・`cp` など sh の書き方は Windows で落ちる | `rimraf`・`cross-env` などを使うか、処理を `node scripts/x.mjs` に書く。`確かめ:` にどちらの OS で回したかを書く |
| ロックファイル | 片方の OS で依存を足すと、もう片方の OS 用の任意の依存（`@esbuild/*`・`@rollup/rollup-*` など）がロックファイルから消えることがある（npm の既知の不具合）。もう一方の OS や CI で `Cannot find module @rollup/rollup-…` になる | 依存を変えたコミットは、ロックファイルの差分で別の OS 用の行が消えていないかを見る。消えていたら `node_modules` とロックファイルを消して `npm install` し直す |
| husky | `.husky/` のフックは Windows でも Git for Windows の sh で動く。CRLF だと落ちる | `.gitattributes` に `.husky/** text eol=lf` |
| `node_modules` | OS ごとにネイティブのモジュールが違う | PC の間で写さない・載せない（P4 が止める）。OS を替えたら `npm install` し直す |

## 運用マニュアル

### 誰が何を育てるか

| 部分 | 育てる repo | ここでの扱い |
|---|---|---|
| 共通（`rules.md`・`hooks/`・`profiles/common.conf`・`install.sh`・`test.sh`） | このリポジトリ | ここで直す |
| `profiles/unreal/` | このリポジトリ（Unreal の repo で使いながら） | **力を入れる**。Unreal で踏んだ罠は検査にして足す |
| `profiles/unity/`・`profiles/node/` | それぞれのフレームワークを使っている repo | 土台だけ置いている。育てるのはその repo で、直したら subtree push で返してもらう |
| フレームワークの新しい profile | それを使う repo | `profiles/<名>/profile.conf`・`stage.md` と test.sh の場合を作って返す |

### 流れ（1 回の直しが全部の repo に届くまで）

```
取り込み先 A で直す ──subtree push──▶ ここのブランチ from-A-<日付>
                                              │ test.sh を回して main に入れる
ここで直す ─────────────────────────────▶ main
                                              │
                  各 repo（A を含む）◀── subtree pull
```

main へ入れるのはこのリポジトリだけ。取り込み先は main へ直接 push しない。

### 取り込み先で直した分を返す（subtree push）

**返すもの:** ほかの repo にも効く直し（フックの不具合・検査の追加・フレームワーク別の決まり・stage.md の追記）。
**返さないもの:** その repo だけの違い（`commit-hooks.conf` に書く。取り込んだフォルダの外なので返らない）。

1. 取り込み先で `Tools/commit-hooks/` の下**だけ**を変えたコミットを作る。ほかのファイルと混ぜない（混ぜたコミットも返るが、そのときの件名と本文がほかのファイルの話になる）。メッセージは `rules.md` の形で、件名の範囲に profile を書く（例 `feat(unity): …`・`fix(hooks): …`）。
2. `sh Tools/commit-hooks/test.sh` が PASS すること。検査を足したなら、止まる場合と通る場合を test.sh に足してあること。
3. ブランチとして送る:

   ```sh
   git subtree push --prefix=Tools/commit-hooks https://github.com/kaedeasset/commit-hooks.git from-<repo名>-<YYYYMMDD>
   ```

   - 書き込みの権限が要る（kaedeasset の repo）。権限の無い人は、GitHub で fork してそこへ push し、PR を出す
   - 履歴の長い repo では、分ける計算に数分かかる（`git subtree split` が全部の履歴をたどる）
   - 同じ日に 2 回返すときは、ブランチ名の末尾に `-2` を付ける
4. 返したことを、その repo の作業の報告に 1 行書く（ブランチ名）。ここの main に入るまでは、その repo の中で先に効いているだけ。

### 返ってきたブランチを main に入れる（このリポジトリの作業）

```sh
git fetch origin
git log --oneline main..origin/from-<repo名>-<日付>      # 何が来たか
git diff main...origin/from-<repo名>-<日付> --stat
git switch main && git merge --no-ff origin/from-<repo名>-<日付>   # 件名は Merge … なので検査に止められない
sh test.sh                                                 # HOOKS-TEST PASS
git push origin main && git push origin --delete from-<repo名>-<日付>
```

入れる前に見ること:
- **共通の部分（`hooks/`・`common.conf`）を変えていないか。** 変えていれば、ほかのフレームワークの repo にも効く。Unreal の repo で試してから入れる
- **既定を変えていないか。** `common.conf` の値（字数・種類・大きさ）を変えると全部の repo が変わる。その repo だけの事情なら、その repo の `commit-hooks.conf` へ戻してもらう
- **新しい設定の名前には、必ず `common.conf` に既定を足しているか。** 既定が無いと、pull しただけの repo が全部 `COMMIT-HOOKS FAIL conf` で止まる
- 外の人の PR なら、フックは誰の PC でも動くシェルなので、中身を全部読んでから入れる

ぶつかったら、ここで解く。取り込み先では解かない（取り込み先は pull だけをする）。

### ここで直す

1. このリポジトリで直す。検査を変えたら test.sh に止まる場合と通る場合を足す。新しい設定の名前は `common.conf` に既定つきで足す（フレームワーク別の値は `profiles/<名>/profile.conf`）
2. `sh test.sh` → `HOOKS-TEST PASS`
3. コミットして push（このリポジトリにもフックが入っている。`sh install.sh plain`）
4. 使っている repo に「pull して」と伝える（下）

### 更新を受け取る（subtree pull）

```sh
git subtree pull --prefix=Tools/commit-hooks https://github.com/kaedeasset/commit-hooks.git main --squash
sh Tools/commit-hooks/test.sh
```

- 中継は本体のパスを指すだけなので、`install.sh` を回し直す必要はない（回しても `unchanged`）
- `commit-hooks.conf` は取り込んだフォルダの外なので変わらない
- subtree の作るコミットは `Merge …` なので検査に止められない
- 作業ツリーが汚れていると pull できない。先にコミットする
- いつ pull するか: 返したブランチが main に入った後と、ここから「pull して」と言われたとき。毎日でなくてよい

### やらないこと

- 取り込み先で直して返さずに置く（次の pull でぶつかる・ほかの repo に届かない）
- 取り込み先から main へ直接 push する
- `--no-verify` で止まったコミットを通す（止まったら検査か中身のどちらが違うかを見る。検査が違うならここを直して返す）
- 自分の repo の事情のために `common.conf` の既定を変える

## 戻し方

`$(git rev-parse --git-common-dir)/hooks/commit-msg` と `pre-commit` を消せば止まる。取り込んだフォルダは `git rm -r Tools/commit-hooks`、設定は `git rm commit-hooks.conf` で消す。

## 注意（踏んだもの）

- 文字数はロケールに頼らず、UTF-8 の続きのバイトを除いて数える（`LC_ALL=C` の awk で日本語 40 字が 120 字になった）。試験の「40 字は通る・41 字は止まる」で確かめている。
- Mac の sed は置き換えの `\t`・`\r` を文字にしない。タブや CR が要るところは awk か `printf` で作る（試験の CRLF の場合がこれで Mac だけ落ちるところだった）。
- `awk -v` で正規表現を渡すと `\.` などのエスケープが先に消え、`^id_rsa\.pub$` が `id_rsaXpub` にも当たっていた。環境変数で渡して `ENVIRON` で読む。
- Claude Code の Bash ツールのコマンド文字列にバックスラッシュを直接書くと潰れることがある。スクリプトはファイルに書いてから実行する。

## ライセンス

MIT（[LICENSE](LICENSE)）。
