-- =============================================================================
-- SCRIPT DE RÉSOLUTION RLS (ROW LEVEL SECURITY) POUR SUPABASE
-- =============================================================================
-- Pourquoi cette erreur est apparue :
-- Par défaut, Supabase active le "Row Level Security" (RLS) sur les tables.
-- Avec le rôle "anon" (clé publique utilisée par l'application Flutter),
-- toute insertion (INSERT/UPSERT) ou lecture est bloquée à 100% tant qu'aucune
-- "Policy" explicite n'autorise l'accès.
--
-- Ce script effectue deux actions complémentaires pour débloquer définitivement l'accès :
-- 1. Il désactive le RLS (DISABLE ROW LEVEL SECURITY) sur toutes les tables existantes.
-- 2. Il crée également une politique permissive universelle ("Allow all for anon and authenticated")
--    sur chaque table, garantissant que même si Supabase réactive le RLS,
--    l'application Flutter aura un accès complet en lecture/écriture.
-- 3. Il attribue tous les droits (GRANT ALL) aux rôles anon et authenticated.
-- =============================================================================

DO $$ 
DECLARE 
    r RECORD;
BEGIN 
    -- Parcourt toutes les tables du schéma public
    FOR r IN (
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public'
    ) LOOP 
        -- 1. Désactivation directe du RLS
        EXECUTE format('ALTER TABLE public.%I DISABLE ROW LEVEL SECURITY;', r.tablename);
        
        -- 2. Suppression de l'ancienne politique si elle existe
        EXECUTE format('DROP POLICY IF EXISTS "anon_full_access" ON public.%I;', r.tablename);
        EXECUTE format('DROP POLICY IF EXISTS "Allow all for anon" ON public.%I;', r.tablename);
        
        -- 3. Création d'une politique universelle de secours (FOR ALL = SELECT, INSERT, UPDATE, DELETE)
        EXECUTE format('CREATE POLICY "anon_full_access" ON public.%I FOR ALL TO anon, authenticated, service_role USING (true) WITH CHECK (true);', r.tablename);
    END LOOP; 
END $$;

-- 4. Attribution des droits sur les tables existantes et futures
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON ROUTINES TO anon, authenticated, service_role;

-- Confirmation
SELECT 'RLS désactivé et autorisations accordées avec succès pour toutes les tables !' AS resultat;
