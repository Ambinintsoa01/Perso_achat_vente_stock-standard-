import 'package:flutter/material.dart';
import '../../config/supabase_config.dart';
import '../../services/supabase_sync_service.dart';

class SupabaseConfigDialog extends StatefulWidget {
  const SupabaseConfigDialog({super.key});

  @override
  State<SupabaseConfigDialog> createState() => _SupabaseConfigDialogState();
}

class _SupabaseConfigDialogState extends State<SupabaseConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();

  bool _obscureKey = true;
  bool _isTesting = false;
  bool _isSaving = false;
  String? _testMessage;
  bool _testSuccess = false;
  bool _testTablesExist = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    final syncService = SupabaseSyncService.instance;
    var url = await syncService.getUrl();
    var key = await syncService.getAnonKey();
    if (url == null || url.isEmpty) url = SupabaseConfig.defaultUrl;
    if (key == null || key.isEmpty) key = SupabaseConfig.defaultAnonKey;

    if (mounted) {
      setState(() {
        _urlController.text = url ?? '';
        _keyController.text = key ?? '';
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _handleTest() async {
    final url = _urlController.text.trim();
    final key = _keyController.text.trim();

    if (url.isEmpty || key.isEmpty) {
      setState(() {
        _testSuccess = false;
        _testTablesExist = false;
        _testMessage = 'Veuillez saisir l\'URL et la clé Anon';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testMessage = null;
    });

    final res = await SupabaseSyncService.instance.testConnection(
      customUrl: url,
      customKey: key,
    );

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testSuccess = res.isConnected;
        _testTablesExist = res.tablesExist;
        _testMessage = res.message;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    await SupabaseSyncService.instance.saveConfig(
      url: _urlController.text.trim(),
      anonKey: _keyController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration Supabase enregistrée'),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.settings_suggest_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Configuration Supabase',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Paramètres de connexion au projet cloud',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Explication
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: Colors.black87),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Trouvez ces clés dans votre projet Supabase sous Settings > API.',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Champ URL
                const Text(
                  'Project URL (URL de l\'API)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: 'https://xxxxxxxxxxxx.supabase.co',
                    prefixIcon: const Icon(Icons.link_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'L\'URL Supabase est requise';
                    }
                    if (!val.trim().startsWith('http://') && !val.trim().startsWith('https://')) {
                      return 'L\'URL doit commencer par https://';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Champ Anon Key
                const Text(
                  'Anon / Public Key',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _keyController,
                  obscureText: _obscureKey,
                  decoration: InputDecoration(
                    hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                    prefixIcon: const Icon(Icons.key_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureKey = !_obscureKey),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'La clé Anon est requise';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Message de résultat du test
                if (_testMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: !_testSuccess
                          ? Colors.red.shade50
                          : (_testTablesExist ? Colors.green.shade50 : Colors.amber.shade50),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: !_testSuccess
                            ? Colors.red.shade200
                            : (_testTablesExist ? Colors.green.shade200 : Colors.amber.shade300),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          !_testSuccess
                              ? Icons.error_outline_rounded
                              : (_testTablesExist ? Icons.check_circle_rounded : Icons.warning_amber_rounded),
                          size: 18,
                          color: !_testSuccess
                              ? Colors.red.shade800
                              : (_testTablesExist ? Colors.green.shade800 : Colors.amber.shade900),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: !_testSuccess
                                  ? Colors.red.shade900
                                  : (_testTablesExist ? Colors.green.shade900 : Colors.brown.shade900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Bouton Tester la connexion
                OutlinedButton.icon(
                  onPressed: _isTesting ? null : _handleTest,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.wifi_tethering_rounded, size: 16),
                  label: Text(_isTesting ? 'Test en cours...' : 'Tester la connexion'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 20),

                // Actions de validation
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black54,
                      ),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _handleSave,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded, size: 18),
                      label: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
