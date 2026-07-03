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

## 진행 상황

**완료**
- 레퍼런스 Simulink 모델(`ev_pmsm_drive`, Simscape Electrical "Model a Three-Phase PMSM Drive"
  예제) 확보 → `models/`에 저장, GitHub(`eagle-146/Digital_Twin`)와 MATLAB Online·로컬 양쪽 동기화
- `params.m`(차량·모터·인버터·배터리 스펙) / `operating_points.m`(정속 운전점 대수계산) / 3상 전류
  로깅(`enable_signal_logging.m`) / `cfg_ev_pmsm_drive.m`(모델별 파라미터·속도지령 주입) /
  `run_ac_loss_sweep.m`(운전점 스윕 하네스) 구축
- `ac_copper_loss.m` FFT 파이프라인 검증·버그 수정: 윈도우 미적용으로 인한 스펙트럼 누설,
  윈도우 보정 후 인접빈 이중계산, 가변스텝 솔버의 불균일 샘플링 대응 등 — 합성신호 이론값과
  일치하는 것까지 확인 (`scripts/test_*.m`, `run_all_tests.m`)
- 모델 인스펙터(`inspect_model.m`/`inspect_model2.m`) 버그 수정 — `get_param`이 `DataLogging`류
  파라미터를 조용히 못 읽는 버전 제약을 발견, generic `get()`/`set()`으로 우회
- 컨트롤러/플랜트 정격 불일치 발견·수정 — 플랜트(PMSM 블록)는 실제 모터(160kW)로 바꿨는데
  컨트롤러(Current Reference Generator)의 `Tmax`/`Pmax`/`Imax`/`Vnom`/극쌍수(`p`)는 여전히
  레퍼런스 예제의 작은 모터(rpm_nom≈1000, Tmax=27N·m) 값이라 무슨 속도를 지시하든 동일한
  포화 전류만 나오던 문제 — `cfg_ev_pmsm_drive.m`에 해당 변수 주입 추가로 해결

**진행 중**
- 그래도 여전히 100/120/140km/h 세 운전점의 AC동손이 동일하게 나오는 현상 — 원인으로
  `PMSM Current Reference Generator`의 `RefType`이 **"Zero d-axis control"(약자속 없음)** 로
  설정되어 있어서, 기저속도(5000rpm)를 훨씬 넘는 목표(8000~12000rpm대)에서 역기전력이
  DC링크 전압(800V) 한계에 걸려 전압포화 상태로 계속 가속만 시도하는 것으로 추정 중.
  `RefType`을 자동생성 lookup-table 기반 모드로 전환해 약자속을 활성화하는 작업 진행 중.

**미확인/다음 단계**
- FOC 속도/전류 루프 PI 게인(`Kp_w`/`Ki_w`/`Kp_id`/`Kp_iq` 등)이 여전히 레퍼런스 예제(작은 모터)
  튜닝값 그대로 — 정격 불일치는 해소했지만 응답속도·오버슈트가 실제 모터 동특성에 안 맞을 수 있어
  다음으로 점검 필요
- `Rac(f,T)` 는 아직 `rac_placeholder.m` 근사식 — 실제 FEA(Motor-CAD/Maxwell) 맵으로 교체 예정
- 열-전기 연성 루프(LPTN, 구리온도 ↔ Rac 재계산)는 미구현 (README 목표에 명시된 항목, 현재는
  `T_cu`가 고정 입력값)

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
