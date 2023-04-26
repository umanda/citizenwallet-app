import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:web3dart/web3dart.dart';

BigInt parseIntFromHex(String hex) {
  return BigInt.parse(hex);
}

const zeroHexValue = '0x0';
const hexPadding = '0x';

bool isZeroHexValue(String hex) {
  return hex == zeroHexValue || hex == hexPadding;
}

bool isHexValue(String hex) {
  return hex.startsWith(hexPadding);
}

EthPrivateKey? stringToPrivateKey(String privateKey) {
  try {
    final String formattedPrivateKey = privateKey.startsWith(hexPadding)
        ? privateKey
        : '$hexPadding$privateKey';

    return EthPrivateKey.fromHex(formattedPrivateKey);
  } catch (e) {
    return null;
  }
}

bool isValidPrivateKey(String privateKey) {
  try {
    final String formattedPrivateKey = privateKey.startsWith(hexPadding)
        ? privateKey
        : '$hexPadding$privateKey';

    EthPrivateKey.fromHex(formattedPrivateKey);
    return true;
  } catch (e) {
    return false;
  }
}

String compress(String data) {
  final enCodedData = utf8.encode(data);
  final gZipData = GZipEncoder().encode(enCodedData, level: 6);
  return base64.encode(gZipData!);
}

String decompress(String data) {
  final decodeBase64Data = base64.decode(data);
  final decodegZipData = GZipDecoder().decodeBytes(decodeBase64Data);
  return utf8.decode(decodegZipData);
}
