<?php
declare(strict_types=1);

namespace Ecommerce;

use Exception;
use PDO;
use DateTime;

class Product
{
    private PDO $db;
    
    public function __construct(PDO $db)
    {
        $this->db = $db;
    }
    
    public function findById(int $id): ?array
    {
        $stmt = $this->db->prepare("
            SELECT p.*, c.name as category_name, 
                   GROUP_CONCAT(CONCAT(pa.name, ':', pa.value) SEPARATOR '|') as attributes
            FROM products p
            LEFT JOIN categories c ON p.category_id = c.id
            LEFT JOIN product_attributes pa ON p.id = pa.product_id
            WHERE p.id = ? AND p.status = 'active'
            GROUP BY p.id
        ");
        
        $stmt->execute([$id]);
        $product = $stmt->fetch();
        
        if ($product) {
            $product['attributes'] = $this->parseAttributes($product['attributes']);
            $product['images'] = $this->getProductImages($id);
            $product['variants'] = $this->getProductVariants($id);
        }
        
        return $product ?: null;
    }
    
    public function search(array $filters = [], int $page = 1, int $limit = 20): array
    {
        $where = ["p.status = 'active'"];
        $params = [];
        
        if (!empty($filters['category_id'])) {
            $where[] = "p.category_id = ?";
            $params[] = $filters['category_id'];
        }
        
        if (!empty($filters['min_price'])) {
            $where[] = "p.price >= ?";
            $params[] = $filters['min_price'];
        }
        
        if (!empty($filters['max_price'])) {
            $where[] = "p.price <= ?";
            $params[] = $filters['max_price'];
        }
        
        if (!empty($filters['search'])) {
            $where[] = "(p.name LIKE ? OR p.description LIKE ?)";
            $searchTerm = "%{$filters['search']}%";
            $params[] = $searchTerm;
            $params[] = $searchTerm;
        }
        
        if (!empty($filters['in_stock'])) {
            $where[] = "p.stock > 0";
        }
        
        $whereClause = implode(' AND ', $where);
        $offset = ($page - 1) * $limit;
        
        $countStmt = $this->db->prepare("SELECT COUNT(*) FROM products p WHERE {$whereClause}");
        $countStmt->execute($params);
        $total = $countStmt->fetchColumn();
        
        $stmt = $this->db->prepare("
            SELECT p.*, c.name as category_name
            FROM products p
            LEFT JOIN categories c ON p.category_id = c.id
            WHERE {$whereClause}
            ORDER BY p.created_at DESC
            LIMIT ? OFFSET ?
        ");
        
        $params[] = $limit;
        $params[] = $offset;
        $stmt->execute($params);
        $products = $stmt->fetchAll();
        
        return [
            'products' => $products,
            'total' => $total,
            'page' => $page,
            'limit' => $limit,
            'pages' => ceil($total / $limit)
        ];
    }
    
    public function updateStock(int $productId, int $quantity): bool
    {
        $stmt = $this->db->prepare("UPDATE products SET stock = stock - ? WHERE id = ? AND stock >= ?");
        return $stmt->execute([$quantity, $productId, $quantity]);
    }
    
    public function restoreStock(int $productId, int $quantity): bool
    {
        $stmt = $this->db->prepare("UPDATE products SET stock = stock + ? WHERE id = ?");
        return $stmt->execute([$quantity, $productId]);
    }
    
    private function parseAttributes(?string $attributes): array
    {
        if (!$attributes) return [];
        
        $parsed = [];
        foreach (explode('|', $attributes) as $attr) {
            if (strpos($attr, ':') !== false) {
                [$name, $value] = explode(':', $attr, 2);
                $parsed[$name] = $value;
            }
        }
        
        return $parsed;
    }
    
    private function getProductImages(int $productId): array
    {
        $stmt = $this->db->prepare("SELECT * FROM product_images WHERE product_id = ? ORDER BY sort_order");
        $stmt->execute([$productId]);
        return $stmt->fetchAll();
    }
    
    private function getProductVariants(int $productId): array
    {
        $stmt = $this->db->prepare("SELECT * FROM product_variants WHERE product_id = ? AND status = 'active'");
        $stmt->execute([$productId]);
        return $stmt->fetchAll();
    }
}

class ShoppingCart
{
    private array $items = [];
    private string $sessionKey = 'shopping_cart';
    private Product $productService;
    
    public function __construct(Product $productService)
    {
        $this->productService = $productService;
        $this->loadFromSession();
    }
    
    public function addItem(int $productId, int $quantity = 1, array $options = []): bool
    {
        $product = $this->productService->findById($productId);
        
        if (!$product) {
            throw new Exception("Product not found");
        }
        
        if ($product['stock'] < $quantity) {
            throw new Exception("Insufficient stock available");
        }
        
        $itemKey = $this->generateItemKey($productId, $options);
        
        if (isset($this->items[$itemKey])) {
            $newQuantity = $this->items[$itemKey]['quantity'] + $quantity;
            
            if ($product['stock'] < $newQuantity) {
                throw new Exception("Insufficient stock for requested quantity");
            }
            
            $this->items[$itemKey]['quantity'] = $newQuantity;
        } else {
            $this->items[$itemKey] = [
                'product_id' => $productId,
                'quantity' => $quantity,
                'options' => $options,
                'product' => $product,
                'added_at' => time()
            ];
        }
        
        $this->saveToSession();
        return true;
    }
    
    public function updateQuantity(string $itemKey, int $quantity): bool
    {
        if (!isset($this->items[$itemKey])) {
            throw new Exception("Item not found in cart");
        }
        
        if ($quantity <= 0) {
            return $this->removeItem($itemKey);
        }
        
        $product = $this->items[$itemKey]['product'];
        
        if ($product['stock'] < $quantity) {
            throw new Exception("Insufficient stock available");
        }
        
        $this->items[$itemKey]['quantity'] = $quantity;
        $this->saveToSession();
        return true;
    }
    
    public function removeItem(string $itemKey): bool
    {
        if (isset($this->items[$itemKey])) {
            unset($this->items[$itemKey]);
            $this->saveToSession();
            return true;
        }
        
        return false;
    }
    
    public function clear(): void
    {
        $this->items = [];
        $this->saveToSession();
    }
    
    public function getItems(): array
    {
        return $this->items;
    }
    
    public function getItemCount(): int
    {
        return array_sum(array_column($this->items, 'quantity'));
    }
    
    public function getTotal(): float
    {
        $total = 0;
        
        foreach ($this->items as $item) {
            $price = $item['product']['price'];
            $total += $price * $item['quantity'];
        }
        
        return $total;
    }
    
    public function getSubtotal(): float
    {
        return $this->getTotal();
    }
    
    public function isEmpty(): bool
    {
        return empty($this->items);
    }
    
    public function validateInventory(): array
    {
        $errors = [];
        
        foreach ($this->items as $key => $item) {
            $currentProduct = $this->productService->findById($item['product_id']);
            
            if (!$currentProduct) {
                $errors[] = "Product {$item['product']['name']} is no longer available";
                continue;
            }
            
            if ($currentProduct['stock'] < $item['quantity']) {
                $errors[] = "Only {$currentProduct['stock']} units of {$item['product']['name']} available";
            }
            
            $this->items[$key]['product'] = $currentProduct;
        }
        
        if (!empty($errors)) {
            $this->saveToSession();
        }
        
        return $errors;
    }
    
    private function generateItemKey(int $productId, array $options): string
    {
        $optionsString = !empty($options) ? serialize($options) : '';
        return md5($productId . $optionsString);
    }
    
    private function loadFromSession(): void
    {
        if (session_status() === PHP_SESSION_NONE) {
            session_start();
        }
        
        if (isset($_SESSION[$this->sessionKey])) {
            $this->items = $_SESSION[$this->sessionKey];
        }
    }
    
    private function saveToSession(): void
    {
        if (session_status() === PHP_SESSION_NONE) {
            session_start();
        }
        
        $_SESSION[$this->sessionKey] = $this->items;
    }
}

class Order
{
    private PDO $db;
    
    public function __construct(PDO $db)
    {
        $this->db = $db;
    }
    
    public function create(array $orderData): int
    {
        $this->db->beginTransaction();
        
        try {
            $stmt = $this->db->prepare("
                INSERT INTO orders (
                    user_id, status, subtotal, tax_amount, shipping_amount, 
                    total_amount, currency, billing_address, shipping_address,
                    payment_method, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
            ");
            
            $stmt->execute([
                $orderData['user_id'],
                'pending',
                $orderData['subtotal'],
                $orderData['tax_amount'],
                $orderData['shipping_amount'],
                $orderData['total_amount'],
                $orderData['currency'] ?? 'USD',
                json_encode($orderData['billing_address']),
                json_encode($orderData['shipping_address']),
                $orderData['payment_method']
            ]);
            
            $orderId = (int)$this->db->lastInsertId();
            
            foreach ($orderData['items'] as $item) {
                $this->createOrderItem($orderId, $item);
                
                $productService = new Product($this->db);
                if (!$productService->updateStock($item['product_id'], $item['quantity'])) {
                    throw new Exception("Failed to update stock for product {$item['product_id']}");
                }
            }
            
            $this->db->commit();
            return $orderId;
            
        } catch (Exception $e) {
            $this->db->rollback();
            throw $e;
        }
    }
    
    public function findById(int $orderId): ?array
    {
        $stmt = $this->db->prepare("
            SELECT o.*, u.name as customer_name, u.email as customer_email
            FROM orders o
            LEFT JOIN users u ON o.user_id = u.id
            WHERE o.id = ?
        ");
        
        $stmt->execute([$orderId]);
        $order = $stmt->fetch();
        
        if ($order) {
            $order['items'] = $this->getOrderItems($orderId);
            $order['billing_address'] = json_decode($order['billing_address'], true);
            $order['shipping_address'] = json_decode($order['shipping_address'], true);
        }
        
        return $order ?: null;
    }
    
    public function updateStatus(int $orderId, string $status): bool
    {
        $validStatuses = ['pending', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded'];
        
        if (!in_array($status, $validStatuses)) {
            throw new Exception("Invalid order status: {$status}");
        }
        
        $stmt = $this->db->prepare("UPDATE orders SET status = ?, updated_at = NOW() WHERE id = ?");
        return $stmt->execute([$status, $orderId]);
    }
    
    public function cancel(int $orderId): bool
    {
        $order = $this->findById($orderId);
        
        if (!$order) {
            throw new Exception("Order not found");
        }
        
        if (!in_array($order['status'], ['pending', 'processing'])) {
            throw new Exception("Cannot cancel order with status: {$order['status']}");
        }
        
        $this->db->beginTransaction();
        
        try {
            $productService = new Product($this->db);
            foreach ($order['items'] as $item) {
                $productService->restoreStock($item['product_id'], $item['quantity']);
            }
            
            $this->updateStatus($orderId, 'cancelled');
            
            $this->db->commit();
            return true;
            
        } catch (Exception $e) {
            $this->db->rollback();
            throw $e;
        }
    }
    
    public function getOrdersByUser(int $userId, int $page = 1, int $limit = 10): array
    {
        $offset = ($page - 1) * $limit;
        
        $countStmt = $this->db->prepare("SELECT COUNT(*) FROM orders WHERE user_id = ?");
        $countStmt->execute([$userId]);
        $total = $countStmt->fetchColumn();
        
        $stmt = $this->db->prepare("
            SELECT * FROM orders 
            WHERE user_id = ? 
            ORDER BY created_at DESC 
            LIMIT ? OFFSET ?
        ");
        
        $stmt->execute([$userId, $limit, $offset]);
        $orders = $stmt->fetchAll();
        
        foreach ($orders as &$order) {
            $order['items'] = $this->getOrderItems($order['id']);
        }
        
        return [
            'orders' => $orders,
            'total' => $total,
            'page' => $page,
            'limit' => $limit,
            'pages' => ceil($total / $limit)
        ];
    }
    
    private function createOrderItem(int $orderId, array $item): void
    {
        $stmt = $this->db->prepare("
            INSERT INTO order_items (
                order_id, product_id, quantity, unit_price, 
                total_price, product_name, product_sku
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ");
        
        $stmt->execute([
            $orderId,
            $item['product_id'],
            $item['quantity'],
            $item['unit_price'],
            $item['total_price'],
            $item['product_name'],
            $item['product_sku']
        ]);
    }
    
    private function getOrderItems(int $orderId): array
    {
        $stmt = $this->db->prepare("
            SELECT oi.*, p.image_url
            FROM order_items oi
            LEFT JOIN products p ON oi.product_id = p.id
            WHERE oi.order_id = ?
            ORDER BY oi.id
        ");
        
        $stmt->execute([$orderId]);
        return $stmt->fetchAll();
    }
}

interface PaymentGateway
{
    public function charge(PaymentRequest $request): PaymentResponse;
    public function refund(string $transactionId, float $amount): PaymentResponse;
    public function getTransaction(string $transactionId): ?array;
}

class PaymentRequest
{
    public function __construct(
        public float $amount,
        public string $currency,
        public array $paymentMethod,
        public array $customerInfo,
        public string $description,
        public ?string $orderId = null
    ) {}
}

class PaymentResponse
{
    public function __construct(
        public bool $success,
        public ?string $transactionId = null,
        public ?string $errorMessage = null,
        public array $metadata = []
    ) {}
}

class StripeGateway implements PaymentGateway
{
    private string $secretKey;
    private string $apiUrl = 'https://api.stripe.com/v1';
    
    public function __construct(string $secretKey)
    {
        $this->secretKey = $secretKey;
    }
    
    public function charge(PaymentRequest $request): PaymentResponse
    {
        $data = [
            'amount' => (int)($request->amount * 100),
            'currency' => strtolower($request->currency),
            'description' => $request->description,
            'metadata' => [
                'order_id' => $request->orderId
            ]
        ];
        
        if (isset($request->paymentMethod['card_token'])) {
            $data['source'] = $request->paymentMethod['card_token'];
        } elseif (isset($request->paymentMethod['payment_method_id'])) {
            $data['payment_method'] = $request->paymentMethod['payment_method_id'];
            $data['confirmation_method'] = 'manual';
            $data['confirm'] = true;
        }
        
        $response = $this->makeRequest('charges', $data);
        
        if ($response['success']) {
            return new PaymentResponse(
                success: true,
                transactionId: $response['data']['id'],
                metadata: $response['data']
            );
        } else {
            return new PaymentResponse(
                success: false,
                errorMessage: $response['error']
            );
        }
    }
    
    public function refund(string $transactionId, float $amount): PaymentResponse
    {
        $data = [
            'charge' => $transactionId,
            'amount' => (int)($amount * 100)
        ];
        
        $response = $this->makeRequest('refunds', $data);
        
        if ($response['success']) {
            return new PaymentResponse(
                success: true,
                transactionId: $response['data']['id'],
                metadata: $response['data']
            );
        } else {
            return new PaymentResponse(
                success: false,
                errorMessage: $response['error']
            );
        }
    }
    
    public function getTransaction(string $transactionId): ?array
    {
        $response = $this->makeRequest("charges/{$transactionId}", [], 'GET');
        
        return $response['success'] ? $response['data'] : null;
    }
    
    private function makeRequest(string $endpoint, array $data = [], string $method = 'POST'): array
    {
        $url = "{$this->apiUrl}/{$endpoint}";
        
        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL => $url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => [
                'Authorization: Bearer ' . $this->secretKey,
                'Content-Type: application/x-www-form-urlencoded'
            ],
            CURLOPT_CUSTOMREQUEST => $method
        ]);
        
        if ($method === 'POST' && !empty($data)) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($data));
        }
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        $decodedResponse = json_decode($response, true);
        
        if ($httpCode >= 200 && $httpCode < 300) {
            return ['success' => true, 'data' => $decodedResponse];
        } else {
            $error = $decodedResponse['error']['message'] ?? 'Payment processing failed';
            return ['success' => false, 'error' => $error];
        }
    }
}

class PayPalGateway implements PaymentGateway
{
    private string $clientId;
    private string $clientSecret;
    private string $apiUrl;
    private ?string $accessToken = null;
    
    public function __construct(string $clientId, string $clientSecret, bool $sandbox = true)
    {
        $this->clientId = $clientId;
        $this->clientSecret = $clientSecret;
        $this->apiUrl = $sandbox ? 'https://api.sandbox.paypal.com' : 'https://api.paypal.com';
    }
    
    public function charge(PaymentRequest $request): PaymentResponse
    {
        $accessToken = $this->getAccessToken();
        
        if (!$accessToken) {
            return new PaymentResponse(false, null, 'Failed to authenticate with PayPal');
        }
        
        $orderData = [
            'intent' => 'CAPTURE',
            'purchase_units' => [[
                'amount' => [
                    'currency_code' => $request->currency,
                    'value' => number_format($request->amount, 2, '.', '')
                ],
                'description' => $request->description
            ]]
        ];
        
        $response = $this->makeAuthenticatedRequest('/v2/checkout/orders', $orderData);
        
        if ($response['success']) {
            $orderId = $response['data']['id'];
            
            $captureResponse = $this->makeAuthenticatedRequest("/v2/checkout/orders/{$orderId}/capture", []);
            
            if ($captureResponse['success']) {
                return new PaymentResponse(
                    success: true,
                    transactionId: $captureResponse['data']['id'],
                    metadata: $captureResponse['data']
                );
            }
        }
        
        return new PaymentResponse(
            success: false,
            errorMessage: $response['error'] ?? 'PayPal payment failed'
        );
    }
    
    public function refund(string $transactionId, float $amount): PaymentResponse
    {
        $refundData = [
            'amount' => [
                'value' => number_format($amount, 2, '.', ''),
                'currency_code' => 'USD'
            ]
        ];
        
        $response = $this->makeAuthenticatedRequest("/v2/payments/captures/{$transactionId}/refund", $refundData);
        
        if ($response['success']) {
            return new PaymentResponse(
                success: true,
                transactionId: $response['data']['id'],
                metadata: $response['data']
            );
        } else {
            return new PaymentResponse(
                success: false,
                errorMessage: $response['error']
            );
        }
    }
    
    public function getTransaction(string $transactionId): ?array
    {
        $response = $this->makeAuthenticatedRequest("/v2/payments/captures/{$transactionId}", [], 'GET');
        
        return $response['success'] ? $response['data'] : null;
    }
    
    private function getAccessToken(): ?string
    {
        if ($this->accessToken) {
            return $this->accessToken;
        }
        
        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL => $this->apiUrl . '/v1/oauth2/token',
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => [
                'Accept: application/json',
                'Accept-Language: en_US'
            ],
            CURLOPT_USERPWD => $this->clientId . ':' . $this->clientSecret,
            CURLOPT_POSTFIELDS => 'grant_type=client_credentials'
        ]);
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($httpCode === 200) {
            $data = json_decode($response, true);
            $this->accessToken = $data['access_token'];
            return $this->accessToken;
        }
        
        return null;
    }
    
    private function makeAuthenticatedRequest(string $endpoint, array $data, string $method = 'POST'): array
    {
        $url = $this->apiUrl . $endpoint;
        
        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL => $url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json',
                'Authorization: Bearer ' . $this->accessToken
            ],
            CURLOPT_CUSTOMREQUEST => $method
        ]);
        
        if ($method === 'POST' && !empty($data)) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        }
        
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        $decodedResponse = json_decode($response, true);
        
        if ($httpCode >= 200 && $httpCode < 300) {
            return ['success' => true, 'data' => $decodedResponse];
        } else {
            $error = $decodedResponse['message'] ?? 'PayPal API request failed';
            return ['success' => false, 'error' => $error];
        }
    }
}

class CheckoutManager
{
    private PDO $db;
    private ShoppingCart $cart;
    private PaymentGateway $paymentGateway;
    private Order $orderService;
    
    public function __construct(PDO $db, ShoppingCart $cart, PaymentGateway $paymentGateway)
    {
        $this->db = $db;
        $this->cart = $cart;
        $this->paymentGateway = $paymentGateway;
        $this->orderService = new Order($db);
    }
    
    public function processCheckout(array $checkoutData): array
    {
        if ($this->cart->isEmpty()) {
            throw new Exception("Cart is empty");
        }
        
        $inventoryErrors = $this->cart->validateInventory();
        if (!empty($inventoryErrors)) {
            throw new Exception("Inventory validation failed: " . implode(', ', $inventoryErrors));
        }
        
        $subtotal = $this->cart->getSubtotal();
        $taxAmount = $this->calculateTax($subtotal, $checkoutData['billing_address']);
        $shippingAmount = $this->calculateShipping($checkoutData['shipping_address']);
        $totalAmount = $subtotal + $taxAmount + $shippingAmount;
        
        $discountAmount = 0;
        if (!empty($checkoutData['coupon_code'])) {
            $discountAmount = $this->applyCoupon($checkoutData['coupon_code'], $subtotal);
            $totalAmount -= $discountAmount;
        }
        
        $paymentRequest = new PaymentRequest(
            amount: $totalAmount,
            currency: $checkoutData['currency'] ?? 'USD',
            paymentMethod: $checkoutData['payment_method'],
            customerInfo: $checkoutData['customer_info'],
            description: "Order for {$checkoutData['customer_info']['name']}",
            orderId: null
        );
        
        $paymentResponse = $this->paymentGateway->charge($paymentRequest);
        
        if (!$paymentResponse->success) {
            throw new Exception("Payment failed: " . $paymentResponse->errorMessage);
        }
        
        $orderData = [
            'user_id' => $checkoutData['user_id'],
            'subtotal' => $subtotal,
            'tax_amount' => $taxAmount,
            'shipping_amount' => $shippingAmount,
            'discount_amount' => $discountAmount,
            'total_amount' => $totalAmount,
            'currency' => $checkoutData['currency'] ?? 'USD',
            'billing_address' => $checkoutData['billing_address'],
            'shipping_address' => $checkoutData['shipping_address'],
            'payment_method' => $checkoutData['payment_method']['type'],
            'transaction_id' => $paymentResponse->transactionId,
            'items' => $this->prepareOrderItems()
        ];
        
        $orderId = $this->orderService->create($orderData);
        
        $this->cart->clear();
        
        $this->sendOrderConfirmation($orderId);
        
        return [
            'success' => true,
            'order_id' => $orderId,
            'transaction_id' => $paymentResponse->transactionId,
            'total_amount' => $totalAmount
        ];
    }
    
    private function calculateTax(float $subtotal, array $address): float
    {
        $taxRates = [
            'CA' => 0.08,
            'NY' => 0.08,
            'TX' => 0.06
        ];
        
        $state = $address['state'] ?? '';
        $taxRate = $taxRates[$state] ?? 0;
        
        return $subtotal * $taxRate;
    }
    
    private function calculateShipping(array $address): float
    {
        $shippingRates = [
            'standard' => 5.99,
            'express' => 12.99,
            'overnight' => 24.99
        ];
        
        $method = $address['shipping_method'] ?? 'standard';
        return $shippingRates[$method] ?? $shippingRates['standard'];
    }
    
    private function applyCoupon(string $couponCode, float $subtotal): float
    {
        $stmt = $this->db->prepare("
            SELECT * FROM coupons 
            WHERE code = ? AND status = 'active' 
            AND (expires_at IS NULL OR expires_at > NOW())
            AND usage_count < usage_limit
        ");
        
        $stmt->execute([$couponCode]);
        $coupon = $stmt->fetch();
        
        if (!$coupon) {
            throw new Exception("Invalid or expired coupon code");
        }
        
        if ($coupon['minimum_amount'] && $subtotal < $coupon['minimum_amount']) {
            throw new Exception("Coupon requires minimum order of $" . $coupon['minimum_amount']);
        }
        
        $discount = 0;
        
        if ($coupon['type'] === 'percentage') {
            $discount = $subtotal * ($coupon['value'] / 100);
        } elseif ($coupon['type'] === 'fixed') {
            $discount = $coupon['value'];
        }
        
        $this->db->prepare("UPDATE coupons SET usage_count = usage_count + 1 WHERE id = ?")
                 ->execute([$coupon['id']]);
        
        return min($discount, $subtotal);
    }
    
    private function prepareOrderItems(): array
    {
        $items = [];
        
        foreach ($this->cart->getItems() as $item) {
            $items[] = [
                'product_id' => $item['product_id'],
                'quantity' => $item['quantity'],
                'unit_price' => $item['product']['price'],
                'total_price' => $item['product']['price'] * $item['quantity'],
                'product_name' => $item['product']['name'],
                'product_sku' => $item['product']['sku']
            ];
        }
        
        return $items;
    }
    
    private function sendOrderConfirmation(int $orderId): void
    {
        $order = $this->orderService->findById($orderId);
        
        if ($order) {
            $subject = "Order Confirmation #{$orderId}";
            $message = $this->generateOrderEmailTemplate($order);
            
            error_log("Order confirmation email would be sent to: {$order['customer_email']}");
        }
    }
    
    private function generateOrderEmailTemplate(array $order): string
    {
        $html = "<h1>Thank you for your order!</h1>";
        $html .= "<p>Order ID: #{$order['id']}</p>";
        $html .= "<p>Total: $" . number_format($order['total_amount'], 2) . "</p>";
        $html .= "<h3>Items:</h3><ul>";
        
        foreach ($order['items'] as $item) {
            $html .= "<li>{$item['quantity']}x {$item['product_name']} - $" . 
                     number_format($item['total_price'], 2) . "</li>";
        }
        
        $html .= "</ul>";
        $html .= "<p>We'll send you an update when your order ships.</p>";
        
        return $html;
    }
}

class InventoryManager
{
    private PDO $db;
    
    public function __construct(PDO $db)
    {
        $this->db = $db;
    }
    
    public function getLowStockProducts(int $threshold = 10): array
    {
        $stmt = $this->db->prepare("
            SELECT * FROM products 
            WHERE stock <= ? AND status = 'active'
            ORDER BY stock ASC
        ");
        
        $stmt->execute([$threshold]);
        return $stmt->fetchAll();
    }
    
    public function updateStock(int $productId, int $newStock): bool
    {
        $stmt = $this->db->prepare("UPDATE products SET stock = ?, updated_at = NOW() WHERE id = ?");
        return $stmt->execute([$newStock, $productId]);
    }
    
    public function addStockMovement(int $productId, int $quantity, string $type, string $reference = ''): void
    {
        $stmt = $this->db->prepare("
            INSERT INTO stock_movements (product_id, quantity, type, reference, created_at)
            VALUES (?, ?, ?, ?, NOW())
        ");
        
        $stmt->execute([$productId, $quantity, $type, $reference]);
    }
    
    public function getStockHistory(int $productId): array
    {
        $stmt = $this->db->prepare("
            SELECT * FROM stock_movements 
            WHERE product_id = ? 
            ORDER BY created_at DESC
        ");
        
        $stmt->execute([$productId]);
        return $stmt->fetchAll();
    }
}

function demonstrateEcommerceSystem(): void
{
    $pdo = new PDO('mysql:host=localhost;dbname=ecommerce', 'user', 'password');
    
    $productService = new Product($pdo);
    $cart = new ShoppingCart($productService);
    $orderService = new Order($pdo);
    
    $paymentGateway = new StripeGateway('sk_test_...');
    
    $checkout = new CheckoutManager($pdo, $cart, $paymentGateway);
    
    echo "=== E-commerce System Demo ===\n";
    
    try {
        $cart->addItem(1, 2); 
        $cart->addItem(2, 1);
        
        echo "Cart total: $" . number_format($cart->getTotal(), 2) . "\n";
        echo "Item count: " . $cart->getItemCount() . "\n";
        
        $checkoutData = [
            'user_id' => 1,
            'customer_info' => [
                'name' => 'John Doe',
                'email' => 'john@example.com'
            ],
            'billing_address' => [
                'street' => '123 Main St',
                'city' => 'San Francisco',
                'state' => 'CA',
                'zip' => '94105'
            ],
            'shipping_address' => [
                'street' => '123 Main St',
                'city' => 'San Francisco',
                'state' => 'CA',
                'zip' => '94105',
                'shipping_method' => 'standard'
            ],
            'payment_method' => [
                'type' => 'credit_card',
                'card_token' => 'tok_visa'
            ],
            'currency' => 'USD'
        ];
        
        echo "Checkout process would complete here with payment processing\n";
        
    } catch (Exception $e) {
        echo "Error: " . $e->getMessage() . "\n";
    }
    
    echo "E-commerce demo completed\n";
} 