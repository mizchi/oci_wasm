///|
// Keep the public Show representation stable without deprecated collection impls.
fn[T] show_optional(value : T?, render : (T) -> String) -> String {
  match value {
    None => "None"
    Some(value) => "Some(" + render(value) + ")"
  }
}

///|
fn[T] show_array(values : Array[T], render : (T) -> String) -> String {
  "[" + values.map(render).join(", ") + "]"
}

///|
pub impl Show for PackageName with fn output(self, logger) {
  logger.write_string(
    "{" +
    "ns: " +
    Show::to_string(self.ns) +
    ", name: " +
    Show::to_string(self.name) +
    "}",
  )
}

///|
pub impl Show for AnyHash with fn output(self, logger) {
  logger.write_string(
    "{" +
    "algorithm: " +
    Show::to_string(self.algorithm) +
    ", hex: " +
    Show::to_string(self.hex) +
    "}",
  )
}

///|
pub impl Show for OciConfig with fn output(self, logger) {
  logger.write_string(
    "{" +
    "registry: " +
    Show::to_string(self.registry) +
    ", namespace_prefix: " +
    Show::to_string(self.namespace_prefix) +
    "}",
  )
}

///|
pub impl Show for WargConfig with fn output(self, logger) {
  logger.write_string("{" + "url: " + Show::to_string(self.url) + "}")
}

///|
pub impl Show for RegistryBackend with fn output(self, logger) {
  match self {
    Oci(arg0) => logger.write_string("Oci(" + "" + Show::to_string(arg0) + ")")
    Warg(arg0) =>
      logger.write_string("Warg(" + "" + Show::to_string(arg0) + ")")
  }
}

///|
pub impl Show for RegistryConfig with fn output(self, logger) {
  logger.write_string(
    "{" +
    "preferred: " +
    Show::to_string(self.preferred) +
    ", oci: " +
    show_optional(self.oci, value => Show::to_string(value)) +
    ", warg: " +
    show_optional(self.warg, value => Show::to_string(value)) +
    "}",
  )
}

///|
pub impl Show for OciDescriptor with fn output(self, logger) {
  logger.write_string(
    "{" +
    "media_type: " +
    Show::to_string(self.media_type) +
    ", size: " +
    Show::to_string(self.size) +
    ", digest: " +
    Show::to_string(self.digest) +
    "}",
  )
}

///|
pub impl Show for OciManifest with fn output(self, logger) {
  logger.write_string(
    "{" +
    "schema_version: " +
    Show::to_string(self.schema_version) +
    ", media_type: " +
    Show::to_string(self.media_type) +
    ", config: " +
    Show::to_string(self.config) +
    ", layers: " +
    show_array(self.layers, value => Show::to_string(value)) +
    "}",
  )
}

///|
pub impl Show for WasmComponentInfo with fn output(self, logger) {
  logger.write_string(
    "{" +
    "exports: " +
    show_array(self.exports, value => Show::to_string(value)) +
    ", imports: " +
    show_array(self.imports, value => Show::to_string(value)) +
    ", target: " +
    show_optional(self.target, value => Show::to_string(value)) +
    "}",
  )
}

///|
pub impl Show for WasmConfig with fn output(self, logger) {
  logger.write_string(
    "{" +
    "architecture: " +
    Show::to_string(self.architecture) +
    ", os: " +
    Show::to_string(self.os) +
    ", component: " +
    show_optional(self.component, value => Show::to_string(value)) +
    "}",
  )
}

///|
pub extend PackageName with Show::{output}

///|
pub extend PackageName with Eq::{not_equal, equal}

///|
pub extend AnyHash with Show::{output}

///|
pub extend AnyHash with Eq::{not_equal, equal}

///|
pub extend OciConfig with Show::{to_string, output}

///|
pub extend OciConfig with Eq::{not_equal, equal}

///|
pub extend WargConfig with Show::{to_string, output}

///|
pub extend WargConfig with Eq::{not_equal, equal}

///|
pub extend RegistryBackend with Show::{to_string, output}

///|
pub extend RegistryBackend with Eq::{not_equal, equal}

///|
pub extend RegistryConfig with Show::{to_string, output}

///|
pub extend RegistryConfig with Eq::{not_equal, equal}

///|
pub extend OciDescriptor with Show::{to_string, output}

///|
pub extend OciDescriptor with Eq::{not_equal, equal}

///|
pub extend OciManifest with Show::{to_string, output}

///|
pub extend OciManifest with Eq::{not_equal, equal}

///|
pub extend WasmComponentInfo with Show::{to_string, output}

///|
pub extend WasmComponentInfo with Eq::{not_equal, equal}

///|
pub extend WasmConfig with Show::{to_string, output}

///|
pub extend WasmConfig with Eq::{not_equal, equal}
