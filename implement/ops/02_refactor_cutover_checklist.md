# OPS-02. Refactor Cutover Checklist

## Summary
Cutover는 반드시 `DB -> Backend -> iOS` 순으로 수행한다.
운영 기준은 `ops/03~06` 문서를 함께 따른다.

## 0) Required Governance References
1. `ops/03_ai_delivery_workflow.md`
2. `ops/04_git_commit_pr_workflow.md`
3. `ops/05_documentation_governance.md`
4. `ops/06_ai_task_contract.md`
5. `templates/evidence_report_template.md`
6. `templates/gate_decision_template.md`

## 1) Pre-Cutover
1. baseline branch/commit 기록
2. DB backup 확보
3. env config 확정
4. docs/api and runtime contract sync 확인
5. task brief 작성 (`templates/task_brief_template.md`)

## 2) Cutover Steps
### Step A: DB
1. migrate head 적용
2. schema/invariant 확인
3. Gate A decision (`templates/gate_decision_template.md`)

### Step B: Backend
1. runtime bring-up
2. upload/publish/idempotency/security 확인
3. Gate B decision (`templates/gate_decision_template.md`)

### Step C: iOS
1. route parity smoke
2. seller/buyer/chat/auth 시연
3. Gate C decision (`templates/gate_decision_template.md`)

## 3) Go/No-Go Rules
### GO
1. 모든 게이트 PASS
2. 증빙 파일 누락 없음
3. blocker 없음

### NO-GO
1. asset status 전이 불일치
2. upload complete 무결성 검증 실패
3. ar-asset availability 전이 오류
4. iOS parity 핵심 시나리오 실패

## 4) Rollback Baseline
1. write traffic stop
2. image/runtime rollback
3. DB는 downgrade보다 forward-fix 우선

## 5) Final Evidence Index
- `evidence/db/`
- `evidence/backend/`
- `evidence/ios/`

## 6) Sign-off Output
각 Gate 종료 시 아래 2개를 남긴다.
1. evidence report (`templates/evidence_report_template.md`)
2. gate decision (`templates/gate_decision_template.md`)
