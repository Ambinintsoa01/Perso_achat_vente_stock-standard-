import 'package:flutter/material.dart';
import '../../../models/utilisateur.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';
import '../../sync/supabase_sync_dialog.dart';

class ProfilUtilisateurDialog extends StatefulWidget {
  final Utilisateur user;

  const ProfilUtilisateurDialog({super.key, required this.user});

  @override
  State<ProfilUtilisateurDialog> createState() => _ProfilUtilisateurDialogState();
}

class _ProfilUtilisateurDialogState extends State<ProfilUtilisateurDialog> {
  final AuthService _authService = AuthService.instance;

  final TextEditingController _ancienMdpController = TextEditingController();
  final TextEditingController _nouveauMdpController = TextEditingController();
  bool _showChangerMdp = false;
  bool _isSavingMdp = false;
  String? _pwdMessage;
  bool _pwdSuccess = false;

  @override
  void dispose() {
    _ancienMdpController.dispose();
    _nouveauMdpController.dispose();
    super.dispose();
  }

  Future<void> _handleChangerMdp() async {
    final ancien = _ancienMdpController.text.trim();
    final nouveau = _nouveauMdpController.text.trim();

    if (ancien.isEmpty || nouveau.isEmpty) {
      setState(() {
        _pwdMessage = 'Veuillez remplir tous les champs';
        _pwdSuccess = false;
      });
      return;
    }

    setState(() => _isSavingMdp = true);
    try {
      await _authService.changerMotDePasse(
        idUtilisateur: widget.user.id,
        ancienMdp: ancien,
        nouveauMdp: nouveau,
      );
      if (mounted) {
        setState(() {
          _isSavingMdp = false;
          _pwdSuccess = true;
          _pwdMessage = 'Mot de passe modifié avec succès';
          _ancienMdpController.clear();
          _nouveauMdpController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingMdp = false;
          _pwdSuccess = false;
          _pwdMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _handleLogout() {
    Navigator.of(context).pop();
    _authService.logout();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.user.initiales,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Nom Complet & Username
              Text(
                widget.user.nomComplet,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                '@${widget.user.nomUtilisateur}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),

              // Badge de profil SQL
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_outlined, size: 14, color: Colors.black87),
                    const SizedBox(width: 6),
                    Text(
                      widget.user.profilLibelle ?? widget.user.profilCode ?? 'Utilisateur',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Informations détaillées
              _buildInfoRow(Icons.mail_outline, 'Email', widget.user.email ?? 'Non renseigné'),
              const SizedBox(height: 10),
              _buildInfoRow(Icons.phone_outlined, 'Téléphone', widget.user.telephone ?? 'Non renseigné'),
              const SizedBox(height: 10),
              _buildInfoRow(Icons.calendar_today_outlined, 'Créé le', widget.user.createdAt?.substring(0, 10) ?? 'N/A'),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Section Changer de mot de passe (Toggle)
              InkWell(
                onTap: () => setState(() => _showChangerMdp = !_showChangerMdp),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.lock_reset_rounded, size: 18, color: Colors.black87),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Changer de mot de passe',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _showChangerMdp ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              if (_showChangerMdp) ...[
                const SizedBox(height: 10),
                if (_pwdMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _pwdSuccess ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _pwdMessage!,
                      style: TextStyle(
                        fontSize: 11,
                        color: _pwdSuccess ? AppTheme.success : AppTheme.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: _ancienMdpController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Ancien mot de passe',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nouveauMdpController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _isSavingMdp ? null : _handleChangerMdp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: _isSavingMdp
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Valider le changement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],

              const SizedBox(height: 14),

              // Option Cloud Supabase Sync
              InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  showDialog(
                    context: context,
                    builder: (_) => const SupabaseSyncDialog(),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_sync_outlined, size: 20, color: Colors.black87),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Synchronisation Cloud Supabase',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Synchroniser SQLite avec Supabase',
                              style: TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 18, color: Colors.black45),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Bouton Déconnexion
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleLogout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text(
                    'Se déconnecter',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Bouton Fermer
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer', style: TextStyle(color: Colors.black54)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 8),
        Text(
          '$label : ',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
