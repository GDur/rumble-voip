import 'dart:convert';
import 'dart:io';
import 'package:basic_utils/basic_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rumble/models/certificate.dart';

class CertificateService extends ChangeNotifier {
  List<MumbleCertificate> _certificates = [];
  String? _defaultCertificateId;
  final Set<String> _hiddenIds = {};
  bool _isInitialized = false;

  List<MumbleCertificate> get certificates =>
      _certificates.where((c) => !_hiddenIds.contains(c.id)).toList();
  String? get defaultCertificateId => _defaultCertificateId;

  MumbleCertificate? getCertificateById(String id) {
    try {
      return _certificates.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  bool get isInitialized => _isInitialized;

  MumbleCertificate? get defaultCertificate {
    if (_defaultCertificateId == null) return null;
    try {
      return _certificates.firstWhere((c) => c.id == _defaultCertificateId);
    } catch (_) {
      return null;
    }
  }

  CertificateService() {
    _init();
  }

  Future<void> _init() async {
    await loadCertificates();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> loadCertificates() async {
    try {
      final file = await _getCertFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> json = jsonDecode(content);
        _certificates = json.map((j) => MumbleCertificate.fromJson(j)).toList();
      }

      final prefsFile = await _getPrefsFile();
      if (await prefsFile.exists()) {
        final prefs = jsonDecode(await prefsFile.readAsString());
        _defaultCertificateId = prefs['defaultCertificateId'];
      }

      // If no certificates but we need one, we might want to auto-generate one later
      // But for now, we leave it to the user or initial setup.
    } catch (e) {
      debugPrint('Error loading certificates: $e');
    }
  }

  Future<void> _save() async {
    try {
      final file = await _getCertFile();
      final content = jsonEncode(_certificates.map((c) => c.toJson()).toList());
      await file.writeAsString(content);

      final prefsFile = await _getPrefsFile();
      await prefsFile.writeAsString(
        jsonEncode({'defaultCertificateId': _defaultCertificateId}),
      );
    } catch (e) {
      debugPrint('Error saving certificates: $e');
    }
  }

  Future<MumbleCertificate> generateCertificate(String name) async {
    // Generate RSA Key Pair
    final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    final privKey = pair.privateKey as RSAPrivateKey;
    final pubKey = pair.publicKey as RSAPublicKey;

    // Prepare DN/Attributes for CSR
    final Map<String, String> attributes = {
      'CN': name,
      'O': 'Rumble Client',
      'OU': 'User Identity',
    };

    // Generate CSR
    final csr = X509Utils.generateRsaCsrPem(attributes, privKey, pubKey);

    // Generate Self-Signed Certificate
    final certPem = X509Utils.generateSelfSignedCertificate(
      privKey,
      csr,
      3650, // 10 years
    );

    final privKeyPem = CryptoUtils.encodeRSAPrivateKeyToPem(privKey);

    final cert = MumbleCertificate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      certificatePem: certPem,
      privateKeyPem: privKeyPem,
      createdAt: DateTime.now(),
    );

    _certificates.add(cert);
    _defaultCertificateId ??= cert.id;

    await _save();
    notifyListeners();
    return cert;
  }

  Future<void> deleteCertificate(String id) async {
    _certificates.removeWhere((c) => c.id == id);
    _hiddenIds.remove(id);
    if (_defaultCertificateId == id) {
      _defaultCertificateId = _certificates.isNotEmpty
          ? _certificates.first.id
          : null;
    }
    await _save();
    notifyListeners();
  }

  void hideCertificate(String id) {
    _hiddenIds.add(id);
    notifyListeners();
  }

  void unhideCertificate(String id) {
    _hiddenIds.remove(id);
    notifyListeners();
  }

  Future<void> setDefaultCertificate(String? id) async {
    _defaultCertificateId = id;
    await _save();
    notifyListeners();
  }

  Future<MumbleCertificate?> importFromP12(
    Uint8List data,
    String? password,
    String name,
  ) async {
    try {
      debugPrint(
        '[CertificateService] Attempting to import P12 with basic_utils...',
      );
      List<String> pems;
      try {
        final p12Password = password ?? "";
        pems = Pkcs12Utils.parsePkcs12(data, password: p12Password);
      } catch (e) {
        debugPrint(
          '[CertificateService] basic_utils import failed ($e). Trying openssl fallback...',
        );
        final fallback = await _tryOpensslFallback(data, password);
        if (fallback != null && fallback.isNotEmpty) {
          pems = fallback;
        } else {
          rethrow;
        }
      }

      String? certPem;
      String? keyPem;

      for (var pem in pems) {
        if (pem.contains('BEGIN CERTIFICATE')) {
          certPem = pem;
        } else if (pem.contains('BEGIN PRIVATE KEY') ||
            pem.contains('BEGIN RSA PRIVATE KEY')) {
          keyPem = pem;
        }
      }

      if (certPem != null && keyPem != null) {
        final cert = MumbleCertificate(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          certificatePem: certPem,
          privateKeyPem: keyPem,
          createdAt: DateTime.now(),
        );

        _certificates.add(cert);
        _defaultCertificateId ??= cert.id;
        await _save();
        notifyListeners();
        debugPrint(
          '[CertificateService] Successfully imported certificate: $name',
        );
        return cert;
      } else {
        debugPrint(
          '[CertificateService] Failed to find both certificate and private key in P12.',
        );
      }
    } catch (e) {
      debugPrint('[CertificateService] Final error importing P12: $e');
    }
    return null;
  }

  Future<List<String>?> _tryOpensslFallback(
    Uint8List data,
    String? password,
  ) async {
    if (kIsWeb) return null;
    if (!(Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      return null;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/rumble_import_${DateTime.now().millisecondsSinceEpoch}.p12',
      );
      await tempFile.writeAsBytes(data);

      debugPrint('[CertificateService] Running openssl pkcs12 export...');
      final result = await Process.run('openssl', [
        'pkcs12',
        '-in',
        tempFile.path,
        '-nodes',
        '-passin',
        'pass:${password ?? ""}',
      ]);

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      if (result.exitCode == 0) {
        final String output = result.stdout as String;
        final List<String> pems = [];

        // Extract PEM blocks
        final certRegex = RegExp(
          r'-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----',
        );
        final keyRegex = RegExp(
          r'-----BEGIN (?:RSA )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA )?PRIVATE KEY-----',
        );

        final certs = certRegex.allMatches(output);
        final keys = keyRegex.allMatches(output);

        for (final m in certs) {
          pems.add(m.group(0)!);
        }
        for (final m in keys) {
          pems.add(m.group(0)!);
        }

        if (pems.isNotEmpty) {
          debugPrint('[CertificateService] Openssl fallback succeeded.');
          return pems;
        }
      } else {
        debugPrint(
          '[CertificateService] Openssl failed with exit code ${result.exitCode}: ${result.stderr}',
        );
      }
    } catch (e) {
      debugPrint('[CertificateService] Openssl fallback process error: $e');
    }
    return null;
  }

  Uint8List exportToP12(MumbleCertificate cert, String? password) {
    return Pkcs12Utils.generatePkcs12(
      cert.privateKeyPem,
      [cert.certificatePem],
      password: password,
      friendlyName: cert.name,
    );
  }

  Future<File> _getCertFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/certificates.json');
  }

  Future<File> _getPrefsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/cert_prefs.json');
  }
}
