# 프론트엔드 BLE 마이그레이션 변경 사항

핫스팟 페어링 방식을 **BLE 페어링 방식**으로 전환했습니다.

---

## 한눈에 보는 변경 사항

### 변경되는 파일 (8개)

| 파일 | 변경 내용 |
|---|---|
| `pubspec.yaml` | `flutter_blue_plus` 추가, `network_info_plus`/`connectivity_plus` 제거 |
| `android/app/src/main/AndroidManifest.xml` | BLE 권한 추가, Wi-Fi 권한 정리 |
| `android/app/src/profile/AndroidManifest.xml` | 동일 |
| `lib/screens/add_camera_screen.dart` | **완전 재작성** (BLE 마법사) |
| `lib/screens/settings_screen.dart` | 안내 문구만 한 줄 변경 |

### 새로 추가되는 파일 (2개)

| 파일 | 역할 |
|---|---|
| `lib/services/bridge_ble_service.dart` | BLE 통신 핵심 (스캔/연결/프로비저닝) |
| `lib/services/ble_permission_helper.dart` | 플랫폼별 BLE 권한 처리 |

### iOS만 해당 (1개)

| 파일 | 변경 내용 |
|---|---|
| `ios/Runner/Info.plist` | `NSBluetoothAlwaysUsageDescription` 추가 (안 하면 강제 종료) |

### 변경 없는 파일 — **이게 핵심!**

- ✅ `camera_provider.dart` — `pairCamera()` 그대로 사용 (BLE로 받은 코드 → 서버 호출)
- ✅ `auth_provider.dart` — 그대로
- ✅ `main_screen.dart`, `zone_screen.dart`, `history_screen.dart` — 그대로
- ✅ `api_client.dart` — 그대로
- ✅ 백엔드 — **백엔드는 단 한 줄도 안 바뀜**

핫스팟 방식과 백엔드 컨트랙트가 동일합니다. `/bridges/register` → 코드 → `/bridges/pair` 흐름 그대로. 브릿지가 "사람 눈" 대신 "BLE"로 코드를 전달한다는 차이만 있어요.

---

## 새 카메라 추가 흐름 (사용자 관점)

```
[설정] → "카메라 추가하기"
   ↓
[카메라 추가] 화면 진입
   ↓
1. "카메라를 페어링 모드로 켜주세요"
   → 카메라가 처음 켜지면 자동으로 BLE 광고 시작
   → [카메라 찾기] 버튼 탭
   ↓
2. 블루투스 권한 요청 (한 번만)
   ↓
3. "주변 카메라를 찾는 중..."
   → 발견된 EyeCatch-XXXX 자동 감지
   ↓
4. 발견된 카메라 목록
   → 신호 강도 순으로 정렬, 거리 힌트 표시
   → 사용자가 선택
   ↓
5. Wi-Fi 정보 입력
   → SSID + 비밀번호 + 카메라 이름
   ↓
6. "Wi-Fi 정보를 전달하는 중..."
   → BLE로 브릿지에 전송
   ↓
7. "카메라가 Wi-Fi에 연결하는 중..."
   → 브릿지가 status notify로 진행 알림
   ↓
8. "서버에서 페어링 코드를 받는 중..."
   → 브릿지가 서버에 register → 코드를 BLE로 앱에 전달
   ↓
9. "서버에 카메라를 등록하는 중..."
   → 앱이 코드로 POST /bridges/pair 호출
   ↓
10. "카메라가 등록되었어요!" ✅
    → 메인 화면 자동 이동
    → 환영 SnackBar 표시 (기존 로직 그대로 작동)
```

---

## 사용자가 직접 해야 할 작업

### 1. Flutter 패키지 설치

```bash
flutter pub get
```

### 2. iOS 빌드 시 (선택)

`ios/Runner/Info.plist`에 아래 키 추가 (`Info.plist.ble-additions.xml` 파일 참고):

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>새 카메라와 페어링하려면 블루투스가 필요해요</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>새 카메라와 페어링하려면 블루투스가 필요해요</string>
```

### 3. 브릿지 담당자에게 컨트랙트 전달

`BLE_CONTRACT.md` 파일을 브릿지 담당자에게 공유하고 BLE Service/Characteristic UUID를 맞추세요.

만약 브릿지 측 UUID가 다르면, `lib/services/bridge_ble_service.dart`의 `BleContract` 클래스 상수만 수정하면 됩니다.

---

## 시연 직전 체크리스트

- [ ] `flutter pub get` 완료
- [ ] 브릿지 담당자랑 UUID 확정 → `BleContract` 상수 일치
- [ ] 안드로이드 12+ 기기에서 권한 팝업 정상 표시
- [ ] 브릿지가 `EyeCatch-XXXX` 이름으로 광고 중인지 확인
- [ ] Wi-Fi 비밀번호 한글/특수문자 포함 케이스 테스트
- [ ] 페어링 완료 후 BLE 광고 꺼지는지 (다음 부팅엔 광고 X)
- [ ] 라즈베리파이가 sudo 권한으로 nmcli 실행 가능한지

---

## 트러블슈팅

### "주변에서 카메라를 찾지 못했어요"

- 카메라 전원 확인
- 카메라가 한 번이라도 페어링된 적 있다면 `bridge_state.json` 삭제 후 재부팅
- BLE 광고 이름이 `EyeCatch-`로 시작하는지 (`hcitool lescan` 또는 nRF Connect 앱으로 확인)

### "카메라에서 EyeCatch 서비스를 찾지 못했어요"

- 브릿지의 Service UUID와 앱의 `BleContract.serviceUuid`가 정확히 일치하는지
- 브릿지가 광고에 Service UUID를 포함했는지 (포함 안 해도 연결은 되지만 권장)

### "카메라가 Wi-Fi에 연결하지 못했어요"

- 비밀번호 오타
- 2.4GHz/5GHz 혼합 SSID 문제 (라즈베리파이 일부 모델은 5GHz 미지원)
- nmcli 권한 (sudo 설정 확인)

### "카메라 응답이 너무 늦어요" (60초 타임아웃)

- 라즈베리파이 Wi-Fi 모듈 신호 약함
- 서버 응답 지연 (서버 down 확인)
- nmcli 자체가 30초 이상 걸리는 경우 → 타임아웃을 늘리려면 `bridge_ble_service.dart`의 `totalTimeout` 조정

---

## 핫스팟 방식으로 롤백하고 싶다면

git에서 이전 커밋으로 돌아가면 됩니다. 백엔드 변경이 없어서 롤백 비용 적어요.