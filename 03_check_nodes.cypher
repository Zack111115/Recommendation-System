// ================================================================
// FILE 03 - KIỂM TRA NODE SAU KHI NẠP FILE 02
// Các kết quả đếm mong đợi: Category=12, Product=120, Customer=60.
// Những truy vấn kiểm tra lỗi bên dưới lý tưởng sẽ trả 0 dòng.
// ================================================================

// CHECK 1: Đếm Category. Mong đợi 12.
MATCH (cat:Category) RETURN count(cat) AS categoryCount;

// CHECK 2: Đếm Product. Mong đợi 120.
MATCH (p:Product) RETURN count(p) AS productCount;

// CHECK 3: Đếm Customer. Mong đợi 60.
MATCH (c:Customer) RETURN count(c) AS customerCount;

// CHECK 4: Tổng số node thuộc mô hình chính. Mong đợi 192 (=12+120+60).
MATCH (n)
WHERE n:Category OR n:Product OR n:Customer
RETURN count(n) AS totalCoreNodes;

// CHECK 5: Tìm node thiếu ID. Mong đợi không có kết quả.
MATCH (n)
WHERE (n:Category OR n:Product OR n:Customer) AND n.id IS NULL
RETURN labels(n) AS nodeLabels, n AS nodeMissingId;

// CHECK 6: Tìm Customer thiếu email/nhóm hành vi/ngày tạo. Mong đợi 0 dòng.
MATCH (c:Customer)
WHERE c.email IS NULL OR c.behaviorGroup IS NULL OR c.createdAt IS NULL
RETURN c.id, c.email, c.behaviorGroup, c.createdAt;

// CHECK 7: Tìm Product thiếu thông tin hoặc có giá/tồn kho âm. Mong đợi 0 dòng.
MATCH (p:Product)
WHERE p.name IS NULL OR p.brand IS NULL OR p.categoryId IS NULL
   OR p.price IS NULL OR p.stock IS NULL OR p.price < 0 OR p.stock < 0
RETURN p.id, p.name, p.categoryId, p.price, p.stock;

// CHECK 8: Tìm Product có categoryId không trỏ đến Category nào. Mong đợi 0 dòng.
MATCH (p:Product)
OPTIONAL MATCH (cat:Category {id: p.categoryId})
WITH p, cat
WHERE cat IS NULL
RETURN p.id AS productId, p.name AS productName, p.categoryId AS missingCategoryId;

// CHECK 9: Kiểm tra trùng ID trong dữ liệu. Mong đợi 0 dòng.
// Constraint trong FILE 01 cũng ngăn trường hợp này xảy ra khi ghi dữ liệu.
MATCH (n)
WHERE n:Category OR n:Product OR n:Customer
WITH labels(n) AS nodeLabels, n.id AS id, count(*) AS duplicateCount
WHERE duplicateCount > 1
RETURN nodeLabels, id, duplicateCount;

// CHECK 10: Xem thử 5 sản phẩm và đối chiếu categoryId với Category.
// Truy vấn này chỉ dùng thuộc tính categoryId, nên chạy được TRƯỚC khi nạp BELONGS_TO.
MATCH (p:Product)
MATCH (cat:Category {id: p.categoryId})
RETURN p.id, p.name, p.brand, p.price, p.stock, cat.id AS categoryId, cat.name AS categoryName
ORDER BY p.id
LIMIT 5;
