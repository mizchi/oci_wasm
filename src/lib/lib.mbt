///|
fn main {

}

///|
fn registry_config_to_json(config : @types.RegistryConfig) -> Json {
  let obj : Map[String, Json] = {}
  match config.preferred {
    @types.Oci(oci) => {
      let pref : Map[String, Json] = {}
      pref["type"] = Json::string("oci")
      pref["registry"] = Json::string(oci.registry)
      pref["namespacePrefix"] = Json::string(oci.namespace_prefix)
      obj["preferred"] = Json::object(pref)
    }
    @types.Warg(warg) => {
      let pref : Map[String, Json] = {}
      pref["type"] = Json::string("warg")
      pref["url"] = Json::string(warg.url)
      obj["preferred"] = Json::object(pref)
    }
  }
  match config.oci {
    Some(oci) => {
      let o : Map[String, Json] = {}
      o["registry"] = Json::string(oci.registry)
      o["namespacePrefix"] = Json::string(oci.namespace_prefix)
      obj["oci"] = Json::object(o)
    }
    None => ()
  }
  match config.warg {
    Some(warg) => {
      let w : Map[String, Json] = {}
      w["url"] = Json::string(warg.url)
      obj["warg"] = Json::object(w)
    }
    None => ()
  }
  Json::object(obj)
}

///|
fn manifest_to_json(manifest : @types.OciManifest) -> Json {
  let obj : Map[String, Json] = {}
  obj["schemaVersion"] = Json::number(manifest.schema_version.to_double())
  obj["mediaType"] = Json::string(manifest.media_type)
  let config : Map[String, Json] = {}
  config["mediaType"] = Json::string(manifest.config.media_type)
  config["size"] = Json::number(manifest.config.size.to_double())
  config["digest"] = Json::string(manifest.config.digest)
  obj["config"] = Json::object(config)
  let layers : Array[Json] = []
  for layer in manifest.layers {
    let l : Map[String, Json] = {}
    l["mediaType"] = Json::string(layer.media_type)
    l["size"] = Json::number(layer.size.to_double())
    l["digest"] = Json::string(layer.digest)
    layers.push(Json::object(l))
  }
  obj["layers"] = Json::array(layers)
  Json::object(obj)
}

///|
fn wasm_config_to_json(config : @types.WasmConfig) -> Json {
  let obj : Map[String, Json] = {}
  obj["architecture"] = Json::string(config.architecture)
  obj["os"] = Json::string(config.os)
  match config.component {
    Some(comp) => {
      let c : Map[String, Json] = {}
      let exports : Array[Json] = []
      for e in comp.exports {
        exports.push(Json::string(e))
      }
      c["exports"] = Json::array(exports)
      let imports : Array[Json] = []
      for i in comp.imports {
        imports.push(Json::string(i))
      }
      c["imports"] = Json::array(imports)
      match comp.target {
        Some(t) => c["target"] = Json::string(t)
        None => ()
      }
      obj["component"] = Json::object(c)
    }
    None => ()
  }
  Json::object(obj)
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
  @js_async.Promise::from_async(fn() {
    let config = @discovery.fetch_registry_config(host)
    registry_config_to_json(config)
  })
}

///|
pub fn list_tags(
  registry : String,
  ns_prefix : String,
  pkg_str : String,
) -> @js_async.Promise[Json] {
  @js_async.Promise::from_async(fn() {
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
  @js_async.Promise::from_async(fn() {
    let pkg = match @types.PackageName::parse(pkg_str) {
      Some(p) => p
      None => raise Failure::Failure("invalid package name: \{pkg_str}")
    }
    let client = @oci.OciClient::new(registry, ns_prefix, pkg)
    let manifest = client.get_manifest(pkg, reference)
    manifest_to_json(manifest)
  })
}

///|
pub fn get_wasm_config(
  registry : String,
  ns_prefix : String,
  pkg_str : String,
  reference : String,
) -> @js_async.Promise[Json] {
  @js_async.Promise::from_async(fn() {
    let pkg = match @types.PackageName::parse(pkg_str) {
      Some(p) => p
      None => raise Failure::Failure("invalid package name: \{pkg_str}")
    }
    let client = @oci.OciClient::new(registry, ns_prefix, pkg)
    let config = client.get_wasm_config(pkg, reference)
    wasm_config_to_json(config)
  })
}

///|
pub fn pull_wasm(
  registry : String,
  ns_prefix : String,
  pkg_str : String,
  version : String,
) -> @js_async.Promise[Bytes] {
  @js_async.Promise::from_async(fn() {
    let pkg = match @types.PackageName::parse(pkg_str) {
      Some(p) => p
      None => raise Failure::Failure("invalid package name: \{pkg_str}")
    }
    let client = @oci.OciClient::new(registry, ns_prefix, pkg)
    client.pull_wasm(pkg, version)
  })
}
