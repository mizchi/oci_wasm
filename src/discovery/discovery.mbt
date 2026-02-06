///|
/// Fetch registry configuration from a host's well-known URL.
/// GET https://{host}/.well-known/wasm-pkg/registry.json
/// Validates hostname to prevent injection (#11).
pub async fn fetch_registry_config(
  host : String,
) -> @types.RegistryConfig raise Error {
  guard @types.validate_hostname(host) else {
    raise Failure::Failure("fetch_registry_config: invalid hostname")
  }
  let url = "https://\{host}/.well-known/wasm-pkg/registry.json"
  let (status, json) = @ffi.fetch_json(url)
  guard status == 200 else {
    raise Failure::Failure("fetch_registry_config: HTTP \{status}")
  }
  guard @types.RegistryConfig::from_json(json) is Some(config) else {
    raise Failure::Failure("fetch_registry_config: failed to parse JSON")
  }
  config
}
