from fastapi import APIRouter, Depends
from neo4j import Session
from database import get_session

router = APIRouter()

def serialize_val(val):
    if hasattr(val, "year") and hasattr(val, "month") and hasattr(val, "day"):
        return str(val)
    if hasattr(val, "iso_format"):
        return val.iso_format()
    if isinstance(val, dict):
        return {k: serialize_val(v) for k, v in val.items()}
    if isinstance(val, list):
        return [serialize_val(v) for v in val]
    return val

# ── GET /api/recommend/collaborative/{customer_id} ────────────────
@router.get("/collaborative/{customer_id}")
def collaborative_filtering(customer_id: str, limit: int = 10, session: Session = Depends(get_session)):
    cid = customer_id.strip().upper()
    result = session.run(
        """
        MATCH (c1:Customer {id: $cid})-[:BOUGHT]->(p1:Product)<-[:BOUGHT]-(c2:Customer)-[:BOUGHT]->(p2:Product)
        WHERE c2.id <> c1.id
          AND NOT (c1)-[:BOUGHT]->(p2)
        WITH p2, count(DISTINCT c2) AS supportCount, count(DISTINCT p1) AS sharedProductCount
        MATCH (p2)-[:BELONGS_TO]->(cat:Category)
        RETURN p2.id AS productId, p2.name AS productName, p2.brand AS brand,
               p2.price AS priceVND, p2.stock AS stock, cat.name AS categoryName,
               supportCount, sharedProductCount,
               'Khách hàng có lịch sử mua chung cũng đã mua sản phẩm này' AS reason
        ORDER BY supportCount DESC, sharedProductCount DESC, productId ASC
        LIMIT $limit
        """,
        cid=cid, limit=limit
    )
    return [serialize_val(dict(r)) for r in result]

# ── GET /api/recommend/explain/{customer_id}/{product_id} ─────────
@router.get("/explain/{customer_id}/{product_id}")
def explain_recommendation(customer_id: str, product_id: str, session: Session = Depends(get_session)):
    cid = customer_id.strip().upper()
    pid = product_id.strip().upper()
    result = session.run(
        """
        MATCH (target:Customer {id: $cid})-[:BOUGHT]->(shared:Product)<-[:BOUGHT]-(supporter:Customer)
              -[:BOUGHT]->(recommended:Product {id: $pid})
        WHERE supporter.id <> target.id
          AND NOT (target)-[:BOUGHT]->(recommended)
        RETURN target.id AS targetCustomer,
               recommended.id AS recommendedProductId,
               recommended.name AS recommendedProductName,
               collect(DISTINCT supporter.id) AS supportingCustomers,
               count(DISTINCT supporter) AS supportCount,
               collect(DISTINCT {productId: shared.id, productName: shared.name}) AS sharedPurchaseEvidence
        """,
        cid=cid, pid=pid
    )
    record = result.single()
    if not record:
        return {"message": "No explanation path found", "targetCustomer": cid, "recommendedProductId": pid}
    return serialize_val(dict(record))

# ── GET /api/recommend/copurchase/{product_id} ────────────────────
@router.get("/copurchase/{product_id}")
def co_purchase(product_id: str, limit: int = 10, session: Session = Depends(get_session)):
    pid = product_id.strip().upper()
    result = session.run(
        """
        MATCH (c:Customer)-[b1:BOUGHT]->(p1:Product {id: $pid}),
              (c)-[b2:BOUGHT]->(p2:Product)
        WHERE p1 <> p2 AND b1.orderId = b2.orderId
        MATCH (p2)-[:BELONGS_TO]->(cat:Category)
        RETURN p2.id AS productId, p2.name AS productName, p2.brand AS brand,
               p2.price AS priceVND, p2.stock AS stock, cat.name AS categoryName,
               count(DISTINCT b1.orderId) AS coPurchaseOrderCount
        ORDER BY coPurchaseOrderCount DESC, productId ASC
        LIMIT $limit
        """,
        pid=pid, limit=limit
    )
    return [serialize_val(dict(r)) for r in result]

# ── GET /api/recommend/complementary/{product_id} ─────────────────
@router.get("/complementary/{product_id}")
def complementary(product_id: str, session: Session = Depends(get_session)):
    pid = product_id.strip().upper()
    result = session.run(
        """
        MATCH (base:Product {id: $pid})-[:COMPLEMENTARY_TO]->(rec:Product)
        MATCH (rec)-[:BELONGS_TO]->(cat:Category)
        RETURN rec.id AS productId, rec.name AS productName, rec.brand AS brand,
               rec.price AS priceVND, rec.stock AS stock, cat.name AS categoryName,
               'San pham bo tro duoc khai bao trong du lieu' AS reason
        ORDER BY rec.id
        """,
        pid=pid
    )
    return [serialize_val(dict(r)) for r in result]

# ── GET /api/recommend/viewed-also/{customer_id} ──────────────────
@router.get("/viewed-also/{customer_id}")
def viewed_also(customer_id: str, limit: int = 8, session: Session = Depends(get_session)):
    cid = customer_id.strip().upper()
    result = session.run(
        """
        MATCH (c1:Customer {id: $cid})-[:VIEWED]->(p1:Product)<-[:VIEWED]-(c2:Customer)-[:BOUGHT]->(p2:Product)
        WHERE c2.id <> c1.id AND NOT (c1)-[:BOUGHT]->(p2)
        WITH p2, count(DISTINCT c2) AS score
        MATCH (p2)-[:BELONGS_TO]->(cat:Category)
        RETURN p2.id AS productId, p2.name AS productName, p2.brand AS brand,
               p2.price AS priceVND, p2.stock AS stock, cat.name AS categoryName,
               score, 'Khach hang xem chung cung da mua san pham nay' AS reason
        ORDER BY score DESC
        LIMIT $limit
        """,
        cid=cid, limit=limit
    )
    return [serialize_val(dict(r)) for r in result]
