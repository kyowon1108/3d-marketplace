# 3D Marketplace Refactor Master Plan

- Mode: Gate-based
- Sequence: `DB -> Backend -> iOS`
- Target: Web baseline parity on iOS (`structure + copy + state`)
- Policy: Public API is additive-only, no breaking changes on `/v1`
- Runtime Principle: **3D 모델링/재구성은 iOS 앱에서 수행, 서버는 업로드/검증/저장/게시/조회만 담당 (No GPU in backend)**

## 1) Scope
### In Scope
1. DB schema/migration/invariant recovery (model asset 중심)
2. Backend contract/security/idempotency recovery (upload/publish 중심)
3. iOS route-level parity implementation against web canonical routes
4. Docs, checklists, and evidence trails for cutover decisions
5. AI delegation governance for execution/commit/PR/reporting

### Out of Scope
1. Payment/settlement/shipping domain
2. Backoffice production UI
3. Server-side GPU reconstruction pipeline
4. New native OAuth architecture for iOS (dev-minimal auth only)

## 2) Ground Rules
1. Each gate must pass before entering the next gate.
2. Every decision line must include code/document evidence path.
3. `openapi.yaml` is the REST contract source of truth.
4. Evidence files are mandatory for Go/No-Go.
5. Existing production invariants must not be weakened.
6. AI 작업은 `ops/03~06` 운영 문서 계약을 따른다.

## 3) Freeze Definition (Gate 0)
### Web Components Freeze Set
- `apps/web/components/ui/button.tsx`
- `apps/web/components/ui/card.tsx`
- `apps/web/components/layout/screen.tsx`
- `apps/web/components/layout/global-tab-bar.tsx`
- `apps/web/components/layout/bottom-nav.tsx`
- `apps/web/app/globals.css`
- `apps/web/tailwind.config.ts`

### Freeze Objective
- Keep web baseline stable while iOS parity work is in progress.

## 4) Gate Model
| Gate | Entry | Required Work | Exit |
|---|---|---|---|
| Gate 0 | Baseline branch/doc lock | Freeze set + specs/checklists scaffold + AI ops docs | docs and templates complete |
| Gate A (DB) | Gate 0 pass | schema integrity + upload/publish invariants + idempotency key constraints | DB checklist PASS + SQL/test evidence |
| Gate B (Backend) | Gate A pass | additive contract + upload state rules + storage verification + OpenAPI sync | Backend checklist PASS + API evidence |
| Gate C (iOS) | Gate B pass | full web canonical-route parity on iOS | iOS checklist PASS + demo/test evidence |

## 5) Mandatory Deliverables
1. DB: `db/03_execution_spec.md`, `db/04_gate_a_checklist.md`
2. Backend: `backend/04_execution_spec.md`, `backend/05_gate_b_checklist.md`
3. iOS: `ios/03_execution_spec.md`, `ios/04_web_ios_route_parity_matrix.md`, `ios/05_gate_c_checklist.md`
4. Ops: `ops/01_env_profiles_commands.md`, `ops/02_refactor_cutover_checklist.md`
5. AI Ops: `ops/03_ai_delivery_workflow.md`, `ops/04_git_commit_pr_workflow.md`, `ops/05_documentation_governance.md`, `ops/06_ai_task_contract.md`
6. Templates: `templates/*`
7. Evidence: date-stamped files under `evidence/db`, `evidence/backend`, `evidence/ios`

## 6) Public Interface Synchronization
Always sync together when contract changes:
1. `docs/api/openapi.yaml`
2. `apps/web/lib/api.generated.ts`
3. `apps/ios/Modules/Networking/ContractEnums.swift`
4. `apps/ios/Modules/Networking/APIClient.swift`

## 7) Testing Matrix (Minimum)
### DB
1. model asset metadata integrity and status transitions
2. upload idempotency key uniqueness
3. migration order and head integrity

### Backend
1. upload init -> object upload -> upload complete -> publish -> ar-asset
2. asset status mapping consistency
3. duplicate complete/publish no-op safety
4. availability calculation consistency

### iOS
1. local modeling/export success path
2. upload/complete/publish flow
3. buyer AR placement from published asset
4. WS disconnect fallback to HTTP (chat)
5. loading/error/empty states parity per route

## 8) Done Criteria
### Program Done
1. Gate A/B/C all PASS
2. No unresolved blocker in cutover checklist
3. Evidence exists for all mandatory scenarios
4. Go/No-Go decision can be made from docs only
5. AI가 `implement` 폴더 문서만으로 동일 프로세스를 재현 가능
