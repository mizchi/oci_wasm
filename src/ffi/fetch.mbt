///|
#external
priv type JsResponse

///|
extern "js" fn js_fetch_simple(url : String) -> @js_async.Promise[JsResponse] =
  #| (url) => fetch(url)

///|
extern "js" fn js_fetch_with_headers(
  url : String,
  headers_json : String,
) -> @js_async.Promise[JsResponse] =
  #| async (url, hj) => fetch(url, { headers: JSON.parse(hj) })

///|
extern "js" fn js_fetch_manual_redirect(
  url : String,
  headers_json : String,
) -> @js_async.Promise[JsResponse] =
  #| async (url, hj) => fetch(url, { headers: JSON.parse(hj), redirect: 'manual' })

///|
extern "js" fn js_response_status(response : JsResponse) -> Int =
  #| (r) => r.status

///|
extern "js" fn js_response_text(
  response : JsResponse,
) -> @js_async.Promise[String] =
  #| (r) => r.text()

///|
extern "js" fn js_response_bytes(
  response : JsResponse,
) -> @js_async.Promise[Bytes] =
  #| async (r) => new Uint8Array(await r.arrayBuffer())

///|
extern "js" fn js_response_all_headers(response : JsResponse) -> String =
  #| (r) => { let o = {}; r.headers.forEach((v, k) => { o[k] = v; }); return JSON.stringify(o); }

///|
fn headers_to_json(headers : Map[String, String]) -> String {
  let buf = StringBuilder::new()
  buf.write_string("{")
  let mut first = true
  for k, v in headers {
    if first {
      first = false
    } else {
      buf.write_string(",")
    }
    buf.write_string("\"")
    buf.write_string(k)
    buf.write_string("\":\"")
    buf.write_string(v)
    buf.write_string("\"")
  }
  buf.write_string("}")
  buf.to_string()
}

///|
fn parse_headers_json(json_str : String) -> Map[String, String] {
  let headers : Map[String, String] = {}
  // Try to parse the JSON string for headers
  try {
    let json = @json.parse(json_str)
    match json {
      Object(map) =>
        for k, v in map {
          match v {
            String(s) => headers[k] = s
            _ => ()
          }
        }
      _ => ()
    }
  } catch {
    _ => ()
  }
  headers
}

///|
fn js_to_response(js_resp : JsResponse, body : Bytes) -> Response {
  let status_code = js_response_status(js_resp)
  let headers_json = js_response_all_headers(js_resp)
  let response_headers = parse_headers_json(headers_json)
  Response::{ status_code, response_headers, response_body: body }
}

///|
pub async fn fetch_simple(url : String) -> Response {
  let js_resp = js_fetch_simple(url).wait()
  let body = js_response_bytes(js_resp).wait()
  js_to_response(js_resp, body)
}

///|
pub async fn fetch_json(url : String) -> (Int, Json) raise Error {
  let js_resp = js_fetch_simple(url).wait()
  let status = js_response_status(js_resp)
  let text = js_response_text(js_resp).wait()
  let json = @json.parse(text)
  (status, json)
}

///|
pub async fn fetch_json_with_headers(
  url : String,
  headers : Map[String, String],
) -> (Int, Json, Response) raise Error {
  let hj = headers_to_json(headers)
  let js_resp = js_fetch_with_headers(url, hj).wait()
  let status = js_response_status(js_resp)
  let body = js_response_bytes(js_resp).wait()
  let response = js_to_response(js_resp, body)
  let text = response.text()
  let json = @json.parse(text)
  (status, json, response)
}

///|
pub async fn fetch_with_headers(
  url : String,
  headers : Map[String, String],
) -> Response {
  let hj = headers_to_json(headers)
  let js_resp = js_fetch_with_headers(url, hj).wait()
  let body = js_response_bytes(js_resp).wait()
  js_to_response(js_resp, body)
}

///|
pub async fn fetch_manual_redirect(
  url : String,
  headers : Map[String, String],
) -> Response {
  let hj = headers_to_json(headers)
  let js_resp = js_fetch_manual_redirect(url, hj).wait()
  // For redirect responses, body may be empty
  let status = js_response_status(js_resp)
  if status >= 300 && status < 400 {
    // Redirect - don't read body, just capture headers
    Response::{
      status_code: status,
      response_headers: parse_headers_json(js_response_all_headers(js_resp)),
      response_body: Bytes::new(0),
    }
  } else {
    let body = js_response_bytes(js_resp).wait()
    js_to_response(js_resp, body)
  }
}
