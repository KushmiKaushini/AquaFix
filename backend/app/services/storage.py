import os
import uuid
import shutil
import logging
from abc import ABC, abstractmethod
from fastapi import UploadFile
from app.core.config import settings

logger = logging.getLogger("aquafix.storage")

class BaseStorageService(ABC):
    @abstractmethod
    async def save_file(self, file: UploadFile, file_extension: str) -> str:
        """Saves uploaded file and returns accessible asset URL."""
        pass

    @abstractmethod
    async def delete_file(self, file_url: str) -> bool:
        """Deletes file by URL."""
        pass


class LocalStorageService(BaseStorageService):
    def __init__(self, upload_dir: str = None):
        self.upload_dir = upload_dir or os.path.join(os.getcwd(), "uploads")
        os.makedirs(self.upload_dir, exist_ok=True)

    async def save_file(self, file: UploadFile, file_extension: str) -> str:
        unique_filename = f"{uuid.uuid4()}{file_extension}"
        filepath = os.path.join(self.upload_dir, unique_filename)

        await file.seek(0)
        with open(filepath, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        return f"/uploads/{unique_filename}"

    async def delete_file(self, file_url: str) -> bool:
        try:
            filename = os.path.basename(file_url)
            filepath = os.path.join(self.upload_dir, filename)
            if os.path.exists(filepath):
                os.remove(filepath)
                return True
            return False
        except Exception as e:
            logger.warning(f"Failed to delete local file {file_url}: {str(e)}")
            return False


class S3StorageService(BaseStorageService):
    def __init__(self, bucket_name: str, region: str = "us-east-1"):
        self.bucket_name = bucket_name
        self.region = region
        try:
            import boto3
            self.s3_client = boto3.client("s3", region_name=region)
        except Exception as e:
            logger.error(f"Failed to initialize S3 client: {str(e)}")
            self.s3_client = None

    async def save_file(self, file: UploadFile, file_extension: str) -> str:
        if not self.s3_client:
            raise RuntimeError("S3 client not initialized")
        
        unique_filename = f"incidents/{uuid.uuid4()}{file_extension}"
        await file.seek(0)
        
        self.s3_client.upload_fileobj(
            file.file,
            self.bucket_name,
            unique_filename,
            ExtraArgs={"ContentType": file.content_type or "image/jpeg"}
        )
        return f"https://{self.bucket_name}.s3.{self.region}.amazonaws.com/{unique_filename}"

    async def delete_file(self, file_url: str) -> bool:
        if not self.s3_client:
            return False
        try:
            key = file_url.split(f"{self.bucket_name}.s3.{self.region}.amazonaws.com/")[1]
            self.s3_client.delete_object(Bucket=self.bucket_name, Key=key)
            return True
        except Exception as e:
            logger.warning(f"Failed to delete S3 object {file_url}: {str(e)}")
            return False


def get_storage_service() -> BaseStorageService:
    backend_type = settings.STORAGE_BACKEND.lower()
    if backend_type == "s3" and settings.S3_BUCKET_NAME:
        return S3StorageService(bucket_name=settings.S3_BUCKET_NAME, region=settings.AWS_REGION)
    return LocalStorageService()

storage_service = get_storage_service()
