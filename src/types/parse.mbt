///|
/// Parse OCI manifest from JSON
pub fn OciManifest::from_json(json : Json) -> OciManifest? {
  match json {
    Object(map) => {
      let schema_version = match map.get("schemaVersion") {
        Some(Number(n, ..)) => n.to_int()
        _ => return None
      }
      let media_type = match map.get("mediaType") {
        Some(String(s)) => s
        _ => ""
      }
      let config = match map.get("config") {
        Some(c) =>
          match OciDescriptor::from_json(c) {
            Some(d) => d
            None => return None
          }
        _ => return None
      }
      let layers : Array[OciDescriptor] = []
      match map.get("layers") {
        Some(Array(arr)) =>
          for item in arr {
            match OciDescriptor::from_json(item) {
              Some(d) => layers.push(d)
              None => return None
            }
          }
        _ => return None
      }
      Some(OciManifest::{ schema_version, media_type, config, layers, })
    }
    _ => None
  }
}

///|
/// Parse OCI descriptor from JSON
pub fn OciDescriptor::from_json(json : Json) -> OciDescriptor? {
  match json {
    Object(map) => {
      let media_type = match map.get("mediaType") {
        Some(String(s)) => s
        _ => return None
      }
      let size : Int64 = match map.get("size") {
        Some(Number(n, ..)) => n.to_int64()
        _ => return None
      }
      let digest = match map.get("digest") {
        Some(String(s)) => s
        _ => return None
      }
      Some(OciDescriptor::{ media_type, size, digest, })
    }
    _ => None
  }
}

///|
/// Parse WasmConfig from JSON
pub fn WasmConfig::from_json(json : Json) -> WasmConfig? {
  match json {
    Object(map) => {
      let architecture = match map.get("architecture") {
        Some(String(s)) => s
        _ => "wasm"
      }
      let os = match map.get("os") {
        Some(String(s)) => s
        _ => "wasip2"
      }
      let component : WasmComponentInfo? = match map.get("component") {
        Some(c) => WasmComponentInfo::from_json(c)
        _ => None
      }
      Some(WasmConfig::{ architecture, os, component, })
    }
    _ => None
  }
}

///|
/// Parse WasmComponentInfo from JSON
pub fn WasmComponentInfo::from_json(json : Json) -> WasmComponentInfo? {
  match json {
    Object(map) => {
      let exports : Array[String] = []
      match map.get("exports") {
        Some(Array(arr)) =>
          for item in arr {
            match item {
              String(s) => exports.push(s)
              _ => ()
            }
          }
        _ => ()
      }
      let imports : Array[String] = []
      match map.get("imports") {
        Some(Array(arr)) =>
          for item in arr {
            match item {
              String(s) => imports.push(s)
              _ => ()
            }
          }
        _ => ()
      }
      let target : String? = match map.get("target") {
        Some(String(s)) => Some(s)
        _ => None
      }
      Some(WasmComponentInfo::{ exports, imports, target, })
    }
    _ => None
  }
}

///|
/// Parse registry config from well-known JSON
pub fn RegistryConfig::from_json(json : Json) -> RegistryConfig? {
  match json {
    Object(map) => {
      // Parse OCI config (modern or legacy format)
      let oci : OciConfig? = match map.get("oci") {
        Some(Object(oci_map)) => {
          let registry = match oci_map.get("registry") {
            Some(String(s)) => s
            _ => return None
          }
          let namespace_prefix = match oci_map.get("namespacePrefix") {
            Some(String(s)) => s
            _ => ""
          }
          Some(OciConfig::{ registry, namespace_prefix, })
        }
        _ =>
          // Legacy format
          match map.get("ociRegistry") {
            Some(String(registry)) => {
              let namespace_prefix = match map.get("ociNamespacePrefix") {
                Some(String(s)) => s
                _ => ""
              }
              Some(OciConfig::{ registry, namespace_prefix, })
            }
            _ => None
          }
      }
      // Parse Warg config (modern or legacy format)
      let warg : WargConfig? = match map.get("warg") {
        Some(Object(warg_map)) =>
          match warg_map.get("url") {
            Some(String(url)) => Some(WargConfig::{ url, })
            _ => None
          }
        _ =>
          match map.get("wargUrl") {
            Some(String(url)) => Some(WargConfig::{ url, })
            _ => None
          }
      }
      // Determine preferred backend
      let preferred_protocol : String = match map.get("preferredProtocol") {
        Some(String(s)) => s
        _ => if oci is Some(_) { "oci" } else { "warg" }
      }
      let preferred : RegistryBackend = if preferred_protocol == "oci" {
        match oci {
          Some(c) => Oci(c)
          None => return None
        }
      } else {
        match warg {
          Some(c) => Warg(c)
          None => return None
        }
      }
      Some(RegistryConfig::{ preferred, oci, warg, })
    }
    _ => None
  }
}
