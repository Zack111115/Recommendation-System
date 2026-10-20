// ================================================================
// FILE 06 - TRUY VẤN NGHIỆP VỤ / GỢI Ý SẢN PHẨM
// Đây là các truy vấn để demo trong Neo4j Browser và sau này đóng gói API.
// ================================================================

// QUERY 1 - COLLABORATIVE FILTERING (thuật toán chính).
// Thử với C001. Tìm người khác cùng mua các sản phẩm với C001;
// lấy các sản phẩm họ mua thêm mà C001 chưa mua.
// supportCount = số Customer khác nhau ủng hộ gợi ý.
// sharedProductCount = số sản phẩm khác nhau được dùng làm bằng chứng mua chung.
MATCH (c1:Customer {id: 'C001'})-[:BOUGHT]->(p1:Product)<-[:BOUGHT]-(c2:Customer)-[:BOUGHT]->(p2:Product)
WHERE c2.id <> c1.id
  AND NOT (c1)-[:BOUGHT]->(p2)
WITH p2, count(DISTINCT c2) AS supportCount, count(DISTINCT p1) AS sharedProductCount
RETURN p2.id AS productId, p2.name AS productName, p2.brand AS brand,
       p2.price AS priceVND, supportCount, sharedProductCount,
       'Khách hàng có lịch sử mua chung cũng đã mua sản phẩm này' AS reason
ORDER BY supportCount DESC, sharedProductCount DESC, productId ASC
LIMIT 10;

// QUERY 2 - GIẢI THÍCH VÌ SAO GỢI Ý.
// Ví dụ giải thích sản phẩm P014 cho khách hàng C001.
// Nếu chưa có đường đi hoặc C001 đã mua P014, kết quả có thể rỗng.
MATCH (target:Customer {id: 'C001'})-[:BOUGHT]->(shared:Product)<-[:BOUGHT]-(supporter:Customer)-[:BOUGHT]->(recommended:Product {id: 'P014'})
WHERE supporter.id <> target.id
  AND NOT (target)-[:BOUGHT]->(recommended)
RETURN target.id AS targetCustomer,
       recommended.id AS recommendedProductId,
       recommended.name AS recommendedProductName,
       collect(DISTINCT supporter.id) AS supportingCustomers,
       count(DISTINCT supporter) AS supportCount,
       collect(DISTINCT {productId: shared.id, productName: shared.name}) AS sharedPurchaseEvidence;

// QUERY 3 - GỢI Ý MUA KÈM THEO CÙNG orderId.
// Không kết luận mua cùng chỉ vì khách từng mua hai sản phẩm ở hai thời điểm.
// Ví dụ: các sản phẩm thường nằm cùng đơn với P001.
MATCH (c:Customer)-[b1:BOUGHT]->(p1:Product {id: 'P001'}),
      (c)-[b2:BOUGHT]->(p2:Product)
WHERE p1 <> p2 AND b1.orderId = b2.orderId
RETURN p2.id AS productId, p2.name AS productName,
       count(DISTINCT b1.orderId) AS coPurchaseOrderCount,
       collect(DISTINCT b1.orderId)[0..5] AS evidenceOrderIds
ORDER BY coPurchaseOrderCount DESC, productId ASC
LIMIT 10;

// QUERY 4 - GỢI Ý THEO SẢN PHẨM BỔ TRỢ ĐƯỢC KHAI BÁO THỦ CÔNG.
// Đây là quan hệ quy tắc demo; không phải kết quả Collaborative Filtering.
MATCH (base:Product {id: 'P001'})-[:COMPLEMENTARY_TO]->(recommended:Product)
RETURN base.id AS baseProductId, base.name AS baseProductName,
       recommended.id AS recommendedProductId, recommended.name AS recommendedProductName,
       recommended.price AS priceVND,
       'Sản phẩm bổ trợ được khai báo trong dữ liệu demo' AS reason
ORDER BY recommended.id;

// QUERY 5 - TÌM KIẾM SẢN PHẨM THEO TỪ KHÓA.
// Đổi 'laptop' thành từ khóa muốn thử.
MATCH (p:Product)-[:BELONGS_TO]->(cat:Category)
WHERE toLower(p.name) CONTAINS toLower('laptop')
   OR toLower(p.description) CONTAINS toLower('laptop')
RETURN p.id AS productId, p.name AS productName, p.brand AS brand,
       p.price AS priceVND, p.stock AS stock, cat.name AS categoryName
ORDER BY p.price ASC
LIMIT 20;

// QUERY 6 - VẼ ĐƯỜNG ĐI GIẢI THÍCH COLLABORATIVE FILTERING.
// Neo4j Browser sẽ hiển thị các node và cạnh của các đường đi C001 -> P1 <- C2 -> P2.
MATCH path = (c1:Customer {id: 'C001'})-[:BOUGHT]->(p1:Product)<-[:BOUGHT]-(c2:Customer)-[:BOUGHT]->(p2:Product)
WHERE c2.id <> c1.id AND NOT (c1)-[:BOUGHT]->(p2)
RETURN path
LIMIT 25;

// QUERY 7 - XEM HOẠT ĐỘNG CỦA MỘT KHÁCH HÀNG (mua và xem).
MATCH (c:Customer {id: 'C001'})-[r]->(p:Product)
WHERE type(r) IN ['BOUGHT','VIEWED']
RETURN c.id AS customerId, type(r) AS action, p.id AS productId, p.name AS productName,
       r.orderId AS orderId, r.sessionId AS sessionId,
       r.purchasedAt AS purchasedAt, r.viewedAt AS viewedAt
ORDER BY action, productId
LIMIT 50;

// QUERY 8 - EXPLAIN: chỉ xem kế hoạch thực thi, không chạy truy vấn lấy dữ liệu.
EXPLAIN
MATCH (c1:Customer {id: 'C001'})-[:BOUGHT]->(p1:Product)<-[:BOUGHT]-(c2:Customer)-[:BOUGHT]->(p2:Product)
WHERE c2.id <> c1.id AND NOT (c1)-[:BOUGHT]->(p2)
RETURN p2.id, count(DISTINCT c2) AS supportCount
ORDER BY supportCount DESC
LIMIT 10;

// QUERY 9 - PROFILE: thực thi thật và hiển thị số liệu/plan thực tế.
// Chạy QUERY 8 trước để xem kế hoạch; không tự ghi số liệu hiệu năng khi chưa chạy.
PROFILE
MATCH (c1:Customer {id: 'C001'})-[:BOUGHT]->(p1:Product)<-[:BOUGHT]-(c2:Customer)-[:BOUGHT]->(p2:Product)
WHERE c2.id <> c1.id AND NOT (c1)-[:BOUGHT]->(p2)
RETURN p2.id, count(DISTINCT c2) AS supportCount
ORDER BY supportCount DESC
LIMIT 10;
