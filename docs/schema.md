# DB Schema Reference

PostgreSQL 16. Managed by Alembic (current head: revision 014).

---

## Entity Relationships

```
users
  ├─< products (seller_id)
  ├─< purchases (buyer_id)
  ├─< product_likes (user_id)
  ├─< chat_rooms (buyer_id, seller_id)
  ├─< chat_messages (sender_id)
  └─< refresh_tokens (user_id)

model_assets
  ├─< model_asset_files (asset_id)
  ├─< products (asset_id)
  └─< capture_sessions (asset_id, optional)

products
  ├─< purchases (product_id)
  ├─< product_likes (product_id)
  ├─< chat_rooms (product_id)
  └─< asset_images (product_id)

chat_rooms
  └─< chat_messages (room_id)

idempotency_keys (actor_id, method, path, key)
```

---

## Table Summaries

| Table | Key Columns | Notes |
|---|---|---|
| `users` | id, email, name, provider, location_name | OAuth-only signup |
| `model_assets` | id, seller_id, status, dims_json | Status: INITIATED→UPLOADING→READY→PUBLISHED\|FAILED |
| `model_asset_files` | id, asset_id, file_role, storage_key, checksum, size_bytes | file_role: MODEL_USDZ \| MODEL_GLB \| PREVIEW_PNG |
| `capture_sessions` | id, asset_id, frame_count, capture_duration_s | Optional capture metadata |
| `products` | id, seller_id, asset_id, title, price_cents, status, category, condition, dims_comparison, published_at, deleted_at | soft delete via deleted_at |
| `purchases` | id, product_id, buyer_id, price_cents | One purchase per product |
| `asset_images` | id, product_id, url, image_type, sort_order | image_type: THUMBNAIL \| DISPLAY |
| `product_likes` | user_id, product_id | Unique pair |
| `chat_rooms` | id, product_id, buyer_id, seller_id, last_message_body, unread counts | |
| `chat_messages` | id, room_id, sender_id, body, image_url | |
| `idempotency_keys` | id, actor_id, method, path, key, response_status, response_body | |
| `refresh_tokens` | id, user_id, token_hash, expires_at, revoked_at | |

---

## Asset State Machine

```
INITIATED ──► UPLOADING ──► READY ──► PUBLISHED
                   │
                   └──► FAILED
```

Transition rules:
- `INITIATED → UPLOADING`: server records first upload activity
- `UPLOADING → READY`: `/uploads/complete` passes checksum + size verification
- `READY → PUBLISHED`: `/products/publish` called with `asset.status=READY`
- `UPLOADING → FAILED`: checksum mismatch or missing object on complete

---

## Constraints

### Unique Constraints

| Table | Columns | Rule |
|---|---|---|
| `model_asset_files` | `(asset_id, file_role)` | One file per role per asset |
| `model_asset_files` | `(storage_key)` | No duplicate S3 keys |
| `purchases` | `(product_id)` | One purchase per product |
| `product_likes` | `(user_id, product_id)` | One like per user per product |
| `idempotency_keys` | `(actor_id, method, path, key)` | Idempotent operations |

### Foreign Key Rules

| FK | On Delete |
|---|---|
| `products.asset_id → model_assets.id` | RESTRICT (asset must exist) |
| `products.seller_id → users.id` | RESTRICT |
| `model_asset_files.asset_id → model_assets.id` | CASCADE |
| `purchases.product_id → products.id` | RESTRICT |
| `chat_messages.room_id → chat_rooms.id` | CASCADE |

### CHECK Constraints

| Table | Column | Values |
|---|---|---|
| `products` | `category` | ELECTRONICS, FURNITURE, CLOTHING, BOOKS_MEDIA, SPORTS, LIVING, BEAUTY, HOBBY, OTHER (or NULL) |
| `products` | `condition` | NEW, LIKE_NEW, USED, WORN (or NULL) |
| `products` | `status` | FOR_SALE, RESERVED, SOLD_OUT |
| `model_assets` | `status` | INITIATED, UPLOADING, READY, PUBLISHED, FAILED |
| `model_asset_files` | `file_role` | MODEL_USDZ, MODEL_GLB, PREVIEW_PNG |

### Publish Gate

`products.asset_id` may only reference an asset where `status IN ('READY', 'PUBLISHED')`. Enforced at API level (Pydantic + router guard) and by DB CHECK on publish path.

---

## Indexes

| Index | Table | Columns | Purpose |
|---|---|---|---|
| `ix_products_category_published_at` | `products` | `(category, published_at DESC)` | Category feed queries |
| `ix_products_seller_id` | `products` | `(seller_id)` | Seller's listings |
| `ix_model_asset_files_asset_id` | `model_asset_files` | `(asset_id)` | Files by asset |
| `ix_chat_messages_room_id` | `chat_messages` | `(room_id)` | Message pagination |
| `ix_product_likes_user_id` | `product_likes` | `(user_id)` | User's liked items |

---

## Storage Key Patterns

| File role | Key pattern |
|---|---|
| MODEL_USDZ | `assets/{assetId}/model.usdz` |
| MODEL_GLB | `assets/{assetId}/model.glb` |
| PREVIEW_PNG | `assets/{assetId}/preview.png` |
