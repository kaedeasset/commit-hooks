# commit-hooks

コミットメッセージの形と、載せてはいけない物を git のフックで検査する。決まりは [`rules.md`](rules.md)（これ 1 か所が正）。

**このリポジトリが正。** 直すのは主にここ。ほかのリポジトリはこれを `git subtree` で取り込み、更新は `git subtree pull` で受け取る。取り込んだ側で直したときは、その日のうちに `git subtree push` でここへ送り返す（下の「取り込み先で直した分を返す」）。

**読む人: 取り込む側のリポジトリで働く Claude Code（Codex でも同じ）と人。**

## どこを直すか（3 段）

repo ごとの違いは、取り込んだフォルダの**外**の `commit-hooks.conf` に書く。だから pull しても上書きされない。

| 直したいもの | 直す場所 | pull で |
|---|---|---|
| 全部の repo に効く決まり（メッセージの形・検査の仕組み・既定の値） | このリポジトリの `rules.md`・`hooks/`・`profiles/common.conf` | 全部の repo に入る |
| あるフレームワークの repo 全部に効くもの（生成物のフォルダ・`.meta`・ステージの決まり） | このリポジトリの `profiles/<profile>/`（`unreal`・`unity`・`node`・`plain`） | そのフレームワークの repo に入る |
| その repo だけの違い（種類を足す・字数・生成物を足す） | 取り込んだ repo の直下の `commit-hooks.conf` | 上書きされない |

フレームワークを足すときは `profiles/<名>/profile.conf` と `stage.md` を作り、`test.sh` に場合を足す。

## 中身

| ファイル | 役目 |
|---|---|
| `rules.md` | メッセージの形と検査の一覧（M1〜M5・P1〜P5）・値の 3 段 |
| `hooks/commit-msg` | メッセージの形を検査する。外れたらコミットを止め、外れた項目とひな形を出す |
| `hooks/pre-commit` | ステージした中身を検査する（`add -f`・秘密らしい名前・大きさ・生成物・Unity の `.meta`） |
| `hooks/conf.sh` | 値を 3 段で読む |
| `hooks/relay.sh` | 中継のひな形。`install.sh` が `.git/hooks/` に書く |
| `profiles/common.conf` | 全部の値の名前と既定 |
| `profiles/<profile>/profile.conf`・`stage.md` | フレームワーク別の値と、ステージの決まり（人と Claude Code が読む） |
| `commit-hooks.conf.example` | repo の直下に置く設定のひな形（`install.sh` が写す） |
| `install.sh` | 中継を書き、`commit-hooks.conf` が無ければ作る。`core.hooksPath` は変えない |
| `test.sh` | 使い捨ての repo で入れて、本物の `git commit` で 50 の場合を回す |
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
   sh Tools/commit-hooks/test.sh               # → HOOKS-TEST PASS cases=50
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

### 更新を受け取る

```sh
git subtree pull --prefix=Tools/commit-hooks https://github.com/kaedeasset/commit-hooks.git main --squash
sh Tools/commit-hooks/test.sh
```

中継は本体のパスを指すだけなので、更新の後に `install.sh` を回し直す必要はない（回しても `unchanged`）。`commit-hooks.conf` は取り込んだフォルダの外なので変わらない。subtree の作るコミットは `Merge …` なので検査に止められない。

### 取り込み先で直した分を返す

その repo だけの違いなら返さない（`commit-hooks.conf` に書く）。ほかの repo にも効く直し（フックの不具合・フレームワーク別の決まり）だけを返す。

1. 取り込み先で `Tools/commit-hooks/` の下**だけ**を変えたコミットを作る（ほかのファイルと混ぜない。混ぜると返るコミットにその repo の件名と本文が付いてくる）。`sh Tools/commit-hooks/test.sh` が PASS すること。
2. ブランチとして送る（main へは直接送らない）:

   ```sh
   git subtree push --prefix=Tools/commit-hooks https://github.com/kaedeasset/commit-hooks.git from-<repo名>-<日付>
   ```

   履歴の長い repo では、分ける計算に数分かかる。
3. このリポジトリで、そのブランチを読んで main に入れる（`gh pr create --base main --head <ブランチ>` で PR にするか、手元で `git merge`）。test.sh を回してから。入れたらブランチを消す。
4. 送った repo を含め、各 repo が「更新を受け取る」の pull をする。送った repo でもぶつからない（同じ中身が返ってくるだけ）。

返す前にここで別の変更が入っていたら、3 で普通のマージになる。ぶつかったらここで解いて、各 repo は pull だけをする（取り込み先では解かない）。

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

## 戻し方

`$(git rev-parse --git-common-dir)/hooks/commit-msg` と `pre-commit` を消せば止まる。取り込んだフォルダは `git rm -r Tools/commit-hooks`、設定は `git rm commit-hooks.conf` で消す。

## 注意（踏んだもの）

- 文字数はロケールに頼らず、UTF-8 の続きのバイトを除いて数える（`LC_ALL=C` の awk で日本語 40 字が 120 字になった）。試験の「40 字は通る・41 字は止まる」で確かめている。
- Mac の sed は `\t` をタブにしない。タブが要るところは awk か `printf '\t'` で作る。
- Claude Code の Bash ツールのコマンド文字列にバックスラッシュを直接書くと潰れることがある。スクリプトはファイルに書いてから実行する。

## ライセンス

MIT（[LICENSE](LICENSE)）。
