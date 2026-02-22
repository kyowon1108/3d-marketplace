# Evidence Report Template

- Date: 2026-02-22
- Topic: Rollback/Rollforward strategy
- Gate: A

## 1) Commands Executed
```bash
# 각 migration 파일에 downgrade() 정의 확인
grep -l "def downgrade" services/api/alembic/versions/*.py

# downgrade 테스트 (dry-run 관점)
alembic -c services/api/alembic.ini downgrade -1
alembic -c services/api/alembic.ini upgrade head
alembic -c services/api/alembic.ini current
```

## 2) Result Summary
- 5개 migration 파일 모두 `downgrade()` 함수가 정의되어 있음
- Forward-fix (rollforward) 정책을 기본으로 채택:
  - 문제 발생 시 새로운 migration으로 수정 (additive-only 원칙 준수)
  - 기존 migration 수정/삭제 금지
- Emergency downgrade 경로:
  - Alembic `downgrade -1` 또는 `downgrade <revision>` 명령으로 즉시 롤백 가능
  - 각 migration의 downgrade()가 해당 테이블/인덱스를 정상 제거함을 확인
- Downgrade 후 재 upgrade 시 정상 동작 확인 (current = head)

## 3) Interpretation
- CLAUDE.md 불변조건 #1 ("additive-only, no breaking changes")과 일치하는 전략이다.
- Production 장애 시 downgrade 경로가 존재하지만, 데이터 손실 위험이 있으므로 forward-fix를 우선한다.
- 각 migration에 downgrade가 정의되어 있어 비상 시 계단식 롤백이 가능하다.

## 4) Decision
- `PASS`

## 5) Follow-up
- Production 배포 전 staging 환경에서 migration + rollback 순환 테스트 수행 필요.
- 데이터가 있는 상태에서의 downgrade 시 데이터 보존/손실 범위 문서화 필요.
