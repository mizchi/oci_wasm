///|
#external
pub type JsResponse

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
extern "js" fn js_response_get_header(
  response : JsResponse,
  name : String,
) -> String =
  #| (r, name) => r.headers.get(name) ?? ""

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
pub fn JsResponse::status(self : JsResponse) -> Int {
  js_response_status(self)
}

///|
pub fn JsResponse::get_header(self : JsResponse, name : String) -> String {
  js_response_get_header(self, name)
}

///|
pub fn JsResponse::text(self : JsResponse) -> @js_async.Promise[String] {
  js_response_text(self)
}

///|
pub fn JsResponse::bytes(self : JsResponse) -> @js_async.Promise[Bytes] {
  js_response_bytes(self)
}

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
pub async fn fetch_simple(url : String) -> JsResponse {
  js_fetch_simple(url).wait()
}

///|
pub async fn fetch_json(url : String) -> (Int, Json) raise Error {
  let response = js_fetch_simple(url).wait()
  let status = response.status()
  let text = response.text().wait()
  let json = @json.parse(text)
  (status, json)
}

///|
pub async fn fetch_json_with_headers(
  url : String,
  headers : Map[String, String],
) -> (Int, Json, JsResponse) raise Error {
  let hj = headers_to_json(headers)
  let response = js_fetch_with_headers(url, hj).wait()
  let status = response.status()
  let text = response.text().wait()
  let json = @json.parse(text)
  (status, json, response)
}

///|
pub async fn fetch_with_headers(
  url : String,
  headers : Map[String, String],
) -> JsResponse {
  let hj = headers_to_json(headers)
  js_fetch_with_headers(url, hj).wait()
}

///|
pub async fn fetch_manual_redirect(
  url : String,
  headers : Map[String, String],
) -> JsResponse {
  let hj = headers_to_json(headers)
  js_fetch_manual_redirect(url, hj).wait()
}
