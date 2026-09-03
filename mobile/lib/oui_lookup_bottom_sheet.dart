import 'package:flutter/material.dart';
import 'oui_database.dart';

class OuiLookupBottomSheet extends StatefulWidget {
  final String? initialMac;

  const OuiLookupBottomSheet({super.key, this.initialMac});

  static void show(BuildContext context, {String? initialMac}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OuiLookupBottomSheet(initialMac: initialMac),
    );
  }

  @override
  State<OuiLookupBottomSheet> createState() => _OuiLookupBottomSheetState();
}

class _OuiLookupBottomSheetState extends State<OuiLookupBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  OuiInfo? _resolvedInfo;
  bool _searched = false;
  String _searchedMac = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialMac != null && widget.initialMac!.isNotEmpty) {
      _controller.text = widget.initialMac!;
      _performLookup(widget.initialMac!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _performLookup(String mac) {
    if (mac.trim().isEmpty) return;
    final info = OuiDatabase().lookup(mac);
    setState(() {
      _resolvedInfo = info;
      _searchedMac = mac.trim().toUpperCase();
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: surface,
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'OUI MAC RESOLVER',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: primary,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: primary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 2, color: primary.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ENTER MAC ADDRESS...',
                    hintStyle: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: onSurface.withValues(alpha: 0.38),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: primary, width: 1.5),
                      borderRadius: BorderRadius.zero,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: primary, width: 2.5),
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: _performLookup,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  _performLookup(_controller.text);
                },
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: primary,
                    border: Border.all(color: primary, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'LOOKUP',
                    style: TextStyle(
                      color: surface,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_searched) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.03),
                border: Border.all(color: primary, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QUERY: $_searchedMac',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: onSurface.withValues(alpha: 0.54),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_resolvedInfo != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.business, size: 16, color: primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VENDOR / ORGANIZATION',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: onSurface.withValues(alpha: 0.54),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _resolvedInfo!.organization,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_resolvedInfo!.country != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.flag, size: 16, color: primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'COUNTRY',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: onSurface.withValues(alpha: 0.54),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${getFlagEmoji(_resolvedInfo!.country!)} ${_resolvedInfo!.country}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ] else ...[
                    Row(
                      children: [
                        const Icon(Icons.help_outline, size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'NO MATCH FOUND IN OFFLINE OUI DATABASE',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'AWAITING INPUT...',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: onSurface.withValues(alpha: 0.38),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
