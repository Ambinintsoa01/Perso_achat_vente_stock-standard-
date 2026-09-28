-- =============================================================================
-- BASE DE DONNÉES : GESTION DES ACHATS, VENTES ET STOCKS
-- Compatible : PostgreSQL, MySQL / MariaDB (ajuster SERIAL -> INT AUTO_INCREMENT)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. RÉFÉRENTIELS & PARAMÉTRAGE DE BASE
-- -----------------------------------------------------------------------------

-- Catégories d'articles (avec support hiérarchique parent/enfant)
CREATE TABLE categorie (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    nom VARCHAR(150) NOT NULL,
    description TEXT,
    id_parent INT REFERENCES categorie(id) ON DELETE SET NULL,
    actif BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Unités de mesure (Pièce, Kg, Litre, Carton, etc.)
CREATE TABLE unite_mesure (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,       -- ex: U, KG, L, CRT, M
    nom VARCHAR(100) NOT NULL,              -- ex: Unité, Kilogramme, Litre
    actif BOOLEAN DEFAULT TRUE
);

-- Dépôts / Magasins de stockage
CREATE TABLE depot (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    nom VARCHAR(150) NOT NULL,
    adresse TEXT,
    telephone VARCHAR(50),
    actif BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Articles / Produits
CREATE TABLE article (
    id SERIAL PRIMARY KEY,
    reference VARCHAR(50) NOT NULL UNIQUE,
    designation VARCHAR(255) NOT NULL,
    description TEXT,
    id_categorie INT REFERENCES categorie(id) ON DELETE RESTRICT,
    id_unite INT REFERENCES unite_mesure(id) ON DELETE RESTRICT,
    prix_achat_estime NUMERIC(15, 2) DEFAULT 0.00,
    prix_vente_standard NUMERIC(15, 2) DEFAULT 0.00,
    taux_tva NUMERIC(5, 2) DEFAULT 20.00,   -- Taux TVA en % (ex: 20%)
    seuil_alerte_stock NUMERIC(15, 3) DEFAULT 0.000,
    suivi_stock BOOLEAN DEFAULT TRUE,       -- Si FALSE : prestation de service sans stock
    actif BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 2. TIERS (Fournisseurs & Clients)
-- -----------------------------------------------------------------------------

-- Fournisseurs
CREATE TABLE fournisseur (
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
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Clients
CREATE TABLE client (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    nom_complet VARCHAR(255) NOT NULL,
    type_client VARCHAR(50) DEFAULT 'PARTICULIER', -- 'PARTICULIER', 'ENTREPRISE', etc.
    telephone VARCHAR(50),
    email VARCHAR(150),
    adresse TEXT,
    ville VARCHAR(100),
    nif VARCHAR(50),
    stat VARCHAR(50),
    solde_credit_max NUMERIC(15, 2) DEFAULT 0.00,
    actif BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 3. WORKFLOW ACHAT (Fournisseur)
-- Commande (BC) -> Réception (BR, Entrée en Stock) -> Facture -> Paiement
-- -----------------------------------------------------------------------------

-- Commandes d'Achat (Bon de Commande Fournisseur)
CREATE TABLE commande_achat (
    id SERIAL PRIMARY KEY,
    numero_commande VARCHAR(50) NOT NULL UNIQUE, -- ex: BCA-2026-0001
    id_fournisseur INT NOT NULL REFERENCES fournisseur(id) ON DELETE RESTRICT,
    id_depot_destination INT NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    date_commande DATE NOT NULL DEFAULT CURRENT_DATE,
    date_livraison_prevue DATE,
    statut VARCHAR(50) NOT NULL DEFAULT 'BROUILLON', -- 'BROUILLON', 'VALIDEE', 'PARTIELLEMENT_RECUE', 'RECUE', 'ANNULEE'
    montant_ht NUMERIC(15, 2) DEFAULT 0.00,
    montant_tva NUMERIC(15, 2) DEFAULT 0.00,
    montant_ttc NUMERIC(15, 2) DEFAULT 0.00,
    remarques TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Lignes de Commande d'Achat
CREATE TABLE commande_achat_ligne (
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

-- Bons de Réception Achat (Déclencheur de l'entrée de stock)
CREATE TABLE reception_achat (
    id SERIAL PRIMARY KEY,
    numero_reception VARCHAR(50) NOT NULL UNIQUE, -- ex: BRA-2026-0001
    id_commande_achat INT REFERENCES commande_achat(id) ON DELETE SET NULL,
    id_fournisseur INT NOT NULL REFERENCES fournisseur(id) ON DELETE RESTRICT,
    id_depot INT NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    date_reception TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    numero_bon_fournisseur VARCHAR(100),         -- Réf du bon de livraison papier fournisseur
    statut VARCHAR(50) NOT NULL DEFAULT 'VALIDEE', -- 'BROUILLON', 'VALIDEE', 'ANNULEE'
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Lignes de Réception Achat
CREATE TABLE reception_achat_ligne (
    id SERIAL PRIMARY KEY,
    id_reception INT NOT NULL REFERENCES reception_achat(id) ON DELETE CASCADE,
    id_commande_achat_ligne INT REFERENCES commande_achat_ligne(id) ON DELETE SET NULL,
    id_article INT NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
    quantite_recue NUMERIC(15, 3) NOT NULL CHECK (quantite_recue > 0),
    prix_achat_unitaire_ht NUMERIC(15, 2) NOT NULL
);

-- Factures Fournisseurs (Achat)
CREATE TABLE facture_fournisseur (
    id SERIAL PRIMARY KEY,
    numero_facture VARCHAR(50) NOT NULL UNIQUE,     -- ex: FA-2026-0001 ou référence facture fournisseur
    id_fournisseur INT NOT NULL REFERENCES fournisseur(id) ON DELETE RESTRICT,
    id_commande_achat INT REFERENCES commande_achat(id) ON DELETE SET NULL,
    date_facture DATE NOT NULL DEFAULT CURRENT_DATE,
    date_echeance DATE,
    statut_facture VARCHAR(50) DEFAULT 'NON_PAYEE', -- 'NON_PAYEE', 'PARTIELLEMENT_PAYEE', 'PAYEE', 'ANNULEE'
    montant_ht NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    montant_tva NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    montant_ttc NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    montant_paye NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Paiements Fournisseurs
CREATE TABLE paiement_achat (
    id SERIAL PRIMARY KEY,
    numero_paiement VARCHAR(50) NOT NULL UNIQUE,
    id_facture_fournisseur INT NOT NULL REFERENCES facture_fournisseur(id) ON DELETE RESTRICT,
    date_paiement DATE NOT NULL DEFAULT CURRENT_DATE,
    montant NUMERIC(15, 2) NOT NULL CHECK (montant > 0),
    mode_paiement VARCHAR(50) NOT NULL, -- 'ESPECES', 'CHEQUE', 'VIREMENT', 'MOBILE_MONEY'
    reference_transaction VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 4. WORKFLOW VENTE (Client)
-- Devis -> Commande (BC) -> Livraison (BL, Sortie de Stock) -> Facture -> Règlement
-- -----------------------------------------------------------------------------

-- Devis / Proformas Vente
CREATE TABLE devis_vente (
    id SERIAL PRIMARY KEY,
    numero_devis VARCHAR(50) NOT NULL UNIQUE, -- ex: DEV-2026-0001
    id_client INT NOT NULL REFERENCES client(id) ON DELETE RESTRICT,
    date_devis DATE NOT NULL DEFAULT CURRENT_DATE,
    date_validite DATE,
    statut VARCHAR(50) DEFAULT 'EN_ATTENTE',   -- 'EN_ATTENTE', 'ACCEPTE', 'REFUSE', 'EXPIRE'
    montant_ht NUMERIC(15, 2) DEFAULT 0.00,
    montant_tva NUMERIC(15, 2) DEFAULT 0.00,
    montant_ttc NUMERIC(15, 2) DEFAULT 0.00,
    conditions TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Lignes de Devis
CREATE TABLE devis_vente_ligne (
    id SERIAL PRIMARY KEY,
    id_devis INT NOT NULL REFERENCES devis_vente(id) ON DELETE CASCADE,
    id_article INT NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
    quantite NUMERIC(15, 3) NOT NULL CHECK (quantite > 0),
    prix_unitaire_ht NUMERIC(15, 2) NOT NULL CHECK (prix_unitaire_ht >= 0),
    taux_remise NUMERIC(5, 2) DEFAULT 0.00,
    taux_tva NUMERIC(5, 2) DEFAULT 20.00,
    montant_ht NUMERIC(15, 2) NOT NULL,
    montant_ttc NUMERIC(15, 2) NOT NULL
);

-- Commandes de Vente (Bons de Commande Client)
CREATE TABLE commande_vente (
    id SERIAL PRIMARY KEY,
    numero_commande VARCHAR(50) NOT NULL UNIQUE, -- ex: BCV-2026-0001
    id_client INT NOT NULL REFERENCES client(id) ON DELETE RESTRICT,
    id_devis INT REFERENCES devis_vente(id) ON DELETE SET NULL,
    id_depot_source INT NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    date_commande DATE NOT NULL DEFAULT CURRENT_DATE,
    date_livraison_souhaitee DATE,
    statut VARCHAR(50) NOT NULL DEFAULT 'BROUILLON', -- 'BROUILLON', 'VALIDEE', 'EN_PREPARATION', 'PARTIELLEMENT_LIVREE', 'LIVREE', 'ANNULEE'
    montant_ht NUMERIC(15, 2) DEFAULT 0.00,
    montant_tva NUMERIC(15, 2) DEFAULT 0.00,
    montant_ttc NUMERIC(15, 2) DEFAULT 0.00,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Lignes de Commande de Vente
CREATE TABLE commande_vente_ligne (
    id SERIAL PRIMARY KEY,
    id_commande_vente INT NOT NULL REFERENCES commande_vente(id) ON DELETE CASCADE,
    id_article INT NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
    quantite_commandee NUMERIC(15, 3) NOT NULL CHECK (quantite_commandee > 0),
    quantite_livree NUMERIC(15, 3) DEFAULT 0.000 CHECK (quantite_livree >= 0),
    prix_unitaire_ht NUMERIC(15, 2) NOT NULL CHECK (prix_unitaire_ht >= 0),
    taux_remise NUMERIC(5, 2) DEFAULT 0.00,
    taux_tva NUMERIC(5, 2) DEFAULT 20.00,
    montant_ht NUMERIC(15, 2) NOT NULL,
    montant_ttc NUMERIC(15, 2) NOT NULL
);

-- Bons de Livraison Vente (Déclencheur de la sortie de stock)
CREATE TABLE livraison_vente (
    id SERIAL PRIMARY KEY,
    numero_livraison VARCHAR(50) NOT NULL UNIQUE, -- ex: BLV-2026-0001
    id_commande_vente INT REFERENCES commande_vente(id) ON DELETE SET NULL,
    id_client INT NOT NULL REFERENCES client(id) ON DELETE RESTRICT,
    id_depot INT NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    date_livraison TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    statut VARCHAR(50) NOT NULL DEFAULT 'VALIDEE', -- 'BROUILLON', 'VALIDEE', 'ANNULEE'
    nom_livreur VARCHAR(100),
    adresse_livraison TEXT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Lignes de Livraison Vente
CREATE TABLE livraison_vente_ligne (
    id SERIAL PRIMARY KEY,
    id_livraison INT NOT NULL REFERENCES livraison_vente(id) ON DELETE CASCADE,
    id_commande_vente_ligne INT REFERENCES commande_vente_ligne(id) ON DELETE SET NULL,
    id_article INT NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
    quantite_livree NUMERIC(15, 3) NOT NULL CHECK (quantite_livree > 0),
    prix_vente_unitaire_ht NUMERIC(15, 2) NOT NULL
);

-- Factures Clients (Vente)
CREATE TABLE facture_client (
    id SERIAL PRIMARY KEY,
    numero_facture VARCHAR(50) NOT NULL UNIQUE,    -- ex: FAC-2026-0001
    id_client INT NOT NULL REFERENCES client(id) ON DELETE RESTRICT,
    id_commande_vente INT REFERENCES commande_vente(id) ON DELETE SET NULL,
    id_livraison INT REFERENCES livraison_vente(id) ON DELETE SET NULL,
    date_facture DATE NOT NULL DEFAULT CURRENT_DATE,
    date_echeance DATE,
    statut_facture VARCHAR(50) DEFAULT 'NON_PAYEE', -- 'NON_PAYEE', 'PARTIELLEMENT_PAYEE', 'PAYEE', 'ANNULEE'
    montant_ht NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    montant_tva NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    montant_ttc NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    montant_paye NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Règlements / Paiements Clients
CREATE TABLE paiement_vente (
    id SERIAL PRIMARY KEY,
    numero_paiement VARCHAR(50) NOT NULL UNIQUE,
    id_facture_client INT NOT NULL REFERENCES facture_client(id) ON DELETE RESTRICT,
    date_paiement DATE NOT NULL DEFAULT CURRENT_DATE,
    montant NUMERIC(15, 2) NOT NULL CHECK (montant > 0),
    mode_paiement VARCHAR(50) NOT NULL, -- 'ESPECES', 'CHEQUE', 'VIREMENT', 'MOBILE_MONEY', 'CARTE'
    reference_transaction VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 5. GESTION DES STOCKS & MOUVEMENTS
-- -----------------------------------------------------------------------------

-- Situation de stock en temps réel par Dépôt et Article
CREATE TABLE stock_depot (
    id SERIAL PRIMARY KEY,
    id_depot INT NOT NULL REFERENCES depot(id) ON DELETE CASCADE,
    id_article INT NOT NULL REFERENCES article(id) ON DELETE CASCADE,
    quantite_reelle NUMERIC(15, 3) NOT NULL DEFAULT 0.000,      -- Stock physique présent
    quantite_reservee NUMERIC(15, 3) NOT NULL DEFAULT 0.000,    -- Réservé sur commandes clients validées
    quantite_en_commande NUMERIC(15, 3) NOT NULL DEFAULT 0.000, -- En commande chez fournisseur
    derniere_mise_a_jour TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_depot_article UNIQUE (id_depot, id_article)
);

-- Historique complet & Traçabilité des mouvements de stock
CREATE TABLE mouvement_stock (
    id SERIAL PRIMARY KEY,
    id_depot INT NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    id_article INT NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
    type_mouvement VARCHAR(50) NOT NULL, -- 'ENTREE_ACHAT', 'SORTIE_VENTE', 'AJUSTEMENT_POSITIF', 'AJUSTEMENT_NEGATIF', 'TRANSFERT_ENTREE', 'TRANSFERT_SORTIE', 'RETOUR_CLIENT', 'RETOUR_FOURNISSEUR'
    quantite NUMERIC(15, 3) NOT NULL,    -- Valeur absolue déplacée
    prix_unitaire NUMERIC(15, 2) DEFAULT 0.00,
    stock_avant NUMERIC(15, 3) NOT NULL,
    stock_apres NUMERIC(15, 3) NOT NULL,
    reference_document VARCHAR(100),      -- Ex: 'BRA-2026-0001', 'BLV-2026-0001', 'INV-2026-09'
    date_mouvement TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    remarque TEXT
);

-- -----------------------------------------------------------------------------
-- 6. INDEX DE PERFORMANCE
-- -----------------------------------------------------------------------------
CREATE INDEX idx_article_categorie ON article(id_categorie);
CREATE INDEX idx_article_reference ON article(reference);
CREATE INDEX idx_stock_depot_article ON stock_depot(id_depot, id_article);
CREATE INDEX idx_mvt_stock_article_depot ON mouvement_stock(id_article, id_depot);
CREATE INDEX idx_cmd_achat_fournisseur ON commande_achat(id_fournisseur);
CREATE INDEX idx_cmd_vente_client ON commande_vente(id_client);
CREATE INDEX idx_facture_fournisseur_statut ON facture_fournisseur(statut_facture);
CREATE INDEX idx_facture_client_statut ON facture_client(statut_facture);