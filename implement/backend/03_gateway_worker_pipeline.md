# BE-03. Model Ingest Pipeline (No GPU)

## Summary
서버는 GPU 재구성을 하지 않는다. iOS에서 생성된 모델 파일을 ingest/publish 한다.

## 1) Ingest Payload Minimum
1. asset/session/owner identifiers
2. uploaded file metadata (role/key/size/checksum)
3. dims and dimsSource metadata
4. preview image metadata (optional)

## 2) Ingest Sequence
1. `uploads/init` 요청으로 presigned targets 발급
2. iOS가 storage에 직접 업로드
3. `uploads/complete` 요청으로 파일 검증
4. asset status를 `READY`로 전환
5. `products/publish`로 게시

## 3) Artifact Key Naming
1. `assets/{assetId}/model.usdz`
2. `assets/{assetId}/model.glb` (optional)
3. `assets/{assetId}/preview.png` (optional)

## 4) Integrity Rule
1. complete 단계에서 object 존재 검증
2. size/checksum 검증 실패 시 `FAILED`
3. publish는 `READY` asset만 허용

## 5) Invariants
1. 서버는 모델 생성/수정 연산을 하지 않는다.
2. 동일 asset/file_role 중복 row 금지
3. publish 후 ar-asset 조회 일관성 유지

## 6) Evidence Expectations
- ingest timeline: `evidence/backend/YYYY-MM-DD_ingest_timeline.md`
- artifact integrity checks: `evidence/backend/YYYY-MM-DD_artifact_integrity.md`
