// OCI client ported from MoonBit src/oci/client.mbt

import {
  type PackageName,
  type OciManifest,
  type WasmConfig,
  MANIFEST_MEDIA_TYPE,
  WASM_MEDIA_TYPE,
  validateHostname,
  validateNamespacePrefix,
  validateNameComponent,
  validateReference,
  validateDigest,
  validateHttpsUrl,
  parseOciManifest,
  parseWasmConfig,
} from "./types.ts";
import { fetchToken } from "./oci_auth.ts";

const MAX_BLOB_SIZE = 268435456; // 256 MB

function validatePkg(pkg: PackageName): void {
  if (!validateNameComponent(pkg.ns)) {
    throw new Error(`invalid package namespace: ${pkg.ns}`);
  }
  if (!validateNameComponent(pkg.name)) {
    throw new Error(`invalid package name: ${pkg.name}`);
  }
}

export class OciClient {
  private registry: string;
  private namespacePrefix: string;
  private token: string;

  private constructor(
    registry: string,
    namespacePrefix: string,
    token: string,
  ) {
    this.registry = registry;
    this.namespacePrefix = namespacePrefix;
    this.token = token;
  }

  static async create(
    registry: string,
    namespacePrefix: string,
    pkg: PackageName,
  ): Promise<OciClient> {
    if (!validateHostname(registry)) {
      throw new Error("invalid registry hostname");
    }
    if (!validateNamespacePrefix(namespacePrefix)) {
      throw new Error("invalid namespace prefix");
    }
    validatePkg(pkg);
    const repo = `${namespacePrefix}${pkg.ns}/${pkg.name}`;
    const token = await fetchToken(registry, repo);
    return new OciClient(registry, namespacePrefix, token);
  }

  private repoName(pkg: PackageName): string {
    return `${this.namespacePrefix}${pkg.ns}/${pkg.name}`;
  }

  private authHeaders(): Record<string, string> {
    const headers: Record<string, string> = {};
    if (this.token !== "") {
      headers["Authorization"] = `Bearer ${this.token}`;
    }
    return headers;
  }

  async authFor(pkg: PackageName): Promise<void> {
    validatePkg(pkg);
    const repo = this.repoName(pkg);
    this.token = await fetchToken(this.registry, repo);
  }

  async listTags(pkg: PackageName): Promise<string[]> {
    validatePkg(pkg);
    const repo = this.repoName(pkg);
    const res = await fetch(
      `https://${this.registry}/v2/${repo}/tags/list`,
      { headers: this.authHeaders() },
    );
    if (res.status !== 200) {
      throw new Error(`listTags: HTTP ${res.status}`);
    }
    const json = await res.json();
    if (json && Array.isArray(json.tags)) {
      return json.tags.filter((t: unknown) => typeof t === "string");
    }
    return [];
  }

  async getManifest(
    pkg: PackageName,
    reference: string,
  ): Promise<OciManifest> {
    validatePkg(pkg);
    if (!validateReference(reference)) {
      throw new Error("invalid OCI reference");
    }
    const repo = this.repoName(pkg);
    const res = await fetch(
      `https://${this.registry}/v2/${repo}/manifests/${reference}`,
      {
        headers: {
          ...this.authHeaders(),
          Accept: MANIFEST_MEDIA_TYPE,
        },
      },
    );
    if (res.status !== 200) {
      throw new Error(`getManifest: HTTP ${res.status}`);
    }
    const json = await res.json();
    const manifest = parseOciManifest(json);
    if (!manifest) {
      throw new Error("getManifest: failed to parse manifest JSON");
    }
    if (manifest.schemaVersion !== 2) {
      throw new Error(
        `getManifest: unsupported schemaVersion ${manifest.schemaVersion}`,
      );
    }
    if (
      manifest.mediaType !== "" &&
      manifest.mediaType !== MANIFEST_MEDIA_TYPE
    ) {
      throw new Error(
        `getManifest: unexpected mediaType ${manifest.mediaType}`,
      );
    }
    return manifest;
  }

  async getBlob(
    pkg: PackageName,
    digest: string,
    expectedSize = 0,
  ): Promise<ArrayBuffer> {
    validatePkg(pkg);
    if (!validateDigest(digest)) {
      throw new Error("invalid digest format");
    }
    const repo = this.repoName(pkg);
    const res = await fetch(
      `https://${this.registry}/v2/${repo}/blobs/${digest}`,
      {
        headers: this.authHeaders(),
        redirect: "manual",
      },
    );

    let data: ArrayBuffer;
    if (res.status === 200) {
      data = await res.arrayBuffer();
    } else if (
      res.status === 307 ||
      res.status === 302 ||
      res.status === 301
    ) {
      const location = res.headers.get("location");
      if (!location) {
        throw new Error("getBlob: redirect without Location header");
      }
      data = await safeRedirectGet(location);
    } else {
      throw new Error(`getBlob: HTTP ${res.status}`);
    }

    if (expectedSize > 0 && data.byteLength !== expectedSize) {
      throw new Error(
        `getBlob: size mismatch: expected ${expectedSize}, got ${data.byteLength}`,
      );
    }
    if (data.byteLength > MAX_BLOB_SIZE) {
      throw new Error("getBlob: blob exceeds maximum size limit");
    }
    await verifyDigest(data, digest);
    return data;
  }

  async getWasmConfig(
    pkg: PackageName,
    reference: string,
  ): Promise<WasmConfig> {
    const manifest = await this.getManifest(pkg, reference);
    const blob = await this.getBlob(
      pkg,
      manifest.config.digest,
      manifest.config.size,
    );
    const text = new TextDecoder().decode(blob);
    const json = JSON.parse(text);
    const config = parseWasmConfig(json);
    if (!config) {
      throw new Error("getWasmConfig: failed to parse config JSON");
    }
    return config;
  }

  async pullWasm(
    pkg: PackageName,
    version: string,
  ): Promise<ArrayBuffer> {
    const manifest = await this.getManifest(pkg, version);
    const wasmLayer = manifest.layers.find(
      (l) => l.mediaType === WASM_MEDIA_TYPE,
    );
    if (!wasmLayer) {
      throw new Error("pullWasm: no wasm layer found in manifest");
    }
    return this.getBlob(pkg, wasmLayer.digest, wasmLayer.size);
  }
}

async function safeRedirectGet(location: string): Promise<ArrayBuffer> {
  if (!validateHttpsUrl(location)) {
    throw new Error("redirect to non-https or private URL blocked");
  }
  const res = await fetch(location);
  if (res.status !== 200) {
    throw new Error(`redirect target returned ${res.status}`);
  }
  return res.arrayBuffer();
}

async function verifyDigest(
  data: ArrayBuffer,
  expectedDigest: string,
): Promise<void> {
  if (!expectedDigest.startsWith("sha256:")) return;
  const expectedHex = expectedDigest.slice(7);
  const hashBuf = await crypto.subtle.digest("SHA-256", data);
  const actualHex = Array.from(new Uint8Array(hashBuf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  if (actualHex !== expectedHex) {
    throw new Error(
      `digest verification failed: expected ${expectedHex}, got ${actualHex}`,
    );
  }
}
