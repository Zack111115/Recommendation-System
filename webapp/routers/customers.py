from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from neo4j import Session
from database import get_session
import uuid, datetime

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

class CustomerCreate(BaseModel):
    id: Optional[str] = None
    name: str
    email: str
    behaviorGroup: Optional[str] = "casual"

class BuyRequest(BaseModel):
    quantity: int = 1

# ── GET /api/customers ────────────────────────────────────────────
@router.get("/")
def list_customers(session: Session = Depends(get_session)):
    result = session.run(
        "MATCH (c:Customer) RETURN c ORDER BY c.id LIMIT 60"
    )
    return [serialize_val(dict(r["c"])) for r in result]

# ── GET /api/customers/{customer_id} ─────────────────────────────
@router.get("/{customer_id}")
def get_customer(customer_id: str, session: Session = Depends(get_session)):
    cid = customer_id.strip().upper()
    result = session.run(
        "MATCH (c:Customer {id: $id}) RETURN c",
        id=cid
    )
    record = result.single()
    if not record:
        raise HTTPException(status_code=404, detail="Customer not found")
    return serialize_val(dict(record["c"]))

# ── GET /api/customers/{customer_id}/history ─────────────────────
@router.get("/{customer_id}/history")
def get_history(customer_id: str, session: Session = Depends(get_session)):
    cid = customer_id.strip().upper()
    bought = session.run(
        """
        MATCH (c:Customer {id: $id})-[r:BOUGHT]->(p:Product)-[:BELONGS_TO]->(cat:Category)
        RETURN p.id AS productId, p.name AS productName, p.price AS price,
               p.brand AS brand, cat.name AS categoryName,
               r.orderId AS orderId, r.purchasedAt AS purchasedAt, r.quantity AS quantity
        ORDER BY r.purchasedAt DESC
        LIMIT 50
        """,
        id=cid
    )
    viewed = session.run(
        """
        MATCH (c:Customer {id: $id})-[r:VIEWED]->(p:Product)
        OPTIONAL MATCH (p)-[:BELONGS_TO]->(cat:Category)
        RETURN p.id AS productId, p.name AS productName, p.price AS price,
               p.brand AS brand, cat.name AS categoryName,
               r.viewedAt AS viewedAt
        ORDER BY r.viewedAt DESC
        LIMIT 30
        """,
        id=cid
    )
    return {
        "bought": [serialize_val(dict(r)) for r in bought],
        "viewed": [serialize_val(dict(r)) for r in viewed]
    }

# ── POST /api/customers/{customer_id}/view/{product_id} ──────────
@router.post("/{customer_id}/view/{product_id}")
def view_product(customer_id: str, product_id: str, session: Session = Depends(get_session)):
    cid = customer_id.strip().upper()
    pid = product_id.strip().upper()
    c = session.run("MATCH (c:Customer {id:$id}) RETURN c", id=cid).single()
    p = session.run("MATCH (p:Product  {id:$id}) RETURN p", id=pid).single()
    if not c:
        raise HTTPException(status_code=404, detail="Customer not found")
    if not p:
        raise HTTPException(status_code=404, detail="Product not found")
    session_id = "SES-" + uuid.uuid4().hex[:8].upper()
    viewed_at  = datetime.datetime.utcnow().isoformat()
    session.run(
        """
        MATCH (c:Customer {id:$cid}), (p:Product {id:$pid})
        CREATE (c)-[:VIEWED {sessionId:$sid, viewedAt:$viewedAt}]->(p)
        """,
        cid=cid, pid=pid,
        sid=session_id, viewedAt=viewed_at
    )
    return {"message": "View recorded", "sessionId": session_id}

# ── POST /api/customers/{customer_id}/buy/{product_id} ───────────
@router.post("/{customer_id}/buy/{product_id}")
def buy_product(customer_id: str, product_id: str, body: BuyRequest, session: Session = Depends(get_session)):
    cid = customer_id.strip().upper()
    pid = product_id.strip().upper()
    c = session.run("MATCH (c:Customer {id:$id}) RETURN c", id=cid).single()
    p_rec = session.run("MATCH (p:Product  {id:$id}) RETURN p", id=pid).single()
    if not c:
        raise HTTPException(status_code=404, detail="Customer not found")
    if not p_rec:
        raise HTTPException(status_code=404, detail="Product not found")
    p_data = dict(p_rec["p"])
    if p_data.get("stock", 0) < body.quantity:
        raise HTTPException(status_code=400, detail="Not enough stock")
    order_id     = f"O-{cid}-WEB-{uuid.uuid4().hex[:4].upper()}"
    purchased_at = datetime.datetime.utcnow().isoformat()
    session.run(
        """
        MATCH (c:Customer {id:$cid}), (p:Product {id:$pid})
        CREATE (c)-[:BOUGHT {orderId:$oid, purchasedAt:$pat, quantity:$qty}]->(p)
        WITH p
        SET p.stock = p.stock - $qty
        """,
        cid=cid, pid=pid,
        oid=order_id, pat=purchased_at, qty=body.quantity
    )
    return {"message": "Purchase recorded", "orderId": order_id}

# ── POST /api/customers (create) ─────────────────────────────────
@router.post("/", status_code=201)
def create_customer(body: CustomerCreate, session: Session = Depends(get_session)):
    cid = (body.id or ("C" + uuid.uuid4().hex[:4])).strip().upper()
    existing = session.run("MATCH (c:Customer {email:$email}) RETURN c", email=body.email).single()
    if existing:
        raise HTTPException(status_code=400, detail="Email already exists")
    created_at = datetime.datetime.utcnow().isoformat()
    session.run(
        """
        MERGE (c:Customer {id:$id})
        SET c.name=$name, c.email=$email, c.behaviorGroup=$bg, c.createdAt=$ca
        """,
        id=cid, name=body.name, email=body.email,
        bg=body.behaviorGroup, ca=created_at
    )
    return {"message": "Customer created", "id": cid}
