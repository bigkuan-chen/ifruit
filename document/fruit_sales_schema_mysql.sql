/*
  水果銷售與庫存管理系統 Schema
  Target: MySQL 8.0.16+
  Charset: utf8mb4
  核心原則：
  1. 水果基本資料包含水果種類與品種。
  2. 商品檔定義產地、等級、大小、銷售單位與包裝，不保存售價。
  3. 每日正式售價保存於 product_price_daily，AI/規則建議保存於 price_recommendation。
  4. inventory_ledger 以「門市 + 商品 + 批號」保存唯一庫存餘額，商品總庫存由 View 加總。
  5. 銷售不因庫存不足而失敗；FIFO 正常批號不足時，差額記入系統 NEGATIVE 批號。
  6. sales_posting 唯一對應 sales_detail，控制未過帳、過帳中、完成與失敗，避免重複沖庫存。
*/

CREATE DATABASE IF NOT EXISTS ifruit_sales_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE fruit_sales_db;

SET NAMES utf8mb4;
SET time_zone = '+08:00';

/* =========================================================
   01. 門市與系統使用者
   ========================================================= */

CREATE TABLE store (
    store_id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '門市主鍵識別碼',
    store_code          VARCHAR(20) NOT NULL COMMENT '門市代碼，供單據編碼及系統介接使用',
    store_name          VARCHAR(100) NOT NULL COMMENT '門市名稱',
    phone               VARCHAR(30) NULL COMMENT '門市聯絡電話',
    address             VARCHAR(255) NULL COMMENT '門市地址',
    tax_id              VARCHAR(20) NULL COMMENT '統一編號',
    timezone_name       VARCHAR(50) NOT NULL DEFAULT 'Asia/Taipei' COMMENT '門市所屬時區名稱',
    is_active           TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否啟用，1為啟用，0為停用',
    created_at          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (store_id),
    UNIQUE KEY uk_store_code (store_code),
    CONSTRAINT ck_store_active CHECK (is_active IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='門市基本資料';

CREATE TABLE system_user (
    user_id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '系統使用者主鍵識別碼',
    store_id            BIGINT UNSIGNED NULL COMMENT '使用者主要所屬門市，總公司人員可為NULL',
    login_account       VARCHAR(100) NOT NULL COMMENT '系統登入帳號',
    user_name           VARCHAR(100) NOT NULL COMMENT '使用者名稱',
    email               VARCHAR(255) NULL COMMENT '使用者電子郵件',
    password_hash       VARCHAR(255) NOT NULL COMMENT '密碼雜湊值，不得保存明碼密碼',
    role_code           VARCHAR(30) NOT NULL COMMENT '角色代碼，例如ADMIN、MANAGER、CASHIER或WAREHOUSE',
    is_active           TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否啟用，1為啟用，0為停用',
    created_at          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (user_id),
    UNIQUE KEY uk_system_user_account (login_account),
    KEY idx_system_user_store (store_id),
    CONSTRAINT fk_system_user_store FOREIGN KEY (store_id) REFERENCES store (store_id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT ck_system_user_active CHECK (is_active IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='系統使用者與權限角色基本資料';

/* =========================================================
   02. 基礎主檔
   ========================================================= */

CREATE TABLE supplier (
    supplier_id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '供應商主鍵識別碼',
    supplier_code       VARCHAR(30) NOT NULL COMMENT '供應商代碼',
    supplier_name       VARCHAR(150) NOT NULL COMMENT '供應商名稱',
    tax_id              VARCHAR(20) NULL COMMENT '供應商統一編號或稅籍編號',
    contact_name        VARCHAR(100) NULL COMMENT '主要聯絡人姓名',
    phone               VARCHAR(30) NULL COMMENT '供應商聯絡電話',
    email               VARCHAR(255) NULL COMMENT '供應商電子郵件',
    address             VARCHAR(255) NULL COMMENT '供應商地址',
    payment_terms_days  SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '付款條件天數，0代表現金或立即付款',
    is_active           TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否啟用，1為啟用，0為停用',
    created_at          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (supplier_id),
    UNIQUE KEY uk_supplier_code (supplier_code),
    CONSTRAINT ck_supplier_active CHECK (is_active IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='水果供應商基本資料';

CREATE TABLE origin (
    origin_id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '產地主鍵識別碼',
    origin_code         VARCHAR(30) NOT NULL COMMENT '產地代碼(country_code+sequence)',
    country_code        VARCHAR(10) NOT NULL COMMENT '產地國家代碼',
    country_name        VARCHAR(100) NOT NULL COMMENT '產地國家或地區名稱，例如台灣、日本',
    region_name         VARCHAR(100) NOT NULL DEFAULT '' COMMENT '產地行政區或主要產區，例如青森、梨山',
    farm_name           VARCHAR(150) NOT NULL DEFAULT '' COMMENT '農場、果園或合作社名稱',
    display_name        VARCHAR(200) NOT NULL COMMENT '前台及報表使用的完整產地名稱',
    is_active           TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否啟用，1為啟用，0為停用',
    created_at          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (origin_id),
    UNIQUE KEY uk_origin_code (origin_code),
    UNIQUE KEY uk_origin_business (country_code, region_name, farm_name),
    CONSTRAINT ck_origin_active CHECK (is_active IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='水果產地基本資料';

CREATE TABLE unit (
    unit_id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '單位主鍵識別碼',
    unit_code           VARCHAR(20) NOT NULL COMMENT '單位代碼，例如KG、G、PCS、BOX或BAG',
    unit_name           VARCHAR(50) NOT NULL COMMENT '單位中文名稱，例如公斤、顆、盒或袋',
    unit_category       VARCHAR(20) NOT NULL COMMENT '單位分類，WEIGHT為重量、COUNT為數量、PACKAGE為包裝',
    decimal_places      TINYINT UNSIGNED NOT NULL DEFAULT 3 COMMENT '此單位允許的小數位數',
    is_active           TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否啟用，1為啟用，0為停用',
    created_at          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (unit_id),
    UNIQUE KEY uk_unit_code (unit_code),
    CONSTRAINT ck_unit_category CHECK (unit_category IN ('WEIGHT', 'COUNT', 'PACKAGE')),
    CONSTRAINT ck_unit_decimal CHECK (decimal_places BETWEEN 0 AND 6),
    CONSTRAINT ck_unit_active CHECK (is_active IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='重量、數量與包裝單位主檔';

CREATE TABLE fruit_base (
    fruit_id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '水果基本資料主鍵識別碼',
    fruit_code          VARCHAR(30) NOT NULL COMMENT '水果基本資料代碼',
    fruit_type_name     VARCHAR(100) NOT NULL COMMENT '水果種類名稱，例如蘋果、芒果、香蕉',
    variety_name        VARCHAR(100) NOT NULL DEFAULT '' COMMENT '水果品種名稱，例如富士、愛文；無品種時留空字串',
    display_name        VARCHAR(200) NOT NULL COMMENT '水果顯示名稱，例如富士蘋果或愛文芒果',
    english_name        VARCHAR(150) NULL COMMENT '水果英文名稱',
    inventory_unit_id   BIGINT UNSIGNED NOT NULL COMMENT '此水果主要庫存管理單位，例如公斤或顆',
    storage_method      VARCHAR(30) NOT NULL DEFAULT 'ROOM_TEMPERATURE' COMMENT '預設保存方式，例如ROOM_TEMPERATURE、REFRIGERATED或FROZEN',
    description         TEXT NULL COMMENT '水果特性、保存注意事項或其他說明',
    is_active           TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否啟用，1為啟用，0為停用',
    created_at          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (fruit_id),
    UNIQUE KEY uk_fruit_code (fruit_code),
    UNIQUE KEY uk_fruit_type_variety (fruit_type_name, variety_name),
    KEY idx_fruit_inventory_unit (inventory_unit_id),
    CONSTRAINT fk_fruit_inventory_unit FOREIGN KEY (inventory_unit_id) REFERENCES unit (unit_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_fruit_storage CHECK (storage_method IN ('ROOM_TEMPERATURE', 'REFRIGERATED', 'FROZEN', 'CONTROLLED')),
    CONSTRAINT ck_fruit_active CHECK (is_active IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='水果基本資料，直接包含水果種類與品種';

CREATE TABLE fruit_grade (
    grade_id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '水果等級主鍵識別碼',
    grade_code          VARCHAR(30) NOT NULL COMMENT '等級代碼，例如PREMIUM、A、B或UNGRADED',
    grade_name          VARCHAR(50) NOT NULL COMMENT '等級名稱，例如特級、A級、B級或未分級',
    sort_order          SMALLINT NOT NULL DEFAULT 0 COMMENT '畫面顯示及報表排序順序，數字小者優先',
    description         VARCHAR(255) NULL COMMENT '等級判定標準與說明',
    is_active           TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否啟用，1為啟用，0為停用',
    created_at          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (grade_id),
    UNIQUE KEY uk_grade_code (grade_code),
    CONSTRAINT ck_grade_active CHECK (is_active IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='水果品質等級主檔';

CREATE TABLE fruit_size (
    size_id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '水果大小規格主鍵識別碼',
    size_code           VARCHAR(30) NOT NULL COMMENT '大小規格代碼，例如XL、L、M、S或UNSIZED',
    size_name           VARCHAR(50) NOT NULL COMMENT '大小規格名稱，例如特大果、大果、中果、小果或未分級',
    min_weight_g        DECIMAL(12,3) NULL COMMENT '單顆最小重量克數，未以重量定義時可為NULL',
    max_weight_g        DECIMAL(12,3) NULL COMMENT '單顆最大重量克數，未以重量定義時可為NULL',
    sort_order          SMALLINT NOT NULL DEFAULT 0 COMMENT '畫面顯示及報表排序順序，數字小者優先',
    description         VARCHAR(255) NULL COMMENT '大小規格判定標準與說明',
    is_active           TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否啟用，1為啟用，0為停用',
    created_at          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (size_id),
    UNIQUE KEY uk_size_code (size_code),
    CONSTRAINT ck_size_weight CHECK (min_weight_g IS NULL OR max_weight_g IS NULL OR min_weight_g <= max_weight_g),
    CONSTRAINT ck_size_active CHECK (is_active IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='水果大小或果徑規格主檔';

/* =========================================================
   03. 商品主檔
   ========================================================= */

CREATE TABLE product (
    product_id                     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '商品主鍵識別碼',
    product_code                   VARCHAR(50) NOT NULL COMMENT '公司內部商品代碼，為主要業務唯一鍵',
    product_name                   VARCHAR(255) NOT NULL COMMENT 'POS與報表顯示的完整商品名稱',
    fruit_id                       BIGINT UNSIGNED NOT NULL COMMENT '對應水果基本資料',
    origin_id                      BIGINT UNSIGNED NOT NULL COMMENT '商品標示產地，用於區分不同銷售商品',
    grade_id                       BIGINT UNSIGNED NULL COMMENT '商品等級，可為NULL表示不區分等級',
    size_id                        BIGINT UNSIGNED NULL COMMENT '商品大小規格，可為NULL表示不區分大小',
    sale_unit_id                   BIGINT UNSIGNED NOT NULL COMMENT 'POS銷售單位，例如公斤、顆、盒或袋',
    inventory_unit_id              BIGINT UNSIGNED NOT NULL COMMENT '過帳時實際扣除庫存所使用的單位',
    sale_mode                      VARCHAR(20) NOT NULL COMMENT '銷售計量方式，BY_WEIGHT、BY_COUNT或BY_PACKAGE',
    package_spec                   VARCHAR(100) NOT NULL DEFAULT '' COMMENT '包裝規格，例如散裝、6入盒、3公斤箱',
    conversion_mode               VARCHAR(20) NOT NULL DEFAULT 'FIXED' COMMENT '銷售單位轉庫存單位方式，FIXED為固定換算，ACTUAL為銷售時輸入實際重量或數量',
    inventory_qty_per_sale_unit    DECIMAL(18,6) NULL COMMENT '每銷售一個銷售單位，預估應扣除的庫存重量（公斤）；例如按公斤銷售填1，按顆銷售可填0.30，按盒銷售可填1.50',
    track_shelf_life               TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否需要依批號追蹤保存期限與到期日',
    is_active                      TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否啟用，1為啟用，0為停用',
    grade_key                      BIGINT UNSIGNED GENERATED ALWAYS AS (IFNULL(grade_id, 0)) STORED COMMENT '供商品規格唯一鍵使用的等級正規化值',
    size_key                       BIGINT UNSIGNED GENERATED ALWAYS AS (IFNULL(size_id, 0)) STORED COMMENT '供商品規格唯一鍵使用的大小正規化值',
    conversion_key                 DECIMAL(18,6) GENERATED ALWAYS AS (IFNULL(inventory_qty_per_sale_unit, 0)) STORED COMMENT '供商品規格唯一鍵使用的換算數量正規化值',
    created_at                     DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at                     DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (product_id),
    UNIQUE KEY uk_product_code (product_code),
    UNIQUE KEY uk_product_business (fruit_id, origin_id, grade_key, size_key, sale_unit_id, package_spec, conversion_key),
    KEY idx_product_origin (origin_id),
    KEY idx_product_grade (grade_id),
    KEY idx_product_size (size_id),
    KEY idx_product_sale_unit (sale_unit_id),
    KEY idx_product_inventory_unit (inventory_unit_id),
    CONSTRAINT fk_product_fruit FOREIGN KEY (fruit_id) REFERENCES fruit_master (fruit_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_product_origin FOREIGN KEY (origin_id) REFERENCES origin (origin_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_product_grade FOREIGN KEY (grade_id) REFERENCES fruit_grade (grade_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_product_size FOREIGN KEY (size_id) REFERENCES fruit_size (size_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_product_sale_unit FOREIGN KEY (sale_unit_id) REFERENCES unit_master (unit_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_product_inventory_unit FOREIGN KEY (inventory_unit_id) REFERENCES unit_master (unit_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_product_sale_mode CHECK (sale_mode IN ('BY_WEIGHT', 'BY_COUNT', 'BY_PACKAGE')),
    CONSTRAINT ck_product_conversion_mode CHECK (conversion_mode IN ('FIXED', 'ACTUAL')),
    CONSTRAINT ck_product_conversion_qty CHECK ((conversion_mode = 'ACTUAL') OR (inventory_qty_per_sale_unit IS NOT NULL AND inventory_qty_per_sale_unit > 0)),
    CONSTRAINT ck_product_negative CHECK (allow_negative_inventory IN (0, 1)),
    CONSTRAINT ck_product_shelf_life CHECK (track_shelf_life IN (0, 1)),
    CONSTRAINT ck_product_active CHECK (is_active IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='可販售商品主檔，不保存售價，負責區分產地、等級、大小、單位與包裝';

CREATE TABLE product_identifier (
    identifier_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '商品識別碼資料主鍵',
    product_id          BIGINT UNSIGNED NOT NULL COMMENT '對應商品主鍵',
    identifier_type     VARCHAR(30) NOT NULL COMMENT '識別碼類型，例如BARCODE、PLU、GTIN或SUPPLIER_CODE',
    identifier_value    VARCHAR(100) NOT NULL COMMENT '條碼、PLU、GTIN或其他外部識別碼內容',
    is_primary          TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否為該類型主要識別碼，1為是，0為否',
    is_active           TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否啟用，1為啟用，0為停用',
    created_at          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at          DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (identifier_id),
    UNIQUE KEY uk_product_identifier_value (identifier_type, identifier_value),
    KEY idx_product_identifier_product (product_id),
    CONSTRAINT fk_product_identifier_product FOREIGN KEY (product_id) REFERENCES product (product_id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT ck_product_identifier_primary CHECK (is_primary IN (0, 1)),
    CONSTRAINT ck_product_identifier_active CHECK (is_active IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='商品條碼、PLU及外部識別碼';

/* =========================================================
   04. 保存期限規則
   ========================================================= */

CREATE TABLE shelf_life_rule (
    shelf_life_rule_id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '保存期限規則主鍵識別碼',
    product_id                  BIGINT UNSIGNED NOT NULL COMMENT '規則適用的商品',
    store_id                    BIGINT UNSIGNED NULL COMMENT '規則限定門市；NULL代表所有門市共用',
    storage_method              VARCHAR(30) NOT NULL COMMENT '保存方式，例如ROOM_TEMPERATURE、REFRIGERATED或FROZEN',
    shelf_life_days             SMALLINT UNSIGNED NOT NULL COMMENT '自進貨日或指定基準日起計算的預估可保存天數',
    warning_days_before_expiry  SMALLINT UNSIGNED NOT NULL DEFAULT 3 COMMENT '到期前多少天開始顯示庫存警示',
    markdown_days_before_expiry SMALLINT UNSIGNED NOT NULL DEFAULT 2 COMMENT '到期前多少天開始建議降價',
    stop_sale_days_before_expiry SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '到期前多少天建議停止銷售，0代表到期日停止',
    effective_from              DATE NOT NULL COMMENT '規則生效日期',
    effective_to                DATE NULL COMMENT '規則失效日期；NULL代表持續有效',
    priority_no                 SMALLINT NOT NULL DEFAULT 100 COMMENT '多筆規則同時符合時的優先順序，數字小者優先',
    is_active                   TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否啟用，1為啟用，0為停用',
    created_at                  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at                  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (shelf_life_rule_id),
    KEY idx_shelf_life_lookup (product_id, store_id, effective_from, effective_to, is_active),
    CONSTRAINT fk_shelf_life_product FOREIGN KEY (product_id) REFERENCES product (product_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_shelf_life_store FOREIGN KEY (store_id) REFERENCES store (store_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_shelf_life_dates CHECK (effective_to IS NULL OR effective_to >= effective_from),
    CONSTRAINT ck_shelf_life_active CHECK (is_active IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='依商品、門市與保存方式定義預估保存期限及警示規則';

/* =========================================================
   05. 售價政策、AI建議與每日正式售價
   ========================================================= */

CREATE TABLE pricing_policy (
    pricing_policy_id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '定價政策主鍵識別碼',
    policy_code                VARCHAR(30) NOT NULL COMMENT '定價政策代碼',
    policy_name                VARCHAR(100) NOT NULL COMMENT '定價政策名稱',
    store_id                   BIGINT UNSIGNED NULL COMMENT '指定門市；NULL代表共用政策',
    fruit_id                   BIGINT UNSIGNED NULL COMMENT '指定水果基本資料；NULL代表不限水果',
    product_id                 BIGINT UNSIGNED NULL COMMENT '指定商品；設定後優先於水果層級政策',
    target_margin_rate         DECIMAL(7,4) NOT NULL COMMENT '目標毛利率，例如0.3000代表30%',
    minimum_margin_rate        DECIMAL(7,4) NOT NULL COMMENT '最低容許毛利率，AI或規則不得低於此值，除非人工核准',
    maximum_markdown_rate      DECIMAL(7,4) NOT NULL DEFAULT 0.5000 COMMENT '相對基準售價最大降價比率，例如0.5000代表最多降50%',
    target_stock_cover_days    DECIMAL(8,2) NOT NULL DEFAULT 3.00 COMMENT '希望現有庫存可供銷售的目標天數',
    expected_waste_rate        DECIMAL(7,4) NOT NULL DEFAULT 0.0500 COMMENT '定價成本計算時預估的耗損率',
    price_rounding_unit        DECIMAL(10,2) NOT NULL DEFAULT 1.00 COMMENT '售價尾數調整單位，例如1、5或10元',
    require_manual_approval    TINYINT(1) NOT NULL DEFAULT 1 COMMENT '建議售價是否必須人工核准後才可發布',
    algorithm_version          VARCHAR(50) NOT NULL DEFAULT 'RULE_V1' COMMENT '定價規則或AI模型版本',
    rule_parameters            JSON NULL COMMENT '其他定價規則參數，例如期限折扣、庫存壓力及需求係數',
    effective_from             DATE NOT NULL COMMENT '定價政策生效日期',
    effective_to               DATE NULL COMMENT '定價政策失效日期；NULL代表持續有效',
    is_active                  TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否啟用，1為啟用，0為停用',
    created_at                 DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at                 DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (pricing_policy_id),
    UNIQUE KEY uk_pricing_policy_code (policy_code),
    KEY idx_pricing_policy_lookup (store_id, fruit_id, product_id, effective_from, effective_to, is_active),
    CONSTRAINT fk_pricing_policy_store FOREIGN KEY (store_id) REFERENCES store (store_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_pricing_policy_fruit FOREIGN KEY (fruit_id) REFERENCES fruit_master (fruit_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_pricing_policy_product FOREIGN KEY (product_id) REFERENCES product (product_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_pricing_target_margin CHECK (target_margin_rate > -1 AND target_margin_rate < 1),
    CONSTRAINT ck_pricing_min_margin CHECK (minimum_margin_rate > -1 AND minimum_margin_rate < 1),
    CONSTRAINT ck_pricing_markdown CHECK (maximum_markdown_rate >= 0 AND maximum_markdown_rate <= 1),
    CONSTRAINT ck_pricing_waste CHECK (expected_waste_rate >= 0 AND expected_waste_rate < 1),
    CONSTRAINT ck_pricing_rounding CHECK (price_rounding_unit > 0),
    CONSTRAINT ck_pricing_dates CHECK (effective_to IS NULL OR effective_to >= effective_from),
    CONSTRAINT ck_pricing_approval CHECK (require_manual_approval IN (0, 1)),
    CONSTRAINT ck_pricing_active CHECK (is_active IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='水果每日售價計算所使用的毛利、耗損、庫存與AI政策';

CREATE TABLE price_generation_run (
    price_generation_run_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '每日價格產生批次主鍵識別碼',
    store_id                  BIGINT UNSIGNED NOT NULL COMMENT '價格產生所屬門市',
    price_date                DATE NOT NULL COMMENT '本批次要產生售價的營業日期',
    run_no                    SMALLINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '同一門市同一天的執行次數，重跑時遞增',
    generation_mode           VARCHAR(20) NOT NULL COMMENT '價格產生模式，RULE、AI或HYBRID',
    run_status                VARCHAR(20) NOT NULL DEFAULT 'PENDING' COMMENT '執行狀態，PENDING、PROCESSING、COMPLETED或FAILED',
    model_version             VARCHAR(100) NULL COMMENT '本次使用的AI模型或規則版本',
    input_snapshot            JSON NULL COMMENT '本次定價使用的銷量、成本、庫存、效期與外部資料摘要',
    started_at                DATETIME(3) NULL COMMENT '價格產生開始時間',
    completed_at              DATETIME(3) NULL COMMENT '價格產生完成時間',
    error_message             TEXT NULL COMMENT '執行失敗時的錯誤訊息',
    created_by                BIGINT UNSIGNED NULL COMMENT '建立或手動執行此批次的系統使用者',
    created_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (price_generation_run_id),
    UNIQUE KEY uk_price_run (store_id, price_date, run_no),
    KEY idx_price_run_status (run_status, price_date),
    CONSTRAINT fk_price_run_store FOREIGN KEY (store_id) REFERENCES store (store_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_price_run_user FOREIGN KEY (created_by) REFERENCES system_user (user_id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT ck_price_run_mode CHECK (generation_mode IN ('RULE', 'AI', 'HYBRID')),
    CONSTRAINT ck_price_run_status CHECK (run_status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'CANCELLED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='每日售價產生工作的執行控制與輸入快照';

CREATE TABLE price_recommendation (
    price_recommendation_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '售價建議主鍵識別碼',
    price_generation_run_id   BIGINT UNSIGNED NOT NULL COMMENT '所屬每日價格產生批次',
    pricing_policy_id         BIGINT UNSIGNED NULL COMMENT '本次建議採用的定價政策',
    product_id                BIGINT UNSIGNED NOT NULL COMMENT '建議售價對應商品',
    cost_basis                DECIMAL(18,4) NOT NULL COMMENT '計算建議售價使用的單位成本，含進價、分攤成本及耗損影響',
    current_price             DECIMAL(18,2) NULL COMMENT '產生建議時商品目前正式售價',
    predicted_sales_qty       DECIMAL(18,3) NULL COMMENT 'AI或規則預測的當日庫存單位銷量',
    current_stock_qty         DECIMAL(18,3) NOT NULL DEFAULT 0 COMMENT '產生建議時商品總庫存，包含負庫存',
    earliest_expiry_date      DATE NULL COMMENT '產生建議時最早正常批號到期日',
    remaining_shelf_life_days SMALLINT NULL COMMENT '產生建議時距最早到期日的剩餘天數',
    expected_waste_qty        DECIMAL(18,3) NOT NULL DEFAULT 0 COMMENT '預估在到期前無法售出的數量',
    minimum_allowed_price     DECIMAL(18,2) NULL COMMENT '依最低毛利或政策計算的最低容許售價',
    maximum_allowed_price     DECIMAL(18,2) NULL COMMENT '依政策或市場限制計算的最高容許售價',
    recommended_price         DECIMAL(18,2) NOT NULL COMMENT '規則或AI產生的建議售價',
    confidence_score          DECIMAL(7,4) NULL COMMENT 'AI建議信心分數，範圍0至1',
    recommendation_reason     VARCHAR(1000) NULL COMMENT '建議售價原因，例如成本上升、庫存偏高或即將到期',
    input_features            JSON NULL COMMENT '模型使用的完整輸入特徵，供稽核與重新訓練',
    model_response            JSON NULL COMMENT 'AI模型原始回應或結構化輸出',
    decision_status           VARCHAR(20) NOT NULL DEFAULT 'PENDING' COMMENT '人工決策狀態，PENDING、ACCEPTED、MODIFIED或REJECTED',
    decided_price             DECIMAL(18,2) NULL COMMENT '人工接受或修改後決定的售價',
    decided_by                BIGINT UNSIGNED NULL COMMENT '核准、修改或拒絕建議的使用者',
    decided_at                DATETIME(3) NULL COMMENT '人工決策時間',
    created_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    PRIMARY KEY (price_recommendation_id),
    UNIQUE KEY uk_price_recommendation_run_product (price_generation_run_id, product_id),
    KEY idx_price_recommendation_product (product_id, created_at),
    CONSTRAINT fk_price_rec_run FOREIGN KEY (price_generation_run_id) REFERENCES price_generation_run (price_generation_run_id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_price_rec_policy FOREIGN KEY (pricing_policy_id) REFERENCES pricing_policy (pricing_policy_id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_price_rec_product FOREIGN KEY (product_id) REFERENCES product (product_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_price_rec_user FOREIGN KEY (decided_by) REFERENCES system_user (user_id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT ck_price_rec_cost CHECK (cost_basis >= 0),
    CONSTRAINT ck_price_rec_price CHECK (recommended_price >= 0),
    CONSTRAINT ck_price_rec_confidence CHECK (confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 1)),
    CONSTRAINT ck_price_rec_decision CHECK (decision_status IN ('PENDING', 'ACCEPTED', 'MODIFIED', 'REJECTED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='規則或AI產生的每日商品售價建議及人工決策結果';

CREATE TABLE product_price_daily (
    product_price_daily_id    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '每日正式售價主鍵識別碼',
    store_id                  BIGINT UNSIGNED NOT NULL COMMENT '售價所屬門市',
    product_id                BIGINT UNSIGNED NOT NULL COMMENT '售價所屬商品',
    price_date                DATE NOT NULL COMMENT '售價適用的營業日期',
    sale_price                DECIMAL(18,2) NOT NULL COMMENT 'POS當日使用的正式銷售單價',
    cost_basis                DECIMAL(18,4) NULL COMMENT '核准售價時所參考的單位成本',
    price_source              VARCHAR(20) NOT NULL COMMENT '價格來源，MANUAL、RULE、AI或HYBRID',
    price_recommendation_id   BIGINT UNSIGNED NULL COMMENT '若採用AI或規則建議，記錄對應售價建議',
    price_status              VARCHAR(20) NOT NULL DEFAULT 'DRAFT' COMMENT '價格狀態，DRAFT、APPROVED、PUBLISHED或CANCELLED',
    approved_by               BIGINT UNSIGNED NULL COMMENT '核准正式售價的使用者',
    approved_at               DATETIME(3) NULL COMMENT '正式售價核准時間',
    published_at              DATETIME(3) NULL COMMENT '正式售價發布至POS時間',
    created_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (product_price_daily_id),
    UNIQUE KEY uk_product_price_daily (store_id, product_id, price_date),
    KEY idx_product_price_date (price_date, price_status),
    KEY idx_product_price_recommendation (price_recommendation_id),
    CONSTRAINT fk_product_price_store FOREIGN KEY (store_id) REFERENCES store (store_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_product_price_product FOREIGN KEY (product_id) REFERENCES product (product_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_product_price_rec FOREIGN KEY (price_recommendation_id) REFERENCES price_recommendation (price_recommendation_id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_product_price_user FOREIGN KEY (approved_by) REFERENCES system_user (user_id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT ck_product_price_nonnegative CHECK (sale_price >= 0),
    CONSTRAINT ck_product_price_source CHECK (price_source IN ('MANUAL', 'RULE', 'AI', 'HYBRID')),
    CONSTRAINT ck_product_price_status CHECK (price_status IN ('DRAFT', 'APPROVED', 'PUBLISHED', 'CANCELLED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='每個門市、商品及日期唯一一筆的正式售價';

/* =========================================================
   06. 採購入庫
   ========================================================= */

CREATE TABLE purchase_receipt_master (
    purchase_receipt_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '進貨驗收單主鍵識別碼',
    store_id                  BIGINT UNSIGNED NOT NULL COMMENT '本批貨入庫門市',
    supplier_id               BIGINT UNSIGNED NOT NULL COMMENT '本批貨供應商',
    receipt_no                VARCHAR(50) NOT NULL COMMENT '進貨驗收單號',
    receipt_date              DATE NOT NULL COMMENT '實際進貨或驗收日期',
    supplier_document_no      VARCHAR(100) NULL COMMENT '供應商送貨單號、發票號碼或外部文件編號',
    currency_code             CHAR(3) NOT NULL DEFAULT 'TWD' COMMENT '交易幣別，使用ISO 4217三碼，例如TWD',
    receipt_status            VARCHAR(20) NOT NULL DEFAULT 'DRAFT' COMMENT '驗收單狀態，DRAFT、CONFIRMED、PARTIALLY_POSTED、POSTED或CANCELLED',
    total_amount              DECIMAL(18,2) NOT NULL DEFAULT 0 COMMENT '進貨驗收單總金額',
    remarks                   VARCHAR(1000) NULL COMMENT '進貨驗收備註',
    created_by                BIGINT UNSIGNED NULL COMMENT '建立進貨驗收單的使用者',
    created_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (purchase_receipt_id),
    UNIQUE KEY uk_purchase_receipt_no (store_id, receipt_no),
    KEY idx_purchase_receipt_date (store_id, receipt_date),
    KEY idx_purchase_receipt_supplier (supplier_id, receipt_date),
    CONSTRAINT fk_purchase_receipt_master_store FOREIGN KEY (store_id) REFERENCES store (store_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_purchase_receipt_master_supplier FOREIGN KEY (supplier_id) REFERENCES supplier (supplier_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_purchase_receipt_master_user FOREIGN KEY (created_by) REFERENCES system_user (user_id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT ck_purchase_receipt_master_status CHECK (receipt_status IN ('DRAFT', 'CONFIRMED', 'PARTIALLY_POSTED', 'POSTED', 'CANCELLED')),
    CONSTRAINT ck_purchase_receipt_master_amount CHECK (total_amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='水果進貨驗收單主檔';

CREATE TABLE purchase_receipt_item (
    purchase_receipt_item_id   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '進貨驗收明細主鍵識別碼',
    purchase_receipt_id        BIGINT UNSIGNED NOT NULL COMMENT '所屬進貨驗收單主鍵',
    item_no                    SMALLINT UNSIGNED NOT NULL COMMENT '進貨驗收單行號',
    product_id                 BIGINT UNSIGNED NOT NULL COMMENT '進貨商品',
    lot_no                     VARCHAR(80) NOT NULL COMMENT '進貨批號；供應商無批號時由系統依日期與流水號產生',
    purchase_qty               DECIMAL(18,3) NOT NULL COMMENT '供應商單據上的進貨數量',
    purchase_unit_id           BIGINT UNSIGNED NOT NULL COMMENT '供應商單據上的進貨單位',
    inventory_qty              DECIMAL(18,3) NOT NULL COMMENT '換算為商品庫存單位後的入庫數量',
    purchase_unit_cost         DECIMAL(18,4) NOT NULL COMMENT '每一供應商進貨單位的未稅或約定進價',
    additional_cost            DECIMAL(18,4) NOT NULL DEFAULT 0 COMMENT '此明細分攤的運費、包材、人工或其他附加成本',
    line_total_cost            DECIMAL(18,4) GENERATED ALWAYS AS ((purchase_qty * purchase_unit_cost) + additional_cost) STORED COMMENT '此明細總成本，由進貨數量乘進價再加附加成本產生',
    inventory_unit_cost        DECIMAL(18,4) NULL COMMENT '換算至每一庫存單位的實際成本，可於過帳時計算並保存',
    actual_origin_id           BIGINT UNSIGNED NULL COMMENT '本批實際產地；可用來核對商品主檔標示產地',
    harvest_date               DATE NULL COMMENT '採收日期，供應商未提供時可為NULL',
    packing_date               DATE NULL COMMENT '包裝日期，散裝或未知時可為NULL',
    expiry_date                DATE NULL COMMENT '本批實際或預估到期日；未知時由保存期限規則計算',
    remarks                    VARCHAR(500) NULL COMMENT '本批品質、成熟度或驗收備註',
    item_status                VARCHAR(20) NOT NULL DEFAULT 'PENDING' COMMENT '過帳狀態，PENDING、PROCESSING、POSTED、FAILED或CANCELLED',
    posted_at                  DATETIME(3) NULL COMMENT '入庫成功時間',
    error_message              TEXT NULL COMMENT '入庫失敗原因',
    created_by                 BIGINT UNSIGNED NULL COMMENT '建立進貨驗收單的使用者',
    created_at                 DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at                 DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (purchase_receipt_item_id),
    UNIQUE KEY uk_purchase_receipt_item (purchase_receipt_id, item_no),
    KEY idx_purchase_receipt_item_product (product_id, lot_no),
    KEY idx_purchase_detail_origin (actual_origin_id),
    CONSTRAINT fk_purchase_detail_header FOREIGN KEY (purchase_receipt_id) REFERENCES purchase_receipt_header (purchase_receipt_id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_purchase_detail_product FOREIGN KEY (product_id) REFERENCES product (product_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_purchase_detail_unit FOREIGN KEY (purchase_unit_id) REFERENCES unit_master (unit_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_purchase_detail_origin FOREIGN KEY (actual_origin_id) REFERENCES origin (origin_id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT ck_purchase_detail_qty CHECK (purchase_qty > 0 AND inventory_qty > 0),
    CONSTRAINT fk_purchase_detail_user FOREIGN KEY (created_by) REFERENCES system_user (user_id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT ck_purchase_detail_cost CHECK (purchase_unit_cost >= 0 AND additional_cost >= 0),
    CONSTRAINT ck_purchase_detail_dates CHECK (expiry_date IS NULL OR harvest_date IS NULL OR expiry_date >= harvest_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='水果進貨驗收明細，包含商品、批號、數量、成本及效期';

/* =========================================================
   07. 商品批號庫存帳：唯一庫存餘額來源
   ========================================================= */

CREATE TABLE stock_lot (
    stock_lot_id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '商品批號庫存帳主鍵識別碼',
    stock_ym                  VARCHAR(6) NOT NULL COMMENT '庫存年月，格式為YYYYMM',
    store_id                  BIGINT UNSIGNED NOT NULL COMMENT '庫存所屬門市',
    product_id                BIGINT UNSIGNED NOT NULL COMMENT '庫存所屬商品',
    lot_no                    VARCHAR(80) NOT NULL COMMENT '庫存批號；負庫存使用系統固定批號NEGATIVE',
    lot_type                  VARCHAR(20) NOT NULL DEFAULT 'NORMAL' COMMENT '批號類型，NORMAL為正常進貨批號、NEGATIVE為系統負庫存批號、ADJUSTMENT為調整批號',
    supplier_id               BIGINT UNSIGNED NULL COMMENT '正常批號的供應商；系統負庫存批號可為NULL',
    first_receipt_detail_id   BIGINT UNSIGNED NULL COMMENT '首次建立此批號的進貨驗收明細',
    received_date             DATE NOT NULL COMMENT '批號首次入庫日期；FIFO依此日期排序',
    harvest_date              DATE NULL COMMENT '本批採收日期',
    expiry_date               DATE NULL COMMENT '本批實際或預估到期日',
    warning_date              DATE NULL COMMENT '本批開始顯示即期警示的日期',
    begin_in_qty              DECIMAL(18,3) NOT NULL DEFAULT 0 COMMENT '月初此批號累計入庫及回補數量',
    begin_out_qty             DECIMAL(18,3) NOT NULL DEFAULT 0 COMMENT '月初此批號累計銷售、耗損及其他出庫數量',
    begin_balance_qty         DECIMAL(18,3) NOT NULL DEFAULT 0 COMMENT '月初此批號目前庫存餘額；NEGATIVE批號可為負值',
    end_in_qty                DECIMAL(18,3) NOT NULL DEFAULT 0 COMMENT '月底此批號累計入庫及回補數量',
    end_out_qty             DECIMAL(18,3) NOT NULL DEFAULT 0 COMMENT '月底此批號累計銷售、耗損及其他出庫數量',
    end_balance_qty           DECIMAL(18,3) NOT NULL DEFAULT 0 COMMENT '月底此批號目前庫存餘額；NEGATIVE批號可為負值',
    inventory_unit_cost       DECIMAL(18,4) NULL COMMENT '每一庫存單位成本；負庫存尚未回補時可為NULL',
    balance_value             DECIMAL(18,4) GENERATED ALWAYS AS (balance_qty * IFNULL(inventory_unit_cost, 0)) STORED COMMENT '目前批號庫存帳面價值',
    lot_status                VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' COMMENT '批號狀態，ACTIVE、DEPLETED、EXPIRED或CLOSED',
    version_no                BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '樂觀鎖版本號，每次更新庫存時遞增',
    created_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (stock_lot_id),
    UNIQUE KEY uk_stock_lot (stock_ym,store_id, product_id, lot_no),
    KEY idx_stock_lot_fifo (store_id, product_id, lot_type, lot_status, received_date, inventory_ledger_id),
    KEY idx_stock_lot_expiry (store_id, expiry_date, lot_status),
    KEY idx_stock_lot_supplier (supplier_id),
    CONSTRAINT fk_stock_lot_store FOREIGN KEY (store_id) REFERENCES store (store_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_stock_lot_product FOREIGN KEY (product_id) REFERENCES product (product_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_inventory_supplier FOREIGN KEY (supplier_id) REFERENCES supplier (supplier_id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_inventory_first_receipt FOREIGN KEY (first_receipt_detail_id) REFERENCES purchase_receipt_detail (purchase_receipt_detail_id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT ck_inventory_lot_type CHECK (lot_type IN ('NORMAL', 'NEGATIVE', 'ADJUSTMENT')),
    CONSTRAINT ck_inventory_lot_status CHECK (lot_status IN ('ACTIVE', 'DEPLETED', 'EXPIRED', 'CLOSED')),
    CONSTRAINT ck_inventory_sign CHECK ((lot_type = 'NEGATIVE' AND balance_qty <= 0) OR (lot_type <> 'NEGATIVE' AND balance_qty >= 0)),
    CONSTRAINT ck_inventory_totals CHECK (total_in_qty >= 0 AND total_out_qty >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='商品批號庫存帳，商品總庫存由本表批號餘額加總，不另存重複總庫存表';

CREATE TABLE stock_lot_detail (
    stock_lot_detail_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '庫存異動交易主鍵識別碼',
    stock_lot_id              BIGINT UNSIGNED NOT NULL COMMENT '實際異動的商品批號庫存帳',
    item_no                   VARCHAR(20) NOT NULL COMMENT '項次編號，通常為進貨驗收單或銷售單的項次',
    store_id                  BIGINT UNSIGNED NOT NULL COMMENT '庫存異動所屬門市',
    product_id                BIGINT UNSIGNED NOT NULL COMMENT '庫存異動所屬商品',
    transaction_type          VARCHAR(30) NOT NULL COMMENT '異動類型，例如PURCHASE、SALE、RETURN、WASTE、ADJUSTMENT或NEGATIVE_SETTLEMENT',
    quantity_change           DECIMAL(18,3) NOT NULL COMMENT '庫存異動數量，入庫為正數，出庫為負數',
    unit_cost                 DECIMAL(18,4) NULL COMMENT '異動當時每一庫存單位成本，未知時可為NULL',
    cost_amount               DECIMAL(18,4) GENERATED ALWAYS AS (quantity_change * IFNULL(unit_cost, 0)) STORED COMMENT '本筆庫存異動成本金額，出庫通常為負值',
    before_balance_qty        DECIMAL(18,3) NOT NULL COMMENT '異動前此批號庫存餘額',
    after_balance_qty         DECIMAL(18,3) NOT NULL COMMENT '異動後此批號庫存餘額',
    business_date             DATE NOT NULL COMMENT '異動所屬營業日期',
    transaction_at            DATETIME(3) NOT NULL COMMENT '實際執行庫存異動的時間',
    reference_type            VARCHAR(30) NOT NULL COMMENT '來源資料類型，例如PURCHASE_POSTING、SALES_POSTING或ADJUSTMENT',
    reference_id              BIGINT UNSIGNED NOT NULL COMMENT '來源主檔或過帳資料識別碼',
    reference_line_id         BIGINT UNSIGNED NULL COMMENT '來源明細識別碼，無明細時可為NULL',
    created_by                BIGINT UNSIGNED NULL COMMENT '執行異動的使用者或系統帳號',
    created_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    PRIMARY KEY (stock_lot_detail_id),
    UNIQUE KEY uk_stock_lot_detail_item (stock_lot_id,item_no),
    KEY idx_stock_lot_detail_ledger (stock_lot_id, transaction_at),
    KEY idx_stock_lot_detail_product_date (store_id, product_id, business_date),
    KEY idx_stock_lot_detail_reference (reference_type, reference_id),
    CONSTRAINT fk_stock_lot_detail_store FOREIGN KEY (store_id) REFERENCES store (store_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_stock_lot_detail_product FOREIGN KEY (product_id) REFERENCES product (product_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_stock_lot_detail_lot FOREIGN KEY (stock_lot_id) REFERENCES stock_lot (stock_lot_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_stock_lot_detail_user FOREIGN KEY (created_by) REFERENCES system_user (user_id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT ck_stock_lot_detail_type CHECK (transaction_type IN ('PURCHASE', 'SALE', 'SALE_RETURN', 'SUPPLIER_RETURN', 'WASTE', 'DAMAGE', 'SAMPLE', 'STOCKTAKE', 'ADJUSTMENT', 'NEGATIVE_SETTLEMENT')),
    CONSTRAINT ck_stock_lot_detail_balance CHECK (after_balance_qty = before_balance_qty + quantity_change)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='不可任意覆寫的庫存異動歷史，供查帳、成本及盤差追蹤';


--進貨過帳，控制進貨驗收單與庫存的過帳 目前整合至 purchase_receipt_item 表
CREATE TABLE purchase_posting (
    purchase_posting_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '進貨過帳控制主鍵識別碼',
    purchase_receipt_master_id BIGINT UNSIGNED NOT NULL COMMENT '待過帳或已過帳的進貨驗收明細',
    stock_lot_id       BIGINT UNSIGNED NULL COMMENT '過帳後增加的商品批號庫存帳',
    posting_status            VARCHAR(20) NOT NULL DEFAULT 'PENDING' COMMENT '過帳狀態，PENDING、PROCESSING、POSTED、FAILED或CANCELLED',
    posted_inventory_qty      DECIMAL(18,3) NOT NULL DEFAULT 0 COMMENT '已成功過帳的庫存單位數量',
    retry_count               SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '失敗後重新執行過帳的次數',
    started_at                DATETIME(3) NULL COMMENT '本次過帳開始時間',
    posted_at                 DATETIME(3) NULL COMMENT '過帳成功時間',
    error_message             TEXT NULL COMMENT '過帳失敗原因',
    lock_token                CHAR(36) NULL COMMENT '背景工作鎖定用UUID，避免多個程序同時處理',
    created_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (purchase_posting_id),
    UNIQUE KEY uk_purchase_posting_master (purchase_receipt_master_id),
    KEY idx_purchase_posting_status (posting_status, created_at),
    KEY idx_purchase_posting_ledger (stock_lot_id),
    CONSTRAINT fk_purchase_posting_master FOREIGN KEY (purchase_receipt_master_id) REFERENCES purchase_receipt_master (purchase_receipt_master_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_purchase_posting_ledger FOREIGN KEY (stock_lot_id) REFERENCES stock_lot (stock_lot_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_purchase_posting_status CHECK (posting_status IN ('PENDING', 'PROCESSING', 'POSTED', 'FAILED', 'CANCELLED')),
    CONSTRAINT ck_purchase_posting_qty CHECK (posted_inventory_qty >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='進貨明細過帳控制，避免同一進貨重複增加庫存';

/* =========================================================
   08. POS銷售與付款
   ========================================================= */

CREATE TABLE sales_master (
    sales_master_id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '銷售單主鍵識別碼',
    store_id                  BIGINT UNSIGNED NOT NULL COMMENT '銷售發生門市',
    sales_no                  VARCHAR(50) NOT NULL COMMENT 'POS銷售單號',
    business_date             DATE NOT NULL COMMENT '銷售所屬營業日期',
    sales_at                  DATETIME(3) NOT NULL COMMENT '實際結帳時間',
    sale_type                 VARCHAR(20) NOT NULL DEFAULT 'SALE' COMMENT '銷售類型，SALE為一般銷售、RETURN為退貨、VOID為作廢',
    sales_status              VARCHAR(20) NOT NULL DEFAULT 'COMPLETED' COMMENT '銷售狀態，OPEN、COMPLETED、VOIDED或REFUNDED',
    subtotal_amount           DECIMAL(18,2) NOT NULL DEFAULT 0 COMMENT '折扣前商品小計',
    discount_amount           DECIMAL(18,2) NOT NULL DEFAULT 0 COMMENT '整張銷售單折扣金額',
    total_amount              DECIMAL(18,2) NOT NULL DEFAULT 0 COMMENT '顧客實際應付或退回總金額',
    remarks                   VARCHAR(500) NULL COMMENT '銷售、退貨或作廢備註',
    cashier_user_id           BIGINT UNSIGNED NULL COMMENT '執行結帳的收銀人員',
    created_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (sales_master_id),
    UNIQUE KEY uk_sales_master_no (store_id, sales_no),
    KEY idx_sales_master_business_date (store_id, business_date, sales_status),
    KEY idx_sales_master_cashier (cashier_user_id, sales_at),
    CONSTRAINT fk_sales_master_store FOREIGN KEY (store_id) REFERENCES store (store_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_sales_master_cashier FOREIGN KEY (cashier_user_id) REFERENCES system_user (user_id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT ck_sales_type CHECK (sale_type IN ('SALE', 'RETURN', 'VOID')),
    CONSTRAINT ck_sales_status CHECK (sales_status IN ('OPEN', 'COMPLETED', 'VOIDED', 'REFUNDED')),
    CONSTRAINT ck_sales_amount CHECK (subtotal_amount >= 0 AND discount_amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='POS銷售、退貨及作廢主檔';

CREATE TABLE sales_detail (
    sales_detail_id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '銷售明細主鍵識別碼',
    sales_master_id           BIGINT UNSIGNED NOT NULL COMMENT '所屬銷售單主鍵',
    item_no                   SMALLINT UNSIGNED NOT NULL COMMENT '銷售單行號',
    product_id                BIGINT UNSIGNED NOT NULL COMMENT '銷售商品',
    product_price_daily_id    BIGINT UNSIGNED NULL COMMENT '結帳時採用的每日正式售價資料；臨時手動價格可為NULL',
    sale_qty                  DECIMAL(18,3) NOT NULL COMMENT '依銷售單位計算的銷售數量，例如2公斤、3顆或1盒',
    sale_unit_id              BIGINT UNSIGNED NOT NULL COMMENT '本筆交易實際銷售單位',
    inventory_qty             DECIMAL(18,3) NOT NULL COMMENT '過帳時應扣除的庫存單位數量，由固定換算或電子秤實際重量取得',
    unit_price                DECIMAL(18,2) NOT NULL COMMENT '本筆交易成交單價，必須保存當時價格快照',
    discount_amount           DECIMAL(18,2) NOT NULL DEFAULT 0 COMMENT '本明細折扣金額',
    amount                    DECIMAL(18,2) GENERATED ALWAYS AS ((sale_qty * unit_price) - discount_amount) STORED COMMENT '本明細成交金額',
    remarks                   VARCHAR(300) NULL COMMENT '銷售明細備註',
    created_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (sales_detail_id),
    UNIQUE KEY uk_sales_detail_line (sales_master_id, item_no),
    KEY idx_sales_detail_product (product_id),
    KEY idx_sales_detail_price (product_price_daily_id),
    CONSTRAINT fk_sales_detail_header FOREIGN KEY (sales_master_id) REFERENCES sales_master (sales_master_id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_sales_detail_product FOREIGN KEY (product_id) REFERENCES product (product_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_sales_detail_price FOREIGN KEY (product_price_daily_id) REFERENCES product_price_daily (product_price_daily_id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_sales_detail_unit FOREIGN KEY (sale_unit_id) REFERENCES unit_master (unit_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_sales_detail_qty CHECK (sale_qty > 0 AND inventory_qty > 0),
    CONSTRAINT ck_sales_detail_price CHECK (unit_price >= 0 AND discount_amount >= 0),
    CONSTRAINT ck_sales_detail_amount CHECK ((sale_qty * unit_price) >= discount_amount)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='POS銷售商品明細，保存成交價與應扣庫存數量';

CREATE TABLE sales_payment (
    sales_payment_id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '銷售付款主鍵識別碼',
    sales_master_id           BIGINT UNSIGNED NOT NULL COMMENT '所屬銷售單主鍵',
    payment_method            VARCHAR(30) NOT NULL COMMENT '付款方式，例如CASH、CREDIT_CARD、MOBILE_PAYMENT、TRANSFER或OTHER',
    payment_amount            DECIMAL(18,2) NOT NULL COMMENT '本次付款或退款金額',
    external_reference_no     VARCHAR(100) NULL COMMENT '信用卡授權碼、行動支付交易碼或轉帳參考號',
    paid_at                   DATETIME(3) NOT NULL COMMENT '付款或退款完成時間',
    created_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    PRIMARY KEY (sales_payment_id),
    KEY idx_sales_payment_master (sales_master_id),
    KEY idx_sales_payment_reference (external_reference_no),
    CONSTRAINT fk_sales_payment_master FOREIGN KEY (sales_master_id) REFERENCES sales_master (sales_master_id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT ck_sales_payment_method CHECK (payment_method IN ('CASH', 'CREDIT_CARD', 'MOBILE_PAYMENT', 'TRANSFER', 'VOUCHER', 'OTHER')),
    CONSTRAINT ck_sales_payment_amount CHECK (payment_amount <> 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='POS銷售付款與退款資料';

/* =========================================================
   09. 銷售過帳與FIFO批號沖銷
   ========================================================= */

CREATE TABLE sales_posting (
    sales_posting_id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '銷售過帳控制主鍵識別碼',
    sales_detail_id           BIGINT UNSIGNED NOT NULL COMMENT '唯一對應一筆銷售明細，防止重複過帳',
    posting_batch_no          VARCHAR(50) NULL COMMENT '每日或批次過帳工作編號，方便查詢整批執行結果',
    posting_status            VARCHAR(20) NOT NULL DEFAULT 'PENDING' COMMENT '過帳狀態，PENDING、PROCESSING、POSTED、FAILED或CANCELLED',
    expected_inventory_qty    DECIMAL(18,3) NOT NULL COMMENT '依銷售明細預計沖銷的庫存數量',
    posted_inventory_qty      DECIMAL(18,3) NOT NULL DEFAULT 0 COMMENT '已完成沖銷的庫存數量',
    has_negative_inventory    TINYINT(1) NOT NULL DEFAULT 0 COMMENT '本筆過帳是否使用系統負庫存批號',
    negative_inventory_qty    DECIMAL(18,3) NOT NULL DEFAULT 0 COMMENT '正常批號不足而轉入NEGATIVE批號的數量',
    cost_status               VARCHAR(20) NOT NULL DEFAULT 'PENDING' COMMENT '銷售成本狀態，PENDING、FINAL或ADJUSTED',
    posted_cost               DECIMAL(18,4) NOT NULL DEFAULT 0 COMMENT '依FIFO批號成本計算的已過帳銷售成本',
    retry_count               SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '失敗後重新過帳次數',
    started_at                DATETIME(3) NULL COMMENT '本次過帳開始時間',
    posted_at                 DATETIME(3) NULL COMMENT '過帳完成時間',
    error_message             TEXT NULL COMMENT '過帳失敗原因',
    lock_token                CHAR(36) NULL COMMENT '背景工作鎖定用UUID，避免同一資料被多個程序處理',
    created_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (sales_posting_id),
    UNIQUE KEY uk_sales_posting_detail (sales_detail_id),
    KEY idx_sales_posting_status (posting_status, created_at),
    KEY idx_sales_posting_batch (posting_batch_no, posting_status),
    CONSTRAINT fk_sales_posting_detail FOREIGN KEY (sales_detail_id) REFERENCES sales_detail (sales_detail_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_sales_posting_status CHECK (posting_status IN ('PENDING', 'PROCESSING', 'POSTED', 'FAILED', 'CANCELLED')),
    CONSTRAINT ck_sales_posting_cost_status CHECK (cost_status IN ('PENDING', 'FINAL', 'ADJUSTED')),
    CONSTRAINT ck_sales_posting_negative CHECK (has_negative_inventory IN (0, 1) AND negative_inventory_qty >= 0),
    CONSTRAINT ck_sales_posting_qty CHECK (expected_inventory_qty > 0 AND posted_inventory_qty >= 0),
    CONSTRAINT ck_sales_posting_cost CHECK (posted_cost >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='銷售明細過帳控制，判斷未過帳、處理中、完成或失敗並防止重複過帳';

CREATE TABLE sales_posting_lot (
    sales_posting_lot_id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '銷售批號沖銷明細主鍵識別碼',
    sales_posting_id            BIGINT UNSIGNED NOT NULL COMMENT '所屬銷售過帳控制資料',
    allocation_seq              SMALLINT UNSIGNED NOT NULL COMMENT '同一銷售明細依FIFO跨批號沖銷的順序',
    sales_master_id             BIGINT UNSIGNED NOT NULL COMMENT '實際被沖銷的商品批號庫存帳',
    lot_no                      VARCHAR(80) NOT NULL COMMENT '過帳當時批號快照，避免日後查帳依賴主檔顯示',
    allocation_type             VARCHAR(20) NOT NULL COMMENT '沖銷類型，FIFO_NORMAL為正常FIFO批號、NEGATIVE為負庫存、RETURN為退貨回補',
    allocated_qty               DECIMAL(18,3) NOT NULL COMMENT '分攤至此批號的庫存數量，保存為正數',
    unit_cost                   DECIMAL(18,4) NULL COMMENT '此批號每一庫存單位成本；負庫存未回補前可為NULL',
    allocated_cost              DECIMAL(18,4) GENERATED ALWAYS AS (allocated_qty * IFNULL(unit_cost, 0)) STORED COMMENT '此批號分攤的銷售成本',
    cost_status                 VARCHAR(20) NOT NULL DEFAULT 'PENDING' COMMENT '成本狀態，PENDING表示負庫存待回補成本，FINAL表示已確定，ADJUSTED表示曾調整',
    created_at                  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at                  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (sales_posting_lot_id),
    UNIQUE KEY uk_sales_lot_seq (sales_posting_id, allocation_seq),
    KEY idx_sales_lot_sales (sales_master_id),
    CONSTRAINT fk_sales_lot_posting FOREIGN KEY (sales_posting_id) REFERENCES sales_posting (sales_posting_id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_sales_lot_sales FOREIGN KEY (sales_master_id) REFERENCES sales_master (sales_master_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_sales_lot_type CHECK (allocation_type IN ('FIFO_NORMAL', 'NEGATIVE', 'RETURN')),
    CONSTRAINT ck_sales_allocation_qty CHECK (allocated_qty > 0),
    CONSTRAINT ck_sales_allocation_cost_status CHECK (cost_status IN ('PENDING', 'FINAL', 'ADJUSTED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='記錄每筆銷售依FIFO實際扣除哪些批號，以及不足時轉入負庫存的數量';

-- 定時任務將負庫存成本回填至原負庫存銷售,  目前應該不用，期未再將負庫存調整為0庫存
CREATE TABLE negative_stock_settlement (
    negative_stock_settlement_id      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '負庫存成本回補主鍵識別碼',
    sales_posting_lot_id             BIGINT UNSIGNED NOT NULL COMMENT '原先使用NEGATIVE批號且成本待定的銷售沖銷明細',
    receipt_stock_lot_master_id      BIGINT UNSIGNED NOT NULL COMMENT '後續進貨用來補回負庫存及確認成本的正常批號庫存帳',
    settled_qty                      DECIMAL(18,3) NOT NULL COMMENT '本次由後續進貨回補的負庫存數量',
    settlement_unit_cost             DECIMAL(18,4) NOT NULL COMMENT '後續進貨正常批號的實際庫存單位成本',
    settlement_cost                  DECIMAL(18,4) GENERATED ALWAYS AS (settled_qty * settlement_unit_cost) STORED COMMENT '本次回補後應補列的銷售成本',
    settled_at                       DATETIME(3) NOT NULL COMMENT '負庫存回補與成本確認時間',
    created_at                       DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    PRIMARY KEY (negative_inventory_settlement_id),
    KEY idx_negative_settlement_allocation (sales_posting_allocation_id),
    KEY idx_negative_settlement_receipt_lot (receipt_stock_lot_master_id),
    CONSTRAINT fk_negative_settlement_allocation FOREIGN KEY (sales_posting_allocation_id) REFERENCES sales_posting_allocation (sales_posting_allocation_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_negative_settlement_ledger FOREIGN KEY (receipt_stock_lot_master_id) REFERENCES stock_lot_master (stock_lot_master_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_negative_settlement_qty CHECK (settled_qty > 0),
    CONSTRAINT ck_negative_settlement_cost CHECK (settlement_unit_cost >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='後續進貨先沖負庫存時，將實際成本回填至原負庫存銷售';

/* =========================================================
   10. 損耗、盤點與庫存調整
   ========================================================= */

CREATE TABLE stock_adj (
    stock_adj_id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '庫存調整單主鍵識別碼',
    store_id                  BIGINT UNSIGNED NOT NULL COMMENT '庫存調整所屬門市',
    stock_adj_no              VARCHAR(20) NOT NULL COMMENT '庫存調整單號',
    stock_adj_date            DATE NOT NULL COMMENT '庫存調整所屬營業日期',
    stock_adj_type            VARCHAR(30) NOT NULL COMMENT '調整類型，STOCKTAKE、WASTE、DAMAGE、SAMPLE、CORRECTION或OTHER',
    stock_adj_status          VARCHAR(20) NOT NULL DEFAULT 'DRAFT' COMMENT '調整單狀態，DRAFT、APPROVED、POSTED或CANCELLED',
    reason                    VARCHAR(1000) NULL COMMENT '盤差、腐壞、碰傷、試吃或其他調整原因',
    created_by                BIGINT UNSIGNED NULL COMMENT '建立庫存調整單的使用者',
    approved_by               BIGINT UNSIGNED NULL COMMENT '核准庫存調整單的使用者',
    approved_at               DATETIME(3) NULL COMMENT '核准時間',
    posted_at                 DATETIME(3) NULL COMMENT '完成庫存過帳時間',
    created_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at                DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (stock_adj_id),
    UNIQUE KEY uk_stock_adj_no (store_id, adjustment_no),
    KEY idx_stock_adj_date (store_id, adjustment_date, adjustment_status),
    CONSTRAINT fk_stock_adj_store FOREIGN KEY (store_id) REFERENCES store (store_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_stock_adj_creator FOREIGN KEY (created_by) REFERENCES system_user (user_id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT fk_stock_adj_approver FOREIGN KEY (approved_by) REFERENCES system_user (user_id) ON UPDATE RESTRICT ON DELETE SET NULL,
    CONSTRAINT ck_adjustment_type CHECK (adjustment_type IN ('STOCKTAKE', 'WASTE', 'DAMAGE', 'SAMPLE', 'CORRECTION', 'OTHER')),
    CONSTRAINT ck_adjustment_status CHECK (adjustment_status IN ('DRAFT', 'APPROVED', 'POSTED', 'CANCELLED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='水果盤點、腐壞、碰傷、試吃及其他庫存調整主檔';

CREATE TABLE stock_adj_detail (
    stock_adj_detail_id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '庫存調整明細主鍵識別碼',
    stock_adj_id                   BIGINT UNSIGNED NOT NULL COMMENT '所屬庫存調整單主鍵',
    line_no                        SMALLINT UNSIGNED NOT NULL COMMENT '庫存調整單行號',
    product_id                     BIGINT UNSIGNED NOT NULL COMMENT '調整商品',
    inventory_ledger_id            BIGINT UNSIGNED NOT NULL COMMENT '實際調整的商品批號庫存帳',
    quantity_change                DECIMAL(18,3) NOT NULL COMMENT '調整數量，增加為正數，耗損或盤虧為負數',
    unit_cost                      DECIMAL(18,4) NULL COMMENT '本次調整使用的庫存單位成本',
    reason_code                    VARCHAR(30) NOT NULL COMMENT '原因代碼，例如SPOILAGE、SHRINKAGE、WEIGHING、DAMAGE、SAMPLE或COUNT_ERROR',
    remarks                       VARCHAR(500) NULL COMMENT '此明細補充說明',
    created_at                    DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '資料建立時間',
    updated_at                    DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '資料最後更新時間',
    PRIMARY KEY (stock_adj_detail_id),
    UNIQUE KEY uk_stock_adj_detail_line (stock_adj_id, line_no),
    KEY idx_stock_adj_detail_ledger (inventory_ledger_id),
    KEY idx_stock_adj_detail_product (product_id),
    CONSTRAINT fk_stock_adj_detail_header FOREIGN KEY (stock_adj_id) REFERENCES stock_adj (stock_adj_id) ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT fk_stock_adj_detail_product FOREIGN KEY (product_id) REFERENCES product (product_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_adjustment_detail_ledger FOREIGN KEY (inventory_ledger_id) REFERENCES inventory_ledger (inventory_ledger_id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_adjustment_detail_qty CHECK (quantity_change <> 0),
    CONSTRAINT ck_adjustment_detail_reason CHECK (reason_code IN ('SPOILAGE', 'SHRINKAGE', 'WEIGHING', 'DAMAGE', 'SAMPLE', 'COUNT_ERROR', 'OTHER'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='水果盤點、耗損與庫存調整明細';

/* =========================================================
   11. 查詢View：不重複保存商品總庫存
   ========================================================= */

CREATE OR REPLACE VIEW v_product_stock_balance AS
SELECT
    il.store_id AS store_id,
    il.product_id AS product_id,
    SUM(il.balance_qty) AS total_balance_qty,
    SUM(CASE WHEN il.lot_type <> 'NEGATIVE' THEN il.balance_qty ELSE 0 END) AS normal_balance_qty,
    SUM(CASE WHEN il.lot_type = 'NEGATIVE' THEN il.balance_qty ELSE 0 END) AS negative_balance_qty,
    SUM(il.balance_value) AS total_balance_value,
    MIN(CASE WHEN il.lot_type = 'NORMAL' AND il.balance_qty > 0 THEN il.received_date ELSE NULL END) AS earliest_received_date,
    MIN(CASE WHEN il.lot_type = 'NORMAL' AND il.balance_qty > 0 THEN il.expiry_date ELSE NULL END) AS earliest_expiry_date,
    MAX(il.updated_at) AS last_inventory_updated_at
FROM stock_lot il
WHERE il.lot_status IN ('ACTIVE', 'DEPLETED', 'EXPIRED')
GROUP BY il.store_id, il.product_id;

CREATE OR REPLACE VIEW v_daily_product_sales AS
SELECT
    sh.store_id AS store_id,
    sh.business_date AS business_date,
    sd.product_id AS product_id,
    SUM(CASE WHEN sh.sale_type = 'SALE' THEN sd.sale_qty ELSE -sd.sale_qty END) AS net_sale_qty,
    SUM(CASE WHEN sh.sale_type = 'SALE' THEN sd.inventory_qty ELSE -sd.inventory_qty END) AS net_inventory_qty,
    SUM(CASE WHEN sh.sale_type = 'SALE' THEN sd.line_amount ELSE -sd.line_amount END) AS net_sales_amount,
    COUNT(DISTINCT sh.sales_id) AS transaction_count
FROM sales_master sh
JOIN sales_detail sd ON sd.sales_id = sh.sales_id
WHERE sh.sales_status IN ('COMPLETED', 'REFUNDED')
  AND sh.sale_type IN ('SALE', 'RETURN')
GROUP BY sh.store_id, sh.business_date, sd.product_id;

/* =========================================================
   12. 建議必要的初始資料範例（非必要，可自行調整後執行）
   ========================================================= */

-- INSERT INTO unit_master (unit_code, unit_name, unit_category, decimal_places) VALUES
-- ('KG', '公斤', 'WEIGHT', 3),
-- ('G', '公克', 'WEIGHT', 0),
-- ('PCS', '顆', 'COUNT', 0),
-- ('BOX', '盒', 'PACKAGE', 0),
-- ('BAG', '袋', 'PACKAGE', 0),
-- ('CASE', '箱', 'PACKAGE', 0);

-- INSERT INTO fruit_grade (grade_code, grade_name, sort_order) VALUES
-- ('PREMIUM', '特級', 10),
-- ('A', 'A級', 20),
-- ('B', 'B級', 30),
-- ('UNGRADED', '未分級', 999);

-- INSERT INTO fruit_size (size_code, size_name, sort_order) VALUES
-- ('XL', '特大果', 10),
-- ('L', '大果', 20),
-- ('M', '中果', 30),
-- ('S', '小果', 40),
-- ('UNSIZED', '未分級', 999);
