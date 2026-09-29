-- =============================================================================
-- BASE DE DONNÉES COMPATIBLE SUPABASE / POSTGRESQL (100% POSTGRESQL STANDARD)
-- GESTION DES ACHATS, VENTES, STOCKS & TRÉSORERIE MULTI-CAISSE
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. TABLES DE RÉFÉRENCE & ÉTATS (LOOKUP TABLES)
-- -----------------------------------------------------------------------------

-- 1.1 Profils d'utilisateurs
CREATE TABLE IF NOT EXISTS profil (
    id SERIAL PRIMARY KEY,
    numero INT NOT NULL UNIQUE,     -- 1: ADMIN, 11: CAISSIER, 21: MAGASINIER, 31: GERANT
    code VARCHAR(50) NOT NULL UNIQUE,
    libelle VARCHAR(100) NOT NULL,
    description TEXT,
    actif BOOLEAN DEFAULT TRUE
);

-- 1.2 Utilisateurs
CREATE TABLE IF NOT EXISTS utilisateur (
    id SERIAL PRIMARY KEY,
    id_profil INT NOT NULL REFERENCES profil(id) ON DELETE RESTRICT,
    nom VARCHAR(100) NOT NULL,
    prenom VARCHAR(100),
    email VARCHAR(150) UNIQUE,
    telephone VARCHAR(50),
    nom_utilisateur VARCHAR(50) NOT NULL UNIQUE,
    mot_de_passe_hash TEXT NOT NULL,
    actif BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 1.3 Statuts de documents
CREATE TABLE IF NOT EXISTS statut (
    id SERIAL PRIMARY KEY,
    numero INT NOT NULL UNIQUE,     -- 1: créé, 11: validé, 21: annulé, 31: partiel, 41: terminé/soldé
    code VARCHAR(50) NOT NULL UNIQUE,
    libelle VARCHAR(100) NOT NULL,
    description TEXT
);

-- 1.4 Modes de paiement
CREATE TABLE IF NOT EXISTS mode_paiement (
    id SERIAL PRIMARY KEY,
    numero INT NOT NULL UNIQUE,     -- 1: ESPECES, 11: VIREMENT, 21: CHEQUE, 31: MVOLA, 41: ORANGE_MONEY, 51: AIRTEL_MONEY, 61: CARTE
    code VARCHAR(50) NOT NULL UNIQUE,
    libelle VARCHAR(100) NOT NULL,
    actif BOOLEAN DEFAULT TRUE
);

-- 1.5 Types de caisse
CREATE TABLE IF NOT EXISTS type_caisse (
    id SERIAL PRIMARY KEY,
    numero INT NOT NULL UNIQUE,     -- 1: CAISSE_PHYSIQUE, 11: BANQUE, 21: MOBILE_MONEY
    code VARCHAR(50) NOT NULL UNIQUE,
    libelle VARCHAR(100) NOT NULL
);

-- 1.6 Types mouvements stock
CREATE TABLE IF NOT EXISTS type_mouvement_stock (
    id SERIAL PRIMARY KEY,
    numero INT NOT NULL UNIQUE,     -- 1: ENTREE_ACHAT, 11: SORTIE_VENTE, 21: AJUSTEMENT_POS, 31: AJUSTEMENT_NEG
    code VARCHAR(50) NOT NULL UNIQUE,
    libelle VARCHAR(100) NOT NULL,
    sens INT NOT NULL CHECK (sens IN (1, -1)),
    actif BOOLEAN DEFAULT TRUE
);

-- 1.7 Types mouvements caisse
CREATE TABLE IF NOT EXISTS type_mouvement_caisse (
    id SERIAL PRIMARY KEY,
    numero INT NOT NULL UNIQUE,     -- 1: ENCAISSEMENT_VENTE, 11: DECAISSEMENT_ACHAT, 21: TRANSFERT_DEBIT, 31: TRANSFERT_CREDIT
    code VARCHAR(50) NOT NULL UNIQUE,
    libelle VARCHAR(100) NOT NULL,
    sens INT NOT NULL CHECK (sens IN (1, -1)),
    actif BOOLEAN DEFAULT TRUE
);

-- 1.8 Types clients
CREATE TABLE IF NOT EXISTS type_client (
    id SERIAL PRIMARY KEY,
    numero INT NOT NULL UNIQUE,     -- 1: PARTICULIER, 11: ENTREPRISE
    code VARCHAR(50) NOT NULL UNIQUE,
    libelle VARCHAR(100) NOT NULL
);

-- 1.9 Devises
CREATE TABLE IF NOT EXISTS devise (
    id SERIAL PRIMARY KEY,
    numero INT NOT NULL UNIQUE,     -- 1: MGA, 11: EUR, 21: USD
    code VARCHAR(10) NOT NULL UNIQUE,
    libelle VARCHAR(50) NOT NULL,
    symbole VARCHAR(10) DEFAULT 'Ar',
    actif BOOLEAN DEFAULT TRUE
);

-- 1.10 Catégories
CREATE TABLE IF NOT EXISTS categorie (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    nom VARCHAR(150) NOT NULL,
    description TEXT,
    id_parent INT REFERENCES categorie(id) ON DELETE SET NULL,
    actif BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 1.11 Unités de mesure
CREATE TABLE IF NOT EXISTS unite_mesure (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,
    nom VARCHAR(100) NOT NULL,
    actif BOOLEAN DEFAULT TRUE
);

-- 1.12 Dépôts
CREATE TABLE IF NOT EXISTS depot (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    nom VARCHAR(150) NOT NULL,
    adresse TEXT,
    telephone VARCHAR(50),
    actif BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 1.13 Articles
CREATE TABLE IF NOT EXISTS article (
    id SERIAL PRIMARY KEY,
    reference VARCHAR(50) NOT NULL UNIQUE,
    code_barre VARCHAR(100) UNIQUE,
    designation VARCHAR(255) NOT NULL,
    description TEXT,
    image_url TEXT,
    id_categorie INT REFERENCES categorie(id) ON DELETE RESTRICT,
    id_unite INT REFERENCES unite_mesure(id) ON DELETE RESTRICT,
    prix_achat_estime NUMERIC(15, 2) DEFAULT 0.00,
    cout_moyen_unitaire NUMERIC(15, 2) DEFAULT 0.00,
    prix_vente_standard NUMERIC(15, 2) DEFAULT 0.00,
    taux_tva NUMERIC(5, 2) DEFAULT 20.00,
    seuil_alerte_stock NUMERIC(15, 3) DEFAULT 0.000,
    suivi_stock BOOLEAN DEFAULT TRUE,
    actif BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 2. TIERS (Fournisseurs & Clients)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS fournisseur (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    raison_sociale VARCHAR(255) NOT NULL,
    nom_contact VARCHAR(150),
    telephone VARCHAR(50),
    email VARCHAR(150),
    adresse TEXT,
    ville VARCHAR(100),
    nif VARCHAR(50),
    stat VARCHAR(50),
    delai_paiement_jours INT DEFAULT 30,
    actif BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS client (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    nom_complet VARCHAR(255) NOT NULL,
    id_type_client INT NOT NULL REFERENCES type_client(id) ON DELETE RESTRICT,
    telephone VARCHAR(50),
    email VARCHAR(150),
    adresse TEXT,
    ville VARCHAR(100),
    nif VARCHAR(50),
    stat VARCHAR(50),
    solde_credit_max NUMERIC(15, 2) DEFAULT 0.00,
    actif BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 3. CAISSES & SESSIONS JOURNALIÈRES
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS caisse (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    nom VARCHAR(100) NOT NULL,
    id_type_caisse INT NOT NULL REFERENCES type_caisse(id) ON DELETE RESTRICT,
    numero_compte VARCHAR(100),
    solde_initial NUMERIC(15, 2) DEFAULT 0.00,
    solde_actuel NUMERIC(15, 2) DEFAULT 0.00,
    id_devise INT NOT NULL REFERENCES devise(id) ON DELETE RESTRICT,
    actif BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Journal de Caisse (Sessions journalières : Ouverture matin, Clôture soir)
CREATE TABLE IF NOT EXISTS journal_caisse (
    id SERIAL PRIMARY KEY,
    numero_journal VARCHAR(50) NOT NULL UNIQUE,
    date_journal DATE NOT NULL,
    date_ouverture TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date_fermeture TIMESTAMP WITH TIME ZONE,
    id_utilisateur_ouverture INT NOT NULL REFERENCES utilisateur(id) ON DELETE RESTRICT,
    id_utilisateur_fermeture INT REFERENCES utilisateur(id) ON DELETE RESTRICT,
    solde_ouverture_total NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    total_entrees NUMERIC(15, 2) DEFAULT 0.00,
    total_sorties NUMERIC(15, 2) DEFAULT 0.00,
    solde_theorique_total NUMERIC(15, 2) DEFAULT 0.00,
    solde_reel_total NUMERIC(15, 2) DEFAULT 0.00,
    ecart_total NUMERIC(15, 2) DEFAULT 0.00,
    statut VARCHAR(20) NOT NULL DEFAULT 'OUVERT' CHECK (statut IN ('OUVERT', 'CLOTURE')),
    notes_ouverture TEXT,
    notes_fermeture TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS journal_caisse_ligne (
    id SERIAL PRIMARY KEY,
    id_journal_caisse INT NOT NULL REFERENCES journal_caisse(id) ON DELETE CASCADE,
    id_caisse INT NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
    solde_ouverture NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    total_entrees NUMERIC(15, 2) DEFAULT 0.00,
    total_sorties NUMERIC(15, 2) DEFAULT 0.00,
    solde_theorique NUMERIC(15, 2) DEFAULT 0.00,
    solde_reel NUMERIC(15, 2),
    ecart NUMERIC(15, 2) DEFAULT 0.00,
    notes TEXT,
    CONSTRAINT uq_journal_caisse_ligne UNIQUE (id_journal_caisse, id_caisse)
);

-- Mouvements de caisse
CREATE TABLE IF NOT EXISTS mouvement_caisse (
    id SERIAL PRIMARY KEY,
    id_caisse INT NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
    id_type_mouvement INT NOT NULL REFERENCES type_mouvement_caisse(id) ON DELETE RESTRICT,
    id_mode_paiement INT NOT NULL REFERENCES mode_paiement(id) ON DELETE RESTRICT,
    id_utilisateur INT REFERENCES utilisateur(id) ON DELETE SET NULL,
    id_journal_caisse INT REFERENCES journal_caisse(id) ON DELETE SET NULL,
    montant NUMERIC(15, 2) NOT NULL CHECK (montant > 0),
    solde_avant NUMERIC(15, 2) NOT NULL,
    solde_apres NUMERIC(15, 2) NOT NULL,
    date_mouvement TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reference_piece VARCHAR(100),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Transferts internes de caisse
CREATE TABLE IF NOT EXISTS transfert_caisse (
    id SERIAL PRIMARY KEY,
    numero_transfert VARCHAR(50) NOT NULL UNIQUE,
    id_caisse_source INT NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
    id_caisse_destination INT NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
    montant NUMERIC(15, 2) NOT NULL CHECK (montant > 0),
    frais_transfert NUMERIC(15, 2) DEFAULT 0.00,
    id_statut INT NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    id_utilisateur INT REFERENCES utilisateur(id) ON DELETE SET NULL,
    date_transfert TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    motif TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_transfert_caisses_distinctes CHECK (id_caisse_source <> id_caisse_destination)
);

-- -----------------------------------------------------------------------------
-- 4. ACHATS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS commande_achat (
    id SERIAL PRIMARY KEY,
    numero_commande VARCHAR(50) NOT NULL UNIQUE,
    id_fournisseur INT NOT NULL REFERENCES fournisseur(id) ON DELETE RESTRICT,
    id_depot_destination INT NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    id_statut INT NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    id_utilisateur INT REFERENCES utilisateur(id) ON DELETE SET NULL,
    date_commande DATE NOT NULL DEFAULT CURRENT_DATE,
    date_livraison_prevue DATE,
    montant_ht NUMERIC(15, 2) DEFAULT 0.00,
    montant_tva NUMERIC(15, 2) DEFAULT 0.00,
    montant_ttc NUMERIC(15, 2) DEFAULT 0.00,
    remarques TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS commande_achat_ligne (
    id SERIAL PRIMARY KEY,
    id_commande_achat INT NOT NULL REFERENCES commande_achat(id) ON DELETE CASCADE,
    id_article INT NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
    quantite_commandee NUMERIC(15, 3) NOT NULL CHECK (quantite_commandee > 0),
    quantite_recue NUMERIC(15, 3) DEFAULT 0.000 CHECK (quantite_recue >= 0),
    prix_unitaire_ht NUMERIC(15, 2) NOT NULL CHECK (prix_unitaire_ht >= 0),
    taux_remise NUMERIC(5, 2) DEFAULT 0.00,
    taux_tva NUMERIC(5, 2) DEFAULT 20.00,
    montant_ht NUMERIC(15, 2) NOT NULL,
    montant_ttc NUMERIC(15, 2) NOT NULL
);

CREATE TABLE IF NOT EXISTS reception_achat (
    id SERIAL PRIMARY KEY,
    numero_reception VARCHAR(50) NOT NULL UNIQUE,
    id_commande_achat INT REFERENCES commande_achat(id) ON DELETE SET NULL,
    id_fournisseur INT NOT NULL REFERENCES fournisseur(id) ON DELETE RESTRICT,
    id_depot INT NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    id_statut INT NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    date_reception TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    numero_bl_fournisseur VARCHAR(100),
    remarques TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reception_achat_ligne (
    id SERIAL PRIMARY KEY,
    id_reception INT NOT NULL REFERENCES reception_achat(id) ON DELETE CASCADE,
    id_commande_achat_ligne INT REFERENCES commande_achat_ligne(id) ON DELETE SET NULL,
    id_article INT NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
    quantite_recue NUMERIC(15, 3) NOT NULL CHECK (quantite_recue > 0)
);

CREATE TABLE IF NOT EXISTS facture_fournisseur (
    id SERIAL PRIMARY KEY,
    numero_facture VARCHAR(50) NOT NULL UNIQUE,
    id_fournisseur INT NOT NULL REFERENCES fournisseur(id) ON DELETE RESTRICT,
    id_commande_achat INT REFERENCES commande_achat(id) ON DELETE SET NULL,
    id_statut INT NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    date_facture DATE NOT NULL DEFAULT CURRENT_DATE,
    date_echeance DATE,
    montant_ht NUMERIC(15, 2) DEFAULT 0.00,
    montant_tva NUMERIC(15, 2) DEFAULT 0.00,
    montant_ttc NUMERIC(15, 2) DEFAULT 0.00,
    montant_paye NUMERIC(15, 2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS paiement_achat (
    id SERIAL PRIMARY KEY,
    numero_paiement VARCHAR(50) NOT NULL UNIQUE,
    id_facture_fournisseur INT NOT NULL REFERENCES facture_fournisseur(id) ON DELETE RESTRICT,
    id_caisse INT NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
    id_mode_paiement INT NOT NULL REFERENCES mode_paiement(id) ON DELETE RESTRICT,
    id_utilisateur INT REFERENCES utilisateur(id) ON DELETE SET NULL,
    date_paiement DATE NOT NULL DEFAULT CURRENT_DATE,
    montant NUMERIC(15, 2) NOT NULL CHECK (montant > 0),
    reference_transaction VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 5. VENTES
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS devis_vente (
    id SERIAL PRIMARY KEY,
    numero_devis VARCHAR(50) NOT NULL UNIQUE,
    id_client INT NOT NULL REFERENCES client(id) ON DELETE RESTRICT,
    id_statut INT NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    date_devis DATE NOT NULL DEFAULT CURRENT_DATE,
    date_validite DATE,
    montant_ht NUMERIC(15, 2) DEFAULT 0.00,
    montant_tva NUMERIC(15, 2) DEFAULT 0.00,
    montant_ttc NUMERIC(15, 2) DEFAULT 0.00,
    conditions TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS devis_vente_ligne (
    id SERIAL PRIMARY KEY,
    id_devis INT NOT NULL REFERENCES devis_vente(id) ON DELETE CASCADE,
    id_article INT NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
    quantite NUMERIC(15, 3) NOT NULL CHECK (quantite > 0),
    prix_unitaire_ht NUMERIC(15, 2) NOT NULL,
    taux_remise NUMERIC(5, 2) DEFAULT 0.00,
    montant_ht NUMERIC(15, 2) NOT NULL,
    montant_ttc NUMERIC(15, 2) NOT NULL
);

CREATE TABLE IF NOT EXISTS commande_vente (
    id SERIAL PRIMARY KEY,
    numero_commande VARCHAR(50) NOT NULL UNIQUE,
    id_client INT NOT NULL REFERENCES client(id) ON DELETE RESTRICT,
    id_devis INT REFERENCES devis_vente(id) ON DELETE SET NULL,
    id_depot_source INT NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    id_statut INT NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    id_utilisateur INT REFERENCES utilisateur(id) ON DELETE SET NULL,
    date_commande DATE NOT NULL DEFAULT CURRENT_DATE,
    date_livraison_souhaitee DATE,
    montant_ht NUMERIC(15, 2) DEFAULT 0.00,
    montant_tva NUMERIC(15, 2) DEFAULT 0.00,
    montant_ttc NUMERIC(15, 2) DEFAULT 0.00,
    marge_brute NUMERIC(15, 2) DEFAULT 0.00,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS commande_vente_ligne (
    id SERIAL PRIMARY KEY,
    id_commande_vente INT NOT NULL REFERENCES commande_vente(id) ON DELETE CASCADE,
    id_article INT NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
    quantite NUMERIC(15, 3) NOT NULL CHECK (quantite > 0),
    prix_unitaire NUMERIC(15, 2) NOT NULL,
    taux_remise NUMERIC(5, 2) DEFAULT 0.00,
    montant_ht NUMERIC(15, 2) NOT NULL,
    montant_ttc NUMERIC(15, 2) NOT NULL
);

CREATE TABLE IF NOT EXISTS livraison_vente (
    id SERIAL PRIMARY KEY,
    numero_livraison VARCHAR(50) NOT NULL UNIQUE,
    id_commande_vente INT REFERENCES commande_vente(id) ON DELETE SET NULL,
    id_client INT NOT NULL REFERENCES client(id) ON DELETE RESTRICT,
    id_depot INT NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    id_statut INT NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    date_livraison TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    adresse_livraison TEXT,
    remarques TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS livraison_vente_ligne (
    id SERIAL PRIMARY KEY,
    id_livraison INT NOT NULL REFERENCES livraison_vente(id) ON DELETE CASCADE,
    id_commande_vente_ligne INT REFERENCES commande_vente_ligne(id) ON DELETE SET NULL,
    id_article INT NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
    quantite_livree NUMERIC(15, 3) NOT NULL CHECK (quantite_livree > 0)
);

CREATE TABLE IF NOT EXISTS facture_client (
    id SERIAL PRIMARY KEY,
    numero_facture VARCHAR(50) NOT NULL UNIQUE,
    id_client INT NOT NULL REFERENCES client(id) ON DELETE RESTRICT,
    id_commande_vente INT REFERENCES commande_vente(id) ON DELETE SET NULL,
    id_livraison INT REFERENCES livraison_vente(id) ON DELETE SET NULL,
    id_statut INT NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    date_facture DATE NOT NULL DEFAULT CURRENT_DATE,
    date_echeance DATE,
    montant_ht NUMERIC(15, 2) DEFAULT 0.00,
    montant_tva NUMERIC(15, 2) DEFAULT 0.00,
    montant_ttc NUMERIC(15, 2) DEFAULT 0.00,
    montant_paye NUMERIC(15, 2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS paiement_vente (
    id SERIAL PRIMARY KEY,
    numero_paiement VARCHAR(50) NOT NULL UNIQUE,
    id_facture_client INT NOT NULL REFERENCES facture_client(id) ON DELETE RESTRICT,
    id_caisse INT NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
    id_mode_paiement INT NOT NULL REFERENCES mode_paiement(id) ON DELETE RESTRICT,
    id_utilisateur INT REFERENCES utilisateur(id) ON DELETE SET NULL,
    date_paiement DATE NOT NULL DEFAULT CURRENT_DATE,
    montant NUMERIC(15, 2) NOT NULL CHECK (montant > 0),
    reference_transaction VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 6. GESTION DES STOCKS & MOUVEMENTS
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS stock_depot (
    id SERIAL PRIMARY KEY,
    id_depot INT NOT NULL REFERENCES depot(id) ON DELETE CASCADE,
    id_article INT NOT NULL REFERENCES article(id) ON DELETE CASCADE,
    quantite_reelle NUMERIC(15, 3) NOT NULL DEFAULT 0.000,
    quantite_reservee NUMERIC(15, 3) NOT NULL DEFAULT 0.000,
    quantite_en_commande NUMERIC(15, 3) NOT NULL DEFAULT 0.000,
    derniere_mise_a_jour TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_depot_article UNIQUE (id_depot, id_article)
);

CREATE TABLE IF NOT EXISTS mouvement_stock (
    id SERIAL PRIMARY KEY,
    id_depot INT NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    id_article INT NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
    id_type_mouvement INT NOT NULL REFERENCES type_mouvement_stock(id) ON DELETE RESTRICT,
    id_utilisateur INT REFERENCES utilisateur(id) ON DELETE SET NULL,
    quantite NUMERIC(15, 3) NOT NULL CHECK (quantite > 0),
    prix_unitaire NUMERIC(15, 2) DEFAULT 0.00,
    stock_avant NUMERIC(15, 3) NOT NULL,
    stock_apres NUMERIC(15, 3) NOT NULL,
    reference_document VARCHAR(100),
    date_mouvement TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    remarque TEXT
);

-- -----------------------------------------------------------------------------
-- 7. SÉCURITÉ & PERMISSIONS POSTGREST / SUPABASE (Accès direct pour l'app)
-- -----------------------------------------------------------------------------

ALTER TABLE profil DISABLE ROW LEVEL SECURITY;
ALTER TABLE utilisateur DISABLE ROW LEVEL SECURITY;
ALTER TABLE statut DISABLE ROW LEVEL SECURITY;
ALTER TABLE mode_paiement DISABLE ROW LEVEL SECURITY;
ALTER TABLE type_caisse DISABLE ROW LEVEL SECURITY;
ALTER TABLE type_mouvement_stock DISABLE ROW LEVEL SECURITY;
ALTER TABLE type_mouvement_caisse DISABLE ROW LEVEL SECURITY;
ALTER TABLE type_client DISABLE ROW LEVEL SECURITY;
ALTER TABLE devise DISABLE ROW LEVEL SECURITY;
ALTER TABLE categorie DISABLE ROW LEVEL SECURITY;
ALTER TABLE unite_mesure DISABLE ROW LEVEL SECURITY;
ALTER TABLE depot DISABLE ROW LEVEL SECURITY;
ALTER TABLE article DISABLE ROW LEVEL SECURITY;
ALTER TABLE fournisseur DISABLE ROW LEVEL SECURITY;
ALTER TABLE client DISABLE ROW LEVEL SECURITY;
ALTER TABLE caisse DISABLE ROW LEVEL SECURITY;
ALTER TABLE journal_caisse DISABLE ROW LEVEL SECURITY;
ALTER TABLE journal_caisse_ligne DISABLE ROW LEVEL SECURITY;
ALTER TABLE mouvement_caisse DISABLE ROW LEVEL SECURITY;
ALTER TABLE transfert_caisse DISABLE ROW LEVEL SECURITY;
ALTER TABLE commande_achat DISABLE ROW LEVEL SECURITY;
ALTER TABLE commande_achat_ligne DISABLE ROW LEVEL SECURITY;
ALTER TABLE reception_achat DISABLE ROW LEVEL SECURITY;
ALTER TABLE reception_achat_ligne DISABLE ROW LEVEL SECURITY;
ALTER TABLE facture_fournisseur DISABLE ROW LEVEL SECURITY;
ALTER TABLE paiement_achat DISABLE ROW LEVEL SECURITY;
ALTER TABLE devis_vente DISABLE ROW LEVEL SECURITY;
ALTER TABLE devis_vente_ligne DISABLE ROW LEVEL SECURITY;
ALTER TABLE commande_vente DISABLE ROW LEVEL SECURITY;
ALTER TABLE commande_vente_ligne DISABLE ROW LEVEL SECURITY;
ALTER TABLE livraison_vente DISABLE ROW LEVEL SECURITY;
ALTER TABLE livraison_vente_ligne DISABLE ROW LEVEL SECURITY;
ALTER TABLE facture_client DISABLE ROW LEVEL SECURITY;
ALTER TABLE paiement_vente DISABLE ROW LEVEL SECURITY;
ALTER TABLE stock_depot DISABLE ROW LEVEL SECURITY;
ALTER TABLE mouvement_stock DISABLE ROW LEVEL SECURITY;

GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
