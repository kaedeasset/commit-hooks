---
description: Use when the user asks to commit changes, stage files, or create a git commit. Triggers on "コミットして", "commit", "変更をコミット".
---

# コミット Skill

`git add` → `git commit` を決まった形で行う。**メッセージの形と検査の正は `Tools/commit-hooks/rules.md`**（この SKILL に写さない）。
<!-- 取り込み先が Tools/commit-hooks 以外なら、上と下のパスを直す。この SKILL は 1 度写したら更新を受け取らなくてよい（中身は rules.md を指すだけ） -->

## 手順

1. `git status` と `git diff --stat` で変更を見る
2. ステージするファイルを決める（下）
3. `Tools/commit-hooks/rules.md` の形でメッセージをファイルに書く
4. `git commit -F <ファイル>`
5. フックで止まったら、表示された項目どおりに直して 4 へ。**`--no-verify` を使わない**
6. `git status` / `git log --oneline -1` で成功を確かめる

## ステージするファイル

| ユーザーの表現 | 動作 |
|---|---|
| "コミットして" | **今回の依頼で変更・作成したファイル**だけ。他の作業の未コミットや自分が作っていないファイルは含めず、残っていることを報告する |
| "全部コミットして" | 未追跡を含む全変更（生成物・秘密は除く）。自分が作っていないファイルは中身を確かめてから |

<!-- ここから下に、この repo だけの決まり（生成物のフォルダ・ビルドの確認など）を書く -->
