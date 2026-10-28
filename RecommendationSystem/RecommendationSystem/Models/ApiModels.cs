namespace RecommendationSystem.Models;

// Thong tin danh muc san pham.
public sealed record CategoryDto(
    string Id,
    string Name,
    string Description
);

// Thong tin san pham.
public sealed record ProductDto(
    string Id,
    string Name,
    string Brand,
    string Description,
    double Price,
    int Stock,
    string? CategoryId,
    string? CategoryName,
    string? ImageUrl = null
);

// Du lieu ghi nhan luot xem.
public sealed record ViewRequest(
    string? SessionId
);

// Du lieu ghi nhan mua hang cu (giu lai de tuong thich API hien co).
public sealed record PurchaseRequest(
    string? OrderId,
    int Quantity = 1
);

// Ket qua goi y san pham.
public sealed record RecommendationDto(
    string ProductId,
    string ProductName,
    string Brand,
    double Price,
    long SupportCount,
    long SharedProductCount,
    IReadOnlyList<string> SupportingCustomers,
    IReadOnlyList<string> SharedPurchaseEvidence,
    string Reason
);

// San pham trong feed goi y da nguon.
public sealed record RecommendationFeedItemDto(
    string ProductId,
    string ProductName,
    string Brand,
    double Price,
    int Stock,
    string CategoryId,
    string CategoryName,
    string ImageUrl,
    string SourceType,
    string SourceLabel,
    string Reason,
    long Score,
    long SupportCount,
    long SharedProductCount,
    IReadOnlyList<string> Evidence
);

// Mot dong san pham da luu trong gio hang.
public sealed record CartLineDto(
    string ProductId,
    string ProductName,
    string Brand,
    double Price,
    int Stock,
    int Quantity,
    string ImageUrl
);

// Du lieu them/cap nhat so luong trong gio hang.
public sealed record CartItemRequest(
    int Quantity
);

// Su kien trong lich su hoat dong cua khach hang.
public sealed record HistoryEventDto(
    string Type,
    string ProductId,
    string ProductName,
    int Quantity,
    string OrderId,
    string EventAt
);

// Ket qua checkout demo.
public sealed record CheckoutResultDto(
    string OrderId,
    int ItemCount,
    double Total,
    string Status
);
