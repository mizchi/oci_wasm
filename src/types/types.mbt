///|
/// Package name in `namespace:name` format (e.g., "wasi:http")
pub struct PackageName {
  ns : String
  name : String
} derive(Eq)

///|
pub fn PackageName::parse(input : String) -> PackageName? {
  match input.find(":") {
    Some(idx) =>
      Some(PackageName::{
        ns: input.view(end_offset=idx).to_owned(),
        name: input.view(start_offset=idx + 1).to_owned(),
      })
    None => None
  }
}

///|
pub fn PackageName::to_string(self : PackageName) -> String {
  "\{self.ns}:\{self.name}"
}

///|
/// Content-addressable hash in `algorithm:hex` format
pub struct AnyHash {
  algorithm : String
  hex : String
} derive(Eq)

///|
pub fn AnyHash::parse(digest : String) -> AnyHash? {
  match digest.find(":") {
    Some(idx) =>
      Some(AnyHash::{
        algorithm: digest.view(end_offset=idx).to_owned(),
        hex: digest.view(start_offset=idx + 1).to_owned(),
      })
    None => None
  }
}

///|
pub fn AnyHash::to_string(self : AnyHash) -> String {
  "\{self.algorithm}:\{self.hex}"
}

///|
/// OCI registry configuration
pub struct OciConfig {
  registry : String
  namespace_prefix : String
} derive(Eq)

///|
/// Warg protocol configuration
pub struct WargConfig {
  url : String
} derive(Eq)

///|
/// Registry backend protocol
pub enum RegistryBackend {
  Oci(OciConfig)
  Warg(WargConfig)
} derive(Eq)

///|
/// Registry discovery result
pub struct RegistryConfig {
  preferred : RegistryBackend
  oci : OciConfig?
  warg : WargConfig?
} derive(Eq)

///|
/// OCI content descriptor
pub struct OciDescriptor {
  media_type : String
  size : Int64
  digest : String
} derive(Eq)

///|
/// OCI image manifest
pub struct OciManifest {
  schema_version : Int
  media_type : String
  config : OciDescriptor
  layers : Array[OciDescriptor]
} derive(Eq)

///|
/// Wasm component metadata
pub struct WasmComponentInfo {
  exports : Array[String]
  imports : Array[String]
  target : String?
} derive(Eq)

///|
/// Wasm config from OCI config blob
pub struct WasmConfig {
  architecture : String
  os : String
  component : WasmComponentInfo?
} derive(Eq)

///|
pub let manifest_media_type : String = "application/vnd.oci.image.manifest.v1+json"

///|
pub let wasm_media_type : String = "application/wasm"

///|
pub let wasm_config_media_type : String = "application/vnd.wasm.config.v0+json"
