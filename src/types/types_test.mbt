///|
test "PackageName::parse valid" {
  let pkg = @types.PackageName::parse("wasi:http")
  assert_true(pkg is Some({ ns: "wasi", name: "http", }))
}

///|
test "PackageName::parse invalid" {
  let pkg = @types.PackageName::parse("invalid")
  assert_true(pkg is None)
}

///|
test "PackageName::to_string" {
  let pkg = @types.PackageName::parse("wasi:http").unwrap()
  inspect(pkg.to_string(), content="wasi:http")
}

///|
test "AnyHash::parse valid" {
  let hash = @types.AnyHash::parse("sha256:abc123")
  assert_true(hash is Some({ algorithm: "sha256", hex: "abc123", }))
}

///|
test "AnyHash::parse invalid" {
  let hash = @types.AnyHash::parse("nocolon")
  assert_true(hash is None)
}

///|
test "OciManifest::from_json" {
  let s =
    #|{
    #|  "schemaVersion": 2,
    #|  "mediaType": "application/vnd.oci.image.manifest.v1+json",
    #|  "config": {
    #|    "mediaType": "application/vnd.wasm.config.v0+json",
    #|    "size": 353,
    #|    "digest": "sha256:abc"
    #|  },
    #|  "layers": [
    #|    {
    #|      "mediaType": "application/wasm",
    #|      "size": 37882,
    #|      "digest": "sha256:def"
    #|    }
    #|  ]
    #|}
  let json = @json.parse(s)
  let manifest = @types.OciManifest::from_json(json).unwrap()
  inspect(manifest.schema_version, content="2")
  inspect(
    manifest.config.media_type,
    content="application/vnd.wasm.config.v0+json",
  )
  inspect(manifest.config.size, content="353")
  inspect(manifest.layers.length(), content="1")
  inspect(manifest.layers[0].media_type, content="application/wasm")
  inspect(manifest.layers[0].size, content="37882")
}

///|
test "RegistryConfig::from_json modern format" {
  let s =
    #|{
    #|  "preferredProtocol": "oci",
    #|  "oci": {
    #|    "registry": "ghcr.io",
    #|    "namespacePrefix": "webassembly/"
    #|  }
    #|}
  let json = @json.parse(s)
  let config = @types.RegistryConfig::from_json(json).unwrap()
  match config.preferred {
    @types.Oci(oci) => {
      inspect(oci.registry, content="ghcr.io")
      inspect(oci.namespace_prefix, content="webassembly/")
    }
    _ => fail("expected Oci backend")
  }
}

///|
test "RegistryConfig::from_json legacy format" {
  let s =
    #|{
    #|  "ociRegistry": "ghcr.io",
    #|  "ociNamespacePrefix": "webassembly/"
    #|}
  let json = @json.parse(s)
  let config = @types.RegistryConfig::from_json(json).unwrap()
  match config.preferred {
    @types.Oci(oci) => {
      inspect(oci.registry, content="ghcr.io")
      inspect(oci.namespace_prefix, content="webassembly/")
    }
    _ => fail("expected Oci backend")
  }
}

///|
test "validate_name_component" {
  inspect(@types.validate_name_component("hello"), content="true")
  inspect(@types.validate_name_component("my-pkg"), content="true")
  inspect(@types.validate_name_component("a.b_c"), content="true")
  inspect(@types.validate_name_component(""), content="false")
  inspect(@types.validate_name_component("UPPER"), content="false")
  inspect(@types.validate_name_component("has space"), content="false")
  inspect(@types.validate_name_component("path/sep"), content="false")
}

///|
test "validate_hostname" {
  inspect(@types.validate_hostname("ghcr.io"), content="true")
  inspect(@types.validate_hostname("registry.example.com"), content="true")
  inspect(@types.validate_hostname("localhost:8080"), content="true")
  inspect(@types.validate_hostname(""), content="false")
  inspect(@types.validate_hostname("host:abc"), content="false")
  inspect(@types.validate_hostname("host::8080"), content="false")
  inspect(@types.validate_hostname("host name"), content="false")
}

///|
test "validate_digest" {
  inspect(@types.validate_digest("sha256:abc123"), content="true")
  inspect(@types.validate_digest("sha512:def456"), content="true")
  inspect(@types.validate_digest("nocolon"), content="false")
  inspect(@types.validate_digest(":abc"), content="false")
  inspect(@types.validate_digest("sha256:"), content="false")
  inspect(@types.validate_digest("sha256:UPPER"), content="false")
}

///|
test "validate_reference" {
  inspect(@types.validate_reference("0.2.0"), content="true")
  inspect(@types.validate_reference("latest"), content="true")
  inspect(@types.validate_reference("sha256:abc123"), content="true")
  inspect(@types.validate_reference(""), content="false")
  inspect(@types.validate_reference("has space"), content="false")
}

///|
test "validate_https_url" {
  inspect(
    @types.validate_https_url("https://auth.ghcr.io/token"),
    content="true",
  )
  inspect(@types.validate_https_url("https://example.com/path"), content="true")
  inspect(@types.validate_https_url("http://example.com"), content="false")
  inspect(@types.validate_https_url("https://localhost/x"), content="false")
  inspect(@types.validate_https_url("https://127.0.0.1/x"), content="false")
  inspect(@types.validate_https_url("https://10.0.0.1/x"), content="false")
  inspect(@types.validate_https_url("https://192.168.1.1/x"), content="false")
  inspect(@types.validate_https_url("https://172.16.0.1/x"), content="false")
  inspect(@types.validate_https_url("https://172.31.255.1/x"), content="false")
  inspect(@types.validate_https_url("https://172.15.0.1/x"), content="true")
  inspect(@types.validate_https_url("https://172.32.0.1/x"), content="true")
}

///|
test "validate_namespace_prefix" {
  inspect(@types.validate_namespace_prefix("webassembly/"), content="true")
  inspect(@types.validate_namespace_prefix("org/sub/"), content="true")
  inspect(@types.validate_namespace_prefix(""), content="true")
  inspect(@types.validate_namespace_prefix("has space"), content="false")
}

///|
test "WasmConfig::from_json" {
  let s =
    #|{
    #|  "architecture": "wasm",
    #|  "os": "wasip2",
    #|  "component": {
    #|    "exports": ["wasi:http/types@0.2.0"],
    #|    "imports": [],
    #|    "target": null
    #|  }
    #|}
  let json = @json.parse(s)
  let config = @types.WasmConfig::from_json(json).unwrap()
  inspect(config.architecture, content="wasm")
  inspect(config.os, content="wasip2")
  let comp = config.component.unwrap()
  inspect(comp.exports.length(), content="1")
  inspect(comp.exports[0], content="wasi:http/types@0.2.0")
  inspect(comp.imports.length(), content="0")
  assert_true(comp.target is None)
}
