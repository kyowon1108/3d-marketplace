# 00. System Snapshot (From Empty Start)

## Summary
이 문서는 저장소가 비어 있다고 가정하고 시스템을 복구할 때 필요한 **최소 아키텍처 기준선**을 정의한다.

핵심 전제:
- iOS가 로컬에서 3D 모델링을 수행한다.
- Backend는 모델 파일 업로드/검증/저장/게시/조회만 담당한다.
- Backend에 GPU 재구성 파이프라인은 두지 않는다.

## 1) Target Monorepo Layout
1. `apps/web`: Next.js app router client
2. `apps/ios`: SwiftUI iPhone app (capture + local modeling + AR placement)
3. `services/api`: FastAPI + SQLAlchemy + Alembic
4. `docs`, `infra`, `scripts`, `packages`

## 2) Core Runtime Flow
1. Seller iOS capture + local model generation (USDZ/GLB)
2. Backend upload init (presigned targets)
3. iOS uploads model/preview artifacts
4. Backend upload complete (checksum/size/object existence verify)
5. publish product
6. buyer browses product
7. buyer iOS AR placement (footprint-first)

## 3) Source of Truth Boundaries
1. Contract: `docs/api/openapi.yaml`
2. API behavior: `services/api/app/routers/*`
3. Persistence: `services/api/app/models/*`, `services/api/app/repositories/*`
4. iOS contract mapping: `apps/ios/Modules/Networking/ContractEnums.swift`
5. Web generated types: `apps/web/lib/api.generated.ts`

## 4) Production Invariants (Must Keep)
1. 서버는 모델링 계산을 수행하지 않는다.
2. 모델 파일 업로드 완료 전 publish 불가.
3. upload complete는 idempotent 해야 한다.
4. artifact key와 checksum 매핑은 검증되어야 한다.
5. buyer AR는 footprint-first 배치 원칙을 유지한다.

## 5) Recovery Entry Questions
1. Migration head is aligned with runtime code?
2. OpenAPI and generated clients are in sync?
3. Asset upload/publish invariants are observable in DB and API?
4. iOS/web canonical route mapping is documented?
