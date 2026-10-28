using Neo4j.Driver;
using RecommendationSystem.Models;

namespace RecommendationSystem.Services;

public sealed class RecommendationService
{
    private readonly IDriver _driver;
    private readonly string _database;

    public RecommendationService(
        IDriver driver,
        IConfiguration configuration)
    {
        _driver = driver;
        _database = configuration["Neo4j:Database"] ?? "neo4j";
    }

    private async Task<List<T>> QueryAsync<T>(
        string cypher,
        Func<IRecord, T> mapper,
        object? parameters = null)
    {
        await using var session = _driver.AsyncSession(
            options => options.WithDatabase(_database));

        var cursor = await session.RunAsync(
            cypher,
            parameters ?? new { });

        var records = await cursor.ToListAsync();

        return records.Select(mapper).ToList();
    }

    private static string GetText(IRecord record, string key)
    {
        if (!record.Keys.Contains(key))
            return string.Empty;

        var value = record[key];

        if (value is null)
            return string.Empty;

        try
        {
            return value.As<string>() ?? string.Empty;
        }
        catch
        {
            return value.ToString() ?? string.Empty;
        }
    }

    private static long GetLong(IRecord record, string key)
    {
        if (!record.Keys.Contains(key))
            return 0L;

        var value = record[key];

        return value is null ? 0L : value.As<long>();
    }

    private static double GetDouble(IRecord record, string key)
    {
        if (!record.Keys.Contains(key))
            return 0.0;

        var value = record[key];

        return value is null ? 0.0 : value.As<double>();
    }

    private static IReadOnlyList<string> GetStringList(
        IRecord record,
        string key)
    {
        if (!record.Keys.Contains(key))
            return Array.Empty<string>();

        var value = record[key];

        return value is null
            ? Array.Empty<string>()
            : value.As<List<string>>();
    }

    // 1. Kiem tra ket noi Neo4j.
    public async Task<object> CheckConnectionAsync()
    {
        await _driver.VerifyConnectivityAsync();

        var rows = await QueryAsync(
            """
            RETURN 1 AS result,
                   'Neo4j ket noi thanh cong' AS message
            """,
            r => new
            {
                result = GetLong(r, "result"),
                message = GetText(r, "message")
            });

        return new
        {
            status = "healthy",
            database = _database,
            result = rows[0].result,
            message = rows[0].message
        };
    }

    // 2. Lay danh sach danh muc.
    public Task<List<CategoryDto>> GetCategoriesAsync()
    {
        return QueryAsync(
            """
            MATCH (c:Category)
            RETURN coalesce(c.id, '') AS id,
                   coalesce(c.name, c.id, 'Chua dat ten') AS name,
                   coalesce(c.description, '') AS description
            ORDER BY id
            """,
            r => new CategoryDto(
                GetText(r, "id"),
                GetText(r, "name"),
                GetText(r, "description")));
    }

    // 3. Tim kiem san pham.
    public Task<List<ProductDto>> GetProductsAsync(
        string? keyword,
        string? categoryId,
        int limit)
    {
        return QueryAsync(
            """
            MATCH (p:Product)
            OPTIONAL MATCH (p)-[:BELONGS_TO]->(c:Category)

            WITH p, c
            WHERE (
                $keyword IS NULL
                OR toLower(coalesce(p.name, ''))
                    CONTAINS toLower($keyword)
                OR toLower(coalesce(p.description, ''))
                    CONTAINS toLower($keyword)
                OR toLower(coalesce(p.brand, ''))
                    CONTAINS toLower($keyword)
            )
            AND (
                $categoryId IS NULL
                OR c.id = $categoryId
            )

            RETURN coalesce(p.id, '') AS id,
                   coalesce(p.name, '') AS name,
                   coalesce(p.brand, '') AS brand,
                   coalesce(p.description, '') AS description,
                   toFloat(coalesce(p.price, 0)) AS price,
                   toInteger(coalesce(p.stock, 0)) AS stock,
                   c.id AS categoryId,
                   c.name AS categoryName

            ORDER BY id
            LIMIT $limit
            """,
            MapProduct,
            new
            {
                keyword = string.IsNullOrWhiteSpace(keyword)
                    ? null : keyword.Trim(),
                categoryId = string.IsNullOrWhiteSpace(categoryId)
                    ? null : categoryId.Trim(),
                limit
            });
    }

    // 4. Lay chi tiet san pham.
    public async Task<ProductDto?> GetProductAsync(string id)
    {
        var rows = await QueryAsync(
            """
        MATCH (p:Product {id:$id})
        OPTIONAL MATCH (p)-[:BELONGS_TO]->(c:Category)

        RETURN coalesce(p.id, '') AS id,
               coalesce(p.name, '') AS name,
               coalesce(p.brand, '') AS brand,
               coalesce(p.description, '') AS description,
               toFloat(coalesce(p.price, 0)) AS price,
               toInteger(coalesce(p.stock, 0)) AS stock,
               c.id AS categoryId,
               c.name AS categoryName,
               coalesce(p.imageUrl, '') AS imageUrl
        """,
            MapProduct,
            new { id });

        return rows.FirstOrDefault();
    }

    private static ProductDto MapProduct(IRecord r)
    {
        var categoryId = r["categoryId"];
        var categoryName = r["categoryName"];

        return new ProductDto(
            GetText(r, "id"),
            GetText(r, "name"),
            GetText(r, "brand"),
            GetText(r, "description"),
            GetDouble(r, "price"),
            checked((int)GetLong(r, "stock")),
            categoryId is null ? null : categoryId.As<string>(),
            categoryName is null ? null : categoryName.As<string>(),
            GetText(r, "imageUrl"));
    }

    // 5. Ghi nhan luot xem san pham.
    public async Task<bool> RecordViewAsync(
        string customerId,
        string productId,
        string? sessionId)
    {
        var rows = await QueryAsync(
            """
            MATCH (c:Customer {id:$customerId})
            MATCH (p:Product {id:$productId})

            CREATE (c)-[:VIEWED {
                sessionId:$sessionId,
                viewedAt:datetime()
            }]->(p)

            RETURN 1 AS saved
            """,
            r => GetLong(r, "saved"),
            new
            {
                customerId,
                productId,
                sessionId = string.IsNullOrWhiteSpace(sessionId)
                    ? Guid.NewGuid().ToString("N")
                    : sessionId.Trim()
            });

        return rows.Count == 1;
    }

    // 6. Ghi nhan mua hang.
    public async Task<bool> RecordPurchaseAsync(
        string customerId,
        string productId,
        string? orderId,
        int quantity)
    {
        if (quantity < 1)
        {
            throw new ArgumentOutOfRangeException(
                nameof(quantity),
                "So luong mua phai lon hon 0.");
        }

        var rows = await QueryAsync(
            """
            MATCH (c:Customer {id:$customerId})
            MATCH (p:Product {id:$productId})

            CREATE (c)-[:BOUGHT {
                orderId:$orderId,
                quantity:$quantity,
                purchasedAt:datetime()
            }]->(p)

            RETURN 1 AS saved
            """,
            r => GetLong(r, "saved"),
            new
            {
                customerId,
                productId,
                orderId = string.IsNullOrWhiteSpace(orderId)
                    ? Guid.NewGuid().ToString("N")
                    : orderId.Trim(),
                quantity
            });

        return rows.Count == 1;
    }

    // 7. Goi y san pham dua tren khach hang co hanh vi mua chung.
    public Task<List<RecommendationDto>> GetRecommendationsAsync(
        string customerId,
        int limit)
    {
        return QueryAsync(
            """
            MATCH (target:Customer {id:$customerId})
                  -[:BOUGHT]->(shared:Product)
                  <-[:BOUGHT]-(supporter:Customer)
                  -[:BOUGHT]->(recommended:Product)

            WHERE target <> supporter
              AND NOT EXISTS {
                  MATCH (target)-[:BOUGHT]->(recommended)
              }

            WITH recommended,
                 count(DISTINCT supporter) AS supportCount,
                 count(DISTINCT shared) AS sharedProductCount,
                 collect(DISTINCT supporter.id)[0..5]
                    AS supportingCustomers,
                 collect(DISTINCT shared.name)[0..5]
                    AS sharedPurchaseEvidence

            RETURN coalesce(recommended.id, '') AS productId,
                   coalesce(recommended.name, '') AS productName,
                   coalesce(recommended.brand, '') AS brand,
                   toFloat(coalesce(recommended.price, 0)) AS price,
                   supportCount,
                   sharedProductCount,
                   supportingCustomers,
                   sharedPurchaseEvidence,
                   'Khach hang co lich su mua chung da mua san pham nay'
                    AS reason

            ORDER BY supportCount DESC,
                     sharedProductCount DESC,
                     productId
            LIMIT $limit
            """,
            MapRecommendation,
            new { customerId, limit });
    }

    private static RecommendationDto MapRecommendation(IRecord r)
    {
        return new RecommendationDto(
            GetText(r, "productId"),
            GetText(r, "productName"),
            GetText(r, "brand"),
            GetDouble(r, "price"),
            GetLong(r, "supportCount"),
            GetLong(r, "sharedProductCount"),
            GetStringList(r, "supportingCustomers"),
            GetStringList(r, "sharedPurchaseEvidence"),
            GetText(r, "reason"));
    }

    // 8. Giai thich ly do goi y.
    public async Task<object?> ExplainRecommendationAsync(
        string customerId,
        string productId)
    {
        var rows = await QueryAsync(
            """
            MATCH (target:Customer {id:$customerId})
                  -[:BOUGHT]->(shared:Product)
                  <-[:BOUGHT]-(supporter:Customer)
                  -[:BOUGHT]->(recommended:Product {id:$productId})

            WHERE target <> supporter
              AND NOT EXISTS {
                  MATCH (target)-[:BOUGHT]->(recommended)
              }

            RETURN recommended.id AS productId,
                   coalesce(recommended.name, '') AS productName,
                   count(DISTINCT supporter) AS supportCount,
                   collect(DISTINCT supporter.id)[0..5]
                    AS supportingCustomers,
                   collect(DISTINCT shared.name)[0..5]
                    AS sharedPurchaseEvidence
            """,
            r => new
            {
                productId = GetText(r, "productId"),
                productName = GetText(r, "productName"),
                supportCount = GetLong(r, "supportCount"),
                supportingCustomers =
                    GetStringList(r, "supportingCustomers"),
                sharedPurchaseEvidence =
                    GetStringList(r, "sharedPurchaseEvidence")
            },
            new { customerId, productId });

        return rows.FirstOrDefault();
    }

    // 9. Goi y mua kem theo cung don hang.
    public Task<List<object>> GetFrequentlyBoughtTogetherAsync(
        string productId,
        int limit)
    {
        return QueryAsync(
            """
            MATCH (:Customer)-[r1:BOUGHT]->(base:Product {id:$productId})
            MATCH (:Customer)-[r2:BOUGHT]->(other:Product)

            WHERE base <> other
              AND r1.orderId IS NOT NULL
              AND r1.orderId = r2.orderId

            WITH other, count(DISTINCT r1.orderId) AS orderCount

            RETURN coalesce(other.id, '') AS productId,
                   coalesce(other.name, '') AS productName,
                   coalesce(other.brand, '') AS brand,
                   toFloat(coalesce(other.price, 0)) AS price,
                   orderCount,
                   'Hai san pham xuat hien trong cung don hang' AS reason

            ORDER BY orderCount DESC, productId
            LIMIT $limit
            """,
            r => (object)new
            {
                productId = GetText(r, "productId"),
                productName = GetText(r, "productName"),
                brand = GetText(r, "brand"),
                price = GetDouble(r, "price"),
                orderCount = GetLong(r, "orderCount"),
                reason = GetText(r, "reason")
            },
            new { productId, limit });
    }

    // ============================================================
    // FEED GOI Y DA NGUON - PHUC VU TRANG CHU VA CHI TIET SAN PHAM
    //
    // Nguon:
    // 1. Collaborative Filtering tu BOUGHT
    // 2. Khach hang co hanh vi VIEWED tuong tu
    // 3. San pham thuong duoc mua cung orderId
    // 4. Quan he COMPLEMENTARY_TO / SIMILAR_FUNCTION / ALTERNATIVE_TO
    // 5. Cung danh muc voi san pham dang xem
    // 6. Cung thuong hieu voi san pham dang xem
    // 7. Cung danh muc voi lich su xem/mua
    // 8. Pho bien - nguon du phong
    // ============================================================

    public async Task<List<RecommendationFeedItemDto>>
        GetRecommendationFeedAsync(
            string customerId,
            string? contextProductId,
            int offset,
            int limit,
            int seed
        )


    {
        contextProductId =
            string.IsNullOrWhiteSpace(contextProductId)
                ? null
                : contextProductId.Trim();

        offset = Math.Max(0, offset);
        limit = Math.Clamp(limit, 1, 24);

        var parameters = new
        {
            customerId,
            contextProductId,
            sourceLimit = 120
        };

        // NGUON 1: COLLABORATIVE FILTERING TU LICH SU MUA.
        var collaborative = await QueryAsync(
            """
            MATCH (target:Customer {id:$customerId})
                  -[:BOUGHT]->(shared:Product)
                  <-[:BOUGHT]-(supporter:Customer)
                  -[:BOUGHT]->(p:Product)

            WHERE supporter.id <> target.id
              AND NOT EXISTS {
                  MATCH (target)-[:BOUGHT]->(p)
              }
              AND NOT EXISTS {
                  MATCH (target)-[:VIEWED]->(p)
              }
              AND ($contextProductId IS NULL
                   OR p.id <> $contextProductId)

            WITH p,
                 count(DISTINCT supporter) AS supportCount,
                 count(DISTINCT shared) AS sharedProductCount,
                 collect(DISTINCT shared.name)[0..5] AS evidence

            OPTIONAL MATCH (p)-[:BELONGS_TO]->(cat:Category)

            RETURN p.id AS productId,
                   coalesce(p.name, '') AS productName,
                   coalesce(p.brand, '') AS brand,
                   toFloat(coalesce(p.price, 0)) AS price,
                   toInteger(coalesce(p.stock, 0)) AS stock,
                   coalesce(cat.id, p.categoryId, '') AS categoryId,
                   coalesce(cat.name, '') AS categoryName,
                   coalesce(p.imageUrl, '') AS imageUrl,

                   'COLLABORATIVE_FILTERING' AS sourceType,
                   'Dựa trên lịch sử mua' AS sourceLabel,
                   'Khách hàng có lịch sử mua chung cũng mua sản phẩm này'
                       AS reason,

                   toInteger(
                       supportCount * 10 + sharedProductCount
                   ) AS score,

                   supportCount AS supportCount,
                   sharedProductCount AS sharedProductCount,
                   evidence AS evidence

            ORDER BY score DESC, productId ASC
            LIMIT $sourceLimit
            """,
            MapFeedItem,
            parameters);

        // NGUON 2: KHACH HANG CO LICH SU XEM TUONG TU.
        var similarViews = await QueryAsync(
            """
            MATCH (target:Customer {id:$customerId})
                  -[:VIEWED]->(shared:Product)
                  <-[:VIEWED]-(supporter:Customer)
                  -[:VIEWED]->(p:Product)

            WHERE supporter.id <> target.id
              AND p.id <> shared.id
              AND NOT EXISTS {
                  MATCH (target)-[:BOUGHT]->(p)
              }
              AND NOT EXISTS {
                  MATCH (target)-[:VIEWED]->(p)
              }
              AND ($contextProductId IS NULL
                   OR p.id <> $contextProductId)

            WITH p,
                 count(DISTINCT supporter) AS supportCount,
                 count(DISTINCT shared) AS sharedProductCount,
                 collect(DISTINCT shared.name)[0..5] AS evidence

            OPTIONAL MATCH (p)-[:BELONGS_TO]->(cat:Category)

            RETURN p.id AS productId,
                   coalesce(p.name, '') AS productName,
                   coalesce(p.brand, '') AS brand,
                   toFloat(coalesce(p.price, 0)) AS price,
                   toInteger(coalesce(p.stock, 0)) AS stock,
                   coalesce(cat.id, p.categoryId, '') AS categoryId,
                   coalesce(cat.name, '') AS categoryName,
                   coalesce(p.imageUrl, '') AS imageUrl,

                   'VIEWED_SIMILAR' AS sourceType,
                   'Dựa trên lượt xem' AS sourceLabel,
                   'Khách hàng có lịch sử xem tương tự cũng xem sản phẩm này'
                       AS reason,

                   toInteger(
                       supportCount * 8 + sharedProductCount
                   ) AS score,

                   supportCount AS supportCount,
                   sharedProductCount AS sharedProductCount,
                   evidence AS evidence

            ORDER BY score DESC, productId ASC
            LIMIT $sourceLimit
            """,
            MapFeedItem,
            parameters);

        // NGUON 3: SAN PHAM THUONG DUOC MUA CUNG DON HANG.
        var boughtTogether = await QueryAsync(
            """
            MATCH (orderCustomer:Customer)-[b1:BOUGHT]->
                  (base:Product {id:$contextProductId}),
                  (orderCustomer)-[b2:BOUGHT]->(p:Product)

            WHERE base <> p
              AND b1.orderId IS NOT NULL
              AND b1.orderId = b2.orderId
              AND NOT EXISTS {
                  MATCH (target:Customer {id:$customerId})
                        -[:BOUGHT]->(p)
              }
              AND NOT EXISTS {
                  MATCH (target:Customer {id:$customerId})
                        -[:VIEWED]->(p)
              }

            WITH p,
                 count(DISTINCT b1.orderId) AS orderCount,
                 collect(DISTINCT b1.orderId)[0..5] AS evidence

            OPTIONAL MATCH (p)-[:BELONGS_TO]->(cat:Category)

            RETURN p.id AS productId,
                   coalesce(p.name, '') AS productName,
                   coalesce(p.brand, '') AS brand,
                   toFloat(coalesce(p.price, 0)) AS price,
                   toInteger(coalesce(p.stock, 0)) AS stock,
                   coalesce(cat.id, p.categoryId, '') AS categoryId,
                   coalesce(cat.name, '') AS categoryName,
                   coalesce(p.imageUrl, '') AS imageUrl,

                   'CO_PURCHASE' AS sourceType,
                   'Thường được mua cùng' AS sourceLabel,
                   'Sản phẩm xuất hiện cùng đơn hàng với sản phẩm bạn đang xem'
                       AS reason,

                   toInteger(orderCount * 15) AS score,
                   0 AS supportCount,
                   0 AS sharedProductCount,
                   evidence AS evidence

            ORDER BY score DESC, productId ASC
            LIMIT $sourceLimit
            """,
            MapFeedItem,
            parameters);

        // NGUON 4: QUAN HE SAN PHAM DA LUU TRONG NEO4J.
        var relatedByGraph = await QueryAsync(
            """
            MATCH (base:Product {id:$contextProductId})
                  -[rel:COMPLEMENTARY_TO|SIMILAR_FUNCTION|ALTERNATIVE_TO]-
                  (p:Product)

            WHERE base <> p
              AND NOT EXISTS {
                  MATCH (target:Customer {id:$customerId})
                        -[:BOUGHT]->(p)
              }
              AND NOT EXISTS {
                  MATCH (target:Customer {id:$customerId})
                        -[:VIEWED]->(p)
              }

            WITH base, p, rel,
                 CASE type(rel)
                     WHEN 'COMPLEMENTARY_TO' THEN 90
                     WHEN 'SIMILAR_FUNCTION' THEN 80
                     ELSE 70
                 END AS graphScore

            OPTIONAL MATCH (p)-[:BELONGS_TO]->(cat:Category)

            RETURN p.id AS productId,
                   coalesce(p.name, '') AS productName,
                   coalesce(p.brand, '') AS brand,
                   toFloat(coalesce(p.price, 0)) AS price,
                   toInteger(coalesce(p.stock, 0)) AS stock,
                   coalesce(cat.id, p.categoryId, '') AS categoryId,
                   coalesce(cat.name, '') AS categoryName,
                   coalesce(p.imageUrl, '') AS imageUrl,

                   type(rel) AS sourceType,

                   CASE type(rel)
                       WHEN 'COMPLEMENTARY_TO'
                           THEN 'Sản phẩm bổ trợ'
                       WHEN 'SIMILAR_FUNCTION'
                           THEN 'Cùng công dụng'
                       ELSE 'Sản phẩm thay thế'
                   END AS sourceLabel,

                   CASE type(rel)
                       WHEN 'COMPLEMENTARY_TO'
                           THEN 'Có quan hệ bổ trợ được lưu trong Neo4j'
                       WHEN 'SIMILAR_FUNCTION'
                           THEN 'Có quan hệ cùng công dụng được lưu trong Neo4j'
                       ELSE 'Có quan hệ thay thế được lưu trong Neo4j'
                   END AS reason,

                   toInteger(graphScore) AS score,
                   0 AS supportCount,
                   0 AS sharedProductCount,
                   [coalesce(base.name, base.id, '')] AS evidence

            ORDER BY score DESC, productId ASC
            LIMIT $sourceLimit
            """,
            MapFeedItem,
            parameters);

        // NGUON 5: CUNG DANH MUC VOI SAN PHAM DANG XEM.
        var sameCategory = await QueryAsync(
            """
            MATCH (base:Product {id:$contextProductId})
                  -[:BELONGS_TO]->(cat:Category)
                  <-[:BELONGS_TO]-(p:Product)

            WHERE base <> p
              AND NOT EXISTS {
                  MATCH (target:Customer {id:$customerId})
                        -[:BOUGHT]->(p)
              }
              AND NOT EXISTS {
                  MATCH (target:Customer {id:$customerId})
                        -[:VIEWED]->(p)
              }

            RETURN p.id AS productId,
                   coalesce(p.name, '') AS productName,
                   coalesce(p.brand, '') AS brand,
                   toFloat(coalesce(p.price, 0)) AS price,
                   toInteger(coalesce(p.stock, 0)) AS stock,
                   coalesce(cat.id, p.categoryId, '') AS categoryId,
                   coalesce(cat.name, '') AS categoryName,
                   coalesce(p.imageUrl, '') AS imageUrl,

                   'SAME_CATEGORY' AS sourceType,
                   'Cùng danh mục' AS sourceLabel,
                   'Cùng danh mục với sản phẩm bạn đang xem' AS reason,

                   60 AS score,
                   0 AS supportCount,
                   0 AS sharedProductCount,
                   [coalesce(cat.name, cat.id, '')] AS evidence

            ORDER BY productId ASC
            LIMIT $sourceLimit
            """,
            MapFeedItem,
            parameters);

        // NGUON 6: CUNG THUONG HIEU VOI SAN PHAM DANG XEM.
        var sameBrand = await QueryAsync(
            """
            MATCH (base:Product {id:$contextProductId}),
                  (p:Product)

            WHERE base <> p
              AND base.brand IS NOT NULL
              AND trim(toString(base.brand)) <> ''
              AND p.brand = base.brand
              AND NOT EXISTS {
                  MATCH (target:Customer {id:$customerId})
                        -[:BOUGHT]->(p)
              }
              AND NOT EXISTS {
                  MATCH (target:Customer {id:$customerId})
                        -[:VIEWED]->(p)
              }

            OPTIONAL MATCH (p)-[:BELONGS_TO]->(cat:Category)

            RETURN p.id AS productId,
                   coalesce(p.name, '') AS productName,
                   coalesce(p.brand, '') AS brand,
                   toFloat(coalesce(p.price, 0)) AS price,
                   toInteger(coalesce(p.stock, 0)) AS stock,
                   coalesce(cat.id, p.categoryId, '') AS categoryId,
                   coalesce(cat.name, '') AS categoryName,
                   coalesce(p.imageUrl, '') AS imageUrl,

                   'SAME_BRAND' AS sourceType,
                   'Cùng thương hiệu' AS sourceLabel,
                   'Có cùng thương hiệu với sản phẩm bạn đang xem' AS reason,

                   50 AS score,
                   0 AS supportCount,
                   0 AS sharedProductCount,
                   [coalesce(base.brand, '')] AS evidence

            ORDER BY productId ASC
            LIMIT $sourceLimit
            """,
            MapFeedItem,
            parameters);

        // NGUON 7: DANH MUC TU LICH SU VIEWED / BOUGHT.
        var historyCategory = await QueryAsync(
            """
            MATCH (target:Customer {id:$customerId})
                  -[:VIEWED|BOUGHT]->(seed:Product)
                  -[:BELONGS_TO]->(cat:Category)
                  <-[:BELONGS_TO]-(p:Product)

            WHERE seed <> p
              AND NOT EXISTS {
                  MATCH (target)-[:BOUGHT]->(p)
              }
              AND NOT EXISTS {
                  MATCH (target)-[:VIEWED]->(p)
              }
              AND ($contextProductId IS NULL
                   OR p.id <> $contextProductId)

            WITH p,
                 count(DISTINCT seed) AS historyOverlap,
                 collect(DISTINCT seed.name)[0..5] AS evidence

            OPTIONAL MATCH (p)-[:BELONGS_TO]->(cat2:Category)

            RETURN p.id AS productId,
                   coalesce(p.name, '') AS productName,
                   coalesce(p.brand, '') AS brand,
                   toFloat(coalesce(p.price, 0)) AS price,
                   toInteger(coalesce(p.stock, 0)) AS stock,
                   coalesce(cat2.id, p.categoryId, '') AS categoryId,
                   coalesce(cat2.name, '') AS categoryName,
                   coalesce(p.imageUrl, '') AS imageUrl,

                   'HISTORY_CATEGORY' AS sourceType,
                   'Theo lịch sử của bạn' AS sourceLabel,
                   'Thuộc nhóm danh mục liên quan đến sản phẩm bạn đã xem hoặc mua'
                       AS reason,

                   toInteger(40 + historyOverlap) AS score,
                   0 AS supportCount,
                   historyOverlap AS sharedProductCount,
                   evidence AS evidence

            ORDER BY score DESC, productId ASC
            LIMIT $sourceLimit
            """,
            MapFeedItem,
            parameters);

        // NGUON 8: SAN PHAM PHO BIEN LAM NGUON DU PHONG.
        var popular = await QueryAsync(
            """
            MATCH (p:Product)

            WHERE ($contextProductId IS NULL
                   OR p.id <> $contextProductId)
              AND NOT EXISTS {
                  MATCH (target:Customer {id:$customerId})
                        -[:BOUGHT]->(p)
              }
              AND NOT EXISTS {
                  MATCH (target:Customer {id:$customerId})
                        -[:VIEWED]->(p)
              }

            OPTIONAL MATCH (:Customer)-[b:BOUGHT]->(p)
            WITH p, count(DISTINCT b) AS purchaseCount

            OPTIONAL MATCH (:Customer)-[v:VIEWED]->(p)
            WITH p, purchaseCount, count(DISTINCT v) AS viewCount

            OPTIONAL MATCH (p)-[:BELONGS_TO]->(cat:Category)

            RETURN p.id AS productId,
                   coalesce(p.name, '') AS productName,
                   coalesce(p.brand, '') AS brand,
                   toFloat(coalesce(p.price, 0)) AS price,
                   toInteger(coalesce(p.stock, 0)) AS stock,
                   coalesce(cat.id, p.categoryId, '') AS categoryId,
                   coalesce(cat.name, '') AS categoryName,
                   coalesce(p.imageUrl, '') AS imageUrl,

                   'POPULAR' AS sourceType,
                   'Phổ biến' AS sourceLabel,
                   'Xếp hạng dựa trên số lượt mua và lượt xem trong Neo4j'
                       AS reason,

                   toInteger(purchaseCount * 3 + viewCount) AS score,
                   purchaseCount AS supportCount,
                   0 AS sharedProductCount,
                   [] AS evidence

            ORDER BY score DESC, productId ASC
            LIMIT $sourceLimit
            """,
            MapFeedItem,
            parameters);

        // GOM CAC NGUON VA LOAI BO SAN PHAM TRUNG NHAU.
        var buckets = new List<List<RecommendationFeedItemDto>>
        {
            collaborative,
            similarViews,
            boughtTogether,
            relatedByGraph,
            historyCategory,
            sameCategory,
            sameBrand,
            popular
        };

        var seen = new HashSet<string>(
            StringComparer.OrdinalIgnoreCase);

        var uniqueBuckets = new List<List<RecommendationFeedItemDto>>();

        foreach (var bucket in buckets)
        {
            var unique = new List<RecommendationFeedItemDto>();

            foreach (var item in bucket)
            {
                if (string.IsNullOrWhiteSpace(item.ProductId))
                {
                    continue;
                }

                if (seen.Add(item.ProductId))
                {
                    unique.Add(item);
                }
            }

            uniqueBuckets.Add(unique);
        }

        // TRON LUAN PHIEN CAC NGUON.
        // Cung seed thi thu tu on dinh khi phan trang.
        // Doi seed thi nguon duoc hien len truoc se thay doi.
        var merged = new List<RecommendationFeedItemDto>();

        var bucketCount = uniqueBuckets.Count;

        var start = (int)(
            ((long)seed % bucketCount + bucketCount) % bucketCount);

        for (var round = 0; ; round++)
        {
            var added = false;

            for (var step = 0; step < bucketCount; step++)
            {
                var index = (start + step) % bucketCount;
                var bucket = uniqueBuckets[index];

                if (round >= bucket.Count)
                {
                    continue;
                }

                merged.Add(bucket[round]);
                added = true;
            }

            if (!added)
            {
                break;
            }
        }

        return merged
            .Where(item => item.Stock > 0)
            .Where(item =>
                string.IsNullOrWhiteSpace(contextProductId) ||
                !string.Equals(
                    item.ProductId,
                    contextProductId,
                    StringComparison.OrdinalIgnoreCase))
            .Skip(offset)
            .Take(limit)
            .ToList();
    }

    private static RecommendationFeedItemDto MapFeedItem(IRecord r)
    {
        return new RecommendationFeedItemDto(
            GetText(r, "productId"),
            GetText(r, "productName"),
            GetText(r, "brand"),
            GetDouble(r, "price"),
            checked((int)GetLong(r, "stock")),
            GetText(r, "categoryId"),
            GetText(r, "categoryName"),
            GetText(r, "imageUrl"),
            GetText(r, "sourceType"),
            GetText(r, "sourceLabel"),
            GetText(r, "reason"),
            GetLong(r, "score"),
            GetLong(r, "supportCount"),
            GetLong(r, "sharedProductCount"),
            GetStringList(r, "evidence")
        );
    }


    // ============================================================
    // GIO HANG DUOC LUU TREN NEO4J THEO TAI KHOAN
    // ============================================================

    public Task<List<CartLineDto>> GetCartAsync(string customerId)
    {
        return QueryAsync(
            """
            MATCH (c:Customer {id:$customerId})-[r:IN_CART]->(p:Product)
            RETURN coalesce(p.id, '') AS productId,
                   coalesce(p.name, '') AS productName,
                   coalesce(p.brand, '') AS brand,
                   toFloat(coalesce(p.price, 0)) AS price,
                   toInteger(coalesce(p.stock, 0)) AS stock,
                   toInteger(coalesce(r.quantity, 1)) AS quantity,
                   coalesce(p.imageUrl, '') AS imageUrl
            ORDER BY productId
            """,
            r => new CartLineDto(
                GetText(r, "productId"),
                GetText(r, "productName"),
                GetText(r, "brand"),
                GetDouble(r, "price"),
                checked((int)GetLong(r, "stock")),
                checked((int)GetLong(r, "quantity")),
                GetText(r, "imageUrl")),
            new { customerId });
    }

    public async Task<bool> SetCartItemAsync(
        string customerId,
        string productId,
        int quantity)
    {
        if (quantity < 1)
        {
            throw new ArgumentOutOfRangeException(
                nameof(quantity), "So luong phai lon hon 0.");
        }

        var rows = await QueryAsync(
            """
            MATCH (c:Customer {id:$customerId})
            MATCH (p:Product {id:$productId})
            WITH c, p
            WHERE toInteger(coalesce(p.stock, 0)) >= $quantity
            MERGE (c)-[r:IN_CART]->(p)
            SET r.quantity = $quantity,
                r.updatedAt = datetime()
            CREATE (c)-[:ADDED_TO_CART {
                quantity:$quantity,
                addedAt:datetime()
            }]->(p)
            RETURN 1 AS saved
            """,
            r => GetLong(r, "saved"),
            new { customerId, productId, quantity });

        return rows.Count > 0;
    }

    public async Task<bool> RemoveCartItemAsync(
        string customerId,
        string productId)
    {
        var rows = await QueryAsync(
            """
            MATCH (c:Customer {id:$customerId})-[r:IN_CART]->(p:Product {id:$productId})
            WITH c, p, r, toInteger(coalesce(r.quantity, 1)) AS quantity
            DELETE r
            CREATE (c)-[:REMOVED_FROM_CART {
                quantity:quantity,
                removedAt:datetime()
            }]->(p)
            RETURN 1 AS saved
            """,
            r => GetLong(r, "saved"),
            new { customerId, productId });

        return rows.Count > 0;
    }

    // Lich su xem, them gio, xoa khoi gio va mua hang.
    public Task<List<HistoryEventDto>> GetCustomerHistoryAsync(
        string customerId,
        int limit)
    {
        return QueryAsync(
            """
            MATCH (c:Customer {id:$customerId})
            CALL {
                WITH c
                MATCH (c)-[r:VIEWED]->(p:Product)
                RETURN 'VIEWED' AS type,
                       p.id AS productId,
                       coalesce(p.name, '') AS productName,
                       1 AS quantity,
                       '' AS orderId,
                       toString(r.viewedAt) AS eventAt

                UNION ALL

                WITH c
                MATCH (c)-[r:ADDED_TO_CART]->(p:Product)
                RETURN 'ADDED_TO_CART' AS type,
                       p.id AS productId,
                       coalesce(p.name, '') AS productName,
                       toInteger(coalesce(r.quantity, 1)) AS quantity,
                       '' AS orderId,
                       toString(r.addedAt) AS eventAt

                UNION ALL

                WITH c
                MATCH (c)-[r:REMOVED_FROM_CART]->(p:Product)
                RETURN 'REMOVED_FROM_CART' AS type,
                       p.id AS productId,
                       coalesce(p.name, '') AS productName,
                       toInteger(coalesce(r.quantity, 1)) AS quantity,
                       '' AS orderId,
                       toString(r.removedAt) AS eventAt

                UNION ALL

                WITH c
                MATCH (c)-[r:BOUGHT]->(p:Product)
                RETURN 'PURCHASED' AS type,
                       p.id AS productId,
                       coalesce(p.name, '') AS productName,
                       toInteger(coalesce(r.quantity, 1)) AS quantity,
                       coalesce(r.orderId, '') AS orderId,
                       toString(r.purchasedAt) AS eventAt
            }
            RETURN type,
                   coalesce(productId, '') AS productId,
                   coalesce(productName, '') AS productName,
                   toInteger(coalesce(quantity, 1)) AS quantity,
                   coalesce(orderId, '') AS orderId,
                   coalesce(eventAt, '') AS eventAt
            ORDER BY eventAt DESC
            LIMIT $limit
            """,
            r => new HistoryEventDto(
                GetText(r, "type"),
                GetText(r, "productId"),
                GetText(r, "productName"),
                checked((int)GetLong(r, "quantity")),
                GetText(r, "orderId"),
                GetText(r, "eventAt")),
            new { customerId, limit = Math.Clamp(limit, 1, 200) });
    }

    // Checkout demo gom ca don vao mot transaction Neo4j.
    // Neu bat ky mat hang nao khong du ton kho, toan bo transaction rollback.
    public async Task<CheckoutResultDto> CheckoutAsync(string customerId)
    {
        var orderId = $"ORD-{Guid.NewGuid():N}".ToUpperInvariant();

        await using var session = _driver.AsyncSession(
            options => options.WithDatabase(_database));

        return await session.ExecuteWriteAsync(async tx =>
        {
            var cartCursor = await tx.RunAsync(
                """
                MATCH (c:Customer {id:$customerId})-[r:IN_CART]->(p:Product)
                RETURN p.id AS productId,
                       toInteger(coalesce(r.quantity, 0)) AS quantity,
                       toInteger(coalesce(p.stock, 0)) AS stock,
                       toFloat(coalesce(p.price, 0)) AS price
                ORDER BY productId
                """,
                new { customerId });

            var cartRows = await cartCursor.ToListAsync();
            if (cartRows.Count == 0)
            {
                throw new InvalidOperationException("Gio hang dang trong.");
            }

            var items = cartRows.Select(r => new
            {
                ProductId = r["productId"].As<string>(),
                Quantity = checked((int)r["quantity"].As<long>()),
                Stock = checked((int)r["stock"].As<long>()),
                Price = r["price"].As<double>()
            }).ToList();

            foreach (var item in items)
            {
                if (item.Quantity < 1 || item.Stock < item.Quantity)
                {
                    throw new InvalidOperationException(
                        $"San pham {item.ProductId} khong du ton kho. Gio hang chua bi xoa.");
                }
            }

            var total = items.Sum(item => item.Price * item.Quantity);
            var orderCursor = await tx.RunAsync(
                """
                MATCH (c:Customer {id:$customerId})
                CREATE (o:Order {
                    id:$orderId,
                    customerId:$customerId,
                    status:'PAID_DEMO',
                    createdAt:datetime(),
                    total:$total
                })
                CREATE (c)-[:PLACED]->(o)
                RETURN o.id AS orderId
                """,
                new { customerId, orderId, total });
            var createdOrder = await orderCursor.ToListAsync();
            if (createdOrder.Count == 0)
            {
                throw new InvalidOperationException("Khong tim thay tai khoan khach hang.");
            }

            foreach (var item in items)
            {
                var itemCursor = await tx.RunAsync(
                    """
                    MATCH (c:Customer {id:$customerId})-[cart:IN_CART]->(p:Product {id:$productId})
                    MATCH (o:Order {id:$orderId})
                    WHERE toInteger(coalesce(p.stock, 0)) >= $quantity
                      AND toInteger(coalesce(cart.quantity, 0)) = $quantity
                    SET p.stock = toInteger(coalesce(p.stock, 0)) - $quantity
                    CREATE (c)-[:BOUGHT {
                        orderId:$orderId,
                        quantity:$quantity,
                        purchasedAt:datetime()
                    }]->(p)
                    CREATE (o)-[:CONTAINS {
                        quantity:$quantity,
                        unitPrice:$unitPrice
                    }]->(p)
                    DELETE cart
                    RETURN 1 AS saved
                    """,
                    new
                    {
                        customerId,
                        productId = item.ProductId,
                        orderId,
                        quantity = item.Quantity,
                        unitPrice = item.Price
                    });

                var savedRows = await itemCursor.ToListAsync();
                if (savedRows.Count == 0)
                {
                    throw new InvalidOperationException(
                        $"Khong the hoan tat don hang do ton kho cua san pham {item.ProductId} da thay doi. Gio hang duoc giu lai.");
                }
            }

            return new CheckoutResultDto(
                orderId,
                items.Count,
                total,
                "PAID_DEMO");
        });
    }

}