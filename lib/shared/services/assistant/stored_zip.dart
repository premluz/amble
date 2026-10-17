import 'dart:convert';
import 'dart:typed_data';

/// A minimal ZIP writer: files are stored uncompressed, which every unzip
/// tool and Claude Desktop's extension installer read. Enough for the
/// Claude extension bundle (a manifest and one small script) without a zip
/// dependency.
Uint8List storedZip(Map<String, List<int>> files) {
  final out = BytesBuilder();
  final central = BytesBuilder();
  for (final entry in files.entries) {
    final name = utf8.encode(entry.key);
    final data = entry.value;
    final crc = crc32(data);
    final offset = out.length;
    out
      ..add(_u32(0x04034b50)) // local file header
      ..add(_entryFields(name, data.length, crc))
      ..add(name)
      ..add(data);
    central
      ..add(_u32(0x02014b50)) // central directory header
      ..add(_u16(_version))
      ..add(_entryFields(name, data.length, crc))
      ..add(_u16(0)) // comment length
      ..add(_u16(0)) // disk number
      ..add(_u16(0)) // internal attributes
      ..add(_u32(0)) // external attributes
      ..add(_u32(offset))
      ..add(name);
  }
  final directoryOffset = out.length;
  final directory = central.takeBytes();
  out
    ..add(directory)
    ..add(_u32(0x06054b50)) // end of central directory
    ..add(_u16(0))
    ..add(_u16(0))
    ..add(_u16(files.length))
    ..add(_u16(files.length))
    ..add(_u32(directory.length))
    ..add(_u32(directoryOffset))
    ..add(_u16(0));
  return out.takeBytes();
}

/// "Version needed to extract": 2.0, plain stored files.
const _version = 20;

/// Bit 11: file names are UTF-8.
const _utf8Flag = 1 << 11;

/// The fields a local header and a central directory entry share, from
/// "version needed" to "extra field length".
List<int> _entryFields(List<int> name, int size, int crc) => [
  ..._u16(_version),
  ..._u16(_utf8Flag),
  ..._u16(0), // method: stored
  ..._u16(0), // modification time
  ..._u16(_dosDate1980),
  ..._u32(crc),
  ..._u32(size), // compressed size
  ..._u32(size), // uncompressed size
  ..._u16(name.length),
  ..._u16(0), // extra field length
];

/// 1 January 1980, the earliest date a ZIP can hold. A fixed date keeps the
/// output identical for identical input.
const _dosDate1980 = (1 << 5) | 1;

List<int> _u16(int value) => [value & 0xff, (value >> 8) & 0xff];

List<int> _u32(int value) => [
  value & 0xff,
  (value >> 8) & 0xff,
  (value >> 16) & 0xff,
  (value >> 24) & 0xff,
];

/// CRC-32 (IEEE), as ZIP requires.
int crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc = _crcTable[(crc ^ byte) & 0xff] ^ (crc >> 8);
  }
  return crc ^ 0xffffffff;
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});
