# iOS-01. Seller Capture + Local Modeling + Upload Runtime

## Summary
Seller 플로우는 sweep capture -> iOS local modeling -> model export -> presigned upload -> complete -> publish 순서로 구성된다.

## 1) Required Modules
1. `CaptureKit/SweepCaptureEngine.swift`
2. `CaptureKit/FrameSelector.swift`
3. `ModelingKit/LocalModelBuilder.swift` (iOS 로컬 모델링)
4. `ModelingKit/ModelExportCoordinator.swift` (USDZ/GLB export)
5. `FeatureListing/SellerListingFlowViewModel.swift`
6. `Networking/APIClient.swift`

## 2) Runtime Rules
1. capture duration: 10~20s
2. quality + yaw diversification selection
3. 로컬 모델링 성공 후에만 upload init 호출
4. upload complete 성공 후에만 publish 가능
5. 실패 시 재시도는 file-level로 수행

## 3) Publish Gate
1. `asset.status=READY` 이전 publish 비활성
2. READY 시 게시 CTA 활성

## 4) Failure UX
1. local modeling 실패 재시도
2. upload 실패 대상 재전송
3. complete 실패 시 checksum/파일 누락 안내

## 5) Evidence Expectations
- seller flow run log: `evidence/ios/YYYY-MM-DD_seller_flow.md`
- local model/export sample: `evidence/ios/YYYY-MM-DD_local_model_export.md`
