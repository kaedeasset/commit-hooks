# ステージの決まり（Unreal Engine）

**載せない（P4 で止まる）:** `Binaries/`・`Intermediate/`・`Saved/`・`DerivedDataCache/`・`.vs/`（`Plugins/*/` の下も同じ）。

**気をつけて載せる:**
- `.uasset`・`.umap` は Git LFS で扱う repo が多い。LFS の対象（`.gitattributes` の `filter=lfs`）に入っていない大きいアセットを足すと P3 で止まる
- `*.sln`・`*.code-workspace` などエディタが作るプロジェクトファイルは、その repo の決まりに従う（多くは載せない）
- 購入したアセット（Fab・Marketplace）は、配布の規約で公開できないことがある。public の repo には載せない

**コミットの前に:** C++（`Source/`・`Plugins/*/Source/`）を変えたら、ビルドが通ることを確かめて `確かめ:` に書く（エディタを閉じて Build.bat）。
