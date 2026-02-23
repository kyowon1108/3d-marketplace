import Foundation

// MARK: - API Response Schemas aligned with openapi.yaml

// MARK: Products

struct ProductListResponse: Decodable {
    let products: [ProductResponse]
    let total: Int
    let page: Int
    let limit: Int
}

struct ProductResponse: Decodable, Identifiable {
    let id: String
    let asset_id: String?
    let title: String
    let description: String?
    let price_cents: Int
    let seller_id: String
    let seller_name: String?
    let seller_avatar_url: String?
    let seller_location_name: String?
    let thumbnail_url: String?
    let status: String
    let chat_count: Int?
    let likes_count: Int?
    let views_count: Int?
    let is_liked: Bool?
    let published_at: String?
    let created_at: String
}

struct ProductPublishRequest: Encodable {
    let asset_id: String
    let title: String
    let description: String?
    let price_cents: Int
}

struct LikeToggleResponse: Decodable {
    let liked: Bool
    let likes_count: Int
}

// MARK: Purchases

struct PurchaseAPIResponse: Decodable, Identifiable {
    let id: String
    let product_id: String
    let buyer_id: String
    let price_cents: Int
    let purchased_at: String
    let product: ProductResponse?
}

struct PurchaseListAPIResponse: Decodable {
    let purchases: [PurchaseAPIResponse]
    let total: Int
    let page: Int
    let limit: Int
}

// MARK: Upload

struct UploadInitRequest: Encodable {
    let dims_source: String
    let dims_width: Double?
    let dims_height: Double?
    let dims_depth: Double?
    let capture_session_id: String?
    let files: [FileInfo]
    let images: [ImageMeta]

    struct FileInfo: Encodable {
        let role: String // MODEL_USDZ, MODEL_GLB
        let size_bytes: Int
    }

    struct ImageMeta: Encodable {
        let image_type: String // THUMBNAIL, DISPLAY
        let sort_order: Int
        let size_bytes: Int
    }
}

struct UploadInitResponse: Decodable {
    let asset_id: String
    let status: String // UPLOADING
    let presigned_uploads: [PresignedUpload]
    let presigned_image_uploads: [PresignedImageUpload]

    struct PresignedUpload: Decodable {
        let role: String
        let url: String
        let expires_at: String
    }

    struct PresignedImageUpload: Decodable {
        let image_type: String
        let sort_order: Int
        let url: String
        let expires_at: String
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        asset_id = try container.decode(String.self, forKey: .asset_id)
        status = try container.decode(String.self, forKey: .status)
        presigned_uploads = try container.decode([PresignedUpload].self, forKey: .presigned_uploads)
        presigned_image_uploads = try container.decodeIfPresent([PresignedImageUpload].self, forKey: .presigned_image_uploads) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case asset_id, status, presigned_uploads, presigned_image_uploads
    }
}

struct UploadCompleteRequest: Encodable {
    let asset_id: String
    let files: [FileVerify]
    let images: [ImageVerify]

    struct FileVerify: Encodable {
        let role: String
        let size_bytes: Int
        let checksum_sha256: String
    }

    struct ImageVerify: Encodable {
        let image_type: String
        let sort_order: Int
        let size_bytes: Int
        let checksum_sha256: String
    }
}

struct UploadCompleteResponse: Decodable {
    let asset_id: String
    let status: String
    let files: [FileVerifyResult]
    let image_results: [ImageVerifyResult]

    struct FileVerifyResult: Decodable {
        let role: String
        let verified: Bool
    }

    struct ImageVerifyResult: Decodable {
        let image_type: String
        let sort_order: Int
        let verified: Bool
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        asset_id = try container.decode(String.self, forKey: .asset_id)
        status = try container.decode(String.self, forKey: .status)
        files = try container.decode([FileVerifyResult].self, forKey: .files)
        image_results = try container.decodeIfPresent([ImageVerifyResult].self, forKey: .image_results) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case asset_id, status, files, image_results
    }
}

// MARK: Auth

struct AuthTokenResponse: Decodable {
    let access_token: String
    let token_type: String
    let refresh_token: String?
    let user: AuthUserResponse
}

struct TokenRefreshRequest: Encodable {
    let refresh_token: String
}

struct TokenRefreshResponse: Decodable {
    let access_token: String
    let token_type: String
    let refresh_token: String?
    let expires_in: Int?
}

struct LogoutRequest: Encodable {
    let refresh_token: String
}

struct EmptyResponse: Decodable {}

struct AuthUserResponse: Decodable {
    let id: String
    let email: String
    let name: String
    let provider: String
    let avatar_url: String?
    let location_name: String?
    let created_at: String
}

// MARK: Profile

struct UserSummaryResponse: Decodable {
    let user: AuthUserResponse
    let product_count: Int
    let unread_messages: Int
}

// MARK: Chat

struct ChatRoomListResponse: Decodable {
    let rooms: [ChatRoomResponse]
}

struct ChatRoomResponse: Decodable, Identifiable {
    let id: String
    let product_id: String
    let buyer_id: String
    let seller_id: String
    let subject: String
    let created_at: String
    let last_message_at: String?
    let last_message_body: String?
    let unread_count: Int
    let buyer_name: String
    let seller_name: String
    let product_title: String
    let product_thumbnail_url: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        product_id = try container.decode(String.self, forKey: .product_id)
        buyer_id = try container.decode(String.self, forKey: .buyer_id)
        seller_id = try container.decode(String.self, forKey: .seller_id)
        subject = try container.decode(String.self, forKey: .subject)
        created_at = try container.decode(String.self, forKey: .created_at)
        last_message_at = try container.decodeIfPresent(String.self, forKey: .last_message_at)
        last_message_body = try container.decodeIfPresent(String.self, forKey: .last_message_body)
        unread_count = try container.decodeIfPresent(Int.self, forKey: .unread_count) ?? 0
        buyer_name = try container.decodeIfPresent(String.self, forKey: .buyer_name) ?? ""
        seller_name = try container.decodeIfPresent(String.self, forKey: .seller_name) ?? ""
        product_title = try container.decodeIfPresent(String.self, forKey: .product_title) ?? ""
        product_thumbnail_url = try container.decodeIfPresent(String.self, forKey: .product_thumbnail_url)
    }

    private enum CodingKeys: String, CodingKey {
        case id, product_id, buyer_id, seller_id, subject, created_at
        case last_message_at, last_message_body, unread_count
        case buyer_name, seller_name, product_title, product_thumbnail_url
    }
}

struct ChatMessageListResponse: Decodable {
    let messages: [ChatMessageResponse]
}

struct ChatMessageResponse: Decodable, Identifiable {
    let id: String
    let room_id: String
    let sender_id: String
    let body: String
    let created_at: String
}

struct SendMessageRequest: Encodable {
    let body: String
}

struct CreateChatRoomRequest: Encodable {
    let subject: String
}

// MARK: Asset

struct ModelAssetResponse: Decodable {
    let id: String
    let owner_id: String
    let status: String
    let availability: String
    let dims_source: String?
    let dims_width: Double?
    let dims_height: Double?
    let dims_depth: Double?
    let files: [AssetFileInfo]
    let images: [AssetImageInfo]
    let created_at: String
    let updated_at: String

    struct AssetFileInfo: Decodable {
        let role: String
        let storage_key: String
        let size_bytes: Int
        let checksum_sha256: String
    }

    struct AssetImageInfo: Decodable {
        let id: String
        let image_type: String
        let storage_key: String
        let size_bytes: Int
        let sort_order: Int
    }
}

struct ArAssetResponse: Decodable {
    let availability: String
    let asset_id: String?
    let files: [ArAssetFile]
    let dims_source: String?
    let dims_trust: String?

    struct ArAssetFile: Decodable {
        let role: String
        let url: String
        let type: String
    }
}
