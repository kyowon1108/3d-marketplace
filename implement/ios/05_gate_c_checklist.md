# iOS-05. Gate C Checklist

- Gate: C (iOS)
- Status: `PASS`

## PASS/FAIL Rules
- PASS: mandatory 항목 전부 PASS + 증빙 경로 존재
- FAIL: 항목 FAIL 또는 증빙 누락

## Required Templates
1. `templates/evidence_report_template.md`
2. `templates/gate_decision_template.md`

## Checklist
| Item | Status | Evidence Path | Template | Notes |
|---|---|---|---|---|
| Home parity complete | PASS | `evidence/ios/2026-02-23_ios_ux_alignment.md` | `templates/evidence_report_template.md` | 홈 내 검색 진입 추가 |
| Product list parity complete | PASS | `evidence/ios/2026-02-23_ios_ux_alignment.md` | `templates/evidence_report_template.md` | 카테고리(최신/인기/무료) 실동작 연결 |
| Product detail parity complete | PASS | `evidence/ios/2026-02-23_ios_ux_alignment.md` | `templates/evidence_report_template.md` | AR+채팅+구매 CTA, 구매 후 SOLD_OUT 반영 |
| Search parity complete | PASS | `evidence/ios/2026-02-23_ios_ux_alignment.md` | `templates/evidence_report_template.md` | 홈 툴바 진입 경로 보장 |
| Sell new parity complete | PASS | `evidence/ios/2026-02-23_ios_ux_alignment.md` | `templates/evidence_report_template.md` | 에셋 필수 카피 반영 |
| Upload status parity complete | PASS | `evidence/ios/2026-02-23_ios_ux_alignment.md` | `templates/evidence_report_template.md` | 업로드 완료 카드에서 상태 화면 진입 |
| Inbox parity complete | PASS | `evidence/ios/2026-02-23_ios_ux_alignment.md` | `templates/evidence_report_template.md` | 빈상태 CTA를 홈 이동 동작으로 연결 |
| Chat room parity complete | PASS | `evidence/ios/2026-02-22_screen_parity.md` | `templates/evidence_report_template.md` | WS real-time + REST fallback |
| Profile parity complete | PASS | `evidence/ios/2026-02-23_ios_ux_alignment.md` | `templates/evidence_report_template.md` | 빈상태 CTA를 홈 이동 동작으로 연결 |
| Login/Signup parity complete | PASS | `evidence/ios/2026-02-23_ios_ux_alignment.md` | `templates/evidence_report_template.md` | Google 버튼에 준비중 상태 명시 |
| Seller local modeling scenario pass | PASS | `evidence/ios/2026-02-22_screen_parity.md` | `templates/evidence_report_template.md` | CaptureKit + ModelingKit extracted |
| Buyer AR placement scenario pass | PASS | `evidence/ios/2026-02-22_screen_parity.md` | `templates/evidence_report_template.md` | ARPlacementKit with plane detection |
| Chat reconnect fallback pass | PASS | `evidence/ios/2026-02-22_ios_auth_ws.md` | `templates/evidence_report_template.md` | Exponential backoff + REST fallback |

## Gate Decision
- Current Decision: `GO`
- Decision File: `evidence/ios/2026-02-23_ios_ux_alignment.md`
- Template: `templates/gate_decision_template.md`
- Reason: All 13 items PASS with evidence
