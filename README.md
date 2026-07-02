# Digital Twin — EV 모터 AC 동손 주행 시뮬레이션

승용 EV(800V) 파워트레인을 MATLAB/Simulink 디지털 트윈으로 모델링하여, 고속 정속 운전 중
모터의 **AC 동손(AC copper loss)** 을 측정하는 프로젝트.

## 목표
이미 설계된 모터 스펙과 FEA 손실맵을 가져와, 디지털 트윈 환경에서 주행 시뮬레이션을 수행한다.
(모터 FEA 설계 자체는 현 단계 범위 외 — 후순위)

## 기준 모터 스펙 (baseline)
| 항목 | 값 |
|------|-----|
| 타입 | IPMSM (V형 매입자석) |
| 극수 / 슬롯 | 8극(극쌍 4) / 48슬롯 |
| 권선 | 헤어핀(각형 도체) |
| 최대 / 연속 출력 | 160 kW / 70 kW |
| 최대 토크 | 350 N·m |
| 최고 회전수 | 16,000 rpm |
| DC 링크 | 800 V |
| 냉각 | 오일 분사 |

## 시뮬레이션 구성
- **범위**: 차량 종방향동역학 → FOC(MTPA/약자속) → 스위칭 PWM 인버터(16–20 kHz, SVPWM) → 800V 배터리
- **온도**: LPTN 열망 연성 (구리온도 → Rac 재계산 루프)
- **AC 동손 산출**: 상전류 FFT → `P_ACcu = Σ Rac(fₕ, T)·Iₕ²`
  - `Rac(f, T)` 맵은 ANSYS(Motor-CAD/Maxwell)에서 추출 → `data/maps/`
- **운전점**: 고속 정속 100 / 120 / 140 km/h (기본 전기주파수 ≈ 560 / 675 / 790 Hz)
- **1차 KPI**: AC 동손[W], Rac/Rdc, AC/DC 손실 비중, 손실맵, 구리 온도

## 폴더 구조
```
models/       Simulink 모델 (.slx)
scripts/      MATLAB 스크립트 (.m) — 파라미터, 후처리, FFT/AC손 계산
data/maps/    Rac(f,T) 등 FEA 손실맵 (작은 CSV/MAT)
results/      시뮬 결과 (git 제외 — 재생성 가능)
docs/         문서·노트
```

## 검증 / 테스트
- `scripts/test_*.m` — 알려진(이론값 계산 가능한) 합성 신호로 핵심 로직(FFT/AC동손, 신호탐색,
  운전점 계산, 모델 인스펙터)을 검증하는 회귀테스트. `scripts/run_all_tests.m` 하나로 전부 실행.
- 이 테스트들은 **Simscape 등 추가 툴박스나 .slx 모델 없이, 기본 MATLAB + Simulink만으로 동작**한다
  (Simulink는 `Simulink.SimulationData.Dataset`/기본 소스 블록 검증용으로만 씀).
  실제 `.slx` 하네스(`run_ac_loss_sweep.m`, `cfg_*.m`)를 건드릴 때도, 먼저 `run_all_tests`와
  `demo_ac_loss`로 코어 로직이 멀쩡한지 빠르게 확인하고 넘어가면 디버깅 범위를 좁힐 수 있다.

## 이식성 (다른 PC에서 구동)
- **MATLAB Project(.prj)** 로 경로/의존성 관리 → 폴더째 옮겨도 실행 (권장)
- `.slx`는 만든 MATLAB 버전 **이상**에서만 열림
- `.slx` 하네스 실행에 필요한 툴박스: Simscape, Simscape Electrical, Powertrain Blockset,
  Motor Control Blockset (단, 위 테스트 스위트는 이 툴박스들 없이도 동작함)
- 대용량 FEA 산출물은 git 제외(.gitignore) 또는 Git LFS 사용
