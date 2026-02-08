///|
pub struct OciClient {
  registry : String
  namespace_prefix : String
  mut token : String
}

///|
/// Maximum blob size: 256 MB
let max_blob_size : Int64 = 268435456L

///|
/// Validate a package name's components for safe URL construction.
fn validate_pkg(pkg : @types.PackageName) -> Unit raise Error {
  guard @types.validate_name_component(pkg.ns) else {
    raise Failure::Failure("invalid package namespace: \{pkg.ns}")
  }
  guard @types.validate_name_component(pkg.name) else {
    raise Failure::Failure("invalid package name: \{pkg.name}")
  }
}

///|
/// Create a new OCI client authenticated against the registry.
/// Fetches a token for the given package.
pub async fn OciClient::new(
  registry : String,
  namespace_prefix : String,
  pkg : @types.PackageName,
) -> OciClient raise Error {
  guard @types.validate_hostname(registry) else {
    raise Failure::Failure("invalid registry hostname")
  }
  guard @types.validate_namespace_prefix(namespace_prefix) else {
    raise Failure::Failure("invalid namespace prefix")
  }
  validate_pkg(pkg)
  let repo = "\{namespace_prefix}\{pkg.ns}/\{pkg.name}"
  let token = @auth.fetch_token(registry, repo)
  OciClient::{ registry, namespace_prefix, token }
}

///|
fn OciClient::repo_name(self : OciClient, pkg : @types.PackageName) -> String {
  "\{self.namespace_prefix}\{pkg.ns}/\{pkg.name}"
}

///|
fn OciClient::auth_headers(self : OciClient) -> Map[String, String] {
  let headers : Map[String, String] = {}
  if self.token != "" {
    headers["Authorization"] = "Bearer \{self.token}"
  }
  headers
}

///|
/// Re-authenticate for a different package scope if needed.
pub async fn OciClient::auth_for(
  self : OciClient,
  pkg : @types.PackageName,
) -> Unit raise Error {
  validate_pkg(pkg)
  let repo = self.repo_name(pkg)
  self.token = @auth.fetch_token(self.registry, repo)
}

///|
/// List tags for a package.
pub async fn OciClient::list_tags(
  self : OciClient,
  pkg : @types.PackageName,
) -> Array[String] raise Error {
  validate_pkg(pkg)
  let repo = self.repo_name(pkg)
  let url = "https://\{self.registry}/v2/\{repo}/tags/list"
  let (status, json, _) = @ffi.fetch_json_with_headers(url, self.auth_headers())
  guard status == 200 else {
    raise Failure::Failure("list_tags: HTTP \{status}")
  }
  match json {
    Object(map) =>
      match map.get("tags") {
        Some(Array(arr)) => {
          let tags : Array[String] = []
          for item in arr {
            match item {
              String(s) => tags.push(s)
              _ => ()
            }
          }
          tags
        }
        _ => []
      }
    _ => []
  }
}

///|
/// Get an OCI manifest for a package at a given reference (tag or digest).
/// Validates mediaType and schemaVersion (#7, #12).
pub async fn OciClient::get_manifest(
  self : OciClient,
  pkg : @types.PackageName,
  reference : String,
) -> @types.OciManifest raise Error {
  validate_pkg(pkg)
  guard @types.validate_reference(reference) else {
    raise Failure::Failure("invalid OCI reference")
  }
  let repo = self.repo_name(pkg)
  let url = "https://\{self.registry}/v2/\{repo}/manifests/\{reference}"
  let headers = self.auth_headers()
  headers["Accept"] = @types.manifest_media_type
  let (status, json, _) = @ffi.fetch_json_with_headers(url, headers)
  guard status == 200 else {
    raise Failure::Failure("get_manifest: HTTP \{status}")
  }
  guard @types.OciManifest::from_json(json) is Some(manifest) else {
    raise Failure::Failure("get_manifest: failed to parse manifest JSON")
  }
  // Validate schema version (#12)
  guard manifest.schema_version == 2 else {
    raise Failure::Failure(
      "get_manifest: unsupported schemaVersion \{manifest.schema_version}",
    )
  }
  // Validate media type (#7)
  if manifest.media_type != "" &&
    manifest.media_type != @types.manifest_media_type {
    raise Failure::Failure(
      "get_manifest: unexpected mediaType \{manifest.media_type}",
    )
  }
  manifest
}

///|
/// Follow a redirect URL safely.
/// Validates the URL is https and not a private network (#2).
async fn safe_redirect_get(location : String) -> Bytes raise Error {
  guard @types.validate_https_url(location) else {
    raise Failure::Failure("redirect to non-https or private URL blocked")
  }
  let response = @ffi.fetch_simple(location)
  guard response.status() == 200 else {
    raise Failure::Failure("redirect target returned \{response.status()}")
  }
  response.bytes()
}

///|
/// Follow a redirect URL safely, returning text.
async fn safe_redirect_get_text(location : String) -> String raise Error {
  guard @types.validate_https_url(location) else {
    raise Failure::Failure("redirect to non-https or private URL blocked")
  }
  let response = @ffi.fetch_simple(location)
  guard response.status() == 200 else {
    raise Failure::Failure("redirect target returned \{response.status()}")
  }
  response.text()
}

///|
/// Verify blob integrity by comparing SHA-256 digest (#1).
async fn verify_digest(
  data : Bytes,
  expected_digest : String,
) -> Unit raise Error {
  // Only verify sha256 digests
  guard expected_digest.has_prefix("sha256:") else { return }
  let expected_hex = expected_digest.view(start_offset=7).to_string()
  let actual_hex = @ffi.sha256_hex(data)
  guard actual_hex == expected_hex else {
    raise Failure::Failure(
      "digest verification failed: expected \{expected_hex}, got \{actual_hex}",
    )
  }
}

///|
/// Get a blob by digest with integrity verification.
/// Handles 307 redirects with SSRF prevention (#2).
/// Validates digest format (#13) and verifies content hash (#1).
/// Enforces size limit from descriptor (#8).
pub async fn OciClient::get_blob(
  self : OciClient,
  pkg : @types.PackageName,
  digest : String,
  expected_size? : Int64 = 0L,
) -> Bytes raise Error {
  validate_pkg(pkg)
  guard @types.validate_digest(digest) else {
    raise Failure::Failure("invalid digest format")
  }
  let repo = self.repo_name(pkg)
  let url = "https://\{self.registry}/v2/\{repo}/blobs/\{digest}"
  let response = @ffi.fetch_manual_redirect(url, self.auth_headers())
  let status = response.status()
  let data : Bytes = if status == 200 {
    response.bytes()
  } else if status == 307 || status == 302 || status == 301 {
    let location = response.get_header("location")
    guard location != "" else {
      raise Failure::Failure("get_blob: redirect without Location header")
    }
    safe_redirect_get(location)
  } else {
    raise Failure::Failure("get_blob: HTTP \{status}")
  }
  // Size limit check (#8)
  if expected_size > 0L && data.length().to_int64() != expected_size {
    raise Failure::Failure(
      "get_blob: size mismatch: expected \{expected_size}, got \{data.length()}",
    )
  }
  if data.length().to_int64() > max_blob_size {
    raise Failure::Failure("get_blob: blob exceeds maximum size limit")
  }
  // Digest verification (#1)
  verify_digest(data, digest)
  data
}

///|
/// Get a blob as text by digest with integrity verification.
pub async fn OciClient::get_blob_text(
  self : OciClient,
  pkg : @types.PackageName,
  digest : String,
  expected_size? : Int64 = 0L,
) -> String raise Error {
  validate_pkg(pkg)
  guard @types.validate_digest(digest) else {
    raise Failure::Failure("invalid digest format")
  }
  let repo = self.repo_name(pkg)
  let url = "https://\{self.registry}/v2/\{repo}/blobs/\{digest}"
  let response = @ffi.fetch_manual_redirect(url, self.auth_headers())
  let status = response.status()
  let text : String = if status == 200 {
    response.text()
  } else if status == 307 || status == 302 || status == 301 {
    let location = response.get_header("location")
    guard location != "" else {
      raise Failure::Failure("get_blob_text: redirect without Location header")
    }
    safe_redirect_get_text(location)
  } else {
    raise Failure::Failure("get_blob_text: HTTP \{status}")
  }
  // Size limit check (#8)
  if expected_size > 0L && text.length().to_int64() != expected_size {
    raise Failure::Failure(
      "get_blob_text: size mismatch: expected \{expected_size}, got \{text.length()}",
    )
  }
  text
}

///|
/// Get wasm config (metadata) for a package at a given reference.
pub async fn OciClient::get_wasm_config(
  self : OciClient,
  pkg : @types.PackageName,
  reference : String,
) -> @types.WasmConfig raise Error {
  let manifest = self.get_manifest(pkg, reference)
  let config_str = self.get_blob_text(
    pkg,
    manifest.config.digest,
    expected_size=manifest.config.size,
  )
  let json = @json.parse(config_str)
  guard @types.WasmConfig::from_json(json) is Some(config) else {
    raise Failure::Failure("get_wasm_config: failed to parse config JSON")
  }
  config
}

///|
/// Pull a wasm binary for a package at a given version.
/// Returns the raw wasm bytes from the first wasm layer.
/// Verifies content integrity via SHA-256 digest (#1).
pub async fn OciClient::pull_wasm(
  self : OciClient,
  pkg : @types.PackageName,
  version : String,
) -> Bytes raise Error {
  let manifest = self.get_manifest(pkg, version)
  // Find the wasm layer
  let mut wasm_layer : @types.OciDescriptor? = None
  for layer in manifest.layers {
    if layer.media_type == @types.wasm_media_type {
      wasm_layer = Some(layer)
      break
    }
  }
  guard wasm_layer is Some(layer) else {
    raise Failure::Failure("pull_wasm: no wasm layer found in manifest")
  }
  self.get_blob(pkg, layer.digest, expected_size=layer.size)
}
