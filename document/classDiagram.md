
classDiagram
direction LR

namespace Organization {
    class store {
        <<table>>
        +BIGINT store_id PK
        +VARCHAR store_code UK
        +VARCHAR store_name
        +VARCHAR phone
        +VARCHAR address
        +VARCHAR tax_id
        +VARCHAR timezone_name
        +TINYINT is_active
    }

    class system_user {
        <<table>>
        +BIGINT user_id PK
        +BIGINT store_id FK
        +VARCHAR login_account UK
        +VARCHAR user_name
        +VARCHAR email
        +VARCHAR role_code
        +TINYINT is_active
    }

    class member_master {
        <<table>>
        +BIGINT member_id PK
        +VARCHAR member_no UK
        +VARCHAR member_name
        +VARCHAR phone
        +VARCHAR email
        +DATE birth_date
        +BIGINT registered_store_id FK
        +VARCHAR member_status
    }

    class supplier {
        <<table>>
        +BIGINT supplier_id PK
        +VARCHAR supplier_code UK
        +VARCHAR supplier_name
        +VARCHAR tax_id
        +VARCHAR contact_name
        +VARCHAR phone
        +SMALLINT payment_terms_days
        +TINYINT is_active
    }
}

namespace ProductMaster {
    class origin {
        <<table>>
        +BIGINT origin_id PK
        +VARCHAR origin_code UK
        +VARCHAR country_code
        +VARCHAR country_name
        +VARCHAR region_name
        +VARCHAR farm_name
        +VARCHAR display_name
        +TINYINT is_active
    }

    class unit {
        <<table>>
        +BIGINT unit_id PK
        +VARCHAR unit_code UK
        +VARCHAR unit_name
        +VARCHAR unit_category
        +TINYINT decimal_places
        +TINYINT is_active
    }

    class fruit_base {
        <<table>>
        +BIGINT fruit_id PK
        +VARCHAR fruit_code UK
        +VARCHAR fruit_type_name
        +VARCHAR variety_name
        +VARCHAR display_name
        +VARCHAR english_name
        +BIGINT stock_unit_id FK
        +VARCHAR storage_method
        +TINYINT is_active
    }

    class fruit_grade {
        <<table>>
        +BIGINT grade_id PK
        +VARCHAR grade_code UK
        +VARCHAR grade_name
        +SMALLINT sort_order
        +TINYINT is_active
    }

    class fruit_size {
        <<table>>
        +BIGINT size_id PK
        +VARCHAR size_code UK
        +VARCHAR size_name
        +DECIMAL min_weight_g
        +DECIMAL max_weight_g
        +SMALLINT sort_order
        +TINYINT is_active
    }

    class product {
        <<table>>
        +BIGINT product_id PK
        +VARCHAR product_code UK
        +VARCHAR product_name
        +BIGINT fruit_id FK
        +BIGINT origin_id FK
        +BIGINT grade_id FK
        +BIGINT size_id FK
        +BIGINT sale_unit_id FK
        +BIGINT stock_unit_id FK
        +VARCHAR sale_mode
        +VARCHAR package_spec
        +VARCHAR conversion_mode
        +DECIMAL stock_qty_per_sale_unit
        +TINYINT is_active
    }

    class product_identifier {
        <<table>>
        +BIGINT identifier_id PK
        +BIGINT product_id FK
        +VARCHAR identifier_type
        +VARCHAR identifier_value UK
        +TINYINT is_primary
        +TINYINT is_active
    }

    class shelf_life_rule {
        <<table>>
        +BIGINT shelf_life_rule_id PK
        +BIGINT product_id FK
        +BIGINT store_id FK nullable
        +VARCHAR storage_method
        +SMALLINT shelf_life_days
        +SMALLINT warning_days_before_expiry
        +SMALLINT markdown_days_before_expiry
        +SMALLINT stop_sale_days_before_expiry
        +DATE effective_from
        +DATE effective_to
        +SMALLINT priority_no
        +TINYINT is_active
    }
}

namespace Pricing {
    class pricing_policy {
        <<table>>
        +BIGINT pricing_policy_id PK
        +VARCHAR policy_code UK
        +VARCHAR policy_name
        +BIGINT store_id FK
        +BIGINT fruit_id FK
        +BIGINT product_id FK
        +DECIMAL target_margin_rate
        +DECIMAL minimum_margin_rate
        +DECIMAL maximum_markdown_rate
        +DECIMAL target_stock_cover_days
        +DECIMAL expected_waste_rate
        +DECIMAL price_rounding_unit
        +DATE effective_from
        +DATE effective_to
        +TINYINT is_active
    }

    class price_generation_run {
        <<table>>
        +BIGINT price_generation_run_id PK
        +BIGINT store_id FK
        +DATE price_date
        +SMALLINT run_no
        +VARCHAR generation_mode
        +VARCHAR run_status
        +VARCHAR model_version
        +JSON input_snapshot
        +BIGINT created_by FK
    }

    class price_recommendation {
        <<table>>
        +BIGINT price_recommendation_id PK
        +BIGINT price_generation_run_id FK
        +BIGINT pricing_policy_id FK
        +BIGINT product_id FK
        +DECIMAL cost_basis
        +DECIMAL current_price
        +DECIMAL predicted_sales_qty
        +DECIMAL current_stock_qty
        +DATE earliest_expiry_date
        +DECIMAL recommended_price
        +VARCHAR recommendation_status
        +BIGINT decided_by FK
    }

    class product_price_daily {
        <<table>>
        +BIGINT product_price_daily_id PK
        +BIGINT store_id FK
        +BIGINT product_id FK
        +DATE price_date
        +DECIMAL sale_price
        +DECIMAL cost_basis
        +VARCHAR price_source
        +BIGINT price_recommendation_id FK
        +VARCHAR price_status
        +BIGINT approved_by FK
        +DATETIME published_at
    }
}

namespace Purchase {
    class purchase_receipt {
        <<table>>
        +BIGINT purchase_receipt_id PK
        +BIGINT store_id FK
        +BIGINT supplier_id FK
        +VARCHAR receipt_no UK
        +DATE receipt_date
        +VARCHAR supplier_document_no
        +CHAR currency_code
        +VARCHAR receipt_status
        +DECIMAL total_amount
        +BIGINT created_by FK
    }

    class purchase_receipt_item {
        <<table>>
        +BIGINT purchase_receipt_item_id PK
        +BIGINT purchase_receipt_id FK
        +SMALLINT item_no
        +BIGINT product_id FK
        +VARCHAR lot_no
        +DECIMAL purchase_qty
        +BIGINT purchase_unit_id FK
        +DECIMAL stock_qty
        +DECIMAL purchase_unit_cost
        +DECIMAL additional_cost
        +DECIMAL line_total_cost
        +DECIMAL stock_unit_cost
        +BIGINT actual_origin_id FK
        +DATE harvest_date
        +DATE expiry_date
        +VARCHAR item_status
        +BIGINT stock_lot_id
        +BIGINT created_by FK
    }

    class purchase_return {
        <<table>>
        +BIGINT purchase_return_id PK
        +BIGINT store_id FK
        +BIGINT supplier_id FK
        +BIGINT original_purchase_receipt_id FK
        +VARCHAR return_no UK
        +DATE return_date
        +VARCHAR return_status
        +CHAR currency_code
        +DECIMAL total_amount
        +VARCHAR reason
        +BIGINT created_by FK
        +BIGINT approved_by FK
        +DATETIME approved_at
        +DATETIME posted_at
    }

    class purchase_return_item {
        <<table>>
        +BIGINT purchase_return_item_id PK
        +BIGINT purchase_return_id FK
        +SMALLINT item_no
        +BIGINT original_purchase_receipt_id FK
        +BIGINT original_purchase_receipt_item_id FK
        +BIGINT product_id FK
        +BIGINT stock_lot_id FK
        +DECIMAL return_qty
        +BIGINT return_unit_id FK
        +DECIMAL stock_qty
        +DECIMAL return_unit_cost
        +DECIMAL line_total_amount
        +VARCHAR reason_code
        +VARCHAR item_status
        +DATETIME posted_at
    }

    class purchase_posting {
        <<table-unused>>
        +BIGINT purchase_posting_id PK
        +BIGINT purchase_receipt_item_id FK
        +BIGINT stock_lot_id FK
        +VARCHAR posting_status
        +DECIMAL posted_stock_qty
        +SMALLINT retry_count
        +VARCHAR lock_token
        +TEXT error_message
    }
}

namespace Inventory {
    class stock_lot {
        <<table>>
        +BIGINT stock_lot_id PK
        +VARCHAR stock_ym
        +BIGINT store_id FK
        +BIGINT product_id FK
        +VARCHAR lot_no
        +VARCHAR lot_type
        +BIGINT supplier_id FK
        +BIGINT first_receipt_item_id FK
        +DATE received_date
        +DATE harvest_date
        +DATE expiry_date
        +DATE warning_date
        +DECIMAL begin_in_qty
        +DECIMAL begin_out_qty
        +DECIMAL in_qty
        +DECIMAL out_qty
        +DECIMAL end_in_qty
        +DECIMAL end_out_qty
        +DECIMAL end_balance_qty
        +DECIMAL stock_unit_cost
        +DECIMAL end_balance_value
        +VARCHAR lot_status
    }

    class stock_lot_detail {
        <<table>>
        +BIGINT stock_lot_detail_id PK
        +BIGINT stock_lot_id FK
        +VARCHAR item_no
        +BIGINT store_id FK
        +BIGINT product_id FK
        +VARCHAR transaction_type
        +DECIMAL quantity_change
        +DECIMAL unit_cost
        +DECIMAL cost_amount
        +DECIMAL before_balance_qty
        +DECIMAL after_balance_qty
        +DATE business_date
        +VARCHAR reference_type
        +BIGINT reference_id
        +BIGINT reference_line_id
        +BIGINT created_by FK
    }

    class stock_adj {
        <<table>>
        +BIGINT stock_adj_id PK
        +VARCHAR stock_ym
        +BIGINT store_id FK
        +BIGINT from_store_id FK
        +VARCHAR stock_adj_no UK
        +DATE stock_adj_date
        +VARCHAR stock_adj_type
        +VARCHAR stock_adj_status
        +VARCHAR reason
        +BIGINT created_by FK
        +BIGINT approved_by FK
        +DATETIME approved_at
        +DATETIME posted_at
    }

    class stock_adj_detail {
        <<table>>
        +BIGINT stock_adj_detail_id PK
        +BIGINT stock_adj_id FK
        +SMALLINT item_no
        +BIGINT product_id FK
        +BIGINT from_stock_lot_id FK
        +BIGINT to_stock_lot_id FK
        +DECIMAL stock_in_qty
        +DECIMAL stock_out_qty
        +DECIMAL unit_cost
        +VARCHAR reason_code
        +VARCHAR remarks
    }
}

namespace Sales {
    class sales_master {
        <<table>>
        +BIGINT sales_master_id PK
        +BIGINT store_id FK
        +VARCHAR sales_no UK
        +DATE business_date
        +DATETIME sales_at
        +VARCHAR sale_type
        +VARCHAR sales_status
        +DECIMAL subtotal_amount
        +DECIMAL discount_amount
        +DECIMAL total_amount
        +BIGINT member_id FK
        +BIGINT cashier_user_id FK
        +VARCHAR remarks
    }

    class sales_detail {
        <<table>>
        +BIGINT sales_detail_id PK
        +BIGINT sales_master_id FK
        +SMALLINT item_no
        +BIGINT original_sales_master_id FK
        +BIGINT original_sales_detail_id FK
        +BIGINT product_id FK
        +BIGINT product_price_daily_id FK
        +DECIMAL sale_qty
        +BIGINT sale_unit_id FK
        +DECIMAL stock_qty
        +DECIMAL unit_price
        +DECIMAL discount_amount
        +DECIMAL amount
    }

    class sales_payment {
        <<table>>
        +BIGINT sales_payment_id PK
        +BIGINT sales_master_id FK
        +VARCHAR payment_method
        +DECIMAL payment_amount
        +VARCHAR external_reference_no
        +DATETIME paid_at
    }

    class sales_posting {
        <<table>>
        +BIGINT sales_posting_id PK
        +BIGINT sales_detail_id FK
        +VARCHAR posting_batch_no
        +VARCHAR posting_status
        +DECIMAL expected_stock_qty
        +DECIMAL posted_stock_qty
        +TINYINT has_negative_stock
        +DECIMAL negative_stock_qty
        +VARCHAR cost_status
        +DECIMAL posted_cost
        +SMALLINT retry_count
        +VARCHAR lock_token
    }

    class sales_posting_lot {
        <<table>>
        +BIGINT sales_posting_lot_id PK
        +BIGINT sales_posting_id FK
        +SMALLINT allocation_seq
        +BIGINT stock_lot_id FK
        +VARCHAR lot_no
        +VARCHAR allocation_type
        +DECIMAL allocated_qty
        +DECIMAL unit_cost
        +DECIMAL allocated_cost
        +VARCHAR cost_status
    }

    class negative_stock_settlement {
        <<table-unused>>
        +BIGINT negative_stock_settlement_id PK
        +BIGINT sales_posting_lot_id FK
        +BIGINT receipt_stock_lot_id FK
        +DECIMAL settled_qty
        +DECIMAL settlement_unit_cost
        +DECIMAL settlement_cost
        +DATETIME settled_at
    }
}

store "1" --> "0..*" system_user : 所屬門市
store "1" --> "0..*" member_master : 註冊門市
store "1" --> "0..*" shelf_life_rule : 門市規則

unit "1" --> "0..*" fruit_base : 庫存單位
fruit_base "1" --> "0..*" product : 水果種類
origin "1" --> "0..*" product : 產地
fruit_grade "0..1" --> "0..*" product : 等級
fruit_size "0..1" --> "0..*" product : 尺寸
unit "1" --> "0..*" product : 銷售／庫存單位
product "1" --> "0..*" product_identifier : 條碼或PLU
product "1" --> "0..*" shelf_life_rule : 保存期限規則

store "0..1" --> "0..*" pricing_policy : 門市定價政策
fruit_base "0..1" --> "0..*" pricing_policy : 水果政策
product "0..1" --> "0..*" pricing_policy : 商品政策
store "1" --> "0..*" price_generation_run : 價格產生批次
system_user "1" --> "0..*" price_generation_run : 建立者
price_generation_run "1" --> "0..*" price_recommendation : 產生建議
pricing_policy "0..1" --> "0..*" price_recommendation : 套用政策
product "1" --> "0..*" price_recommendation : 建議商品
system_user "0..1" --> "0..*" price_recommendation : 決策者
store "1" --> "0..*" product_price_daily : 每日門市價格
product "1" --> "0..*" product_price_daily : 每日商品價格
price_recommendation "0..1" --> "0..1" product_price_daily : 核准發布
system_user "0..1" --> "0..*" product_price_daily : 核准者

store "1" --> "0..*" purchase_receipt : 進貨門市
supplier "1" --> "0..*" purchase_receipt : 進貨供應商
system_user "1" --> "0..*" purchase_receipt : 建立者
purchase_receipt "1" --> "1..*" purchase_receipt_item : 進貨明細
product "1" --> "0..*" purchase_receipt_item : 進貨商品
unit "1" --> "0..*" purchase_receipt_item : 進貨單位
origin "0..1" --> "0..*" purchase_receipt_item : 實際產地
system_user "1" --> "0..*" purchase_receipt_item : 建立者

purchase_receipt "1" --> "0..*" purchase_return : 原始進貨單
store "1" --> "0..*" purchase_return : 退回門市
supplier "1" --> "0..*" purchase_return : 退回供應商
system_user "1" --> "0..*" purchase_return : 建立者
system_user "0..1" --> "0..*" purchase_return : 核准者
purchase_return "1" --> "1..*" purchase_return_item : 退回明細
purchase_receipt_item "1" --> "0..*" purchase_return_item : 原始進貨明細
product "1" --> "0..*" purchase_return_item : 退回商品
unit "1" --> "0..*" purchase_return_item : 退回單位

store "1" --> "0..*" stock_lot : 門市批號庫存
product "1" --> "0..*" stock_lot : 商品批號
supplier "0..1" --> "0..*" stock_lot : 批號供應商
purchase_receipt_item "0..1" --> "0..*" stock_lot : 首次進貨來源
stock_lot "1" --> "0..*" stock_lot_detail : 庫存異動
store "1" --> "0..*" stock_lot_detail : 異動門市
product "1" --> "0..*" stock_lot_detail : 異動商品
system_user "1" --> "0..*" stock_lot_detail : 建立者

purchase_receipt_item "0..1" --> "0..1" purchase_posting : 備用進貨過帳
stock_lot "0..1" --> "0..*" purchase_posting : 過帳批號
stock_lot "0..1" --> "0..*" purchase_return_item : 退回批號

store "1" --> "0..*" sales_master : 銷售門市
member_master "0..1" --> "0..*" sales_master : 消費會員
system_user "1" --> "0..*" sales_master : 收銀員
sales_master "1" --> "1..*" sales_detail : 銷售明細
product "1" --> "0..*" sales_detail : 銷售商品
product_price_daily "0..1" --> "0..*" sales_detail : 成交價格來源
unit "1" --> "0..*" sales_detail : 銷售單位
sales_detail "0..1" --> "0..*" sales_detail : 原銷售退貨
sales_master "1" --> "0..*" sales_payment : 付款紀錄
sales_detail "1" --> "0..1" sales_posting : 庫存過帳
sales_posting "1" --> "1..*" sales_posting_lot : FIFO批號分攤
stock_lot "1" --> "0..*" sales_posting_lot : 扣除批號

sales_posting_lot "1" --> "0..*" negative_stock_settlement : 備用負庫存回補
stock_lot "1" --> "0..*" negative_stock_settlement : 回補進貨批號

store "1" --> "0..*" stock_adj : 調入／調整門市
store "0..1" --> "0..*" stock_adj : 調出門市
system_user "1" --> "0..*" stock_adj : 建立者
system_user "0..1" --> "0..*" stock_adj : 核准者
stock_adj "1" --> "1..*" stock_adj_detail : 調整明細
product "1" --> "0..*" stock_adj_detail : 調整商品
stock_lot "0..1" --> "0..*" stock_adj_detail : 來源批號
stock_lot "0..1" --> "0..*" stock_adj_detail : 目的批號
```