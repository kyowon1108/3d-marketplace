import enum


class AssetStatus(str, enum.Enum):
    INITIATED = "INITIATED"
    UPLOADING = "UPLOADING"
    READY = "READY"
    FAILED = "FAILED"
    PUBLISHED = "PUBLISHED"


class FileRole(str, enum.Enum):
    MODEL_USDZ = "MODEL_USDZ"
    MODEL_GLB = "MODEL_GLB"
    PREVIEW_PNG = "PREVIEW_PNG"


class DimsSource(str, enum.Enum):
    IOS_LIDAR = "ios_lidar"
    IOS_MANUAL = "ios_manual"
    UNKNOWN = "unknown"


class ArAvailability(str, enum.Enum):
    READY = "READY"
    PROCESSING = "PROCESSING"
    NONE = "NONE"
