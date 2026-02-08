///|
pub struct Response {
  status_code : Int
  response_headers : Map[String, String]
  response_body : Bytes
}

///|
pub fn Response::status(self : Response) -> Int {
  self.status_code
}

///|
/// Case-insensitive header lookup. Returns "" if not found.
pub fn Response::get_header(self : Response, name : String) -> String {
  let lower = name.to_lower()
  for k, v in self.response_headers {
    if k.to_lower() == lower {
      return v
    }
  }
  ""
}

///|
pub fn Response::text(self : Response) -> String {
  // UTF-8 decode from bytes
  let buf = StringBuilder::new()
  let bytes = self.response_body
  let len = bytes.length()
  let mut i = 0
  while i < len {
    let b = bytes[i].to_int()
    if b < 0x80 {
      buf.write_char(b.unsafe_to_char())
      i += 1
    } else if b < 0xE0 {
      if i + 1 < len {
        let cp = ((b & 0x1F) << 6) | (bytes[i + 1].to_int() & 0x3F)
        buf.write_char(cp.unsafe_to_char())
      }
      i += 2
    } else if b < 0xF0 {
      if i + 2 < len {
        let cp = ((b & 0x0F) << 12) |
          ((bytes[i + 1].to_int() & 0x3F) << 6) |
          (bytes[i + 2].to_int() & 0x3F)
        buf.write_char(cp.unsafe_to_char())
      }
      i += 3
    } else {
      if i + 3 < len {
        let cp = ((b & 0x07) << 18) |
          ((bytes[i + 1].to_int() & 0x3F) << 12) |
          ((bytes[i + 2].to_int() & 0x3F) << 6) |
          (bytes[i + 3].to_int() & 0x3F)
        buf.write_char(cp.unsafe_to_char())
      }
      i += 4
    }
  }
  buf.to_string()
}

///|
pub fn Response::bytes(self : Response) -> Bytes {
  self.response_body
}
