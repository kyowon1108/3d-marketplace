import enum


class AssetStatus(enum.StrEnum):
    INITIATED = "INITIATED"
    UPLOADING = "UPLOADING"
    READY = "READY"
    FAILED = "FAILED"
    PUBLISHED = "PUBLISHED"


class FileRole(enum.StrEnum):
    MODEL_USDZ = "MODEL_USDZ"
    MODEL_GLB = "MODEL_GLB"
    PREVIEW_PNG = "PREVIEW_PNG"


class DimsSource(enum.StrEnum):
    IOS_LIDAR = "ios_lidar"
    IOS_MANUAL = "ios_manual"
    UNKNOWN = "unknown"


class ArAvailability(enum.StrEnum):
    READY = "READY"
    PROCESSING = "PROCESSING"
    NONE = "NONE"


class ImageType(enum.StrEnum):
    THUMBNAIL = "THUMBNAIL"
    DISPLAY = "DISPLAY"


class MessageType(enum.StrEnum):
    TEXT = "TEXT"
    IMAGE = "IMAGE"


class ProductStatus(enum.StrEnum):
    FOR_SALE = "FOR_SALE"
    RESERVED = "RESERVED"
    SOLD_OUT = "SOLD_OUT"
