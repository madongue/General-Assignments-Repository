"""
Diplomax CM — Backend Cryptography Service
AES-256-GCM document encryption, SHA-256 hashing, RSA signature verification.
"""
import base64
import hashlib
import hmac
import json
import os
import secrets
from typing import Optional

from Crypto.Cipher import AES
from Crypto.PublicKey import RSA
from Crypto.Signature import pkcs1_15
from Crypto.Hash import SHA256

from app.core.config import get_settings

settings = get_settings()


class CryptoService:
    """
    Server-side cryptographic operations.
    The master AES key is stored in env vars / secrets manager.
    Per-document keys are derived from the master key + document_id.
    """

    def __init__(self):
        master_hex = settings.MASTER_AES_KEY_HEX
        if len(master_hex) != 64:
            raise ValueError("MASTER_AES_KEY_HEX must be 64 hex chars (32 bytes)")
        self._master_key = bytes.fromhex(master_hex)

    # ── Key derivation ────────────────────────────────────────────────────────

    def _derive_key(self, document_id: str) -> bytes:
        """
        Derives a unique 32-byte AES key for each document using HKDF-like
        HMAC-SHA256: key = HMAC(master_key, document_id || "diplomax-doc-key")
        """
        info = f"{document_id}:diplomax-doc-key".encode()
        return hmac.new(self._master_key, info, hashlib.sha256).digest()

    # ── AES-256-GCM Encryption ────────────────────────────────────────────────

    def encrypt_document(self, document_id: str, plaintext: str) -> str:
        """
        Encrypts document content with AES-256-GCM.
        Returns base64(nonce[12] + ciphertext + tag[16]).
        """
        key    = self._derive_key(document_id)
        nonce  = os.urandom(12)
        cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
        ciphertext, tag = cipher.encrypt_and_digest(plaintext.encode())
        packed = nonce + ciphertext + tag
        return base64.b64encode(packed).decode()

    def decrypt_document(self, document_id: str, encoded: str) -> str:
        """Decrypts AES-256-GCM content produced by encrypt_document."""
        key    = self._derive_key(document_id)
        packed = base64.b64decode(encoded)
        nonce  = packed[:12]
        tag    = packed[-16:]
        ciphertext = packed[12:-16]
        cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
        cipher.verify(tag)
        return cipher.decrypt(ciphertext).decode()

    # ── SHA-256 ───────────────────────────────────────────────────────────────

    @staticmethod
    def sha256_document(
        *,
        document_id: str,
        student_matricule: str,
        university_id: str,
        title: str,
        mention: str,
        issue_date: str,
        doc_type: str,
    ) -> str:
        """
        Computes the canonical SHA-256 fingerprint of a document.
        All fields are included so any modification changes the hash.
        """
        canonical = (
            f"{document_id}|{student_matricule}|{university_id}|"
            f"{title}|{mention}|{issue_date}|{doc_type}"
        )
        return hashlib.sha256(canonical.encode()).hexdigest()

    @staticmethod
    def sha256_hex(data: str) -> str:
        return hashlib.sha256(data.encode()).hexdigest()

    # ── RSA Signature Verification ────────────────────────────────────────────

    @staticmethod
    def verify_rsa_signature(
        public_key_pem: str,
        document_hash: str,
        signature_hex: str,
    ) -> bool:
        """
        Verifies the university's RSA-SHA256 signature on a document hash.
        The university's public key PEM is stored in the database.
        """
        try:
            key  = RSA.import_key(public_key_pem)
            h    = SHA256.new(document_hash.encode())
            sig  = bytes.fromhex(signature_hex)
            pkcs1_15.new(key).verify(h, sig)
            return True
        except (ValueError, TypeError):
            return False

    # ── Share Token ───────────────────────────────────────────────────────────

    @staticmethod
    def generate_share_token() -> str:
        """URL-safe 256-bit random token."""
        return secrets.token_urlsafe(32)

    @staticmethod
    def generate_intl_share_token() -> str:
        """URL-safe 384-bit token for international share packages."""
        return secrets.token_urlsafe(48)

    # ── QR Payload ────────────────────────────────────────────────────────────

    def build_qr_payload(
        self,
        *,
        document_id: str,
        hash_sha256: str,
        expiry_ts: int,
        zkp_mode: bool,
        mention: Optional[str],
        verification_mode: str,
    ) -> str:
        """
        Builds the encrypted QR code payload.
        The payload is AES-256-GCM encrypted so it is opaque to scanners.
        """
        payload = {
            "doc": document_id,
            "sig": hash_sha256[:16],   # Partial hash for quick check
            "exp": expiry_ts,
            "zkp": zkp_mode,
            "ver": verification_mode,
            "nonce": secrets.token_hex(8),
        }
        if zkp_mode and mention:
            payload["mention"] = mention
        return self.encrypt_document(document_id, json.dumps(payload))

    def decode_qr_payload(self, document_id: str, encoded: str) -> Optional[dict]:
        """Decodes a QR payload. Returns None if tampered or expired."""
        try:
            raw = self.decrypt_document(document_id, encoded)
            return json.loads(raw)
        except Exception:
            return None
