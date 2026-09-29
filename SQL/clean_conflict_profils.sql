-- =============================================================================
-- SCRIPT DE RÉSOLUTION DU CONFLIT D'IDENTIFIANTS (PROFIL & UTILISATEUR)
-- =============================================================================
-- Pourquoi ce script est nécessaire :
-- 1. Le script initial exécuté dans Supabase contenait des profils pré-créés
--    (ADMIN=1, CAISSIER=2, MAGASINIER=3 avec numero=21).
-- 2. Votre base locale SQLite sur le téléphone contient les profils avec des IDs
--    légèrement différents (par ex. MAGASINIER=4, GÉRANT=5).
-- 3. Quand Flutter envoie les profils locaux, PostgreSQL bloque car numero=21
--    existe déjà sous un ID différent.
-- 4. Par effet domino, les tables utilisateur, journal_caisse et journal_caisse_ligne
--    étaient bloquées par les contraintes de clés étrangères.
--
-- Exécutez ce script dans l'éditeur SQL de Supabase, puis relancez la synchronisation
-- depuis l'application : Supabase recevra alors fidèlement tous vos enregistrements SQLite !
-- =============================================================================

-- Vider les tables qui ont un conflit d'identifiants
TRUNCATE TABLE 
    journal_caisse_ligne,
    journal_caisse,
    utilisateur,
    profil
CASCADE;

SELECT 'Tables vidées avec succès ! Vous pouvez maintenant relancer la synchronisation depuis l''application.' AS resultat;
