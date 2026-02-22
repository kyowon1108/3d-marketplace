# Evidence Report Template

- Date: 2026-02-22
- Topic: Migration Chain Application + Alembic head/current aligned
- Gate: A

## 1) Commands Executed
```bash
alembic -c services/api/alembic.ini upgrade head
alembic -c services/api/alembic.ini current
```

## 2) Result Summary
- 5 migrations (001 ~ 005) applied successfully in order:
  1. `001_create_users_table` — users 테이블 생성
  2. `002_create_capture_sessions` — capture_sessions 테이블 생성
  3. `003_create_model_assets_and_files` — model_assets, model_asset_files 테이블 생성
  4. `004_create_products_and_chat` — products, chat_rooms, chat_messages 테이블 생성
  5. `005_create_idempotency_keys` — idempotency_keys 테이블 생성
- `alembic current` 출력: `005 (head)` — head와 current가 일치
- 생성된 테이블 목록: users, capture_sessions, model_assets, model_asset_files, products, chat_rooms, chat_messages, idempotency_keys
- 모든 migration에서 오류 없음, 순서 의존성 정상 충족

## 3) Interpretation
- Migration chain이 001부터 005까지 순차적으로 적용되며, 테이블 간 FK 의존성이 올바르게 해소된다.
- Alembic current = head 확인으로 migration drift가 없음을 증명한다.
- 모든 핵심 테이블(model_assets, model_asset_files, idempotency_keys)이 정상 생성되어 Gate A의 DB 스키마 요구사항을 충족한다.

## 4) Decision
- `PASS`

## 5) Follow-up
- Gate B에서 Backend API 라우터가 이 스키마를 정상적으로 사용하는지 검증 필요.
- Production 환경에서의 migration 적용은 별도 검증 대상 (현재는 local/test DB 기준).
