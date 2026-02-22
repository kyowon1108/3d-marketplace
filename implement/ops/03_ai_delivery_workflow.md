# OPS-03. AI Delivery Workflow

## 1) Scope of AI Responsibility
AI는 아래 범위를 end-to-end로 수행한다.
1. 작업 입력 해석 및 범위 확인
2. 설계/코드/문서 변경 수행
3. 검증 명령 실행 및 결과 기록
4. 체크리스트/증빙 문서 갱신
5. 커밋/PR 초안 작성
6. Gate 판정 자료 준비

AI가 수행하지 않는 범위:
1. 승인 없는 범위 확장
2. 증빙 없이 Gate 완료 선언
3. 보안/계약 breaking 변경 강행

## 2) Standard Work Loop
표준 루프: `Intake -> Plan -> Execute -> Validate -> Document -> Commit -> Report`

### Intake
1. 목표, 범위, 제약, 완료조건 수집
2. 대상 Gate(`0/A/B/C`) 식별
3. 선행 조건 확인 (기존 체크리스트 상태)

### Plan
1. 변경 파일 목록 확정
2. 검증 명령 목록 확정
3. 증빙 파일 생성 계획 확정

### Execute
1. 코드/문서 수정
2. 스코프 외 변경 방지
3. 변경 파일을 논리 단위로 유지

### Validate
1. 테스트/정적검사/스모크 실행
2. 실패 시 원인과 재시도 내역 기록

### Document
1. 체크리스트 상태 반영 (`PENDING -> PASS/FAIL`)
2. 증빙 문서 작성 (`evidence/*`)
3. 영향 문서 동기화

### Commit
1. 커밋 단위 분리 (한 커밋, 한 목적)
2. 메시지 규칙 적용 (`ops/04_git_commit_pr_workflow.md`)

### Report
1. 변경 요약
2. 검증 결과
3. 남은 리스크/후속 작업

## 3) Gate-aware Execution Rules
### Gate 0
1. 운영 규칙/템플릿/체크리스트 뼈대 완성
2. 브랜치/문서 경로 고정

### Gate A (DB)
1. migration/invariant/concurrency 항목 우선
2. SQL 검증 증빙 필수

### Gate B (Backend)
1. OpenAPI/상태머신/idempotency/security 우선
2. 타입 동기화 증빙 필수

### Gate C (iOS)
1. route parity + 상태 패리티 우선
2. 수동 시나리오 증빙 필수

Gate 전환 규칙:
1. 해당 Gate 체크리스트가 PASS여야 함
2. 증빙 경로 누락 시 전환 불가

## 4) Blocker Handling Rules
1. blocker 분류: `환경`, `의존성`, `스펙충돌`, `데이터문제`
2. 1차 대응: 재현 조건/로그/영향 범위 수집
3. 2차 대응: 우회 경로 또는 최소 변경안 제시
4. 보고 형식: `영향`, `현재 상태`, `요청 결정`, `임시 조치`

## 5) Completion Checklist per Task
작업 완료 시 아래 6개 항목을 모두 채운다.
1. 수정 파일 목록
2. 검증 명령 목록
3. 검증 결과 요약
4. 증빙 파일 경로
5. 커밋/PR 링크 또는 초안
6. 남은 리스크와 후속 액션
