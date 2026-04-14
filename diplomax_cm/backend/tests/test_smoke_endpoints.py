import asyncio

from main import health, root


def test_health_returns_ok_status():
    payload = asyncio.run(health())
    assert payload["status"] == "ok"
    assert "version" in payload


def test_root_returns_service_metadata():
    payload = asyncio.run(root())
    assert payload["service"] == "Diplomax CM API"
    assert "version" in payload
    assert "docs" in payload
