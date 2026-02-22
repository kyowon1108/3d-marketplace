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
| Home parity complete | PASS | `evidence/ios/2026-02-22_screen_parity.md` | `templates/evidence_report_template.md` | Grid layout, search link |
| Product list parity complete | PASS | `evidence/ios/2026-02-22_screen_parity.md` | `templates/evidence_report_template.md` | ProductListView grid |
| Product detail parity complete | PASS | `evidence/ios/2026-02-22_screen_parity.md` | `templates/evidence_report_template.md` | ARPlacementView (iOS 17+) + ARQuickLook fallback, dims_trust, wallSnap |
| Search parity complete | PASS | `evidence/ios/2026-02-22_screen_parity.md` | `templates/evidence_report_template.md` | SearchView with recent searches |
| Sell new parity complete | PASS | `evidence/ios/2026-02-22_screen_parity.md` | `templates/evidence_report_template.md` | LocalModelBuilder via ModelingKit |
| Upload status parity complete | PASS | `evidence/ios/2026-02-22_screen_parity.md` | `templates/evidence_report_template.md` | UploadStatusView with 3s polling |
| Inbox parity complete | PASS | `evidence/ios/2026-02-22_screen_parity.md` | `templates/evidence_report_template.md` | Unread dots added |
| Chat room parity complete | PASS | `evidence/ios/2026-02-22_screen_parity.md` | `templates/evidence_report_template.md` | WS real-time + REST fallback |
| Profile parity complete | PASS | `evidence/ios/2026-02-22_screen_parity.md` | `templates/evidence_report_template.md` | .refreshable, logout confirm |
| Login/Signup parity complete | PASS | `evidence/ios/2026-02-22_screen_parity.md` | `templates/evidence_report_template.md` | Google Sign-In button added |
| Seller local modeling scenario pass | PASS | `evidence/ios/2026-02-22_screen_parity.md` | `templates/evidence_report_template.md` | CaptureKit + ModelingKit extracted |
| Buyer AR placement scenario pass | PASS | `evidence/ios/2026-02-22_screen_parity.md` | `templates/evidence_report_template.md` | ARPlacementKit with plane detection |
| Chat reconnect fallback pass | PASS | `evidence/ios/2026-02-22_ios_auth_ws.md` | `templates/evidence_report_template.md` | Exponential backoff + REST fallback |

## Gate Decision
- Current Decision: `GO`
- Decision File: `evidence/ios/2026-02-22_screen_parity.md`
- Template: `templates/gate_decision_template.md`
- Reason: All 13 items PASS with evidence
