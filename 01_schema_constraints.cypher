// ================================================================
// FILE 01 - SCHEMA / RÀNG BUỘC
// Dành cho Neo4j 5.x. Chạy trên database sẽ dùng cho đồ án.
// Các constraint ID/email giúp không tạo trùng thực thể.
// Neo4j Community không cung cấp đầy đủ constraint kiểm tra loại node
// ở hai đầu relationship; các kiểm tra đó được thực hiện trong FILE 05.
// Chạy từng câu lệnh riêng nếu Neo4j Browser không nhận nhiều câu cùng lúc.
// ================================================================

// 1. Mỗi khách hàng có ID duy nhất.
CREATE CONSTRAINT customer_id_unique IF NOT EXISTS
FOR (c:Customer) REQUIRE c.id IS UNIQUE;

// 2. Email giả lập của khách hàng cũng không được trùng.
CREATE CONSTRAINT customer_email_unique IF NOT EXISTS
FOR (c:Customer) REQUIRE c.email IS UNIQUE;

// 3. Mỗi sản phẩm có ID duy nhất.
CREATE CONSTRAINT product_id_unique IF NOT EXISTS
FOR (p:Product) REQUIRE p.id IS UNIQUE;

// 4. Mỗi danh mục có ID duy nhất.
CREATE CONSTRAINT category_id_unique IF NOT EXISTS
FOR (cat:Category) REQUIRE cat.id IS UNIQUE;

// 5. Index hỗ trợ tìm kiếm/lọc sản phẩm và lọc nhóm hành vi.
CREATE INDEX product_name_index IF NOT EXISTS FOR (p:Product) ON (p.name);
CREATE INDEX product_brand_index IF NOT EXISTS FOR (p:Product) ON (p.brand);
CREATE INDEX customer_behavior_group_index IF NOT EXISTS FOR (c:Customer) ON (c.behaviorGroup);
