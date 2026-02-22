# iOS-02. Buyer AR Placement Runtime

## Summary
Buyer 플로우는 게시된 `ar-asset`을 조회해 footprint-first 배치 후 모델을 AR에 배치한다.

## 1) Required Modules
1. `ARPlacementKit/ARPlacementViewModel.swift`
2. `ARPlacementKit/ARPlacementCoordinator.swift`
3. `ARPlacementKit/ARPlacementARView.swift`
4. `FeatureAR/BuyerARPlacementView.swift`

## 2) Runtime Rules
1. availability terminal(`READY|NONE`)에서 polling 중지
2. 모델 URL 우선순위: `usdz` -> `glb` fallback
3. footprint-first 후 model placement
4. wall snap 토글 제공

## 3) UX Rules
1. `dims.source=ios_lidar` -> 높은 신뢰 카피
2. 기타 source -> 오차 가능 카피
3. uncertainty badges 서버값 그대로 노출

## 4) Evidence Expectations
- ar placement log: `evidence/ios/YYYY-MM-DD_buyer_ar.md`
- placement validation: `evidence/ios/YYYY-MM-DD_placement_validation.md`
