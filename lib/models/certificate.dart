class MumbleCertificate {
  final String id;
  final String name;
  final String certificatePem; // X.509 Certificate in PEM format
  final String privateKeyPem; // Private Key in PEM format (PKCS8)
  final DateTime createdAt;

  MumbleCertificate({
    required this.id,
    required this.name,
    required this.certificatePem,
    required this.privateKeyPem,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'certificatePem': certificatePem,
    'privateKeyPem': privateKeyPem,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MumbleCertificate.fromJson(Map<String, dynamic> json) =>
      MumbleCertificate(
        id: json['id'],
        name: json['name'],
        certificatePem: json['certificatePem'],
        privateKeyPem: json['privateKeyPem'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}
