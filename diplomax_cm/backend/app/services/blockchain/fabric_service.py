"""
Diplomax CM — Hyperledger Fabric Blockchain Service
Communicates with the Fabric REST API Gateway.
The gateway connects to the 'diplomax-channel' and 'DiplomaxChaincode'.

Smart contract functions used:
  - IssueDocument(documentId, sha256Hash, studentMatricule, universityId, issuedAt, issuerKeyFingerprint)
  - VerifyDocument(documentId) → returns stored record
  - GetHistory(documentId)    → returns audit trail
  - RevokeDocument(documentId, reason) → marks revoked (admin only)
"""
import json
from datetime import datetime, timezone
from typing import Optional

import httpx

from app.core.config import get_settings

settings = get_settings()


class FabricService:
    """
    Calls the Hyperledger Fabric REST API Gateway.
    The gateway translates HTTP calls to gRPC Fabric peer calls.
    """

    def __init__(self):
        self.base        = settings.FABRIC_GATEWAY_URL
        self.channel     = settings.FABRIC_CHANNEL_NAME
        self.chaincode   = settings.FABRIC_CHAINCODE_NAME
        self.identity    = "admin"
        self.headers     = {"Content-Type": "application/json"}

    # ── Submit transaction (write) ────────────────────────────────────────────

    async def _submit(self, function: str, args: list[str]) -> dict:
        """
        Submit a transaction that writes to the ledger.
        Uses /transactions endpoint which goes through the orderer.
        """
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{self.base}/api/v1/transactions",
                headers=self.headers,
                json={
                    "channelName":   self.channel,
                    "chaincodeName": self.chaincode,
                    "transactionName": function,
                    "args": args,
                },
            )
            response.raise_for_status()
            return response.json()

    # ── Evaluate query (read-only) ────────────────────────────────────────────

    async def _evaluate(self, function: str, args: list[str]) -> dict:
        """
        Evaluate a query that reads from the ledger (no orderer needed).
        Uses /queries endpoint.
        """
        async with httpx.AsyncClient(timeout=15.0) as client:
            params = {
                "channelName":   self.channel,
                "chaincodeName": self.chaincode,
                "transactionName": function,
                "args": json.dumps(args),
            }
            response = await client.get(
                f"{self.base}/api/v1/queries",
                headers=self.headers,
                params=params,
            )
            response.raise_for_status()
            return response.json()

    # ── IssueDocument ─────────────────────────────────────────────────────────

    async def anchor_document(
        self,
        *,
        document_id: str,
        sha256_hash: str,
        student_matricule: str,
        university_id: str,
        issued_at: str,            # ISO 8601
        issuer_key_fingerprint: str,
        rsa_signature: str,
    ) -> "BlockchainAnchorResult":
        """
        Writes the document fingerprint to the Fabric ledger.
        Once written, this record cannot be modified.
        """
        try:
            result = await self._submit(
                "IssueDocument",
                [
                    document_id,
                    sha256_hash,
                    student_matricule,
                    university_id,
                    issued_at,
                    issuer_key_fingerprint,
                    rsa_signature,
                ],
            )
            return BlockchainAnchorResult(
                success=True,
                transaction_id=result.get("transactionId"),
                block_number=result.get("blockNumber"),
                timestamp=datetime.now(timezone.utc).isoformat(),
            )
        except httpx.HTTPStatusError as e:
            return BlockchainAnchorResult(
                success=False,
                error=f"Fabric error {e.response.status_code}: {e.response.text}",
            )
        except Exception as e:
            return BlockchainAnchorResult(success=False, error=str(e))

    # ── VerifyDocument ────────────────────────────────────────────────────────

    async def verify_document(
        self, document_id: str, hash_to_verify: str
    ) -> "BlockchainVerifyResult":
        """
        Queries the Fabric ledger for the stored document record and
        compares the stored hash with the provided hash.
        This is the TRUSTLESS verification path — it does not touch the Diplomax DB.
        """
        try:
            result = await self._evaluate("VerifyDocument", [document_id])
            record = result.get("result", {})

            if not record:
                return BlockchainVerifyResult(found=False, is_authentic=False,
                    tampering_detected=False, error="Document not found on blockchain")

            stored_hash = record.get("sha256Hash", "")
            hashes_match = stored_hash == hash_to_verify

            return BlockchainVerifyResult(
                found=True,
                is_authentic=hashes_match,
                tampering_detected=not hashes_match,
                stored_hash=stored_hash,
                transaction_id=record.get("txId"),
                block_number=record.get("blockNumber"),
                anchored_at=record.get("issuedAt"),
                student_matricule=record.get("studentMatricule"),
                university_id=record.get("universityId"),
                issuer_key_fingerprint=record.get("issuerKeyFingerprint"),
                rsa_signature=record.get("rsaSignature"),
            )

        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                return BlockchainVerifyResult(found=False, is_authentic=False,
                    tampering_detected=False, error="Document not found on blockchain")
            return BlockchainVerifyResult(found=False, is_authentic=False,
                tampering_detected=False,
                error=f"Fabric error {e.response.status_code}")
        except Exception as e:
            return BlockchainVerifyResult(found=False, is_authentic=False,
                tampering_detected=False, error=str(e))

    # ── GetHistory ────────────────────────────────────────────────────────────

    async def get_history(self, document_id: str) -> list[dict]:
        """Returns the complete Fabric transaction history for a document."""
        try:
            result = await self._evaluate("GetHistory", [document_id])
            return result.get("result", [])
        except Exception:
            return []

    # ── Health ────────────────────────────────────────────────────────────────

    async def is_healthy(self) -> bool:
        """Returns True if the Fabric gateway is reachable."""
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                r = await client.get(f"{self.base}/healthz")
                return r.status_code == 200
        except Exception:
            return False


# ─── Result types ─────────────────────────────────────────────────────────────

class BlockchainAnchorResult:
    def __init__(self, *, success: bool, transaction_id: Optional[str] = None,
                 block_number: Optional[int] = None, timestamp: Optional[str] = None,
                 error: Optional[str] = None):
        self.success        = success
        self.transaction_id = transaction_id
        self.block_number   = block_number
        self.timestamp      = timestamp
        self.error          = error


class BlockchainVerifyResult:
    def __init__(self, *, found: bool, is_authentic: bool, tampering_detected: bool,
                 stored_hash: Optional[str] = None, transaction_id: Optional[str] = None,
                 block_number: Optional[int] = None, anchored_at: Optional[str] = None,
                 student_matricule: Optional[str] = None, university_id: Optional[str] = None,
                 issuer_key_fingerprint: Optional[str] = None, rsa_signature: Optional[str] = None,
                 error: Optional[str] = None):
        self.found                 = found
        self.is_authentic          = is_authentic
        self.tampering_detected    = tampering_detected
        self.stored_hash           = stored_hash
        self.transaction_id        = transaction_id
        self.block_number          = block_number
        self.anchored_at           = anchored_at
        self.student_matricule     = student_matricule
        self.university_id         = university_id
        self.issuer_key_fingerprint = issuer_key_fingerprint
        self.rsa_signature         = rsa_signature
        self.error                 = error
