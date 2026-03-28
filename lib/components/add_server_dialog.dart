import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:provider/provider.dart';
import 'package:rumble/models/server.dart';
import 'package:rumble/services/server_provider.dart';
import 'package:rumble/components/rumble_tooltip.dart';

// Component: add-edit-server-dialog
class AddServerDialog extends StatefulWidget {
  final MumbleServer? server;
  final String? errorField;

  const AddServerDialog({super.key, this.server, this.errorField});

  @override
  State<AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<AddServerDialog> {
  late final TextEditingController _hostController;
  late final TextEditingController _nameController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _isAutoName = true;
  bool _passwordObscure = true;
  final _formKey = GlobalKey<ShadFormState>();

  @override
  void initState() {
    super.initState();
    final server = widget.server;
    _hostController = TextEditingController(text: server?.host ?? '');
    _nameController = TextEditingController(text: server?.name ?? '');
    _portController = TextEditingController(
      text: server?.port.toString() ?? '64738',
    );
    _usernameController = TextEditingController(
      text: server?.username ?? 'Rumble - Mumble Reloaded',
    );
    _passwordController = TextEditingController(text: server?.password ?? '');
    if (server != null) {
      _isAutoName = false;
      // selection for host field if editing
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hostController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _hostController.text.length,
        );
      });
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _nameController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return ShadDialog(
      radius: const BorderRadius.all(Radius.circular(16)),
      removeBorderRadiusWhenTiny: false,
      closeIconPosition: const ShadPosition(top: 12, right: 12),
      title: Text(widget.server == null ? 'Add New Server' : 'Edit Server'),
      actions: [
        ShadButton.outline(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ShadButton(
          child: const Text('Save Server'),
          onPressed: () {
            if (_formKey.currentState!.saveAndValidate()) {
              final username = _usernameController.text.trim();
              final newServer = MumbleServer(
                id: widget.server?.id,
                name: _nameController.text.isEmpty
                    ? _hostController.text
                    : _nameController.text,
                host: _hostController.text,
                port: int.tryParse(_portController.text) ?? 64738,
                username: username,
                password: _passwordController.text,
                lastChannelId: widget.server?.lastChannelId,
              );

              final provider = Provider.of<ServerProvider>(
                context,
                listen: false,
              );
              if (widget.server == null) {
                provider.addServer(newServer);
              } else {
                provider.updateServer(newServer);
              }
              Navigator.of(context).pop();
            }
          },
        ),
      ],
      child: SafeArea(
        top: isMobile,
        bottom: isMobile,
        child: ShadForm(
          key: _formKey,
          child: Container(
            width: isMobile ? MediaQuery.of(context).size.width * 0.9 : 440,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: ShadInputFormField(
                    id: 'host',
                    label: _buildLabelWithTooltip(
                      'Server Address (Host)',
                      'The hostname or IP of the Mumble server.',
                    ),
                    placeholder: const Text('mumble.example.com'),
                    controller: _hostController,
                    autofocus: widget.errorField == null,
                    onChanged: (val) {
                      if (_isAutoName) {
                        setState(() => _nameController.text = val);
                      }
                    },
                    decoration: widget.errorField == 'host'
                        ? ShadDecoration(
                            border: ShadBorder.all(
                              color: Colors.orange.shade400,
                              width: 2,
                            ),
                          )
                        : null,
                    validator: (v) {
                      if (v.isEmpty) return 'Host address is required';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: ShadInputFormField(
                    id: 'name',
                    label: _buildLabelWithTooltip(
                      'Display Name',
                      'How this server appears in your list.',
                    ),
                    placeholder: const Text('My Awesome Server'),
                    controller: _nameController,
                    onChanged: (val) => setState(() => _isAutoName = false),
                    decoration: widget.errorField == 'name'
                        ? ShadDecoration(
                            border: ShadBorder.all(
                              color: Colors.orange.shade400,
                              width: 2,
                            ),
                          )
                        : null,
                    validator: (v) {
                      if (v.isEmpty) return 'Display name is required';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: ShadInputFormField(
                          id: 'port',
                          label: const Text('Port'),
                          placeholder: const Text('64738'),
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          decoration: widget.errorField == 'port'
                              ? ShadDecoration(
                                  border: ShadBorder.all(
                                    color: Colors.orange.shade400,
                                    width: 2,
                                  ),
                                )
                              : null,
                          validator: (v) {
                            if (int.tryParse(v) == null) return 'Invalid port';
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 250),
                        child: ShadInputFormField(
                          id: 'username',
                          label: _buildLabelWithTooltip(
                            'Username',
                            'Public display name on server.',
                          ),
                          placeholder: const Text('Your Nickname'),
                          controller: _usernameController,
                          decoration: widget.errorField == 'username'
                              ? ShadDecoration(
                                  border: ShadBorder.all(
                                    color: Colors.orange.shade400,
                                    width: 2,
                                  ),
                                )
                              : null,
                          validator: (v) {
                            if (v.length < 2) return 'Username too short';
                            return null;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: ShadInputFormField(
                    id: 'password',
                    label: const Text('Password (Optional)'),
                    placeholder: const Text('Secret Password'),
                    controller: _passwordController,
                    obscureText: _passwordObscure,
                    decoration: widget.errorField == 'password'
                        ? ShadDecoration(
                            border: ShadBorder.all(
                              color: Colors.orange.shade400,
                              width: 2,
                            ),
                          )
                        : null,
                    leading: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(LucideIcons.lock, size: 16),
                    ),
                    trailing: RumbleTooltip(
                      message: 'Toggle password visibility',
                      child: ShadIconButton.ghost(
                        width: 24,
                        height: 24,
                        padding: EdgeInsets.zero,
                        onPressed: () =>
                            setState(() => _passwordObscure = !_passwordObscure),
                        icon: Icon(
                          _passwordObscure ? LucideIcons.eye : LucideIcons.eyeOff,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabelWithTooltip(String text, String tooltip) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        const SizedBox(width: 4),
        RumbleTooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Icon(
              LucideIcons.info,
              size: 14,
              color: ShadTheme.of(context).colorScheme.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }
}
