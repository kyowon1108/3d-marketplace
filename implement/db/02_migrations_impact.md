# DB-02. Migrations Impact

## Summary
빈 저장소에서 시작하더라도 migration은 순서/의미를 유지해야 한다.

## 1) Migration Order (Mandatory)
1. base auth/chat/product tables
2. model asset tables (`model_assets`, `model_asset_files`)
3. idempotency and governance tables
4. publish-read optimization indexes

## 2) Why Order Matters
1. publish 전에 asset linkage schema가 있어야 한다.
2. upload complete idempotency는 중복 요청 안전성에 필수다.
3. read-model 인덱스는 buyer 조회 성능에 직접 영향이 있다.

## 3) Upgrade Risks
1. asset files constraint 미적용 시 중복 key 오염 가능
2. idempotency 미적용 시 complete/publish 중복 처리 리스크

## 4) Downgrade Risks
1. file role/asset linkage 손실 가능
2. 단순 downgrade보다 forward-fix 우선

## 5) Recovery Commands
```bash
alembic -c services/api/alembic.ini upgrade head
alembic -c services/api/alembic.ini current
alembic -c services/api/alembic.ini heads
```

## 6) Evidence Expectations
- migration 실행 로그: `evidence/db/YYYY-MM-DD_migration_apply.md`
- pre/post schema diff: `evidence/db/YYYY-MM-DD_schema_diff.md`
