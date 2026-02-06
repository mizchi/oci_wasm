// Types, validation, and JSON parsers ported from MoonBit src/types/

// --- Types ---

export interface PackageName {
  ns: string;
  name: string;
}

export interface OciConfig {
  registry: string;
  namespacePrefix: string;
}

export interface WargConfig {
  url: string;
}

export type RegistryBackend =
  | { type: "oci"; config: OciConfig }
  | { type: "warg"; config: WargConfig };

export interface RegistryConfig {
  preferred: RegistryBackend;
  oci?: OciConfig;
  warg?: WargConfig;
}

export interface OciDescriptor {
  mediaType: string;
  size: number;
  digest: string;
}

export interface OciManifest {
  schemaVersion: number;
  mediaType: string;
  config: OciDescriptor;
  layers: OciDescriptor[];
}

export interface WasmComponentInfo {
  exports: string[];
  imports: string[];
  target?: string;
}

export interface WasmConfig {
  architecture: string;
  os: string;
  component?: WasmComponentInfo;
}

// --- Constants ---

export const MANIFEST_MEDIA_TYPE =
  "application/vnd.oci.image.manifest.v1+json";
export const WASM_MEDIA_TYPE = "application/wasm";
export const WASM_CONFIG_MEDIA_TYPE =
  "application/vnd.wasm.config.v0+json";

// --- Validation ---

const NAME_COMPONENT_RE = /^[a-z0-9._-]+$/;
const HOSTNAME_RE = /^[a-zA-Z0-9.-]+(:\d+)?$/;
const DIGEST_RE = /^[a-z0-9]+:[a-f0-9]+$/;
const TAG_RE = /^[a-zA-Z0-9._-]+$/;
const NAMESPACE_PREFIX_RE = /^[a-zA-Z0-9._\-/]*$/;

export function validateNameComponent(s: string): boolean {
  return s.length > 0 && NAME_COMPONENT_RE.test(s);
}

export function validateHostname(s: string): boolean {
  return s.length > 0 && HOSTNAME_RE.test(s);
}

export function validateDigest(s: string): boolean {
  return DIGEST_RE.test(s);
}

export function validateReference(s: string): boolean {
  if (s.length === 0) return false;
  if (s.includes(":")) return validateDigest(s);
  return TAG_RE.test(s);
}

export function validateNamespacePrefix(s: string): boolean {
  return NAMESPACE_PREFIX_RE.test(s);
}

export function validateHttpsUrl(url: string): boolean {
  if (!url.startsWith("https://")) return false;
  const afterScheme = url.slice(8);
  const slashIdx = afterScheme.indexOf("/");
  const hostPort = slashIdx >= 0 ? afterScheme.slice(0, slashIdx) : afterScheme;
  const colonIdx = hostPort.indexOf(":");
  const hostname = colonIdx >= 0 ? hostPort.slice(0, colonIdx) : hostPort;

  if (
    hostname === "localhost" ||
    hostname.startsWith("127.") ||
    hostname.startsWith("10.") ||
    hostname.startsWith("192.168.") ||
    hostname.startsWith("169.254.") ||
    hostname === "[::1]"
  ) {
    return false;
  }
  // Block 172.16.0.0/12
  if (hostname.startsWith("172.")) {
    const parts = hostname.split(".");
    if (parts.length >= 2) {
      const second = parseInt(parts[1], 10);
      if (!isNaN(second) && second >= 16 && second <= 31) return false;
    }
  }
  return true;
}

// --- Parsers ---

export function parsePackageName(input: string): PackageName | null {
  const idx = input.indexOf(":");
  if (idx < 0) return null;
  return { ns: input.slice(0, idx), name: input.slice(idx + 1) };
}

export function parseOciDescriptor(json: unknown): OciDescriptor | null {
  if (typeof json !== "object" || json === null) return null;
  const obj = json as Record<string, unknown>;
  if (typeof obj.mediaType !== "string") return null;
  if (typeof obj.size !== "number") return null;
  if (typeof obj.digest !== "string") return null;
  return {
    mediaType: obj.mediaType,
    size: obj.size,
    digest: obj.digest,
  };
}

export function parseOciManifest(json: unknown): OciManifest | null {
  if (typeof json !== "object" || json === null) return null;
  const obj = json as Record<string, unknown>;
  if (typeof obj.schemaVersion !== "number") return null;
  const mediaType = typeof obj.mediaType === "string" ? obj.mediaType : "";
  const config = parseOciDescriptor(obj.config);
  if (!config) return null;
  if (!Array.isArray(obj.layers)) return null;
  const layers: OciDescriptor[] = [];
  for (const item of obj.layers) {
    const d = parseOciDescriptor(item);
    if (!d) return null;
    layers.push(d);
  }
  return { schemaVersion: obj.schemaVersion, mediaType, config, layers };
}

export function parseWasmComponentInfo(
  json: unknown,
): WasmComponentInfo | null {
  if (typeof json !== "object" || json === null) return null;
  const obj = json as Record<string, unknown>;
  const exports: string[] = [];
  if (Array.isArray(obj.exports)) {
    for (const item of obj.exports) {
      if (typeof item === "string") exports.push(item);
    }
  }
  const imports: string[] = [];
  if (Array.isArray(obj.imports)) {
    for (const item of obj.imports) {
      if (typeof item === "string") imports.push(item);
    }
  }
  const target = typeof obj.target === "string" ? obj.target : undefined;
  return { exports, imports, target };
}

export function parseWasmConfig(json: unknown): WasmConfig | null {
  if (typeof json !== "object" || json === null) return null;
  const obj = json as Record<string, unknown>;
  const architecture =
    typeof obj.architecture === "string" ? obj.architecture : "wasm";
  const os = typeof obj.os === "string" ? obj.os : "wasip2";
  const component =
    typeof obj.component === "object" && obj.component !== null
      ? parseWasmComponentInfo(obj.component)
      : undefined;
  return { architecture, os, component: component ?? undefined };
}

export function parseRegistryConfig(json: unknown): RegistryConfig | null {
  if (typeof json !== "object" || json === null) return null;
  const obj = json as Record<string, unknown>;

  // Parse OCI config (modern or legacy format)
  let oci: OciConfig | undefined;
  if (typeof obj.oci === "object" && obj.oci !== null) {
    const ociObj = obj.oci as Record<string, unknown>;
    if (typeof ociObj.registry !== "string") return null;
    oci = {
      registry: ociObj.registry,
      namespacePrefix:
        typeof ociObj.namespacePrefix === "string"
          ? ociObj.namespacePrefix
          : "",
    };
  } else if (typeof obj.ociRegistry === "string") {
    // Legacy format
    oci = {
      registry: obj.ociRegistry,
      namespacePrefix:
        typeof obj.ociNamespacePrefix === "string"
          ? obj.ociNamespacePrefix
          : "",
    };
  }

  // Parse Warg config (modern or legacy format)
  let warg: WargConfig | undefined;
  if (typeof obj.warg === "object" && obj.warg !== null) {
    const wargObj = obj.warg as Record<string, unknown>;
    if (typeof wargObj.url === "string") {
      warg = { url: wargObj.url };
    }
  } else if (typeof obj.wargUrl === "string") {
    warg = { url: obj.wargUrl };
  }

  // Determine preferred backend
  const preferredProtocol =
    typeof obj.preferredProtocol === "string"
      ? obj.preferredProtocol
      : oci
        ? "oci"
        : "warg";

  let preferred: RegistryBackend;
  if (preferredProtocol === "oci") {
    if (!oci) return null;
    preferred = { type: "oci", config: oci };
  } else {
    if (!warg) return null;
    preferred = { type: "warg", config: warg };
  }

  return { preferred, oci, warg };
}
