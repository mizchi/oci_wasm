///|
async fn main {
  // 1. Discover registry config from wasi.dev
  println("Fetching registry config from wasi.dev...")
  let config = @discovery.fetch_registry_config("wasi.dev")
  println("Registry config: \{config}")
  // 2. Extract OCI config
  let (registry, prefix) = match config.preferred {
    @types.Oci(oci) => (oci.registry, oci.namespace_prefix)
    _ => {
      println("Error: expected OCI backend")
      return
    }
  }
  println("OCI registry: \{registry}, prefix: \{prefix}")
  // 3. Create OCI client for wasi:http
  let pkg = match @types.PackageName::parse("wasi:http") {
    Some(p) => p
    None => {
      println("Error: failed to parse package name")
      return
    }
  }
  println("Creating OCI client for \{pkg}...")
  let client = @oci.OciClient::new(registry, prefix, pkg)
  // 4. List tags
  println("Listing tags...")
  let tags = client.list_tags(pkg)
  println("Found \{tags.length()} tags:")
  for tag in tags {
    println("  \{tag}")
  }
  // 5. Get manifest for a known version
  let version = "0.2.0"
  println("\nGetting manifest for \{pkg}@\{version}...")
  let manifest = client.get_manifest(pkg, version)
  println("Manifest:")
  println("  schema_version: \{manifest.schema_version}")
  println("  media_type: \{manifest.media_type}")
  println(
    "  config: \{manifest.config.media_type} (\{manifest.config.size} bytes)",
  )
  println("  layers: \{manifest.layers.length()}")
  for layer in manifest.layers {
    println("    \{layer.media_type} (\{layer.size} bytes)")
  }
  // 6. Get wasm config
  println("\nGetting wasm config...")
  let wasm_config = client.get_wasm_config(pkg, version)
  println("Wasm config:")
  println("  architecture: \{wasm_config.architecture}")
  println("  os: \{wasm_config.os}")
  match wasm_config.component {
    Some(comp) => {
      println("  exports: [" + comp.exports.join(", ") + "]")
      println("  imports: [" + comp.imports.join(", ") + "]")
    }
    None => println("  no component info")
  }
  // 7. Pull wasm binary
  println("\nPulling wasm binary...")
  let wasm_bytes = client.pull_wasm(pkg, version)
  println("Downloaded \{wasm_bytes.length()} bytes of wasm")
  println("\nDone!")
}
