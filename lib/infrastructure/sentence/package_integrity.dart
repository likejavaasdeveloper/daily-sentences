import 'package:crypto/crypto.dart';

bool hasValidPackageChecksum(List<int> bytes, String checksum) =>
    sha256.convert(bytes).toString() == checksum;
