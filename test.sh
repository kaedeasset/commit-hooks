#!/bin/sh
# test.sh — install.sh・commit-msg・pre-commit の試験。一時フォルダに使い捨ての repo を作り、
# このフォルダを Tools/commit-hooks/ に写して install.sh で入れ、本物の git commit で回す。
#   sh test.sh
# 場合ごとに CASE <名> ok|NG、最後に HOOKS-TEST PASS|FAIL（外れた場合の名前つき）。

src=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"
git init -q "$repo" || exit 1
cd "$repo" || exit 1
git config user.name test; git config user.email test@example.invalid; git config core.autocrlf false
mkdir -p Tools/commit-hooks/hooks
cp "$src/install.sh" Tools/commit-hooks/
cp "$src/hooks/commit-msg" "$src/hooks/pre-commit" "$src/hooks/relay.sh" Tools/commit-hooks/hooks/
printf 'Saved/\n*.bin\n' > .gitignore

failed=""
n=0
# check <名> <条件の終了コード>
check() { n=$((n + 1)); if [ "$2" -eq 0 ]; then echo "CASE $1 ok"; else echo "CASE $1 NG"; printf '%s\n' "$3" | sed 's/^/    /'; failed="$failed,$1"; fi; }

# --- install.sh
out=$(sh Tools/commit-hooks/install.sh 2>&1)
printf '%s' "$out" | grep -q 'commit-msg=installed pre-commit=installed .*verdict=PASS'; check 'install 1回目' $? "$out"
out=$(sh Tools/commit-hooks/install.sh 2>&1)
printf '%s' "$out" | grep -q 'commit-msg=unchanged pre-commit=unchanged .*verdict=PASS'; check 'install 2回目' $? "$out"
grep -q 'Tools/commit-hooks/hooks/commit-msg' .git/hooks/commit-msg; check '中継が置き場を指す' $? "$(cat .git/hooks/commit-msg)"
mkdir -p "$tmp/other"; git init -q "$tmp/other"; printf '#!/bin/sh\nexit 0\n' > "$tmp/other/.git/hooks/pre-commit"
mkdir -p "$tmp/other/ch/hooks"; cp Tools/commit-hooks/install.sh "$tmp/other/ch/"; cp Tools/commit-hooks/hooks/* "$tmp/other/ch/hooks/"
out=$(sh "$tmp/other/ch/install.sh" 2>&1); rc=$?
[ $rc -ne 0 ] && printf '%s' "$out" | grep -q 'pre-commit=conflict .*verdict=FAIL'; check '既存のフックを上書きしない' $? "$out"
git -C "$tmp/other" config core.hooksPath .husky
out=$(sh "$tmp/other/ch/install.sh" 2>&1); rc=$?
[ $rc -ne 0 ] && printf '%s' "$out" | grep -q 'verdict=FAIL'; check 'hooksPathがあれば止める' $? "$out"

# rules.md の例（説明を差し替えて使う）
good() {
    printf '%s\n\n期限が切れても前の画面に留まり、操作がすべて失敗していた。\n期限切れを受けたらログイン画面へ戻す。\n\n%s\n\n---\n原因は思ったより手前にあった。\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n' \
        "${1:-fix(login): 期限切れのときにログイン画面へ戻す}" "${2:-確かめ: 単体テスト 42 件 PASS。}"
}
git add .gitignore Tools
good "chore: 試験の土台" > "$tmp/m"
git commit -q -F "$tmp/m" >/dev/null 2>&1 || { echo 'HOOKS-TEST FAIL 土台のコミットができない'; exit 1; }

# expect <名> <pass|止める項目> <メッセージのファイル>  — ステージした中身でコミットを試し、結果を比べる
expect() {
    name=$1; want=$2; file=$3
    out=$(git commit -q -F "$file" 2>&1); rc=$?
    if [ "$want" = pass ]; then
        [ $rc -eq 0 ]; r=$?
    else
        [ $rc -ne 0 ] && printf '%s' "$out" | grep -q "FAIL.*$want"; r=$?
    fi
    check "$name" $r "want=$want rc=$rc
$out"
    # 止まった場合はステージを空に戻す
    git reset -q
}
# 小さな更新をステージする（メッセージの場合用）
k=0
touchfile() { k=$((k + 1)); echo "$k" >> note.txt; git add note.txt; }

# --- commit-msg
touchfile; good > "$tmp/m"; expect 'rules.md の例' pass "$tmp/m"
touchfile; good 'fix: 一二三四五六七八九十一二三四五六七八九十一二三四五六七八九十一二三四五六七八九十' > "$tmp/m"; expect '説明が40字' pass "$tmp/m"
touchfile; good 'fix: 一二三四五六七八九十一二三四五六七八九十一二三四五六七八九十一二三四五六七八九十一' > "$tmp/m"; expect '説明が41字' M2 "$tmp/m"
touchfile; good 'fix: abcdefghijabcdefghijabcdefghijabcdefghij' > "$tmp/m"; expect '英字で40字' pass "$tmp/m"
touchfile; good 'ログインを直した' > "$tmp/m"; expect '種類が無い' M1 "$tmp/m"
touchfile; good | sed '2s/^$/すぐ本文/' > "$tmp/m"; expect '2行目が空でない' M3 "$tmp/m"
touchfile; good | grep -v '^確かめ' > "$tmp/m"; expect '確かめが無い' M4 "$tmp/m"
touchfile; printf 'fix: ログインを直す\n\n確かめ: なし（文書のみ）\n\n---\n感想。\n' > "$tmp/m"; expect '本文が確かめだけ' M4 "$tmp/m"
touchfile; good | sed '/^---$/,/^$/d' > "$tmp/m"; expect '---が無い' M5 "$tmp/m"
touchfile; good | grep -v '^原因は' > "$tmp/m"; expect '---の後がCo-Authorだけ' M5 "$tmp/m"
touchfile; printf "Merge branch 'x'\n" > "$tmp/m"; expect 'Merge' pass "$tmp/m"
touchfile; printf 'Revert "fix: ログインを直す"\n\nThis reverts commit abc.\n' > "$tmp/m"; expect 'Revert' pass "$tmp/m"
touchfile; printf 'fixup! fix: ログインを直す\n' > "$tmp/m"; expect 'fixup' pass "$tmp/m"
touchfile; good '' '確かめ：全角のコロン' > "$tmp/m"; expect '全角の確かめ' pass "$tmp/m"
touchfile; good 'docs(readme): 範囲つき' > "$tmp/m"; expect '範囲つき' pass "$tmp/m"
touchfile; good | sed 's/$/\r/' > "$tmp/m"; expect 'CRLFのメッセージ' pass "$tmp/m"

# --- pre-commit（メッセージは rules.md の例）
good > "$tmp/m"
mkdir -p Saved; echo x > Saved/out.txt; git add -f Saved/out.txt; expect 'ignoreに当たるファイルをadd -f' P1 "$tmp/m"
touchfile; expect '追跡済みのファイルの更新' pass "$tmp/m"
echo SECRET=1 > .env; git add .env; expect '.envを足す' P2 "$tmp/m"
rm -f .env
mkdir -p big
head -c $((96 * 1048576)) /dev/zero > big/96.dat; git add big/96.dat; expect '96MBのファイル' P3 "$tmp/m"
rm -f big/96.dat
head -c $((60 * 1048576)) /dev/zero > big/60.dat; git add big/60.dat
out60=$(git commit -q -F "$tmp/m" 2>&1); rc60=$?
[ $rc60 -eq 0 ] && printf '%s' "$out60" | grep -q 'WARN P3'; check '60MBのファイル' $? "rc=$rc60
$out60"

if [ -z "$failed" ]; then echo "HOOKS-TEST PASS cases=$n"; exit 0; fi
echo "HOOKS-TEST FAIL cases=$n failed=${failed#,}"
exit 1
