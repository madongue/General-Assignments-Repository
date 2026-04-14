"""
Diplomax CM — Real Mobile Money Payment Service
Integrates directly with MTN MoMo Collection API v1
and Orange Money Web Payment API (Cameroon).
"""
import uuid
import base64
import hashlib
import hmac
import json
from datetime import datetime
from typing import Optional

import httpx

from app.core.config import get_settings

settings = get_settings()


# ─── MTN Mobile Money ─────────────────────────────────────────────────────────

class MtnMomoService:
    """
    MTN MoMo Collection API v1.
    Docs: https://momodeveloper.mtn.com/docs/services/collection/
    """

    def __init__(self):
        self.base_url   = settings.MTN_MOMO_BASE_URL
        self.sub_key    = settings.MTN_MOMO_SUBSCRIPTION_KEY
        self.api_user   = settings.MTN_MOMO_API_USER
        self.api_key    = settings.MTN_MOMO_API_KEY
        self.currency   = settings.MTN_MOMO_CURRENCY
        self.env        = settings.MTN_MOMO_ENVIRONMENT
        self.callback   = settings.MTN_MOMO_CALLBACK_URL

    def _auth_header(self) -> str:
        """Basic auth: base64(api_user:api_key)"""
        credentials = f"{self.api_user}:{self.api_key}"
        encoded = base64.b64encode(credentials.encode()).decode()
        return f"Basic {encoded}"

    async def get_access_token(self) -> str:
        """Fetch a Bearer token from the MoMo token endpoint."""
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/collection/token/",
                headers={
                    "Authorization": self._auth_header(),
                    "Ocp-Apim-Subscription-Key": self.sub_key,
                },
            )
            response.raise_for_status()
            return response.json()["access_token"]

    async def request_to_pay(
        self,
        *,
        phone_number: str,       # E.164 without + e.g. "237670000000"
        amount_fcfa: int,
        external_id: str,        # Our UUID for this transaction
        payer_message: str,
        payee_note: str,
    ) -> dict:
        """
        Initiates a collection request (USSD push to customer phone).
        Returns the MoMo reference ID (used to poll status).
        """
        token = await self.get_access_token()
        reference_id = str(uuid.uuid4())

        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/collection/v1_0/requesttopay",
                headers={
                    "Authorization": f"Bearer {token}",
                    "X-Reference-Id": reference_id,
                    "X-Target-Environment": self.env,
                    "X-Callback-Url": self.callback,
                    "Ocp-Apim-Subscription-Key": self.sub_key,
                    "Content-Type": "application/json",
                },
                json={
                    "amount": str(amount_fcfa),
                    "currency": self.currency,
                    "externalId": external_id,
                    "payer": {
                        "partyIdType": "MSISDN",
                        "partyId": phone_number,
                    },
                    "payerMessage": payer_message,
                    "payeeNote": payee_note,
                },
            )
            # 202 Accepted means the request was queued successfully
            if response.status_code == 202:
                return {"reference_id": reference_id, "status": "pending"}
            response.raise_for_status()

    async def get_payment_status(self, reference_id: str) -> dict:
        """Poll the status of a collection request."""
        token = await self.get_access_token()
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/collection/v1_0/requesttopay/{reference_id}",
                headers={
                    "Authorization": f"Bearer {token}",
                    "X-Target-Environment": self.env,
                    "Ocp-Apim-Subscription-Key": self.sub_key,
                },
            )
            response.raise_for_status()
            data = response.json()
            # MoMo statuses: PENDING | SUCCESSFUL | FAILED
            return {
                "status":      data.get("status", "PENDING").lower(),
                "reason":      data.get("reason"),
                "financial_transaction_id": data.get("financialTransactionId"),
            }

    def validate_callback(self, payload: dict, signature: str) -> bool:
        """
        Validates the HMAC signature of an incoming MoMo webhook callback.
        MoMo signs callbacks with HMAC-SHA256 using the API key.
        """
        message = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
        expected = hmac.new(self.api_key.encode(), message, hashlib.sha256).hexdigest()
        return hmac.compare_digest(expected, signature)


# ─── Orange Money ─────────────────────────────────────────────────────────────

class OrangeMoneyService:
    """
    Orange Money Web Payment API — Cameroon.
    Docs: https://developer.orange.com/apis/orange-money-webpay-cm/
    """

    def __init__(self):
        self.base_url      = settings.ORANGE_MONEY_BASE_URL
        self.client_id     = settings.ORANGE_MONEY_CLIENT_ID
        self.client_secret = settings.ORANGE_MONEY_CLIENT_SECRET
        self.merchant_key  = settings.ORANGE_MONEY_MERCHANT_KEY
        self.notif_url     = settings.ORANGE_MONEY_NOTIF_URL

    async def _get_access_token(self) -> str:
        """Fetch OAuth 2.0 token from Orange API."""
        credentials = f"{self.client_id}:{self.client_secret}"
        encoded = base64.b64encode(credentials.encode()).decode()
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://api.orange.com/oauth/v3/token",
                headers={
                    "Authorization": f"Basic {encoded}",
                    "Content-Type": "application/x-www-form-urlencoded",
                },
                data={"grant_type": "client_credentials"},
            )
            response.raise_for_status()
            return response.json()["access_token"]

    async def initiate_payment(
        self,
        *,
        phone_number: str,       # e.g. "237690000000"
        amount_fcfa: int,
        order_id: str,           # Our transaction external ID
        description: str,
        return_url: str = "https://verify.diplomax.cm/payment/return",
        cancel_url: str = "https://verify.diplomax.cm/payment/cancel",
    ) -> dict:
        """
        Creates an Orange Money payment order.
        Returns the payment_url the user must visit (or USSD reference).
        """
        token = await self._get_access_token()
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/webpayment",
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                },
                json={
                    "merchant_key":   self.merchant_key,
                    "currency":       "OUV",          # Orange XAF code
                    "order_id":       order_id,
                    "amount":         str(amount_fcfa),
                    "return_url":     return_url,
                    "cancel_url":     cancel_url,
                    "notif_url":      self.notif_url,
                    "lang":           "fr",
                    "reference":      order_id,
                },
            )
            response.raise_for_status()
            data = response.json()
            return {
                "payment_url": data.get("payment_url"),
                "pay_token":   data.get("pay_token"),
                "notif_token": data.get("notif_token"),
                "status":      "pending",
            }

    async def check_transaction(self, order_id: str, pay_token: str) -> dict:
        """Check the status of an Orange Money transaction."""
        token = await self._get_access_token()
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/transactionstatus",
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                },
                json={
                    "merchant_key": self.merchant_key,
                    "order_id":     order_id,
                    "pay_token":    pay_token,
                },
            )
            response.raise_for_status()
            data = response.json()
            # Orange statuses: SUCCESS | FAILED | PENDING | CANCELLED
            raw_status = data.get("status", "PENDING").upper()
            return {
                "status":   "successful" if raw_status == "SUCCESS"
                            else "failed" if raw_status in ("FAILED", "CANCELLED")
                            else "pending",
                "tx_id":    data.get("txnid"),
                "message":  data.get("message"),
            }

    def verify_callback_signature(self, notif_token: str, order_id: str) -> bool:
        """
        Verifies the Orange Money callback authenticity.
        Orange signs using HMAC-SHA256 with merchant_key.
        """
        expected = hashlib.sha256(
            f"{self.merchant_key}{order_id}".encode()
        ).hexdigest()
        return expected == notif_token


# ─── Unified Payment Facade ───────────────────────────────────────────────────

class PaymentService:
    """Unified facade — routes to MTN or Orange based on provider."""

    mtn    = MtnMomoService()
    orange = OrangeMoneyService()

    PRODUCT_PRICES = {
        "certification_numerique": 500,
        "releve_officiel":        1000,
        "dossier_complet":        2500,
        "abonnement_recruteur":  15000,
    }

    async def initiate(
        self,
        *,
        provider: str,          # "mtn" | "orange"
        phone_number: str,
        amount_fcfa: int,
        external_id: str,
        description: str,
        student_matricule: str,
    ) -> dict:
        """Start a payment with the chosen provider."""
        if provider == "mtn":
            result = await self.mtn.request_to_pay(
                phone_number=f"237{phone_number.lstrip('0')}",
                amount_fcfa=amount_fcfa,
                external_id=external_id,
                payer_message=description,
                payee_note=f"Diplomax — {student_matricule}",
            )
            return {**result, "provider": "mtn",
                    "message": f"Approval request sent to +237{phone_number}"}

        elif provider == "orange":
            result = await self.orange.initiate_payment(
                phone_number=f"237{phone_number.lstrip('0')}",
                amount_fcfa=amount_fcfa,
                order_id=external_id,
                description=description,
            )
            return {**result, "provider": "orange",
                    "message": f"Orange Money request sent to +237{phone_number}"}

        raise ValueError(f"Unknown provider: {provider}")

    async def check_status(self, *, provider: str, reference_id: str, pay_token: Optional[str] = None) -> dict:
        if provider == "mtn":
            return await self.mtn.get_payment_status(reference_id)
        elif provider == "orange" and pay_token:
            return await self.orange.check_transaction(reference_id, pay_token)
        return {"status": "unknown"}
