///|
test "native request headers preserve case-insensitive lookup" {
  let headers = http_headers({
    "Authorization": "Bearer example",
    "Accept": "application/json",
  })
  assert_true(
    headers.get(@http.CaseInsensitiveString("authorization"))
    is Some("Bearer example"),
  )
  assert_true(
    headers.get(@http.CaseInsensitiveString("ACCEPT"))
    is Some("application/json"),
  )
}

///|
test "native response headers use lowercase keys like fetch" {
  let headers = normalize_response_headers(
    Map([
      (@http.CaseInsensitiveString("WWW-Authenticate"), "Bearer example"),
      (@http.CaseInsensitiveString("Location"), "https://example.test/blob"),
    ]),
  )
  assert_true(headers.get("www-authenticate") is Some("Bearer example"))
  assert_true(headers.get("location") is Some("https://example.test/blob"))
}
