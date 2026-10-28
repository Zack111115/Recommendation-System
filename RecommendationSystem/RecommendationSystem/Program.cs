using Neo4j.Driver;
using RecommendationSystem.Models;
using RecommendationSystem.Services;

var builder = WebApplication.CreateBuilder(args);

// Swagger.
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Cho phep Flutter Web goi API trong moi truong phat trien.
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

// Ket noi Neo4j.
builder.Services.AddSingleton<IDriver>(_ =>
{
    var config = builder.Configuration.GetSection("Neo4j");

    var uri = config["Uri"];
    var username = config["Username"] ?? "neo4j";
    var password = config["Password"];

    if (string.IsNullOrWhiteSpace(uri) ||
        uri.Contains("THAY_BANG_URI", StringComparison.OrdinalIgnoreCase))
    {
        throw new InvalidOperationException(
            "Hay dien URI Neo4j trong appsettings.json.");
    }

    if (string.IsNullOrWhiteSpace(password) ||
        password.Contains("THAY_BANG_MAT_KHAU", StringComparison.OrdinalIgnoreCase))
    {
        throw new InvalidOperationException(
            "Hay dien mat khau Neo4j trong appsettings.json.");
    }

    return GraphDatabase.Driver(
        uri,
        AuthTokens.Basic(username, password));
});

builder.Services.AddSingleton<RecommendationService>();

var app = builder.Build();

app.UseCors();
app.UseSwagger();
app.UseSwaggerUI();

// Trang goc.
app.MapGet("/", () => Results.Ok(new
{
    application = "RecommendationSystem",
    status = "running",
    swagger = "/swagger"
}));

// Kiem tra API va Neo4j.
app.MapGet(
    "/api/health",
    async (RecommendationService service) =>
    {
        try
        {
            return Results.Ok(
                await service.CheckConnectionAsync());
        }
        catch (Exception ex)
        {
            return Results.Problem(
                title: "Khong ket noi duoc Neo4j",
                detail: ex.Message,
                statusCode: 503);
        }
    });

// Lay danh muc.
app.MapGet(
    "/api/categories",
    async (RecommendationService service) =>
    {
        return Results.Ok(
            await service.GetCategoriesAsync());
    });

// Tim kiem va lay danh sach san pham.
app.MapGet(
    "/api/products",
    async (
        string? q,
        string? categoryId,
        int? limit,
        RecommendationService service) =>
    {
        return Results.Ok(
            await service.GetProductsAsync(
                q,
                categoryId,
                Math.Clamp(limit ?? 100, 1, 100)));
    });

// Chi tiet san pham.
app.MapGet(
    "/api/products/{id}",
    async (
        string id,
        RecommendationService service) =>
    {
        var product = await service.GetProductAsync(id);

        return product is null
            ? Results.NotFound(new
            {
                message = "Khong tim thay san pham.",
                productId = id
            })
            : Results.Ok(product);
    });

// Ghi nhan luot xem.
app.MapPost(
    "/api/customers/{customerId}/views/{productId}",
    async (
        string customerId,
        string productId,
        ViewRequest? request,
        RecommendationService service) =>
    {
        var saved = await service.RecordViewAsync(
            customerId,
            productId,
            request?.SessionId);

        if (!saved)
        {
            return Results.NotFound(new
            {
                message = "Khong tim thay customer hoac product."
            });
        }

        return Results.Ok(new
        {
            message = "Da ghi nhan luot xem.",
            customerId,
            productId
        });
    });

// Ghi nhan mua hang.
app.MapPost(
    "/api/customers/{customerId}/purchases/{productId}",
    async (
        string customerId,
        string productId,
        PurchaseRequest? request,
        RecommendationService service) =>
    {
        try
        {
            var saved = await service.RecordPurchaseAsync(
                customerId,
                productId,
                request?.OrderId,
                request?.Quantity ?? 1);

            if (!saved)
            {
                return Results.NotFound(new
                {
                    message = "Khong tim thay customer hoac product."
                });
            }

            return Results.Ok(new
            {
                message = "Da ghi nhan mua hang.",
                customerId,
                productId,
                orderId = request?.OrderId
            });
        }
        catch (ArgumentOutOfRangeException ex)
        {
            return Results.BadRequest(new
            {
                message = ex.Message
            });
        }
    });

// Goi y Collaborative Filtering cu.
app.MapGet(
    "/api/customers/{customerId}/recommendations",
    async (
        string customerId,
        int? limit,
        RecommendationService service) =>
    {
        return Results.Ok(
            await service.GetRecommendationsAsync(
                customerId,
                Math.Clamp(limit ?? 10, 1, 50)));
    });

// Feed goi y da nguon.
app.MapGet(
    "/api/customers/{customerId}/feed",
    async (
        string customerId,
        string? contextProductId,
        int? offset,
        int? limit,
        int? seed,
        RecommendationService service) =>
    {
        var result = await service.GetRecommendationFeedAsync(
            customerId,
            contextProductId,
            Math.Max(0, offset ?? 0),
            Math.Clamp(limit ?? 12, 1, 24),
            seed ?? 0);

        return Results.Ok(result);
    });

// Giai thich goi y.
app.MapGet(
    "/api/customers/{customerId}/recommendations/{productId}/explain",
    async (
        string customerId,
        string productId,
        RecommendationService service) =>
    {
        var explanation =
            await service.ExplainRecommendationAsync(
                customerId,
                productId);

        return explanation is null
            ? Results.NotFound(new
            {
                message = "Khong tim thay bang chung de giai thich goi y."
            })
            : Results.Ok(explanation);
    });

// San pham thuong duoc mua cung don hang.
app.MapGet(
    "/api/products/{productId}/frequently-bought-together",
    async (
        string productId,
        int? limit,
        RecommendationService service) =>
    {
        if (await service.GetProductAsync(productId) is null)
        {
            return Results.NotFound(new
            {
                message = "Khong tim thay san pham."
            });
        }

        return Results.Ok(
            await service.GetFrequentlyBoughtTogetherAsync(
                productId,
                Math.Clamp(limit ?? 10, 1, 50)));
    });

// ======================================================
// GIO HANG LUU TREN NEO4J
// ======================================================

// Lay gio hang.
app.MapGet(
    "/api/customers/{customerId}/cart",
    async (
        string customerId,
        RecommendationService service) =>
    {
        var cart = await service.GetCartAsync(customerId);
        return Results.Ok(cart);
    });

// Them hoac cap nhat so luong san pham.
app.MapPut(
    "/api/customers/{customerId}/cart/{productId}",
    async (
        string customerId,
        string productId,
        CartItemRequest request,
        RecommendationService service) =>
    {
        try
        {
            var saved = await service.SetCartItemAsync(
                customerId,
                productId,
                request.Quantity);

            if (!saved)
            {
                return Results.BadRequest(new
                {
                    message =
                        "Khong tim thay tai khoan/san pham "
                        + "hoac so luong vuot ton kho."
                });
            }

            return Results.Ok(new { saved = true });
        }
        catch (ArgumentOutOfRangeException ex)
        {
            return Results.BadRequest(new
            {
                message = ex.Message
            });
        }
    });

// Xoa san pham khoi gio hang.
app.MapDelete(
    "/api/customers/{customerId}/cart/{productId}",
    async (
        string customerId,
        string productId,
        RecommendationService service) =>
    {
        var removed = await service.RemoveCartItemAsync(
            customerId,
            productId);

        return Results.Ok(new { removed });
    });

// ======================================================
// LICH SU HOAT DONG
// ======================================================

app.MapGet(
    "/api/customers/{customerId}/history",
    async (
        string customerId,
        int? limit,
        RecommendationService service) =>
    {
        var history = await service.GetCustomerHistoryAsync(
            customerId,
            limit ?? 100);

        return Results.Ok(history);
    });

// ======================================================
// THANH TOAN DEMO
// ======================================================

app.MapPost(
    "/api/customers/{customerId}/checkout",
    async (
        string customerId,
        RecommendationService service) =>
    {
        try
        {
            var result = await service.CheckoutAsync(customerId);
            return Results.Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return Results.Conflict(new
            {
                message = ex.Message
            });
        }
    });

// CHI GOI app.Run() MOT LAN, SAU TAT CA API.
app.Run();