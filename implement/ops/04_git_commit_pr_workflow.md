# OPS-04. Git Commit & PR Workflow

## 1) Branch Naming
패턴:
1. `codex/gate0-<topic>`
2. `codex/gatea-<topic>`
3. `codex/gateb-<topic>`
4. `codex/gatec-<topic>`

예시:
- `codex/gatea-model-asset-schema`
- `codex/gateb-upload-contract-sync`
- `codex/gatec-ios-route-parity`

## 2) Commit Granularity
1. 한 커밋은 한 목적만 포함
2. 코드와 문서가 함께 바뀌면 동일 목적일 때만 한 커밋
3. 체크리스트/증빙 갱신 없는 코드 커밋 금지

## 3) Commit Message Convention
Conventional Commits 사용:
- `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`

권장 형식:
`<type>(<area>): <intent>`

예시:
1. `docs(ops): add AI delivery workflow and templates`
2. `refactor(db): enforce model asset integrity constraints`
3. `fix(backend): align upload complete idempotency`

## 4) PR Scope & Checklist
### PR 분리 원칙
1. Gate 단위 PR 분리 (`Gate A`, `Gate B`, `Gate C`)
2. 혼합 PR 금지 (예: DB+IOS 대규모 혼합)

### PR 본문 필수 항목
1. 변경 요약
2. 영향 범위
3. 검증 명령/결과
4. 문서 동기화 목록
5. 체크리스트/증빙 링크

템플릿 사용:
- `templates/pr_description_template.md`

## 5) Merge and Tagging Rules
1. 필수 검증 통과 전 merge 금지
2. Gate 완료 시 gate decision 문서 업데이트
3. 필요 시 gate 완료 태그 사용:
   - `gate-a-pass-YYYYMMDD`
   - `gate-b-pass-YYYYMMDD`
   - `gate-c-pass-YYYYMMDD`

## 6) Hard Rules
1. 브랜치 없이 직접 main 작업 금지
2. 증빙 없는 완료 선언 금지
3. 체크리스트 상태와 PR 본문 불일치 금지
