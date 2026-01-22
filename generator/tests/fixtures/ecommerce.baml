// E-commerce example with complex nested types

enum OrderStatus {
    PENDING
    PROCESSING
    SHIPPED
    DELIVERED
    CANCELLED
    REFUNDED
}

enum PaymentMethod {
    CREDIT_CARD
    DEBIT_CARD
    PAYPAL
    APPLE_PAY
    GOOGLE_PAY
    BANK_TRANSFER
}

class Money {
    amount float
    currency string
}

class ProductVariant {
    variant_id string
    sku string
    name string
    price Money
    inventory_count int
    attributes map<string, string>
}

class Product {
    product_id string
    name string
    description string?
    base_price Money
    variants ProductVariant[]
    categories string[]
    is_available bool
    rating float?
    review_count int
}

class OrderItem {
    product Product
    variant ProductVariant?
    quantity int
    unit_price Money
    total_price Money
}

class ShippingAddress {
    recipient_name string
    street_line_1 string
    street_line_2 string?
    city string
    state string?
    postal_code string
    country string
    phone string?
}

class Order {
    order_id string
    customer_id string
    items OrderItem[]
    status OrderStatus
    payment_method PaymentMethod
    shipping_address ShippingAddress
    billing_address ShippingAddress?
    subtotal Money
    tax Money
    shipping_cost Money
    total Money
    notes string?
    created_at string
    updated_at string?
}

function CreateOrder(
    customer_id: string,
    items: OrderItem[],
    shipping_address: ShippingAddress,
    payment_method: PaymentMethod
) -> Order {
    client default
    prompt #"
        Create a new order
    "#
}

function GetOrdersByStatus(
    status: OrderStatus,
    limit: int,
    offset: int
) -> Order[] {
    client default
    prompt #"
        Get orders by status
    "#
}

function CalculateShipping(
    items: OrderItem[],
    destination: ShippingAddress
) -> Money {
    client default
    prompt #"
        Calculate shipping cost
    "#
}
