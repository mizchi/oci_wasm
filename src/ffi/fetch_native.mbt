///|
/// Parse a URL into (origin, path_and_query).
/// "https://host:port/path?q=1" → ("https://host:port", "/path?q=1")
fn parse_url(url : String) -> (String, String) {
  // Find the start of path after protocol://host
  let prefix = if url.has_prefix("https://") {
    8
  } else if url.has_prefix("http://") {
    7
  } else {
    0
  }
  let rest = url.view(start_offset=prefix).to_owned()
  match rest.find("/") {
    Some(idx) => {
      let origin = url.view(end_offset=prefix + idx).to_owned()
      let path = rest.view(start_offset=idx).to_owned()
      (origin, path)
    }
    None => (url, "/")
  }
}

///|
pub async fn fetch_simple(url : String) -> Response {
  let (origin, path) = parse_url(url)
  let client = @http.Client(origin)
  let http_resp = client.get(path)
  let data = client.read_all()
  let body = data.binary()
  let response_headers = normalize_response_headers(http_resp.headers)
  client.close()
  Response::{
    status_code: http_resp.code,
    response_headers,
    response_body: body,
  }
}

///|
pub async fn fetch_json(url : String) -> (Int, Json) raise Error {
  let response = fetch_simple(url)
  let text = response.text()
  let json = @json.parse(text)
  (response.status_code, json)
}

///|
pub async fn fetch_json_with_headers(
  url : String,
  headers : Map[String, String],
) -> (Int, Json, Response) raise Error {
  let (origin, path) = parse_url(url)
  let client = @http.Client(origin)
  let http_resp = client.get(path, extra_headers=http_headers(headers))
  let data = client.read_all()
  let body = data.binary()
  let response_headers = normalize_response_headers(http_resp.headers)
  client.close()
  let response = Response::{
    status_code: http_resp.code,
    response_headers,
    response_body: body,
  }
  let text = response.text()
  let json = @json.parse(text)
  (http_resp.code, json, response)
}

///|
pub async fn fetch_with_headers(
  url : String,
  headers : Map[String, String],
) -> Response {
  let (origin, path) = parse_url(url)
  let client = @http.Client(origin)
  let http_resp = client.get(path, extra_headers=http_headers(headers))
  let data = client.read_all()
  let body = data.binary()
  let response_headers = normalize_response_headers(http_resp.headers)
  client.close()
  Response::{
    status_code: http_resp.code,
    response_headers,
    response_body: body,
  }
}

///|
pub async fn fetch_manual_redirect(
  url : String,
  headers : Map[String, String],
) -> Response {
  // For native, we don't have auto-redirect control in the same way.
  // We make the request and handle the response as-is.
  // The http client doesn't auto-follow redirects.
  let (origin, path) = parse_url(url)
  let client = @http.Client(origin)
  let http_resp = client.get(path, extra_headers=http_headers(headers))
  let status = http_resp.code
  let response_headers = normalize_response_headers(http_resp.headers)
  if status >= 300 && status < 400 {
    // Redirect - skip body
    client.skip_response_body()
    client.close()
    Response::{
      status_code: status,
      response_headers,
      response_body: Bytes::new(0),
    }
  } else {
    let data = client.read_all()
    let body = data.binary()
    client.close()
    Response::{ status_code: status, response_headers, response_body: body, }
  }
}

///|
fn http_headers(
  headers : Map[String, String],
) -> Map[@http.CaseInsensitiveString, String] {
  let result = Map([])
  for key, value in headers {
    result[@http.CaseInsensitiveString(key)] = value
  }
  result
}

///|
fn normalize_response_headers(
  headers : Map[@http.CaseInsensitiveString, String],
) -> Map[String, String] {
  let result = Map([])
  for key, value in headers {
    result[key.to_string().to_lower()] = value
  }
  result
}
