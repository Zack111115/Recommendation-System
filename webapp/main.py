from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import os

from routers import products, customers, recommend
from database import close_driver

app = FastAPI(
    title="Recommendation System API",
    description="Do an 13 - He thong Goi y San pham (Neo4j + FastAPI)",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── API Routes ─────────────────────────────────────────────────────
app.include_router(products.router,  prefix="/api/products",  tags=["Products"])
app.include_router(customers.router, prefix="/api/customers", tags=["Customers"])
app.include_router(recommend.router, prefix="/api/recommend", tags=["Recommend"])

# ── Serve static frontend ─────────────────────────────────────────
frontend_dir = os.path.join(os.path.dirname(__file__), "frontend")
app.mount("/static", StaticFiles(directory=frontend_dir), name="static")

@app.get("/", include_in_schema=False)
def serve_index():
    return FileResponse(os.path.join(frontend_dir, "index.html"))

@app.get("/product", include_in_schema=False)
def serve_product():
    return FileResponse(os.path.join(frontend_dir, "product.html"))

@app.get("/customer", include_in_schema=False)
def serve_customer():
    return FileResponse(os.path.join(frontend_dir, "customer.html"))

@app.on_event("shutdown")
def shutdown():
    close_driver()
