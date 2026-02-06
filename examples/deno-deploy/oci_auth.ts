// OCI authentication ported from MoonBit src/oci/auth.mbt

import { validateHttpsUrl } from "./types.ts";

interface AuthChallenge {
  realm: string;
  service: string;
}

function parseWwwAuthenticate(header: string): AuthChallenge | null {
  if (!header.startsWith("Bearer ")) return null;
  const params = header.slice(7);
  let realm = "";
  let service = "";
  for (const part of params.split(",")) {
    const kv = part.trim();
    if (kv.startsWith("realm=")) {
      realm = stripQuotes(kv.slice(6));
    } else if (kv.startsWith("service=")) {
      service = stripQuotes(kv.slice(8));
    }
  }
  if (realm === "") return null;
  return { realm, service };
}

function stripQuotes(s: string): string {
  if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
    return s.slice(1, -1);
  }
  return s;
}

export async function fetchToken(
  registry: string,
  repo: string,
): Promise<string> {
  const res = await fetch(`https://${registry}/v2/`);
  if (res.status === 200) {
    return "";
  }
  if (res.status !== 401) {
    throw new Error(
      `fetchToken: unexpected status ${res.status} from /v2/`,
    );
  }
  const wwwAuth = res.headers.get("www-authenticate");
  if (!wwwAuth) {
    throw new Error("fetchToken: no WWW-Authenticate header");
  }
  const challenge = parseWwwAuthenticate(wwwAuth);
  if (!challenge) {
    throw new Error("fetchToken: failed to parse WWW-Authenticate");
  }
  if (!validateHttpsUrl(challenge.realm)) {
    throw new Error("fetchToken: realm URL is not a safe https URL");
  }
  const scope = `repository:${repo}:pull`;
  const tokenUrl = `${challenge.realm}?service=${encodeURIComponent(challenge.service)}&scope=${encodeURIComponent(scope)}`;
  const tokenRes = await fetch(tokenUrl);
  if (tokenRes.status !== 200) {
    throw new Error(
      `fetchToken: token endpoint returned ${tokenRes.status}`,
    );
  }
  const json = await tokenRes.json();
  const token = json.token ?? json.access_token;
  if (typeof token !== "string") {
    throw new Error("fetchToken: no token in response");
  }
  return token;
}
