from neo4j import GraphDatabase
import os

NEO4J_URI      = os.getenv("NEO4J_URI",      "bolt://127.0.0.1:7687")
NEO4J_USER     = os.getenv("NEO4J_USER",     "neo4j")
NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD", "12345678")

_driver = None

def get_driver():
    global _driver
    if _driver is None:
        _driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))
    return _driver

def get_session():
    driver = get_driver()
    session = driver.session()
    try:
        yield session
    finally:
        session.close()

def close_driver():
    global _driver
    if _driver is not None:
        _driver.close()
        _driver = None
