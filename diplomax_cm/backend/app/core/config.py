from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    APP_NAME: str = "Diplomax CM API"
    APP_VERSION: str = "2.0.0"
    DEBUG: bool = False
    ALLOWED_ORIGINS: list[str] = ["https://verify.diplomax.cm","https://app.diplomax.cm"]

    DATABASE_URL: str = ""
    REDIS_URL: str = "redis://localhost:6379/0"
    POSTGRES_USER: str = ""
    POSTGRES_PASSWORD: str = ""
    REDIS_PASSWORD: str = ""

    JWT_SECRET_KEY: str = ""
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    MASTER_AES_KEY_HEX: str = ""
    DEFAULT_ICT_ADMIN_PASSWORD: str = ""
    DEFAULT_STUDENT_PASSWORD: str = ""

    MTN_MOMO_BASE_URL: str = "https://sandbox.momodeveloper.mtn.com"
    MTN_MOMO_SUBSCRIPTION_KEY: str = ""
    MTN_MOMO_API_USER: str = ""
    MTN_MOMO_API_KEY: str = ""
    MTN_MOMO_ENVIRONMENT: str = "sandbox"
    MTN_MOMO_CURRENCY: str = "XAF"
    MTN_MOMO_CALLBACK_URL: str = "https://api.diplomax.cm/v1/payments/mtn/callback"

    ORANGE_MONEY_BASE_URL: str = "https://api.orange.com/orange-money-webpay/cm/v1"
    ORANGE_MONEY_CLIENT_ID: str = ""
    ORANGE_MONEY_CLIENT_SECRET: str = ""
    ORANGE_MONEY_MERCHANT_KEY: str = ""
    ORANGE_MONEY_NOTIF_URL: str = "https://api.diplomax.cm/v1/payments/orange/callback"

    FABRIC_GATEWAY_URL: str = "http://localhost:8080"
    FABRIC_CHANNEL_NAME: str = "diplomax-channel"
    FABRIC_CHAINCODE_NAME: str = "DiplomaxChaincode"
    FABRIC_MSP_ID: str = "DiploMaxMSP"

    FIREBASE_CREDENTIALS_PATH: str = "firebase-credentials.json"
    GOOGLE_APPLICATION_CREDENTIALS: str = "google-credentials.json"

    S3_ENDPOINT_URL: str = ""
    S3_ACCESS_KEY: str = ""
    S3_SECRET_KEY: str = ""
    S3_BUCKET_DOCUMENTS: str = "diplomax-documents"
    S3_BUCKET_PDFS: str = "diplomax-pdfs"

    ICT_UNIVERSITY_ID: str = "ict-university-yaounde"
    ICT_UNIVERSITY_NAME: str = "The ICT University"
    ICT_MATRICULE_PREFIX: str = "ICTU"

    INTL_SHARE_BASE_URL: str = "https://verify.diplomax.cm/intl"
    INTL_SHARE_DEFAULT_EXPIRY_DAYS: int = 30

@lru_cache
def get_settings() -> Settings:
    return Settings()
