-- =============================================================================
-- BASE DE DONNÉES : GESTION DES ACHATS, VENTES, STOCKS & TRÉSORERIE (MULTI-CAISSE)
-- Compatible : PostgreSQL (SERIAL), adaptable MySQL (INT AUTO_INCREMENT)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. TABLES DE RÉFÉRENCE & ÉTATS (LOOKUP TABLES)
-- -----------------------------------------------------------------------------

-- Table générique des statuts pour les documents (achats, ventes, factures, etc.)
CREATE TABLE statut (
    id SERIAL PRIMARY KEY,
    numero INT NOT NULL UNIQUE,     -- 1: créé, 11: validé, 21: annulé, 31: partiel, 41: terminé/soldé
    code VARCHAR(50) NOT NULL UNIQUE,
    libelle VARCHAR(100) NOT NULL,
    description TEXT
);

-- Modes de paiement (Espèces, Virement, Mvola, Orange Money, etc.)
CREATE TABLE mode_paiement (
    id SERIAL PRIMARY KEY,
    numero INT NOT NULL UNIQUE,     -- 1: ESPECES, 11: VIREMENT, 21: CHEQUE, 31: MVOLA, 41: ORANGE_MONEY, 51: AIRTEL_MONEY, 61: CARTE
    code VARCHAR(50) NOT NULL UNIQUE,
    libelle VARCHAR(100) NOT NULL,
    actif BOOLEAN DEFAULT TRUE
);

-- Types de caisse / compte de trésorerie
CREATE TABLE type_caisse (
    id SERIAL PRIMARY KEY,
    numero INT NOT NULL UNIQUE,     -- 1: CAISSE_PHYSIQUE, 11: BANQUE, 21: MOBILE_MONEY
    code VARCHAR(50) NOT NULL UNIQUE,
    libelle VARCHAR(100) NOT NULL
);

-- Types de mouvements de stock
CREATE TABLE type_mouvement_stock (
    id SERIAL PRIMARY KEY,
    numero INT NOT NULL UNIQUE,     -- 1: ENTREE_ACHAT, 11: SORTIE_VENTE, 21: AJUSTEMENT_POS, 31: AJUSTEMENT_NEG, etc.
    code VARCHAR(50) NOT NULL UNIQUE,
    libelle VARCHAR(100) NOT NULL,
    sens INT NOT NULL CHECK (sens IN (1, -1)), -- +1: Entrée, -1: Sortie
    actif BOOLEAN DEFAULT TRUE
);

-- Types de mouvements de caisse / trésorerie
CREATE TABLE type_mouvement_caisse (
    id SERIAL PRIMARY KEY,
    numero INT NOT NULL UNIQUE,     -- 1: ENCAISSEMENT_VENTE, 11: DECAISSEMENT_ACHAT, 21: TRANSFERT_DEBIT, 31: TRANSFERT_CREDIT, etc.
    code VARCHAR(50) NOT NULL UNIQUE,
    libelle VARCHAR(100) NOT NULL,
    sens INT NOT NULL CHECK (sens IN (1, -1)), -- +1: Entrée d'argent, -1: Sortie d'argent
    actif BOOLEAN DEFAULT TRUE
);

-- Types de clients
CREATE TABLE type_client (
    id SERIAL PRIMARY KEY,
    numero INT NOT NULL UNIQUE,     -- 1: PARTICULIER, 11: ENTREPRISE, 21: AUTRE
    code VARCHAR(50) NOT NULL UNIQUE,
    libelle VARCHAR(100) NOT NULL
);

-- Devises monétaires
CREATE TABLE devise (
    id SERIAL PRIMARY KEY,
    numero INT NOT NULL UNIQUE,     -- 1: MGA, 11: EUR, 21: USD
    code VARCHAR(10) NOT NULL UNIQUE,
    libelle VARCHAR(50) NOT NULL,
    symbole VARCHAR(10) DEFAULT 'Ar',
    actif BOOLEAN DEFAULT TRUE
);

-- Catégories d'articles (avec support hiérarchique)
CREATE TABLE categorie (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    nom VARCHAR(150) NOT NULL,
    description TEXT,
    id_parent INT REFERENCES categorie(id) ON DELETE SET NULL,
    actif BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Unités de mesure
CREATE TABLE unite_mesure (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,       -- U, KG, L, CRT, M
    nom VARCHAR(100) NOT NULL,
    actif BOOLEAN DEFAULT TRUE
);

-- Dépôts / Magasins physiques de stockage
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
    taux_tva NUMERIC(5, 2) DEFAULT 20.00,
    seuil_alerte_stock NUMERIC(15, 3) DEFAULT 0.000,
    suivi_stock BOOLEAN DEFAULT TRUE,
    actif BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 2. TIERS (Fournisseurs & Clients)
-- -----------------------------------------------------------------------------

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

CREATE TABLE client (
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
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 3. GESTION MULTI-CAISSE & TRÉSORERIE
-- (Banque, Caisse physique, Mvola, Orange Money...)
-- -----------------------------------------------------------------------------

-- Registre des caisses et comptes financiers
CREATE TABLE caisse (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,              -- ex: 'CAISSE-MAGASIN-01', 'BNI-MGA', 'MVOLA-PRO'
    nom VARCHAR(150) NOT NULL,                    -- ex: 'Caisse Principale', 'Compte Courant BNI', 'Compte Mvola'
    id_type_caisse INT NOT NULL REFERENCES type_caisse(id) ON DELETE RESTRICT,
    numero_compte VARCHAR(100),                    -- IBAN, RIB ou numéro mobile money
    solde_initial NUMERIC(15, 2) DEFAULT 0.00,
    solde_actuel NUMERIC(15, 2) DEFAULT 0.00,
    id_devise INT NOT NULL REFERENCES devise(id) ON DELETE RESTRICT,
    actif BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Journal des mouvements de caisse / trésorerie
CREATE TABLE mouvement_caisse (
    id SERIAL PRIMARY KEY,
    id_caisse INT NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
    id_type_mouvement INT NOT NULL REFERENCES type_mouvement_caisse(id) ON DELETE RESTRICT,
    id_mode_paiement INT NOT NULL REFERENCES mode_paiement(id) ON DELETE RESTRICT,
    montant NUMERIC(15, 2) NOT NULL CHECK (montant > 0),
    solde_avant NUMERIC(15, 2) NOT NULL,
    solde_apres NUMERIC(15, 2) NOT NULL,
    date_mouvement TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reference_piece VARCHAR(100),                  -- Réf paiement vente/achat, numéro chèque, réf transaction
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Transferts internes entre caisses (ex: Caisse physique -> Banque, ou Mvola -> Banque)
CREATE TABLE transfert_caisse (
    id SERIAL PRIMARY KEY,
    numero_transfert VARCHAR(50) NOT NULL UNIQUE,  -- ex: TRF-2026-0001
    id_caisse_source INT NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
    id_caisse_destination INT NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,
    montant NUMERIC(15, 2) NOT NULL CHECK (montant > 0),
    frais_transfert NUMERIC(15, 2) DEFAULT 0.00,   -- Frais opérateur (ex: retrait Mvola)
    id_statut INT NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    date_transfert TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    motif TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_transfert_caisses_distinctes CHECK (id_caisse_source <> id_caisse_destination)
);

-- -----------------------------------------------------------------------------
-- 4. WORKFLOW ACHAT (Fournisseur)
-- Commande (BC) -> Réception (BR, Entrée Stock) -> Facture -> Paiement (Caisse)
-- -----------------------------------------------------------------------------

-- Bons de Commande Fournisseur
CREATE TABLE commande_achat (
    id SERIAL PRIMARY KEY,
    numero_commande VARCHAR(50) NOT NULL UNIQUE,   -- ex: BCA-2026-0001
    id_fournisseur INT NOT NULL REFERENCES fournisseur(id) ON DELETE RESTRICT,
    id_depot_destination INT NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    id_statut INT NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    date_commande DATE NOT NULL DEFAULT CURRENT_DATE,
    date_livraison_prevue DATE,
    montant_ht NUMERIC(15, 2) DEFAULT 0.00,
    montant_tva NUMERIC(15, 2) DEFAULT 0.00,
    montant_ttc NUMERIC(15, 2) DEFAULT 0.00,
    remarques TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Lignes de Commande Achat
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

-- Bons de Réception Fournisseur (Entrée effective des marchandises)
CREATE TABLE reception_achat (
    id SERIAL PRIMARY KEY,
    numero_reception VARCHAR(50) NOT NULL UNIQUE,  -- ex: BRA-2026-0001
    id_commande_achat INT REFERENCES commande_achat(id) ON DELETE SET NULL,
    id_fournisseur INT NOT NULL REFERENCES fournisseur(id) ON DELETE RESTRICT,
    id_depot INT NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    id_statut INT NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    date_reception TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    numero_bon_fournisseur VARCHAR(100),
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

-- Factures Fournisseurs
CREATE TABLE facture_fournisseur (
    id SERIAL PRIMARY KEY,
    numero_facture VARCHAR(50) NOT NULL UNIQUE,
    id_fournisseur INT NOT NULL REFERENCES fournisseur(id) ON DELETE RESTRICT,
    id_commande_achat INT REFERENCES commande_achat(id) ON DELETE SET NULL,
    id_statut INT NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    date_facture DATE NOT NULL DEFAULT CURRENT_DATE,
    date_echeance DATE,
    montant_ht NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    montant_tva NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    montant_ttc NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    montant_paye NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Paiements Fournisseurs (Rattachés à une Caisse / Banque / Mvola)
CREATE TABLE paiement_achat (
    id SERIAL PRIMARY KEY,
    numero_paiement VARCHAR(50) NOT NULL UNIQUE,   -- ex: PA-2026-0001
    id_facture_fournisseur INT NOT NULL REFERENCES facture_fournisseur(id) ON DELETE RESTRICT,
    id_caisse INT NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,             -- Caisse débitée
    id_mode_paiement INT NOT NULL REFERENCES mode_paiement(id) ON DELETE RESTRICT,
    date_paiement DATE NOT NULL DEFAULT CURRENT_DATE,
    montant NUMERIC(15, 2) NOT NULL CHECK (montant > 0),
    reference_transaction VARCHAR(100),            -- ex: Référence Mvola, numéro chèque, virement
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 5. WORKFLOW VENTE (Client)
-- Devis -> Commande (BC) -> Livraison (BL, Sortie Stock) -> Facture -> Paiement (Caisse)
-- -----------------------------------------------------------------------------

-- Devis / Offres Commerciales
CREATE TABLE devis_vente (
    id SERIAL PRIMARY KEY,
    numero_devis VARCHAR(50) NOT NULL UNIQUE,      -- ex: DEV-2026-0001
    id_client INT NOT NULL REFERENCES client(id) ON DELETE RESTRICT,
    id_statut INT NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    date_devis DATE NOT NULL DEFAULT CURRENT_DATE,
    date_validite DATE,
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
    numero_commande VARCHAR(50) NOT NULL UNIQUE,   -- ex: BCV-2026-0001
    id_client INT NOT NULL REFERENCES client(id) ON DELETE RESTRICT,
    id_devis INT REFERENCES devis_vente(id) ON DELETE SET NULL,
    id_depot_source INT NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    id_statut INT NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    date_commande DATE NOT NULL DEFAULT CURRENT_DATE,
    date_livraison_souhaitee DATE,
    montant_ht NUMERIC(15, 2) DEFAULT 0.00,
    montant_tva NUMERIC(15, 2) DEFAULT 0.00,
    montant_ttc NUMERIC(15, 2) DEFAULT 0.00,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Lignes de Commande Vente
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

-- Bons de Livraison Vente (Sortie effective du stock)
CREATE TABLE livraison_vente (
    id SERIAL PRIMARY KEY,
    numero_livraison VARCHAR(50) NOT NULL UNIQUE,  -- ex: BLV-2026-0001
    id_commande_vente INT REFERENCES commande_vente(id) ON DELETE SET NULL,
    id_client INT NOT NULL REFERENCES client(id) ON DELETE RESTRICT,
    id_depot INT NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    id_statut INT NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    date_livraison TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
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
    id_statut INT NOT NULL REFERENCES statut(id) ON DELETE RESTRICT,
    date_facture DATE NOT NULL DEFAULT CURRENT_DATE,
    date_echeance DATE,
    montant_ht NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    montant_tva NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    montant_ttc NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    montant_paye NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Règlements Clients (Rattachés à une Caisse / Banque / Mvola)
CREATE TABLE paiement_vente (
    id SERIAL PRIMARY KEY,
    numero_paiement VARCHAR(50) NOT NULL UNIQUE,   -- ex: PV-2026-0001
    id_facture_client INT NOT NULL REFERENCES facture_client(id) ON DELETE RESTRICT,
    id_caisse INT NOT NULL REFERENCES caisse(id) ON DELETE RESTRICT,             -- Caisse créditée
    id_mode_paiement INT NOT NULL REFERENCES mode_paiement(id) ON DELETE RESTRICT,
    date_paiement DATE NOT NULL DEFAULT CURRENT_DATE,
    montant NUMERIC(15, 2) NOT NULL CHECK (montant > 0),
    reference_transaction VARCHAR(100),            -- ex: Référence Mvola / bordereau remise chèque
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 6. GESTION DES STOCKS & MOUVEMENTS
-- -----------------------------------------------------------------------------

-- Situation de stock en temps réel par Dépôt et Article
CREATE TABLE stock_depot (
    id SERIAL PRIMARY KEY,
    id_depot INT NOT NULL REFERENCES depot(id) ON DELETE CASCADE,
    id_article INT NOT NULL REFERENCES article(id) ON DELETE CASCADE,
    quantite_reelle NUMERIC(15, 3) NOT NULL DEFAULT 0.000,      -- Stock physique présent
    quantite_reservee NUMERIC(15, 3) NOT NULL DEFAULT 0.000,    -- Réservé sur commandes clients validées
    quantite_en_commande NUMERIC(15, 3) NOT NULL DEFAULT 0.000, -- En cours d'achat chez fournisseur
    derniere_mise_a_jour TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_depot_article UNIQUE (id_depot, id_article)
);

-- Historique complet & Traçabilité des mouvements de stock
CREATE TABLE mouvement_stock (
    id SERIAL PRIMARY KEY,
    id_depot INT NOT NULL REFERENCES depot(id) ON DELETE RESTRICT,
    id_article INT NOT NULL REFERENCES article(id) ON DELETE RESTRICT,
    id_type_mouvement INT NOT NULL REFERENCES type_mouvement_stock(id) ON DELETE RESTRICT,
    quantite NUMERIC(15, 3) NOT NULL CHECK (quantite > 0),       -- Quantité déplacée
    prix_unitaire NUMERIC(15, 2) DEFAULT 0.00,
    stock_avant NUMERIC(15, 3) NOT NULL,
    stock_apres NUMERIC(15, 3) NOT NULL,
    reference_document VARCHAR(100),                              -- Ex: 'BRA-2026-0001', 'BLV-2026-0001'
    date_mouvement TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    remarque TEXT
);

-- -----------------------------------------------------------------------------
-- 7. INDEX DE PERFORMANCE & CLÉS ÉTRANGÈRES
-- -----------------------------------------------------------------------------

-- Articles & Dépôts
CREATE INDEX idx_article_categorie ON article(id_categorie);
CREATE INDEX idx_article_unite ON article(id_unite);
CREATE INDEX idx_article_reference ON article(reference);
CREATE INDEX idx_stock_depot_article ON stock_depot(id_depot, id_article);

-- Tiers
CREATE INDEX idx_client_type_client ON client(id_type_client);

-- Multi-Caisse & Trésorerie
CREATE INDEX idx_caisse_type_caisse ON caisse(id_type_caisse);
CREATE INDEX idx_caisse_devise ON caisse(id_devise);
CREATE INDEX idx_mvt_caisse_caisse ON mouvement_caisse(id_caisse);
CREATE INDEX idx_mvt_caisse_type ON mouvement_caisse(id_type_mouvement);
CREATE INDEX idx_mvt_caisse_mode ON mouvement_caisse(id_mode_paiement);
CREATE INDEX idx_transfert_caisse_src ON transfert_caisse(id_caisse_source);
CREATE INDEX idx_transfert_caisse_dest ON transfert_caisse(id_caisse_destination);
CREATE INDEX idx_transfert_caisse_statut ON transfert_caisse(id_statut);

-- Workflow Achat
CREATE INDEX idx_cmd_achat_fournisseur ON commande_achat(id_fournisseur);
CREATE INDEX idx_cmd_achat_depot ON commande_achat(id_depot_destination);
CREATE INDEX idx_cmd_achat_statut ON commande_achat(id_statut);
CREATE INDEX idx_cmd_achat_ligne_cmd ON commande_achat_ligne(id_commande_achat);
CREATE INDEX idx_cmd_achat_ligne_article ON commande_achat_ligne(id_article);

CREATE INDEX idx_reception_achat_fournisseur ON reception_achat(id_fournisseur);
CREATE INDEX idx_reception_achat_cmd ON reception_achat(id_commande_achat);
CREATE INDEX idx_reception_achat_depot ON reception_achat(id_depot);
CREATE INDEX idx_reception_achat_statut ON reception_achat(id_statut);
CREATE INDEX idx_reception_achat_ligne_rec ON reception_achat_ligne(id_reception);
CREATE INDEX idx_reception_achat_ligne_art ON reception_achat_ligne(id_article);

CREATE INDEX idx_facture_fournisseur_fournisseur ON facture_fournisseur(id_fournisseur);
CREATE INDEX idx_facture_fournisseur_cmd ON facture_fournisseur(id_commande_achat);
CREATE INDEX idx_facture_fournisseur_statut ON facture_fournisseur(id_statut);
CREATE INDEX idx_paiement_achat_facture ON paiement_achat(id_facture_fournisseur);
CREATE INDEX idx_paiement_achat_caisse ON paiement_achat(id_caisse);
CREATE INDEX idx_paiement_achat_mode ON paiement_achat(id_mode_paiement);

-- Workflow Vente
CREATE INDEX idx_devis_vente_client ON devis_vente(id_client);
CREATE INDEX idx_devis_vente_statut ON devis_vente(id_statut);
CREATE INDEX idx_devis_vente_ligne_dev ON devis_vente_ligne(id_devis);
CREATE INDEX idx_devis_vente_ligne_art ON devis_vente_ligne(id_article);

CREATE INDEX idx_cmd_vente_client ON commande_vente(id_client);
CREATE INDEX idx_cmd_vente_devis ON commande_vente(id_devis);
CREATE INDEX idx_cmd_vente_depot ON commande_vente(id_depot_source);
CREATE INDEX idx_cmd_vente_statut ON commande_vente(id_statut);
CREATE INDEX idx_cmd_vente_ligne_cmd ON commande_vente_ligne(id_commande_vente);
CREATE INDEX idx_cmd_vente_ligne_article ON commande_vente_ligne(id_article);

CREATE INDEX idx_livraison_vente_client ON livraison_vente(id_client);
CREATE INDEX idx_livraison_vente_cmd ON livraison_vente(id_commande_vente);
CREATE INDEX idx_livraison_vente_depot ON livraison_vente(id_depot);
CREATE INDEX idx_livraison_vente_statut ON livraison_vente(id_statut);
CREATE INDEX idx_livraison_vente_ligne_liv ON livraison_vente_ligne(id_livraison);
CREATE INDEX idx_livraison_vente_ligne_art ON livraison_vente_ligne(id_article);

CREATE INDEX idx_facture_client_client ON facture_client(id_client);
CREATE INDEX idx_facture_client_cmd ON facture_client(id_commande_vente);
CREATE INDEX idx_facture_client_liv ON facture_client(id_livraison);
CREATE INDEX idx_facture_client_statut ON facture_client(id_statut);
CREATE INDEX idx_paiement_vente_facture ON paiement_vente(id_facture_client);
CREATE INDEX idx_paiement_vente_caisse ON paiement_vente(id_caisse);
CREATE INDEX idx_paiement_vente_mode ON paiement_vente(id_mode_paiement);

-- Stocks
CREATE INDEX idx_mvt_stock_article_depot ON mouvement_stock(id_article, id_depot);
CREATE INDEX idx_mvt_stock_type ON mouvement_stock(id_type_mouvement);

-- -----------------------------------------------------------------------------
-- 8. DONNÉES INITIALES (SEEDING DE BASE)
-- -----------------------------------------------------------------------------

-- 8.1 Statuts standardisés (selon votre convention de numérotation)
INSERT INTO statut (numero, code, libelle, description) VALUES
(1,  'CREE',      'Créé / Brouillon',       'Document initié mais non encore validé'),
(11, 'VALIDE',    'Validé',                 'Document confirmé et actif'),
(21, 'ANNULE',    'Annulé',                 'Document annulé sans effet opérationnel'),
(31, 'PARTIEL',   'Partiellement traité',   'Partiellement reçu, livré ou payé'),
(41, 'SOLDE',     'Soldé / Clôturé',        'Totalement traité, livré ou soldé');

-- 8.2 Modes de paiement usuels (avec numéros)
INSERT INTO mode_paiement (numero, code, libelle) VALUES
(1,  'ESPECES',      'Espèces / Cash'),
(11, 'VIREMENT',     'Virement Bancaire'),
(21, 'CHEQUE',       'Chèque'),
(31, 'MVOLA',        'Mvola'),
(41, 'ORANGE_MONEY', 'Orange Money'),
(51, 'AIRTEL_MONEY', 'Airtel Money'),
(61, 'CARTE',        'Carte Bancaire');

-- 8.3 Types de caisses / comptes financiers
INSERT INTO type_caisse (numero, code, libelle) VALUES
(1,  'CAISSE_PHYSIQUE', 'Caisse Physique / Espèces'),
(11, 'BANQUE',          'Compte Bancaire'),
(21, 'MOBILE_MONEY',    'Compte Mobile Money');

-- 8.4 Types de clients
INSERT INTO type_client (numero, code, libelle) VALUES
(1,  'PARTICULIER', 'Particulier'),
(11, 'ENTREPRISE',  'Entreprise / Société'),
(21, 'AUTRE',       'Autre / Institutionnel');

-- 8.5 Devises
INSERT INTO devise (numero, code, libelle, symbole) VALUES
(1,  'MGA', 'Ariary',    'Ar'),
(11, 'EUR', 'Euro',      '€'),
(21, 'USD', 'Dollar US', '$');

-- 8.6 Types de mouvements de stock (+1: Entrée, -1: Sortie)
INSERT INTO type_mouvement_stock (numero, code, libelle, sens) VALUES
(1,  'ENTREE_ACHAT',         'Entrée Réception Achat',        1),
(11, 'SORTIE_VENTE',         'Sortie Livraison Vente',       -1),
(21, 'AJUSTEMENT_POSITIF',   'Ajustement Inventaire Positif', 1),
(31, 'AJUSTEMENT_NEGATIF',   'Ajustement Inventaire Négatif',-1),
(41, 'TRANSFERT_ENTREE',     'Transfert Dépôt Entrant',        1),
(51, 'TRANSFERT_SORTIE',     'Transfert Dépôt Sortant',       -1),
(61, 'RETOUR_CLIENT',        'Retour Produit Client',          1),
(71, 'RETOUR_FOURNISSEUR',   'Retour Produit Fournisseur',    -1);

-- 8.7 Types de mouvements de caisse (+1: Entrée d'argent, -1: Sortie d'argent)
INSERT INTO type_mouvement_caisse (numero, code, libelle, sens) VALUES
(1,  'ENCAISSEMENT_VENTE',       'Encaissement Règlement Client',        1),
(11, 'DECAISSEMENT_ACHAT',       'Décaissement Règlement Fournisseur',  -1),
(21, 'TRANSFERT_INTERNE_DEBIT',  'Transfert Interne (Sortie caisse)',    -1),
(31, 'TRANSFERT_INTERNE_CREDIT', 'Transfert Interne (Entrée caisse)',     1),
(41, 'DEPENSE_DIVERSE',          'Dépense Diverse / Charge',             -1),
(51, 'APPORT_FONDS',             'Apport de Fonds / Alimentation',        1);