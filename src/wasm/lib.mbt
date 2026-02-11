///|
fn main {

}

///|
fn tags_to_json(tags : Array[String]) -> Json {
  let arr : Array[Json] = []
  for tag in tags {
    arr.push(Json::string(tag))
  }
  Json::array(arr)
}

///|
pub fn discover(host : String) -> @js_async.Promise[Json] {
  @js_async.Promise::from_async(async fn() {
    let config = @discovery.fetch_registry_config(host)
    config.to_json()
  })
}

///|
pub fn list_tags(
  registry : String,
  ns_prefix : String,
  pkg_str : String,
) -> @js_async.Promise[Json] {
  @js_async.Promise::from_async(async fn() {
    let pkg = match @types.PackageName::parse(pkg_str) {
      Some(p) => p
      None => raise Failure::Failure("invalid package name: \{pkg_str}")
    }
    let client = @oci.OciClient::new(registry, ns_prefix, pkg)
    let tags = client.list_tags(pkg)
    tags_to_json(tags)
  })
}

///|
pub fn get_manifest(
  registry : String,
  ns_prefix : String,
  pkg_str : String,
  reference : String,
) -> @js_async.Promise[Json] {
  @js_async.Promise::from_async(async fn() {
    let pkg = match @types.PackageName::parse(pkg_str) {
      Some(p) => p
      None => raise Failure::Failure("invalid package name: \{pkg_str}")
    }
    let client = @oci.OciClient::new(registry, ns_prefix, pkg)
    let manifest = client.get_manifest(pkg, reference)
    manifest.to_json()
  })
}

///|
pub fn get_wasm_config(
  registry : String,
  ns_prefix : String,
  pkg_str : String,
  reference : String,
) -> @js_async.Promise[Json] {
  @js_async.Promise::from_async(async fn() {
    let pkg = match @types.PackageName::parse(pkg_str) {
      Some(p) => p
      None => raise Failure::Failure("invalid package name: \{pkg_str}")
    }
    let client = @oci.OciClient::new(registry, ns_prefix, pkg)
    let config = client.get_wasm_config(pkg, reference)
    config.to_json()
  })
}

///|
pub fn pull_wasm(
  registry : String,
  ns_prefix : String,
  pkg_str : String,
  version : String,
) -> @js_async.Promise[Bytes] {
  @js_async.Promise::from_async(async fn() {
    let pkg = match @types.PackageName::parse(pkg_str) {
      Some(p) => p
      None => raise Failure::Failure("invalid package name: \{pkg_str}")
    }
    let client = @oci.OciClient::new(registry, ns_prefix, pkg)
    client.pull_wasm(pkg, version)
  })
}
