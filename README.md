# commit-hooks

コミットメッセージの形と、載せてはいけない物を git のフックで検査する。決まりは [`rules.md`](rules.md)（これ 1 か所が正）。

ほかのリポジトリはこれを `git subtree` で取り込み、更新は `git subtree pull` で受け取る。**取り込んだ側でフックや rules.md を直さない**（直すとここからの更新とぶつかる。直したいときはこのリポジトリを直す）。

**読む人: 取り込む側のリポジトリで働く Claude Code（Codex でも同じ）と人。**

## 中身

| ファイル | 役目 |
|---|---|
| `rules.md` | メッセージの形と検査の一覧（M1〜M5・P1〜P3） |
| `hooks/commit-msg` | メッセージの形を検査する。外れたらコミットを止め、外れた項目とひな形を出す |
| `hooks/pre-commit` | ステージした中身を検査する（`.gitignore` に当たる物の `add -f`・秘密らしい名前・95MiB 超） |
| `hooks/relay.sh` | 中継のひな形。`install.sh` が `.git/hooks/` に書く |
| `install.sh` | 共有の `.git/hooks/` に中継を書く。`core.hooksPath` は変えない |
| `test.sh` | 使い捨ての repo で入れて、本物の `git commit` で 26 の場合を回す |
| `skill/SKILL.md` | Claude Code のコミットスキルのひな形（1 度写す） |

sh だけで動く（Windows は Git for Windows の sh・Mac と Linux は標準の sh）。

## 取り込む

取り込み先のルートで。置き場は `Tools/commit-hooks` を既定にする（変えるなら下の全部のパスを替える）。

1. 調べる（結果で分かれる）

   ```sh
   git config --get core.hooksPath                                    # A
   ls "$(git rev-parse --git-common-dir)/hooks" | grep -v '\.sample$'  # B
   git log -50 --format=%s | head -20                                 # C
   ```

   | 結果 | すること |
   |---|---|
   | A が空 | このまま進む |
   | A に値がある（husky・lefthook など） | 下の「hooksPath を使う repo」 |
   | B に `commit-msg` か `pre-commit` がある | `install.sh` は上書きせず FAIL で止まる。中身を読み、残すものならユーザーに確かめる |
   | C に `feat` 〜 `test` 以外の種類が多い | このリポジトリの `rules.md` と `hooks/commit-msg` の `types=` を直すかユーザーに確かめる（取り込んだ側では直さない） |

2. 取り込む（取り込み先の作業ツリーが綺麗な状態で）

   ```sh
   git subtree add --prefix=Tools/commit-hooks https://github.com/kaedeasset/commit-hooks.git main --squash
   ```

3. 試す・入れる

   ```sh
   sh Tools/commit-hooks/test.sh      # → HOOKS-TEST PASS cases=26
   sh Tools/commit-hooks/install.sh   # → HOOKS-INSTALL commit-msg=installed pre-commit=installed others=… verdict=PASS
   sh Tools/commit-hooks/install.sh   # 2 回目 → unchanged
   ```

   `others=` に、1 の B で見たフック（Git LFS の `post-checkout` など）が残っていること。

4. 本物で確かめる

   - `git commit --allow-empty -m "fix: 試し"` → M4・M5 で止まる
   - `rules.md` の形のファイルで `git commit --allow-empty -F <ファイル>` → 通る → `git reset --soft HEAD~1` で取り消す

5. スキルと規約
   - `skill/SKILL.md` を `.claude/skills/commit/SKILL.md` に写す（既にあるなら、メッセージの節だけ「正は `Tools/commit-hooks/rules.md`」に置き換え、その repo のステージの決まりは残す）
   - `CLAUDE.md`（Codex なら `AGENTS.md` も）に 1 行: 「**コミットメッセージの形と載せない物はフックが検査する**（形は `Tools/commit-hooks/rules.md`。`--no-verify` を使わない）」

6. 5 の変更をコミットする。このコミットがフックの最初の本番になる。push はユーザーに言われたときだけ。

**合格:** `HOOKS-TEST PASS`・`HOOKS-INSTALL … verdict=PASS`（2 回目は `unchanged`・元のフックが残る）・4 で旧い形が止まり新しい形が通る・6 のコミットが通る。報告には 1 の結果と各コマンドの最後の行を書く。

### 更新を受け取る

```sh
git subtree pull --prefix=Tools/commit-hooks https://github.com/kaedeasset/commit-hooks.git main --squash
sh Tools/commit-hooks/test.sh
```

中継は本体のパスを指すだけなので、更新の後に `install.sh` を回し直す必要はない（回しても `unchanged`）。subtree の作るコミットは `Merge …` なので検査に止められない。

### worktree を使っている repo

`.git/hooks/` は全 worktree で共有なので `install.sh` は 1 回でよい。本体は各 worktree の追跡ファイルを読むので、まだ取り込んでいないブランチの worktree では中継が「無い」と出して検査を飛ばす（取り込んだ main を入れれば効き始める）。

### hooksPath を使う repo

`core.hooksPath` があると `.git/hooks/` は読まれない。仕組みは外さず、その仕組みのフックから本体を呼ぶ。husky なら:

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

`$(git rev-parse --git-common-dir)/hooks/commit-msg` と `pre-commit` を消せば止まる。取り込んだフォルダは `git rm -r Tools/commit-hooks` で消す。

## 注意（踏んだもの）

- 文字数はロケールに頼らず、UTF-8 の続きのバイトを除いて数える（`LC_ALL=C` の awk で日本語 40 字が 120 字になった）。試験の「40 字は通る・41 字は止まる」で確かめている。
- Claude Code の Bash ツールのコマンド文字列にバックスラッシュを直接書くと潰れることがある。スクリプトはファイルに書いてから実行する。

## ライセンス

MIT（[LICENSE](LICENSE)）。
