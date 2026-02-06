// warg Deno Deploy Worker - OCI Distribution proxy for wasm-pkg registries

import { fetchRegistryConfig } from "./discovery.ts";
import {
  type PackageName,
  validateHostname,
  parsePackageName,
  validateReference,
} from "./types.ts";
import { OciClient } from "./oci_client.ts";

const CORS_HEADERS: Record<string, string> = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, OPTIONS",
  "access-control-allow-headers": "content-type",
};

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json", ...CORS_HEADERS },
  });
}

function errorResponse(message: string, status = 400): Response {
  return jsonResponse({ error: message }, status);
}

async function getClient(
  host: string,
  pkg: PackageName,
): Promise<OciClient> {
  const registryConfig = await fetchRegistryConfig(host);
  if (registryConfig.preferred.type !== "oci") {
    throw new Error("only OCI registries are supported");
  }
  const oci = registryConfig.preferred.config;
  return OciClient.create(oci.registry, oci.namespacePrefix, pkg);
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);

  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  if (req.method !== "GET") {
    return errorResponse("method not allowed", 405);
  }

  // Health check
  if (url.pathname === "/health") {
    return jsonResponse({ status: "ok" });
  }

  // Route: /v1/{action}/{host}/{ns}:{name}[/{ref}]
  const match = url.pathname.match(
    /^\/v1\/(registry|tags|manifest|config|pull)\/([^/]+)(?:\/([^/]+))?(?:\/(.+))?$/,
  );
  if (!match) {
    return errorResponse("not found", 404);
  }

  const [, action, host, pkgStr, ref] = match;

  if (!validateHostname(host)) {
    return errorResponse("invalid hostname");
  }

  try {
    // Registry discovery (no package needed)
    if (action === "registry") {
      const config = await fetchRegistryConfig(host);
      return jsonResponse(config);
    }

    // All other actions require a package name
    if (!pkgStr) {
      return errorResponse("package name required");
    }
    const pkg = parsePackageName(pkgStr);
    if (!pkg) {
      return errorResponse("invalid package name format (expected ns:name)");
    }

    if (action === "tags") {
      const client = await getClient(host, pkg);
      const tags = await client.listTags(pkg);
      return jsonResponse({ tags });
    }

    // Actions requiring a reference
    if (!ref) {
      return errorResponse("reference required");
    }
    if (!validateReference(ref)) {
      return errorResponse("invalid reference");
    }

    const client = await getClient(host, pkg);

    if (action === "manifest") {
      const manifest = await client.getManifest(pkg, ref);
      return jsonResponse(manifest);
    }

    if (action === "config") {
      const config = await client.getWasmConfig(pkg, ref);
      return jsonResponse(config);
    }

    if (action === "pull") {
      const wasm = await client.pullWasm(pkg, ref);
      return new Response(wasm, {
        status: 200,
        headers: {
          "content-type": "application/wasm",
          ...CORS_HEADERS,
        },
      });
    }

    return errorResponse("not found", 404);
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    // Validation errors → 400, OCI errors → 502
    const status = message.startsWith("invalid") ||
      message.startsWith("fetchRegistryConfig: invalid")
      ? 400
      : 502;
    return errorResponse(message, status);
  }
});
