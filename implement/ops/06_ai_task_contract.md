# OPS-06. AI Task Contract

## 1) AI 입력 계약 (Required Input)
작업 요청에는 아래 항목이 포함되어야 한다.
1. 목표 (Goal)
2. 범위 (In Scope)
3. 제외 범위 (Out of Scope)
4. 제약 조건 (Constraints)
5. 완료 조건 (Done Criteria)
6. 대상 Gate (`0/A/B/C`)

권장 형식은 `templates/task_brief_template.md`를 사용한다.

## 2) AI 출력 계약 (Required Output)
AI 결과 보고에는 아래 항목이 포함되어야 한다.
1. 변경 요약
2. 수정 파일 목록
3. 검증 명령/결과
4. 증빙 파일 경로
5. 리스크/한계
6. 후속 작업

## 3) 금지사항
1. 무단 스코프 확장
2. 체크리스트 미갱신 상태에서 완료 선언
3. evidence 누락 커밋
4. breaking API 변경 강행
5. Gate 순서 무시

## 4) 실패/보류 보고 포맷
아래 4줄 포맷으로 고정한다.
1. `상태`: 실패/보류
2. `원인`: 기술적 원인 1~2개
3. `영향`: 일정/범위/리스크
4. `요청 결정`: 선택지 2~3개

## 5) Acceptance Rule
작업은 다음 조건을 모두 만족할 때만 `완료`로 간주한다.
1. 출력 계약 6개 항목 충족
2. 체크리스트 상태 반영 완료
3. evidence 링크 유효
