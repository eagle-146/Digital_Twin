# archive/ ─ 보관 파일 (삭제 아님)

수정된 프로젝트 방향(2026-07-06)에서 당장 쓰지 않는 파일들을 모아둔 곳.
**삭제가 아니라 보관**이며, 아래 "PWM 고조파 AC손" 단계로 갈 때 다시 꺼내 쓴다.

## 왜 옆으로 뺐나

개인 디지털 트윈의 확정 목표는 ① 운전점별 AC손 ② 주행사이클 전비 영향 ③ 설계변주 전후 비교이고,
**PWM 고조파는 후순위**로 결정됨. PWM 고조파를 안 보면 스위칭 인버터·FOC·약자속 상세 모델이
필요 없어지고, 운전점 전류는 dq 해석식으로, 주행사이클은 평균값 EV 모델로 처리한다.
→ 아래 "스위칭 FOC 모델 전용" 자산은 그 PWM 단계 전까지 불필요.

## 보관 목록

### archive/models/ — Simscape Electrical "PMSM Drive" 예제 일체
- `ev_pmsm_drive.slx` : 스펙 반영·컨트롤러 정격 맞춘 스위칭 FOC 드라이브 모델
- `PMSMDrive.slx`, `PMSMDriveExample.m`, `PMSMDrivePlotMotorSpeed.m`, `PMSMDriveSetWindingType.m` : 원본 예제 부속

### archive/scripts/ — 위 모델 전용 도구
- `cfg_ev_pmsm_drive.m` : 모델 파라미터·속도지령·컨트롤러 정격 주입 설정
- `run_ac_loss_sweep.m` : 스위칭 모델을 운전점마다 돌려 AC손 산출하는 하네스
- `enable_signal_logging.m` : 3상 전류선 신호로깅 활성화(DataLogging 버전버그 우회)
- `get_phase_current.m` : 시뮬 결과에서 3상 전류 추출
- `inspect_model.m`, `inspect_model2.m` : 모델 구조 자동분석
- `test_get_phase_current.m`, `test_inspect_model.m` : 위 도구 회귀테스트

## 되살릴 때 (PWM 고조파 단계)
`git mv archive/scripts/<파일> scripts/` 로 되돌리고, `run_all_tests.m`의 tests 목록에
해당 테스트를 다시 추가하면 된다.
