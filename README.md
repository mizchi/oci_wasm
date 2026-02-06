# warg

WebAssembly パッケージレジストリの OCI Distribution クライアント。MoonBit で実装。

[wasi.dev](https://wasi.dev) / [wa.dev](https://wa.dev) 等の wasm-pkg レジストリから Wasm コンポーネントを取得できる。

## Features

- **Registry Discovery**: `/.well-known/wasm-pkg/registry.json` による自動レジストリ検出 (OCI / Warg)
- **OCI Distribution Client**: ghcr.io 等の OCI レジストリから Wasm バイナリを pull
  - Bearer トークン認証 (WWW-Authenticate パース)
  - タグ一覧 / マニフェスト取得 / blob ダウンロード
  - Wasm Config (コンポーネントメタデータ) 取得
- **Security**: SHA-256 ダイジェスト検証、SSRF 防止、入力バリデーション、サイズ制限

## Quick Start

```bash
just run  # wasi.dev 経由で wasi:http@0.2.0 を ghcr.io から取得するデモ
```

```bash
just           # check + test
just check     # 型チェック
just test      # テスト実行 (27 tests)
```

## Architecture

```
src/
├── types/        # 共通型定義・JSON パーサー・バリデーション
├── discovery/    # Well-Known レジストリ発見
├── oci/          # OCI Distribution クライアント
│   ├── auth      # トークン認証
│   └── client    # API クライアント本体
└── main/         # CLI デモ
```

### types

パッケージ名 (`wasi:http`)、OCI マニフェスト、ディスクリプタ、Wasm Config 等の型定義と JSON パーサー。入力バリデーション関数を含む。

| 型 | 説明 |
|---|---|
| `PackageName` | `namespace:name` 形式のパッケージ名 |
| `RegistryConfig` | レジストリ発見結果 (OCI or Warg) |
| `OciManifest` | OCI Image Manifest v2 |
| `OciDescriptor` | Content descriptor (mediaType, size, digest) |
| `WasmConfig` | Wasm コンポーネントのメタデータ |

### discovery

ホスト名から `https://{host}/.well-known/wasm-pkg/registry.json` を取得し、OCI / Warg どちらのプロトコルを使うかを判定する。

```moonbit
let config = @discovery.fetch_registry_config("wasi.dev")
// => OCI { registry: "ghcr.io", namespace_prefix: "webassembly/" }
```

### oci

OCI Distribution Spec 準拠の読み取り専用クライアント。

```moonbit
let pkg = @types.PackageName::parse("wasi:http").unwrap()
let client = @oci.OciClient::new("ghcr.io", "webassembly/", pkg)

let tags = client.list_tags(pkg)           // タグ一覧
let manifest = client.get_manifest(pkg, "0.2.0")  // マニフェスト
let config = client.get_wasm_config(pkg, "0.2.0")  // Wasm メタデータ
let wasm = client.pull_wasm(pkg, "0.2.0")  // Wasm バイナリ
```

**パッケージ名 → OCI リファレンス変換**:
`wasi:http@0.2.0` → `ghcr.io/webassembly/wasi/http:0.2.0`

## Security

| 対策 | 説明 |
|---|---|
| SHA-256 ダイジェスト検証 | blob ダウンロード後に `gmlewis/sha256` でハッシュ検証 |
| SSRF 防止 | リダイレクト先・realm URL を https + 非プライベート IP に制限 |
| 入力バリデーション | パッケージ名、ホスト名、ダイジェスト形式、OCI リファレンスを検証 |
| サイズ制限 | blob は 256MB 上限、ディスクリプタの宣言サイズとの一致を検証 |
| マニフェスト検証 | schemaVersion=2、mediaType の妥当性チェック |
| URL エンコード | トークン取得時のクエリパラメータをパーセントエンコード |

## Dependencies

- [moonbitlang/async](https://mooncakes.io/docs/#/moonbitlang/async/) - HTTP クライアント (native target)
- [gmlewis/sha256](https://mooncakes.io/docs/#/gmlewis/sha256/) - SHA-256 ダイジェスト検証

## Target

native のみ (`moonbitlang/async/http` が native target 専用のため)

## License

Apache-2.0
