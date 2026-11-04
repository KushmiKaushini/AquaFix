import logging
from abc import ABC, abstractmethod
from typing import Optional, Dict, Any
from app.core.config import settings

logger = logging.getLogger(__name__)

class BaseNotificationService(ABC):
    """Abstract interface for push notification providers."""

    @abstractmethod
    def send_push_notification(
        self,
        token: str,
        title: str,
        body: str,
        data: Optional[Dict[str, Any]] = None,
    ) -> bool:
        """Send a push notification to a device token. Returns True on success."""
        pass


class MockNotificationService(BaseNotificationService):
    """In-memory notification logger used for local development, staging, and automated tests."""

    def __init__(self):
        self.sent_notifications = []

    def send_push_notification(
        self,
        token: str,
        title: str,
        body: str,
        data: Optional[Dict[str, Any]] = None,
    ) -> bool:
        record = {
            "token": token,
            "title": title,
            "body": body,
            "data": data or {},
        }
        self.sent_notifications.append(record)
        logger.info(f"[Mock Push Notification] Sent to {token[:12]}...: '{title}' - {body}")
        return True


class FCMNotificationService(BaseNotificationService):
    """Production Firebase Cloud Messaging service using Google Firebase Admin SDK."""

    def __init__(self, credentials_path: str):
        self.credentials_path = credentials_path
        self._initialized = False
        self._init_firebase()

    def _init_firebase(self):
        if not self.credentials_path:
            logger.warning("FCM credentials path not specified. Falling back to mock notification mode.")
            return

        try:
            import firebase_admin
            from firebase_admin import credentials

            if not firebase_admin._apps:
                cred = credentials.Certificate(self.credentials_path)
                firebase_admin.initialize_app(cred)
            self._initialized = True
            logger.info("Firebase Admin SDK successfully initialized.")
        except Exception as e:
            logger.error(f"Failed to initialize Firebase Admin SDK: {e}. Falling back to mock notifications.")
            self._initialized = False

    def send_push_notification(
        self,
        token: str,
        title: str,
        body: str,
        data: Optional[Dict[str, Any]] = None,
    ) -> bool:
        if not self._initialized:
            logger.info(f"[FCM Fallback] Simulated push to {token[:12]}...: '{title}' - {body}")
            return True

        try:
            from firebase_admin import messaging

            # Ensure all data values are strings for FCM payload
            string_data = {k: str(v) for k, v in (data or {}).items()}

            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=string_data,
                token=token,
            )
            response = messaging.send(message)
            logger.info(f"FCM notification sent successfully: message_id={response}")
            return True
        except Exception as e:
            logger.error(f"Failed to send FCM push notification to {token[:12]}...: {e}")
            return False


# Global singleton instance
_notification_service: Optional[BaseNotificationService] = None

def get_notification_service() -> BaseNotificationService:
    """Dependency provider for notification service."""
    global _notification_service
    if _notification_service is None:
        if settings.FIREBASE_CREDENTIALS_PATH:
            _notification_service = FCMNotificationService(settings.FIREBASE_CREDENTIALS_PATH)
        else:
            _notification_service = MockNotificationService()
    return _notification_service
