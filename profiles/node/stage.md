# ステージの決まり（Node.js）

**載せない（P4 で止まる）:** `node_modules/`・`.next/`・`.nuxt/`・`.turbo/`・`.parcel-cache/`・`coverage/`（どこの下でも）。
`dist/`・`build/` は repo によって載せるので止めない。載せない repo は `commit-hooks.conf` の `generated=` で足す。

**気をつけて載せる:**
- ロックファイル（`package-lock.json`・`pnpm-lock.yaml`・`yarn.lock`）は `package.json` の依存を変えたら一緒に載せる
- `.npmrc` に `_authToken` が書いてあれば載せない（トークンは環境変数で渡す）

**コミットの前に:** 試験（`npm test` など）と型の検査があれば回して `確かめ:` に書く。
