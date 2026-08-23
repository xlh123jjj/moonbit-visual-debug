///|
test "stored DEFLATE splits payloads larger than one block" {
  let raw = Array::make(65536, byte(0))
  let encoded = zlib_store(raw)
  // zlib header (2), two stored-block headers (10), Adler-32 (4).
  inspect(encoded.length(), content="65552")
  inspect(encoded[2], content="b'\\x00'")
  inspect(encoded[65542], content="b'\\x01'")
}
