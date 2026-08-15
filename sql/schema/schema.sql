-- schema.sql
-- Gerado automaticamente por generate_schema.py
-- Tipos inferidos a partir da amostragem completa de cada CSV.

-- Origem: addresses.csv
CREATE TABLE IF NOT EXISTS addresses (
    id INTEGER,
    customer_id INTEGER,
    address_type TEXT,
    postal_code TEXT,
    street TEXT,
    number INTEGER,
    complement TEXT,
    district TEXT,
    city TEXT,
    state TEXT,
    country TEXT,
    is_primary BOOLEAN
);

-- Origem: attributes.csv
CREATE TABLE IF NOT EXISTS attributes (
    id INTEGER,
    name TEXT,
    data_type TEXT
);

-- Origem: brands.csv
CREATE TABLE IF NOT EXISTS brands (
    id INTEGER,
    name TEXT,
    country TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Origem: categories.csv
CREATE TABLE IF NOT EXISTS categories (
    id INTEGER,
    name TEXT,
    slug TEXT,
    parent_category_id INTEGER,
    is_active BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Origem: customers.csv
CREATE TABLE IF NOT EXISTS customers (
    id INTEGER,
    person_type TEXT,
    legal_name TEXT,
    trade_name TEXT,
    tax_id TEXT,
    state_registration TEXT,
    email TEXT,
    phone TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Origem: employees.csv
CREATE TABLE IF NOT EXISTS employees (
    id INTEGER,
    full_name TEXT,
    cpf NUMERIC,
    email TEXT,
    role TEXT,
    primary_location_id INTEGER,
    hire_date DATE,
    termination_date DATE,
    is_active BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Origem: fiscal_invoices.csv
CREATE TABLE IF NOT EXISTS fiscal_invoices (
    id INTEGER,
    order_id INTEGER,
    nfe_number TEXT,
    nfe_access_key TEXT,
    series TEXT,
    issued_at TIMESTAMP,
    status TEXT,
    total_amount NUMERIC,
    xml_storage_uri TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Origem: goods_receipt_items.csv
CREATE TABLE IF NOT EXISTS goods_receipt_items (
    id INTEGER,
    goods_receipt_id INTEGER,
    purchase_order_item_id INTEGER,
    quantity_received NUMERIC
);

-- Origem: goods_receipts.csv
CREATE TABLE IF NOT EXISTS goods_receipts (
    id INTEGER,
    purchase_order_id INTEGER,
    received_by_employee_id INTEGER,
    received_at TIMESTAMP,
    notes TEXT,
    created_at TIMESTAMP
);

-- Origem: locations.csv
CREATE TABLE IF NOT EXISTS locations (
    id INTEGER,
    name TEXT,
    location_type TEXT,
    postal_code TEXT,
    street TEXT,
    number INTEGER,
    complement TEXT,
    district TEXT,
    city TEXT,
    state TEXT,
    country TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Origem: order_items.csv
CREATE TABLE IF NOT EXISTS order_items (
    id INTEGER,
    order_id INTEGER,
    product_variant_id INTEGER,
    quantity INTEGER,
    unit_price NUMERIC,
    icms_rate NUMERIC,
    ipi_rate NUMERIC,
    line_total NUMERIC
);

-- Origem: orders.csv
CREATE TABLE IF NOT EXISTS orders (
    id INTEGER,
    order_number TEXT,
    channel TEXT,
    customer_id INTEGER,
    salesperson_id INTEGER,
    location_id INTEGER,
    status TEXT,
    subtotal NUMERIC,
    discount_amount NUMERIC,
    total NUMERIC,
    placed_at TIMESTAMP,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Origem: payments.csv
CREATE TABLE IF NOT EXISTS payments (
    id INTEGER,
    order_id INTEGER,
    method TEXT,
    installments INTEGER,
    amount NUMERIC,
    status TEXT,
    paid_at TIMESTAMP,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Origem: product_suppliers.csv
CREATE TABLE IF NOT EXISTS product_suppliers (
    product_variant_id INTEGER,
    supplier_id INTEGER,
    supplier_sku TEXT,
    last_quoted_cost NUMERIC,
    lead_time_days INTEGER,
    is_preferred BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Origem: product_variants.csv
CREATE TABLE IF NOT EXISTS product_variants (
    id INTEGER,
    product_id INTEGER,
    sku TEXT,
    barcode_ean TEXT,
    sale_price NUMERIC,
    cost_price NUMERIC,
    weight_kg NUMERIC,
    icms_rate NUMERIC,
    ipi_rate NUMERIC,
    is_active BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Origem: products.csv
-- Excecao aplicada em 'ncm_code': Codigo fiscal (NCM), nao uma quantidade. Os capitulos 01-09 da tabela NCM (animais vivos e produtos de origem animal) tem codigos que comecam com zero. Nenhum valor no dataset atual comeca com zero (catalogo nao inclui esses capitulos), mas o campo e semanticamente um identificador e deve ser TEXT independente do conteudo observado, para nao quebrar se o catalogo for expandido.
CREATE TABLE IF NOT EXISTS products (
    id INTEGER,
    name TEXT,
    description TEXT,
    brand_id INTEGER,
    category_id INTEGER,
    ncm_code TEXT,
    unit_of_measure TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Origem: purchase_order_items.csv
CREATE TABLE IF NOT EXISTS purchase_order_items (
    id INTEGER,
    purchase_order_id INTEGER,
    product_variant_id INTEGER,
    quantity_ordered INTEGER,
    unit_cost NUMERIC,
    line_total NUMERIC
);

-- Origem: purchase_orders.csv
CREATE TABLE IF NOT EXISTS purchase_orders (
    id INTEGER,
    po_number TEXT,
    supplier_id INTEGER,
    buyer_id INTEGER,
    destination_location_id INTEGER,
    status TEXT,
    currency TEXT,
    subtotal NUMERIC,
    total NUMERIC,
    placed_at TIMESTAMP,
    expected_delivery_at DATE,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Origem: return_items.csv
CREATE TABLE IF NOT EXISTS return_items (
    id INTEGER,
    return_id INTEGER,
    order_item_id INTEGER,
    quantity NUMERIC,
    action TEXT,
    exchange_variant_id INTEGER,
    unit_refund_amount NUMERIC
);

-- Origem: returns.csv
CREATE TABLE IF NOT EXISTS returns (
    id INTEGER,
    return_number TEXT,
    order_id INTEGER,
    customer_id INTEGER,
    received_at_location_id INTEGER,
    status TEXT,
    reason TEXT,
    total_refund_amount NUMERIC,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Origem: stock_levels.csv
CREATE TABLE IF NOT EXISTS stock_levels (
    product_variant_id INTEGER,
    location_id INTEGER,
    quantity_on_hand NUMERIC,
    reorder_point TEXT,
    updated_at TIMESTAMP
);

-- Origem: stock_movements.csv
CREATE TABLE IF NOT EXISTS stock_movements (
    id INTEGER,
    product_variant_id INTEGER,
    location_id INTEGER,
    movement_type TEXT,
    quantity NUMERIC,
    reference_table TEXT,
    reference_id INTEGER,
    employee_id INTEGER,
    notes TEXT,
    occurred_at TIMESTAMP,
    created_at TIMESTAMP
);

-- Origem: suppliers.csv
CREATE TABLE IF NOT EXISTS suppliers (
    id INTEGER,
    legal_name TEXT,
    trade_name TEXT,
    country TEXT,
    tax_id TEXT,
    tax_id_type TEXT,
    email TEXT,
    phone TEXT,
    contact_name TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

-- Origem: variant_attribute_values.csv
CREATE TABLE IF NOT EXISTS variant_attribute_values (
    product_variant_id INTEGER,
    attribute_id INTEGER,
    value TEXT
);
