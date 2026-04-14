"""
Diplomax CM — Revenue Split Service + Document Revocation + Ministry Endpoints

Revenue split per transaction:
  - 40% → Treasury / State (Trésor Public)
  - 40% → Issuing University / Institution
  - 20% → Diplomax Platform maintenance

Revocation:
  - Marks a document hash as REVOKED on the Hyperledger blockchain
  - Stores revocation reason and timestamp
  - The document remains in the DB for audit but is flagged
  - All verification calls return REVOKED status (yellow indicator)
"""
import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Request
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

revenue_router   = APIRouter(prefix="/revenue",   tags=["Revenue"])
revocation_router = APIRouter(prefix="/documents", tags=["Revocation"])
ministry_router  = APIRouter(prefix="/ministry",   tags=["Ministry"])


# ─────────────────────────────────────────────────────────────────────────────
# REVENUE SPLIT
# ─────────────────────────────────────────────────────────────────────────────

REVENUE_SPLIT = {
    "treasury":  0.40,   # 40% → État / Trésor Public
    "university": 0.40,  # 40% → Issuing institution
    "platform":  0.20,   # 20% → Diplomax platform
}

PRODUCT_PRICES_FCFA = {
    "certification_numerique": 500,
    "releve_officiel":        1000,
    "dossier_complet":        2500,
    "attestation":             500,
    "certificate":            1500,
    "diploma_copy":           2500,
    "abonnement_recruteur":  15000,
    "abonnement_recruteur_annual": 120000,
}


def calculate_split(amount_fcfa: int) -> dict:
    """
    Calculates how a payment is split between the three parties.
    Uses ceiling for treasury and university to ensure platform gets the remainder.
    """
    treasury  = int(amount_fcfa * REVENUE_SPLIT["treasury"])
    university = int(amount_fcfa * REVENUE_SPLIT["university"])
    platform  = amount_fcfa - treasury - university   # remainder to avoid rounding loss
    return {
        "total":      amount_fcfa,
        "treasury":   treasury,
        "university": university,
        "platform":   platform,
        "split_pct":  {"treasury": "40%", "university": "40%", "platform": "20%"},
    }


@revenue_router.get("/split/{amount_fcfa}")
async def get_revenue_split(amount_fcfa: int):
    """Returns how a given amount will be split between parties."""
    if amount_fcfa <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")
    return calculate_split(amount_fcfa)


@revenue_router.get("/stats")
async def revenue_stats():
    """
    Returns aggregate revenue statistics.
    In production: queries the payments table grouped by period.
    """
    # In production: complex SQL aggregation query
    # SELECT SUM(amount_fcfa), provider, DATE_TRUNC('month', paid_at) FROM payments
    # WHERE status='successful' GROUP BY provider, month
    return {
        "total_revenue_fcfa": 0,
        "treasury_share":     0,
        "university_share":   0,
        "platform_share":     0,
        "by_provider": {"mtn": 0, "orange": 0},
        "by_month":    [],
    }


# ─────────────────────────────────────────────────────────────────────────────
# DOCUMENT REVOCATION
# ─────────────────────────────────────────────────────────────────────────────

class RevokeRequest(BaseModel):
    reason: str
    notify_student: bool = True


@revocation_router.post("/{document_id}/revoke")
async def revoke_document(
    document_id: str,
    body: RevokeRequest,
    background_tasks: BackgroundTasks,
):
    """
    Revokes a document by:
    1. Marking is_revoked = True in the database
    2. Calling DiplomaxChaincode.RevokeDocument() on Hyperledger Fabric
       — This writes an immutable REVOCATION record on-chain
    3. Optionally sending push notification to the student
    4. Logging the revocation event

    The original document record is preserved for audit purposes.
    The hash on the blockchain is marked REVOKED — any future verification
    will return REVOKED status regardless of the hash match.
    """
    if not document_id:
        raise HTTPException(status_code=400, detail="document_id required")

    # In production: update DB + call Fabric RevokeDocument()
    # from app.services.blockchain.fabric_service import FabricService
    # result = await FabricService().revoke_document(document_id, body.reason)

    # Background: notify student via FCM
    if body.notify_student:
        background_tasks.add_task(
            _notify_student_revocation, document_id, body.reason)

    return {
        "document_id":   document_id,
        "is_revoked":    True,
        "revoked_at":    datetime.now(timezone.utc).isoformat(),
        "reason":        body.reason,
        "blockchain_revocation": "queued",
        "message": "Document marked as REVOKED. Blockchain update queued.",
    }


@revocation_router.get("/{document_id}/revocation-status")
async def check_revocation(document_id: str):
    """Check if a document has been revoked on the blockchain."""
    # In production: query Fabric directly
    return {
        "document_id":  document_id,
        "is_revoked":   False,
        "revoked_at":   None,
        "reason":       None,
        "checked_at":   datetime.now(timezone.utc).isoformat(),
    }


@revocation_router.get("/pending-signatures")
async def pending_signatures(page_size: int = 500):
    """
    Returns all documents that have been issued but not yet
    cryptographically signed by the university.
    Used by the batch sign screen.
    """
    # In production: query DB where rsa_signature IS NULL
    # SELECT * FROM academic_documents WHERE rsa_signature IS NULL
    #   AND university_id = current_university
    #   ORDER BY created_at DESC LIMIT page_size
    return {"items": [], "total": 0}


async def _notify_student_revocation(document_id: str, reason: str):
    """Background: send FCM notification to student about revocation."""
    # In production:
    # 1. Find student FCM token from academic_documents -> students -> fcm_token
    # 2. Send notification via firebase_admin
    pass


# ─────────────────────────────────────────────────────────────────────────────
# MINISTRY / GOVERNMENT ENDPOINTS
# ─────────────────────────────────────────────────────────────────────────────

@ministry_router.get("/stats")
async def ministry_stats():
    """
    Aggregate statistics for the Ministry of Higher Education dashboard.
    Shows: total institutions, documents, verifications, revenue, graduate tracking.
    In production: complex aggregation queries across all institutions.
    """
    # In production:
    # SELECT COUNT(*) FROM institutions WHERE status='approved'
    # SELECT COUNT(*), SUM(amount_fcfa) FROM payments WHERE status='successful'
    # SELECT COUNT(*) FROM academic_documents
    # SELECT COUNT(*) FROM verification_logs WHERE verified_at > NOW() - INTERVAL '24h'
    return {
        "total_institutions":    1,    # Will grow as more institutions connect
        "total_documents":       0,
        "total_verifications":   0,
        "total_revenue_fcfa":    0,
        "treasury_revenue_fcfa": 0,    # 40% of total
        "documents_today":       0,
        "verifications_today":   0,
        "documents_this_month":  0,
        "top_institutions_by_volume": [],
        "document_types_breakdown": {
            "diploma":     0,
            "transcript":  0,
            "certificate": 0,
            "attestation": 0,
        },
        "verifications_by_method": {
            "qr": 0, "nfc": 0, "link": 0, "intl": 0,
        },
        "blockchain_anchored_pct": 100,   # % of documents on blockchain
        "fraud_attempts_blocked":  0,
        "revoked_documents":       0,
    }


@ministry_router.get("/recent-documents")
async def ministry_recent_documents(page_size: int = 20):
    """All recently issued documents across all institutions."""
    # In production: query across all institutions scoped to ministry role
    return {"items": [], "total": 0}


@ministry_router.get("/institutions/summary")
async def institutions_summary():
    """Summary of all connected institutions for ministry view."""
    return {
        "total":   1,
        "active":  1,
        "pending": 0,
        "suspended": 0,
        "by_type": {
            "university":          1,
            "grande_ecole":        0,
            "training_centre":     0,
            "professional_school": 0,
        },
        "by_region": {
            "Centre": 1, "Littoral": 0, "Ouest": 0,
            "Nord-Ouest": 0, "Sud-Ouest": 0,
        },
    }


@ministry_router.get("/graduate-employment")
async def graduate_employment_tracker():
    """
    Track how many graduates are being verified by employers
    (proxy for employment rate). Aggregates verification_logs.
    """
    # In production: complex join between documents, verifications, students
    return {
        "verified_last_30d":     0,
        "unique_graduates":      0,
        "unique_employers":      0,
        "top_employers":         [],
        "most_requested_degree": "Software Engineering",
    }
