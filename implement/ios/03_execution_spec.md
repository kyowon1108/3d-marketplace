# iOS-03. Execution Spec

## Entry Criteria
1. Gate B PASS
2. OpenAPI and generated clients synced
3. upload/publish/chat/auth APIs callable

## Work Breakdown
### A. Route-Level Screen Build
web canonical route를 iOS 화면으로 1:1 대응한다.

### B. Parity Rules
1. 구조 parity: 정보 배치/섹션 구성
2. copy parity: 핵심 문구/오류 문구
3. state parity: loading/empty/error/offline/processing

### C. Policy Constraints
1. modeling: iOS local only
2. auth: dev-minimal flow
3. chat: WS 우선 + HTTP fallback
4. AR CTA default: in-app AR

### D. Test/Validation
1. unit tests for local modeling/upload mapping
2. manual E2E scenarios
3. gate checklist update

## Deliverables
1. iOS route parity implementation
2. parity matrix and checklist update
3. evidence files under `evidence/ios`

## Exit Criteria
1. `ios/05_gate_c_checklist.md` all PASS
2. manual scenario evidence complete
