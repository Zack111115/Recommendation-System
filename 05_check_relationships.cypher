// ================================================================
// FILE 05 - KIỂM TRA RELATIONSHIP SAU KHI NẠP FILE 04
// Các truy vấn lỗi/vi phạm bên dưới lý tưởng sẽ trả về 0 dòng.
// ================================================================

// CHECK 1: Đếm BOUGHT. Mong đợi 420.
MATCH ()-[r:BOUGHT]->() RETURN count(r) AS boughtCount;

// CHECK 2: Đếm VIEWED. Mong đợi 600.
MATCH ()-[r:VIEWED]->() RETURN count(r) AS viewedCount;

// CHECK 3: Đếm BELONGS_TO. Mong đợi 120.
MATCH ()-[r:BELONGS_TO]->() RETURN count(r) AS belongsToCount;

// CHECK 4: Đếm từng loại relationship để chứng minh cơ cấu cạnh.
// Mong đợi: BOUGHT=420, VIEWED=600, BELONGS_TO=120,
// COMPLEMENTARY_TO=59, ALTERNATIVE_TO=11, SIMILAR_FUNCTION=10.
MATCH ()-[r]->()
WHERE type(r) IN ['BOUGHT','VIEWED','BELONGS_TO','COMPLEMENTARY_TO','ALTERNATIVE_TO','SIMILAR_FUNCTION']
RETURN type(r) AS relationshipType, count(r) AS relationshipCount
ORDER BY relationshipType;

// CHECK 5: Tổng relationship thuộc mô hình. Mong đợi 1220 cạnh.
// 420 + 600 + 120 + 80 = 1220.
MATCH ()-[r]->()
WHERE type(r) IN ['BOUGHT','VIEWED','BELONGS_TO','COMPLEMENTARY_TO','ALTERNATIVE_TO','SIMILAR_FUNCTION']
RETURN count(r) AS totalModelRelationships;

// CHECK 6: Kiểm tra đầu BOUGHT luôn là Customer, cuối là Product. Mong đợi 0 dòng.
MATCH (a)-[r:BOUGHT]->(b)
WHERE NOT (a:Customer) OR NOT (b:Product)
RETURN labels(a) AS startLabels, type(r) AS relationshipType, labels(b) AS endLabels;

// CHECK 7: Kiểm tra đầu VIEWED luôn là Customer, cuối là Product. Mong đợi 0 dòng.
MATCH (a)-[r:VIEWED]->(b)
WHERE NOT (a:Customer) OR NOT (b:Product)
RETURN labels(a) AS startLabels, type(r) AS relationshipType, labels(b) AS endLabels;

// CHECK 8: Kiểm tra BELONGS_TO nối Product -> Category. Mong đợi 0 dòng.
MATCH (a)-[r:BELONGS_TO]->(b)
WHERE NOT (a:Product) OR NOT (b:Category)
RETURN labels(a) AS startLabels, type(r) AS relationshipType, labels(b) AS endLabels;

// CHECK 9: Tìm Product có số cạnh BELONGS_TO khác 1. Mong đợi 0 dòng.
MATCH (p:Product)
OPTIONAL MATCH (p)-[r:BELONGS_TO]->()
WITH p, count(r) AS categoryLinkCount
WHERE categoryLinkCount <> 1
RETURN p.id AS productId, p.name AS productName, categoryLinkCount;

// CHECK 10: Đảm bảo cạnh BELONGS_TO trùng với categoryId trong node. Mong đợi 0 dòng.
MATCH (p:Product)-[:BELONGS_TO]->(cat:Category)
WHERE p.categoryId <> cat.id
RETURN p.id AS productId, p.categoryId AS propertyCategoryId, cat.id AS linkedCategoryId;

// CHECK 11: BOUGHT bắt buộc có orderId, purchasedAt, quantity > 0. Mong đợi 0 dòng.
MATCH (c:Customer)-[r:BOUGHT]->(p:Product)
WHERE r.orderId IS NULL OR r.purchasedAt IS NULL OR r.quantity IS NULL OR r.quantity <= 0
RETURN c.id AS customerId, p.id AS productId, properties(r) AS invalidRelationship;

// CHECK 12: VIEWED bắt buộc có sessionId và viewedAt. Mong đợi 0 dòng.
MATCH (c:Customer)-[r:VIEWED]->(p:Product)
WHERE r.sessionId IS NULL OR r.viewedAt IS NULL
RETURN c.id AS customerId, p.id AS productId, properties(r) AS invalidRelationship;

// CHECK 13: Phát hiện BOUGHT trùng theo Customer + Product + orderId. Mong đợi 0 dòng.
MATCH (c:Customer)-[r:BOUGHT]->(p:Product)
WITH c, p, r.orderId AS orderId, count(*) AS duplicateCount
WHERE duplicateCount > 1
RETURN c.id AS customerId, p.id AS productId, orderId, duplicateCount;

// CHECK 14: Phát hiện VIEWED trùng theo Customer + Product + sessionId. Mong đợi 0 dòng.
MATCH (c:Customer)-[r:VIEWED]->(p:Product)
WITH c, p, r.sessionId AS sessionId, count(*) AS duplicateCount
WHERE duplicateCount > 1
RETURN c.id AS customerId, p.id AS productId, sessionId, duplicateCount;

// CHECK 15: Các relationship giữa Product phải nối hai Product khác nhau. Mong đợi 0 dòng.
MATCH (a)-[r]->(b)
WHERE type(r) IN ['COMPLEMENTARY_TO','ALTERNATIVE_TO','SIMILAR_FUNCTION']
  AND (NOT (a:Product) OR NOT (b:Product) OR a.id = b.id)
RETURN labels(a) AS startLabels, a.id AS fromProduct, type(r) AS relationshipType,
       labels(b) AS endLabels, b.id AS toProduct;

// CHECK 16: Xem 10 cạnh mua của C001 để kiểm tra dữ liệu thuộc tính.
MATCH (c:Customer {id: 'C001'})-[r:BOUGHT]->(p:Product)
RETURN c.id AS customerId, p.id AS productId, p.name AS productName,
       r.orderId AS orderId, r.purchasedAt AS purchasedAt, r.quantity AS quantity
ORDER BY orderId, productId
LIMIT 10;

// CHECK 17: Kiểm tra một customer có mua nhiều món cùng đơn không.
// Ví dụ O-C001-01 dự kiến có 4 sản phẩm; O-C001-02 dự kiến có 3 sản phẩm.
MATCH (c:Customer {id: 'C001'})-[r:BOUGHT]->(p:Product)
RETURN r.orderId AS orderId, count(DISTINCT p) AS distinctProductsInOrder
ORDER BY orderId;
