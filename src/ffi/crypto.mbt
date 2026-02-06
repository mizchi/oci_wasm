///|
extern "js" fn js_sha256(data : Bytes) -> @js_async.Promise[String] =
  #| async (data) => {
  #|   const h = await crypto.subtle.digest('SHA-256', data);
  #|   return Array.from(new Uint8Array(h)).map(b => b.toString(16).padStart(2,'0')).join('');
  #| }

///|
pub async fn sha256_hex(data : Bytes) -> String {
  js_sha256(data).wait()
}

///|
extern "js" fn js_url_encode(s : String) -> String =
  #| (s) => encodeURIComponent(s)

///|
pub fn url_encode(s : String) -> String {
  js_url_encode(s)
}
