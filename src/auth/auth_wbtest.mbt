///|
/// Whitebox: parse_www_authenticate with standard format
test "parse_www_authenticate standard" {
  let header = "Bearer realm=\"https://ghcr.io/token\",service=\"ghcr.io\",scope=\"repository:user/image:pull\""
  let challenge = parse_www_authenticate(header).unwrap()
  inspect(challenge.realm, content="https://ghcr.io/token")
  inspect(challenge.service, content="ghcr.io")
}

///|
/// Whitebox: parse_www_authenticate without quotes
test "parse_www_authenticate no quotes" {
  let header = "Bearer realm=https://ghcr.io/token,service=ghcr.io"
  let challenge = parse_www_authenticate(header).unwrap()
  inspect(challenge.realm, content="https://ghcr.io/token")
  inspect(challenge.service, content="ghcr.io")
}

///|
/// Whitebox: parse_www_authenticate invalid prefix
test "parse_www_authenticate invalid" {
  let result = parse_www_authenticate("Basic realm=\"test\"")
  assert_true(result is None)
}

///|
/// Whitebox: strip_quotes
test "strip_quotes" {
  inspect(strip_quotes("\"hello\""), content="hello")
  inspect(strip_quotes("hello"), content="hello")
  inspect(strip_quotes("\"\""), content="")
}
