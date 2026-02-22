# Refactoring Documentation Pack (From Scratch)

이 디렉터리는 **아무 것도 없는 상태에서 3D Marketplace를 다시 구축**할 때 사용하는 단일 기준 문서 세트다.

## 핵심 아키텍처 전제
1. 3D 모델링/재구성은 iOS 앱에서 수행한다.
2. Backend는 업로드/검증/저장/게시/조회만 수행한다.
3. Backend GPU 재구성 파이프라인은 범위에서 제외한다.

## 목적
- DB -> Backend -> iOS 순서의 게이트 기반 복구/구축
- Web 기준 구조/카피/상태 패리티를 iOS에 이식
- 문서/코드/운영 증빙 경로를 고정
- AI 위임 작업의 운영 규칙(작업/커밋/PR/증빙)을 표준화

## 읽기 순서
1. `MASTER_REFACTOR_PLAN.md`
2. `00_system_snapshot.md`
3. `ops/03_ai_delivery_workflow.md`
4. `ops/04_git_commit_pr_workflow.md`
5. `ops/05_documentation_governance.md`
6. `ops/06_ai_task_contract.md`
7. `db/03_execution_spec.md`
8. `backend/04_execution_spec.md`
9. `ios/03_execution_spec.md`
10. `ops/01_env_profiles_commands.md`
11. `ops/02_refactor_cutover_checklist.md`
12. `templates/README.md`

## 규칙
1. 마스터 문서에는 결정/범위/게이트만 기록한다.
2. 실행 상세는 각 파트 `execution_spec`에 기록한다.
3. 체크리스트는 항상 `PASS/FAIL + evidence path`를 포함한다.
4. 증빙은 `evidence/` 하위에 날짜 단위로 누적한다.
5. AI 작업 요청/보고는 `ops/06_ai_task_contract.md` 계약을 따른다.
