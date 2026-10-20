from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from neo4j import Session
from database import get_session
import uuid, datetime

router = APIRouter()

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
    return [dict(r["c"]) for r in result]

# ── GET /api/customers/{customer_id} ─────────────────────────────
@router.get("/{customer_id}")
def get_customer(customer_id: str, session: Session = Depends(get_session)):
    result = session.run(
        "MATCH (c:Customer {id: $id}) RETURN c",
        id=customer_id
    )
    record = result.single()
    if not record:
        raise HTTPException(status_code=404, detail="Customer not found")
    return dict(record["c"])

# ── GET /api/customers/{customer_id}/history ─────────────────────
@router.get("/{customer_id}/history")
def get_history(customer_id: str, session: Session = Depends(get_session)):
    bought = session.run(
        """
        MATCH (c:Customer {id: $id})-[r:BOUGHT]->(p:Product)-[:BELONGS_TO]->(cat:Category)
        RETURN p.id AS productId, p.name AS productName, p.price AS price,
               p.brand AS brand, cat.name AS categoryName,
               r.orderId AS orderId, r.purchasedAt AS purchasedAt, r.quantity AS quantity
        ORDER BY r.purchasedAt DESC
        LIMIT 50
        """,
        id=customer_id
    )
    viewed = session.run(
        """
        MATCH (c:Customer {id: $id})-[r:VIEWED]->(p:Product)
        RETURN p.id AS productId, p.name AS productName, p.price AS price,
               r.viewedAt AS viewedAt
        ORDER BY r.viewedAt DESC
        LIMIT 20
        """,
        id=customer_id
    )
    return {
        "bought": [dict(r) for r in bought],
        "viewed": [dict(r) for r in viewed]
    }

# ── POST /api/customers/{customer_id}/view/{product_id} ──────────
@router.post("/{customer_id}/view/{product_id}")
def view_product(customer_id: str, product_id: str, session: Session = Depends(get_session)):
    c = session.run("MATCH (c:Customer {id:$id}) RETURN c", id=customer_id).single()
    p = session.run("MATCH (p:Product  {id:$id}) RETURN p", id=product_id).single()
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
        cid=customer_id, pid=product_id,
        sid=session_id, viewedAt=viewed_at
    )
    return {"message": "View recorded", "sessionId": session_id}

# ── POST /api/customers/{customer_id}/buy/{product_id} ───────────
@router.post("/{customer_id}/buy/{product_id}")
def buy_product(customer_id: str, product_id: str, body: BuyRequest, session: Session = Depends(get_session)):
    c = session.run("MATCH (c:Customer {id:$id}) RETURN c", id=customer_id).single()
    p_rec = session.run("MATCH (p:Product  {id:$id}) RETURN p", id=product_id).single()
    if not c:
        raise HTTPException(status_code=404, detail="Customer not found")
    if not p_rec:
        raise HTTPException(status_code=404, detail="Product not found")
    p_data = dict(p_rec["p"])
    if p_data.get("stock", 0) < body.quantity:
        raise HTTPException(status_code=400, detail="Not enough stock")
    order_id     = f"O-{customer_id}-WEB-{uuid.uuid4().hex[:4].upper()}"
    purchased_at = datetime.datetime.utcnow().isoformat()
    session.run(
        """
        MATCH (c:Customer {id:$cid}), (p:Product {id:$pid})
        CREATE (c)-[:BOUGHT {orderId:$oid, purchasedAt:$pat, quantity:$qty}]->(p)
        WITH p
        SET p.stock = p.stock - $qty
        """,
        cid=customer_id, pid=product_id,
        oid=order_id, pat=purchased_at, qty=body.quantity
    )
    return {"message": "Purchase recorded", "orderId": order_id}

# ── POST /api/customers (create) ─────────────────────────────────
@router.post("/", status_code=201)
def create_customer(body: CustomerCreate, session: Session = Depends(get_session)):
    cid = body.id or ("C" + uuid.uuid4().hex[:4].upper())
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
