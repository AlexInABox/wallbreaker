import 'dart:typed_data';

/// Shared type struct representing the sniffed Wi-Fi packet payload.
class SnifferPayload {
  // @type: [u8; 6]
  final Uint8List senderMac;
  // @type: [u8; 6]
  final Uint8List receiverMac;
  // @type: i8
  final int rssi;

  SnifferPayload({
    required this.senderMac,
    required this.receiverMac,
    required this.rssi,
  });

  String get senderMacAddress => senderMac.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
  String get receiverMacAddress => receiverMac.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');

  factory SnifferPayload.fromBytes(List<int> bytes) {
    if (bytes.length < 13) {
      throw ArgumentError('Payload too short');
    }
    return SnifferPayload(
      senderMac: Uint8List.fromList(bytes.sublist(0, 6)),
      receiverMac: Uint8List.fromList(bytes.sublist(6, 12)),
      rssi: (bytes[12] & 0xFF).toSigned(8),
    );
  }

  Uint8List toBytes() {
    final bytes = Uint8List(13);
    bytes.setRange(0, 6, senderMac);
    bytes.setRange(6, 12, receiverMac);
    bytes[12] = rssi & 0xFF;
    return bytes;
  }
}
