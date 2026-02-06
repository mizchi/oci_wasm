///|
/// Check if a character is valid in OCI repository name components.
/// Allowed: lowercase alphanumeric, '.', '-', '_'
fn is_valid_name_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= '0' && c <= '9') ||
  c == '.' ||
  c == '-' ||
  c == '_'
}

///|
/// Validate an OCI name component (namespace or package name).
/// Must be non-empty and contain only [a-z0-9._-].
pub fn validate_name_component(s : String) -> Bool {
  if s.is_empty() {
    return false
  }
  for c in s {
    if not(is_valid_name_char(c)) {
      return false
    }
  }
  true
}

///|
/// Validate a hostname (registry or discovery host).
/// Allowed: alphanumeric, '.', '-', optionally ':' followed by digits (port).
pub fn validate_hostname(s : String) -> Bool {
  if s.is_empty() {
    return false
  }
  let mut saw_colon = false
  for c in s {
    if c == ':' {
      if saw_colon {
        return false
      }
      saw_colon = true
    } else if saw_colon {
      // After colon, only digits (port)
      if c < '0' || c > '9' {
        return false
      }
    } else if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '.' ||
      c == '-' {
      continue
    } else {
      return false
    }
  }
  true
}

///|
/// Validate an OCI digest format: "algorithm:hex"
/// Algorithm: [a-z0-9]+, Hex: [a-f0-9]+
pub fn validate_digest(s : String) -> Bool {
  match s.find(":") {
    None => false
    Some(idx) => {
      if idx == 0 || idx == s.length() - 1 {
        return false
      }
      let algo = s.view(end_offset=idx)
      let hex = s.view(start_offset=idx + 1)
      for c in algo {
        if (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') {
          continue
        } else {
          return false
        }
      }
      for c in hex {
        if (c >= 'a' && c <= 'f') || (c >= '0' && c <= '9') {
          continue
        } else {
          return false
        }
      }
      true
    }
  }
}

///|
/// Validate an OCI reference (tag or digest).
/// Tag: [a-zA-Z0-9._-]+
/// Digest: algorithm:hex
pub fn validate_reference(s : String) -> Bool {
  if s.is_empty() {
    return false
  }
  // If it contains ':', treat as digest
  if s.contains(":") {
    return validate_digest(s)
  }
  // Otherwise treat as tag
  for c in s {
    if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '.' ||
      c == '-' ||
      c == '_' {
      continue
    } else {
      return false
    }
  }
  true
}

///|
/// Validate a namespace prefix (e.g., "webassembly/").
/// Allowed: alphanumeric, '.', '-', '_', '/'
pub fn validate_namespace_prefix(s : String) -> Bool {
  for c in s {
    if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '.' ||
      c == '-' ||
      c == '_' ||
      c == '/' {
      continue
    } else {
      return false
    }
  }
  true
}

///|
/// Validate a URL is safe (https only, no private networks).
pub fn validate_https_url(url : String) -> Bool {
  if not(url.has_prefix("https://")) {
    return false
  }
  // Extract host part
  let after_scheme = url.view(start_offset=8).to_string()
  let host_end = match after_scheme.find("/") {
    Some(idx) => idx
    None => after_scheme.length()
  }
  let host = after_scheme.view(end_offset=host_end).to_string()
  // Strip port if present
  let hostname = match host.find(":") {
    Some(idx) => host.view(end_offset=idx).to_string()
    None => host
  }
  // Block private/reserved addresses
  if hostname == "localhost" ||
    hostname.has_prefix("127.") ||
    hostname.has_prefix("10.") ||
    hostname.has_prefix("192.168.") ||
    hostname.has_prefix("169.254.") ||
    hostname == "[::1]" {
    return false
  }
  // Block 172.16.0.0/12
  if hostname.has_prefix("172.") {
    match hostname.find(".") {
      Some(first_dot) => {
        let rest = hostname.view(start_offset=first_dot + 1).to_string()
        match rest.find(".") {
          Some(second_dot) => {
            let second_octet_str = rest.view(end_offset=second_dot).to_string()
            // Parse second octet manually
            let mut val = 0
            let mut valid = true
            for c in second_octet_str {
              if c >= '0' && c <= '9' {
                val = val * 10 + (c.to_int() - '0'.to_int())
              } else {
                valid = false
                break
              }
            }
            if valid && val >= 16 && val <= 31 {
              return false
            }
          }
          _ => ()
        }
      }
      _ => ()
    }
  }
  true
}
