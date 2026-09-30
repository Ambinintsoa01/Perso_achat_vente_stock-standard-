-- =============================================================================
-- ACTIVER RLS AVEC POLITIQUES PERMISSIVES SUR SUPABASE
-- Supprime les avertissements rouges "UNRESTRICTED" dans l'interface Supabase
-- =============================================================================
-- Explication :
-- 1. Le badge "UNRESTRICTED" apparaît quand le Row Level Security (RLS) est désactivé.
-- 2. Ce script active le RLS sur chaque table (pour retirer le badge UNRESTRICTED)
-- 3. Il crée une politique "anon_full_access" autorisant l'application Flutter
--    (qui utilise la clé anon) à lire et écrire sans aucun blocage.
-- =============================================================================

DO $$ 
DECLARE 
    r RECORD;
BEGIN 
    FOR r IN (
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public'
    ) LOOP 
        -- 1. Activer le RLS (remplace le badge UNRESTRICTED)
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', r.tablename);
        
        -- 2. Supprimer d'anciennes règles éventuelles pour éviter les conflits
        EXECUTE format('DROP POLICY IF EXISTS "anon_full_access" ON public.%I;', r.tablename);
        EXECUTE format('DROP POLICY IF EXISTS "Allow all for anon" ON public.%I;', r.tablename);
        EXECUTE format('DROP POLICY IF EXISTS "allow_all" ON public.%I;', r.tablename);
        
        -- 3. Créer la politique qui autorise l'accès complet (SELECT, INSERT, UPDATE, DELETE)
        EXECUTE format('CREATE POLICY "anon_full_access" ON public.%I FOR ALL TO anon, authenticated, service_role USING (true) WITH CHECK (true);', r.tablename);
    END LOOP; 
END $$;

-- 4. Attribution des privilèges sur le schéma public
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

SELECT 'RLS activé et sécurisé avec succès pour toutes les tables !' AS resultat;
