import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:rumble/services/certificate_service.dart';

// Brand Colors (Moved here or should be in a global theme file)
const kBrandGreen = Color(0xFF64FFDA);

// Component: certificate-tab
class CertificateTab extends StatelessWidget {
  final StateSetter onUpdate;

  const CertificateTab({super.key, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final certService = Provider.of<CertificateService>(context);
    final theme = ShadTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                const Text(
                  'Identity Certificates',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['p12', 'pfx'],
                        );
                        if (result != null &&
                            result.files.single.path != null) {
                          final data = await File(
                            result.files.single.path!,
                          ).readAsBytes();

                          final name = result.files.single.name;

                          if (!context.mounted) return;
                          String? password;
                          await showShadDialog(
                            context: context,
                            builder: (context) => ShadDialog(
                              title: const Text('Certificate Password'),
                              description: const Text(
                                'Enter the password for the PKCS#12 file (leave empty if none).',
                              ),
                              actions: [
                                ShadButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Import'),
                                ),
                              ],
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ShadInput(
                                    placeholder: const Text('Password'),
                                    obscureText: true,
                                    onChanged: (v) => password = v,
                                  ),
                                ],
                              ),
                            ),
                          );

                          await certService.importFromP12(data, password, name);
                          onUpdate(() {});
                        }
                      },
                      child: const Text('Import P12'),
                    ),
                    const SizedBox(width: 8),
                    ShadButton(
                      size: ShadButtonSize.sm,
                      onPressed: () async {
                        await certService.generateCertificate('My Mumble Cert');
                        onUpdate(() {});
                      },
                      child: const Text('Generate'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Expanded(child: _buildCertificateList(context, certService, theme)),
      ],
    );
  }

  Widget _buildCertificateList(
    BuildContext context,
    CertificateService certService,
    ShadThemeData theme,
  ) {
    if (certService.certificates.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No certificates found.'),
        ),
      );
    }

    return ListView.builder(
      itemCount: certService.certificates.length,
      itemBuilder: (context, index) {
        final cert = certService.certificates[index];
        final isDefault = cert.id == certService.defaultCertificateId;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.border),
            borderRadius: BorderRadius.circular(8),
            color: isDefault
                ? theme.colorScheme.primary.withValues(alpha: 0.05)
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cert.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Created: ${cert.createdAt.toString().split('.')[0]}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  ShadTooltip(
                    builder: (context) => const Text('Set as default'),
                    child: ShadButton.ghost(
                      size: ShadButtonSize.sm,
                      onPressed: () {
                        certService.setDefaultCertificate(cert.id);
                        onUpdate(() {});
                      },
                      child: Icon(
                        isDefault
                            ? LucideIcons.circleCheck
                            : LucideIcons.circle,
                        size: 16,
                        color: isDefault ? kBrandGreen : null,
                      ),
                    ),
                  ),
                  ShadTooltip(
                    builder: (context) => const Text('Export P12'),
                    child: ShadButton.ghost(
                      size: ShadButtonSize.sm,
                      onPressed: () async {
                        final path = await FilePicker.platform.saveFile(
                          fileName: '${cert.name}.p12',
                          type: FileType.custom,
                          allowedExtensions: ['p12'],
                        );
                        if (path != null) {
                          final p12Data = certService.exportToP12(cert, null);
                          await File(path).writeAsBytes(p12Data);
                        }
                      },
                      child: const Icon(LucideIcons.download, size: 16),
                    ),
                  ),
                  ShadTooltip(
                    builder: (context) => const Text('Delete'),
                    child: ShadButton.ghost(
                      size: ShadButtonSize.sm,
                      onPressed: () {
                        final certId = cert.id;
                        final certName = cert.name;
                        certService.hideCertificate(certId);
                        onUpdate(() {});
                        bool undone = false;
                        ShadToaster.of(context).show(
                          ShadToast(
                            title: Text('Deleted $certName'),
                            action: ShadButton.outline(
                              size: ShadButtonSize.sm,
                              onPressed: () {
                                undone = true;
                                certService.unhideCertificate(certId);
                                onUpdate(() {});
                                ShadToaster.of(context).hide();
                              },
                              child: const Text('Undo'),
                            ),
                          ),
                        );
                        Future.delayed(const Duration(seconds: 5), () {
                          if (!undone) certService.deleteCertificate(certId);
                        });
                      },
                      child: Icon(
                        LucideIcons.trash2,
                        size: 16,
                        color: theme.colorScheme.destructive,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
