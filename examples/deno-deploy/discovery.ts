// Registry discovery ported from MoonBit src/discovery/discovery.mbt

import {
  type RegistryConfig,
  validateHostname,
  parseRegistryConfig,
} from "./types.ts";

export async function fetchRegistryConfig(
  host: string,
): Promise<RegistryConfig> {
  if (!validateHostname(host)) {
    throw new Error("fetchRegistryConfig: invalid hostname");
  }
  const url = `https://${host}/.well-known/wasm-pkg/registry.json`;
  const response = await fetch(url);
  if (response.status !== 200) {
    throw new Error(`fetchRegistryConfig: HTTP ${response.status}`);
  }
  const json = await response.json();
  const config = parseRegistryConfig(json);
  if (!config) {
    throw new Error("fetchRegistryConfig: failed to parse JSON");
  }
  return config;
}
