from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from typing import Optional
from neo4j import Session
from database import get_session
import uuid, datetime

router = APIRouter()

class ProductCreate(BaseModel):
    id: Optional[str] = None
    name: str
    brand: str
    categoryId: str
    price: float
    stock: int
    description: Optional[str] = ""

class ProductUpdate(BaseModel):
    name: Optional[str] = None
    brand: Optional[str] = None
    price: Optional[float] = None
    stock: Optional[int] = None
    description: Optional[str] = None

def _record_to_dict(record, key="p"):
    node = record[key]
    return dict(node)

# ── GET /api/products ──────────────────────────────────────────────
@router.get("/")
def list_products(
    search: Optional[str] = Query(None),
    categoryId: Optional[str] = Query(None),
    brand: Optional[str] = Query(None),
    skip: int = 0,
    limit: int = 40,
    session: Session = Depends(get_session)
):
    conditions = []
    params: dict = {"skip": skip, "limit": limit}

    if search:
        conditions.append("(toLower(p.name) CONTAINS toLower($search) OR toLower(p.description) CONTAINS toLower($search))")
        params["search"] = search
    if categoryId:
        conditions.append("p.categoryId = $categoryId")
        params["categoryId"] = categoryId
    if brand:
        conditions.append("p.brand = $brand")
        params["brand"] = brand

    where_clause = ("WHERE " + " AND ".join(conditions)) if conditions else ""
    cypher = f"""
        MATCH (p:Product)-[:BELONGS_TO]->(cat:Category)
        {where_clause}
        RETURN p, cat.name AS categoryName
        ORDER BY p.id
        SKIP $skip LIMIT $limit
    """
    result = session.run(cypher, **params)
    products = []
    for r in result:
        d = dict(r["p"])
        d["categoryName"] = r["categoryName"]
        products.append(d)
    return products

# ── GET /api/products/categories ──────────────────────────────────
@router.get("/categories")
def list_categories(session: Session = Depends(get_session)):
    result = session.run("MATCH (cat:Category) RETURN cat ORDER BY cat.id")
    return [dict(r["cat"]) for r in result]

# ── GET /api/products/brands ──────────────────────────────────────
@router.get("/brands")
def list_brands(session: Session = Depends(get_session)):
    result = session.run("MATCH (p:Product) RETURN DISTINCT p.brand AS brand ORDER BY brand")
    return [r["brand"] for r in result]

# ── GET /api/products/{product_id} ────────────────────────────────
@router.get("/{product_id}")
def get_product(product_id: str, session: Session = Depends(get_session)):
    result = session.run(
        """
        MATCH (p:Product {id: $id})-[:BELONGS_TO]->(cat:Category)
        RETURN p, cat.name AS categoryName, cat.id AS categoryId
        """,
        id=product_id
    )
    record = result.single()
    if not record:
        raise HTTPException(status_code=404, detail="Product not found")
    d = dict(record["p"])
    d["categoryName"] = record["categoryName"]
    return d

# ── POST /api/products ────────────────────────────────────────────
@router.post("/", status_code=201)
def create_product(body: ProductCreate, session: Session = Depends(get_session)):
    product_id = body.id or ("P" + uuid.uuid4().hex[:5].upper())
    # Check category exists
    cat = session.run("MATCH (cat:Category {id: $cid}) RETURN cat", cid=body.categoryId).single()
    if not cat:
        raise HTTPException(status_code=400, detail=f"Category {body.categoryId} does not exist")
    session.run(
        """
        MERGE (p:Product {id: $id})
        SET p.name = $name, p.brand = $brand, p.categoryId = $categoryId,
            p.price = $price, p.stock = $stock, p.description = $description
        WITH p
        MATCH (cat:Category {id: $categoryId})
        MERGE (p)-[:BELONGS_TO]->(cat)
        """,
        id=product_id, name=body.name, brand=body.brand,
        categoryId=body.categoryId, price=body.price,
        stock=body.stock, description=body.description
    )
    return {"message": "Product created", "id": product_id}

# ── PUT /api/products/{product_id} ────────────────────────────────
@router.put("/{product_id}")
def update_product(product_id: str, body: ProductUpdate, session: Session = Depends(get_session)):
    p = session.run("MATCH (p:Product {id: $id}) RETURN p", id=product_id).single()
    if not p:
        raise HTTPException(status_code=404, detail="Product not found")
    updates = {k: v for k, v in body.model_dump().items() if v is not None}
    if not updates:
        return {"message": "Nothing to update"}
    set_clause = ", ".join(f"p.{k} = ${k}" for k in updates)
    session.run(f"MATCH (p:Product {{id: $id}}) SET {set_clause}", id=product_id, **updates)
    return {"message": "Updated", "id": product_id}

# ── DELETE /api/products/{product_id} ─────────────────────────────
@router.delete("/{product_id}")
def delete_product(product_id: str, session: Session = Depends(get_session)):
    p = session.run("MATCH (p:Product {id: $id}) RETURN p", id=product_id).single()
    if not p:
        raise HTTPException(status_code=404, detail="Product not found")
    session.run("MATCH (p:Product {id: $id}) DETACH DELETE p", id=product_id)
    return {"message": "Deleted", "id": product_id}
