///|
/// SHA-256 initial hash values
let sha256_h0 : FixedArray[UInt] = [
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab,
  0x5be0cd19,
]

///|
/// SHA-256 round constants
let sha256_k : FixedArray[UInt] = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4,
  0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe,
  0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f,
  0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
  0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116,
  0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
  0xc67178f2,
]

///|
fn rotr(x : UInt, n : Int) -> UInt {
  (x >> n) | (x << (32 - n))
}

///|
let hex_digit_chars : Array[Char] = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
]

///|
pub async fn sha256_hex(data : Bytes) -> String {
  // Pre-processing: pad message
  let msg_len = data.length()
  let bit_len = msg_len * 8
  // Message + 1 byte (0x80) + padding + 8 bytes (length)
  let padded_len = if (msg_len + 1 + 8) % 64 == 0 {
    msg_len + 1 + 8
  } else {
    (msg_len + 1 + 8 + 63) / 64 * 64
  }
  let padded = FixedArray::make(padded_len, 0U)
  for i = 0; i < msg_len; i = i + 1 {
    padded[i] = data[i].to_int().reinterpret_as_uint()
  }
  padded[msg_len] = 0x80U
  // Append length in bits as big-endian 64-bit
  let len_offset = padded_len - 8
  // For messages < 2^32 bits, upper 4 bytes are 0
  padded[len_offset + 4] = ((bit_len >> 24) & 0xFF).reinterpret_as_uint()
  padded[len_offset + 5] = ((bit_len >> 16) & 0xFF).reinterpret_as_uint()
  padded[len_offset + 6] = ((bit_len >> 8) & 0xFF).reinterpret_as_uint()
  padded[len_offset + 7] = (bit_len & 0xFF).reinterpret_as_uint()

  // Initialize hash values
  let h : FixedArray[UInt] = FixedArray::make(8, 0U)
  for i = 0; i < 8; i = i + 1 {
    h[i] = sha256_h0[i]
  }

  // Process each 64-byte block
  let w : FixedArray[UInt] = FixedArray::make(64, 0U)
  let num_blocks = padded_len / 64
  for block = 0; block < num_blocks; block = block + 1 {
    let base = block * 64
    // Prepare message schedule
    for i = 0; i < 16; i = i + 1 {
      let j = base + i * 4
      w[i] = (padded[j] << 24) |
        (padded[j + 1] << 16) |
        (padded[j + 2] << 8) |
        padded[j + 3]
    }
    for i = 16; i < 64; i = i + 1 {
      let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
      let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
      w[i] = w[i - 16] + s0 + w[i - 7] + s1
    }

    // Compression
    let mut a = h[0]
    let mut b = h[1]
    let mut c = h[2]
    let mut d = h[3]
    let mut e = h[4]
    let mut f = h[5]
    let mut g = h[6]
    let mut hh = h[7]
    for i = 0; i < 64; i = i + 1 {
      let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
      let ch = (e & f) ^ (e.lnot() & g)
      let temp1 = hh + s1 + ch + sha256_k[i] + w[i]
      let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
      let maj = (a & b) ^ (a & c) ^ (b & c)
      let temp2 = s0 + maj
      hh = g
      g = f
      f = e
      e = d + temp1
      d = c
      c = b
      b = a
      a = temp1 + temp2
    }
    h[0] = h[0] + a
    h[1] = h[1] + b
    h[2] = h[2] + c
    h[3] = h[3] + d
    h[4] = h[4] + e
    h[5] = h[5] + f
    h[6] = h[6] + g
    h[7] = h[7] + hh
  }

  // Produce hex string
  let hex = StringBuilder()
  for i = 0; i < 8; i = i + 1 {
    let v = h[i]
    for j = 7; j >= 0; j = j - 1 {
      let nibble = ((v >> (j * 4)) & 0xFU).reinterpret_as_int()
      hex.write_char(hex_digit_chars[nibble])
    }
  }
  hex.to_string()
}

///|
let hex_upper_chars : Array[Char] = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
]

///|
fn is_unreserved(c : Char) -> Bool {
  (c >= 'A' && c <= 'Z') ||
  (c >= 'a' && c <= 'z') ||
  (c >= '0' && c <= '9') ||
  c == '-' ||
  c == '_' ||
  c == '.' ||
  c == '~'
}

///|
pub fn url_encode(s : String) -> String {
  let buf = StringBuilder()
  // Iterate chars directly and encode UTF-8 bytes
  for ch in s {
    let code = ch.to_int()
    if code < 128 && is_unreserved(ch) {
      buf.write_char(ch)
    } else if code < 0x80 {
      buf.write_char('%')
      buf.write_char(hex_upper_chars[(code >> 4) & 0x0F])
      buf.write_char(hex_upper_chars[code & 0x0F])
    } else if code < 0x800 {
      let b0 = 0xC0 | (code >> 6)
      let b1 = 0x80 | (code & 0x3F)
      buf.write_char('%')
      buf.write_char(hex_upper_chars[(b0 >> 4) & 0x0F])
      buf.write_char(hex_upper_chars[b0 & 0x0F])
      buf.write_char('%')
      buf.write_char(hex_upper_chars[(b1 >> 4) & 0x0F])
      buf.write_char(hex_upper_chars[b1 & 0x0F])
    } else if code < 0x10000 {
      let b0 = 0xE0 | (code >> 12)
      let b1 = 0x80 | ((code >> 6) & 0x3F)
      let b2 = 0x80 | (code & 0x3F)
      buf.write_char('%')
      buf.write_char(hex_upper_chars[(b0 >> 4) & 0x0F])
      buf.write_char(hex_upper_chars[b0 & 0x0F])
      buf.write_char('%')
      buf.write_char(hex_upper_chars[(b1 >> 4) & 0x0F])
      buf.write_char(hex_upper_chars[b1 & 0x0F])
      buf.write_char('%')
      buf.write_char(hex_upper_chars[(b2 >> 4) & 0x0F])
      buf.write_char(hex_upper_chars[b2 & 0x0F])
    } else {
      let b0 = 0xF0 | (code >> 18)
      let b1 = 0x80 | ((code >> 12) & 0x3F)
      let b2 = 0x80 | ((code >> 6) & 0x3F)
      let b3 = 0x80 | (code & 0x3F)
      buf.write_char('%')
      buf.write_char(hex_upper_chars[(b0 >> 4) & 0x0F])
      buf.write_char(hex_upper_chars[b0 & 0x0F])
      buf.write_char('%')
      buf.write_char(hex_upper_chars[(b1 >> 4) & 0x0F])
      buf.write_char(hex_upper_chars[b1 & 0x0F])
      buf.write_char('%')
      buf.write_char(hex_upper_chars[(b2 >> 4) & 0x0F])
      buf.write_char(hex_upper_chars[b2 & 0x0F])
      buf.write_char('%')
      buf.write_char(hex_upper_chars[(b3 >> 4) & 0x0F])
      buf.write_char(hex_upper_chars[b3 & 0x0F])
    }
  }
  buf.to_string()
}
