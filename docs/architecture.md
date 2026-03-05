# Architecture

## LiDAR → Publish Pipeline

```
iPhone (iOS)
  └─ SweepCaptureEngine (LiDAR, 10-20s sweep)
       └─ FrameSelector (quality + yaw filtering)
            └─ LocalModelBuilder (PhotogrammetrySession, on-device)
                 └─ ModelExportCoordinator
                      ├─ USDZ export
                      ├─ GLB export
                      └─ Thumbnail + dims (bounding box)
                           │
                           ▼
                  POST /v1/model-assets/uploads/init
                  (server returns presigned S3 URLs)
                           │
                           ▼
                  Direct S3 upload (iOS → S3)
                           │
                           ▼
                  POST /v1/model-assets/uploads/complete
                  (server: SHA256 checksum + size verify → READY)
                           │
                           ▼
                  POST /v1/products/publish
                  (asset.status=READY required → PUBLISHED)
                           │
                           ▼
                  Buyer: GET /v1/products/{id}/ar-asset
                  (availability: READY/PROCESSING/NONE)
                           │
                           ▼
                  AR Placement (RealityKit, footprint-first)
```

The server does **not** perform 3D modeling or reconstruction. It is a pure ingest/store/publish layer.

---

## Asset State Machine

```
INITIATED ──► UPLOADING ──► READY ──► PUBLISHED
                    │
                    └──► FAILED
```

| State | Meaning |
|---|---|
| INITIATED | upload/init called; presigned URLs issued |
| UPLOADING | first file chunk received (tracked externally) |
| READY | complete called; checksum + size verified |
| PUBLISHED | product published; asset publicly reachable |
| FAILED | checksum mismatch, missing object, or explicit failure |

### Availability Mapping (buyer-facing)

| Asset state | ar-asset availability |
|---|---|
| READY or PUBLISHED | `READY` — AR placement enabled |
| INITIATED or UPLOADING | `PROCESSING` — show loading state |
| FAILED or none | `NONE` — no 3D available |

---

## AI Agent Workflow

What Claude Code automates vs. what requires a human decision:

| Layer | AI Automates | Requires Human Decision |
|---|---|---|
| DB schema | Migration scaffolding, boilerplate constraints | Column constraint values, CHECK enum lists |
| Security | Test coverage for auth paths, middleware wiring | Secret rotation, presigned URL TTL policy |
| Logging | Adding log calls, middleware | Log retention policy, PII scrubbing rules |
| API | CRUD endpoint structure, Pydantic schemas | Breaking-change policy, rate limits |
| iOS | UI layout from spec, API client wiring | App Store review criteria, LiDAR UX copy |

### Guardrails in Practice

- **Evidence files**: Every Gate checklist item requires a linked evidence file (`implement/evidence/{db|backend|ios}/YYYY-MM-DD_<topic>.md`).
- **Gate checklist**: Changes are only promoted when every checklist item is `PASS`.
- **No scope expansion**: AI does not add features, refactor surrounding code, or expand task scope without explicit instruction.
- **Plan-first**: `EnterPlanMode` is used before any non-trivial change.

---

## iOS Module Map

```
apps/ios/
├── Modules/
│   ├── CaptureKit/        SweepCaptureEngine, FrameSelector
│   ├── ModelingKit/       LocalModelBuilder, ModelExportCoordinator
│   ├── ARPlacementKit/    RealityKit footprint-first placement, dims labels
│   ├── Networking/        APIClient, WebSocketManager, ModelDownloader
│   └── Auth/              AuthManager, KeychainHelper
└── Features/
    ├── SellNew/           Full seller listing flow (capture → publish)
    ├── ProductDetail/     AR opt-in, dims display, chat/purchase CTA
    └── ...                (11 screens total, 1:1 parity with web routes)
```

---

## Security Model

| Concern | Mechanism |
|---|---|
| Upload integrity | SHA256 checksum + byte size verified on `/uploads/complete` |
| Idempotency | `Idempotency-Key` header; duplicate requests return cached result |
| Presigned URL expiry | S3 presigned URLs have enforced TTL; server does not store raw credentials |
| Owner scope | Publish/edit/delete only by asset/product owner |
| Failure codes | `409` checksum mismatch / missing object; `403` owner mismatch |
| JWT | 30-min access token + 30-day refresh token; refresh token stored and revocable |
