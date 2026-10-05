///|
/// WWW-Authenticate challenge parameters
priv struct AuthChallenge {
  realm : String
  service : String
}

///|
/// Parse WWW-Authenticate header value.
/// Format: Bearer realm="...",service="...",scope="..."
fn parse_www_authenticate(header : String) -> AuthChallenge? {
  guard header.has_prefix("Bearer ") else { return None }
  let params = header.view(start_offset=7).to_owned()
  let mut realm = ""
  let mut service = ""
  // Simple key=value parser
  let parts = params.split(",")
  for part in parts {
    let kv = part.to_owned().trim().to_owned()
    if kv.has_prefix("realm=") {
      realm = strip_quotes(kv.view(start_offset=6).to_owned())
    } else if kv.has_prefix("service=") {
      service = strip_quotes(kv.view(start_offset=8).to_owned())
    }
  }
  guard realm != "" else { return None }
  Some(AuthChallenge::{ realm, service, })
}

///|
fn strip_quotes(s : String) -> String {
  if s.length() >= 2 && s.has_prefix("\"") && s.has_suffix("\"") {
    s.view(start_offset=1, end_offset=s.length() - 1).to_owned()
  } else {
    s
  }
}

///|
/// Fetch a bearer token for accessing an OCI registry.
/// Validates realm URL (#4) and URL-encodes query parameters (#5).
pub async fn fetch_token(
  registry : String,
  repo : String,
) -> String raise Error {
  let response = @ffi.fetch_simple("https://\{registry}/v2/")
  let status = response.status()
  guard status == 401 else {
    if status == 200 {
      return ""
    }
    raise Failure::Failure("fetch_token: unexpected status \{status} from /v2/")
  }
  let www_auth = response.get_header("www-authenticate")
  guard www_auth != "" else {
    raise Failure::Failure("fetch_token: no WWW-Authenticate header")
  }
  guard parse_www_authenticate(www_auth) is Some(challenge) else {
    raise Failure::Failure("fetch_token: failed to parse WWW-Authenticate")
  }
  // Validate realm URL is https and not private network (#4)
  guard @types.validate_https_url(challenge.realm) else {
    raise Failure::Failure("fetch_token: realm URL is not a safe https URL")
  }
  // URL-encode query parameters (#5)
  let encoded_service = @ffi.url_encode(challenge.service)
  let scope = "repository:\{repo}:pull"
  let encoded_scope = @ffi.url_encode(scope)
  let token_url = "\{challenge.realm}?service=\{encoded_service}&scope=\{encoded_scope}"
  let (token_status, json) = @ffi.fetch_json(token_url)
  guard token_status == 200 else {
    raise Failure::Failure(
      "fetch_token: token endpoint returned \{token_status}",
    )
  }
  match json {
    Object(map) =>
      match map.get("token") {
        Some(String(t)) => t
        _ =>
          match map.get("access_token") {
            Some(String(t)) => t
            _ => raise Failure::Failure("fetch_token: no token in response")
          }
      }
    _ => raise Failure::Failure("fetch_token: unexpected token response format")
  }
}
