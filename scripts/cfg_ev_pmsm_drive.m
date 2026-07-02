%% cfg_ev_pmsm_drive.m ─ 'ev_pmsm_drive'(Simscape Electrical PMSM 예제) 전용 실행설정
%  inspect_model('ev_pmsm_drive') / inspect_model2('ev_pmsm_drive') 결과를 바탕으로
%  run_ac_loss_sweep 의 cfg를 이 모델에 맞게 구성한다.
%
%  모델 쪽 확인된 대응관계:
%    속도지령 : 최상위 'Step' 블록 (Time/Before/After) — 워크스페이스 변수 아님, 블록파라미터로 직접 덮어씀
%              (Step→RT2→"PMSM controller"의 rpm 포트로 연결됨을 get_param으로 확인)
%    모터 파라미터 : 워크스페이스 변수 Rs/Ld/Lq/N/PM 이 PMSM 블록 마스크에 그대로 바인딩됨
%    DC 링크 전압 : Battery 블록의 Vnom (기본 48V, 리터럴 값 — setBlockParameter로 덮어씀)
%    상전류 신호 : 'Sensing currents' 서브시스템(캔버스에는 커스텀 아이콘 "i"로 표시됨) 출력
%
%  ⚠ 사용 전 필수(모델에서 1회): 위 전류 신호선에 신호 로깅을 켜고 신호명을
%    'i_abc'로 지정한 뒤 모델을 저장할 것. 로깅 안 하면 get_phase_current가
%    상전류를 찾지 못해 에러가 난다. GUI로 할 수도 있지만(신호선 우클릭 >
%    신호 기록 > 속성에서 이름 지정), enable_signal_logging.m으로 스크립트화 가능:
%      lineH = enable_signal_logging('ev_pmsm_drive/Sensing currents', 1, 'i_abc');
%      save_system('ev_pmsm_drive')
%    (set_param(line,'DataLogging',...)은 이 파라미터 계열에서 조용히 실패하는
%     버전 제약이 있어 enable_signal_logging.m은 내부적으로 generic set()을 씀.)
%
%  ⚠ 알려진 미해결 이슈 — 컨트롤러 포화(saturation):
%    이 예제의 FOC 게인·토크/전류 제한은 원래 작은 모터(rpm_nom≈1000, Tmax=27Nm,
%    Pmax≈2.8kW)에 맞춰 튜닝되어 있다. 우리 실제 모터(160kW/16000rpm) 스케일의
%    속도지령(수천~1만rpm대)을 넣으면, 5000rpm과 15000rpm처럼 크게 다른 값을
%    줘도 최대 상전류가 동일하게 나오는 현상이 실측 확인됨(내부 토크/전류
%    리미터가 작은 모터 기준값에 막혀 포화되는 것으로 추정). 즉 지금 상태로
%    돌린 스윕 결과(P_ac_W 등)는 정량적으로 신뢰하면 안 되고, 컨트롤러 내부의
%    토크 리미터·전류 리미터·PI 게인(예: ".../PMSM Current Reference
%    Generator/Torque limiter", ".../Velocity Controller")을 실제 모터 스펙에
%    맞게 재설정해야 한다. 아직 이 cfg에는 반영 안 됨 — 다음 작업 대상.
%
%  사용 예:
%    cfg = cfg_ev_pmsm_drive();
%    r   = run_ac_loss_sweep('ev_pmsm_drive', cfg);

function cfg = cfg_ev_pmsm_drive()

cfg = struct();
cfg.currentSig = {'i_abc'};
cfg.T_cu       = 100;

% 속도지령: 최상위 Step 블록을 정속 지령(t=0부터 목표rpm 유지)으로 덮어씀
cfg.applySpeed = @(simIn, spd_rpm) simIn ...
    .setBlockParameter('ev_pmsm_drive/Step','Time','0') ...
    .setBlockParameter('ev_pmsm_drive/Step','Before','0') ...
    .setBlockParameter('ev_pmsm_drive/Step','After', num2str(spd_rpm));

% 모터 dq 파라미터 + DC 링크 전압 주입 (params.m → 모델 워크스페이스 변수명 매핑)
cfg.applyParams = @(simIn, p) simIn ...
    .setVariable('Rs', p.mot.Rs) ...
    .setVariable('Ld', p.mot.Ld) ...
    .setVariable('Lq', p.mot.Lq) ...
    .setVariable('PM', p.mot.lambda_pm) ...
    .setVariable('N',  p.mot.pole_pairs) ...
    .setBlockParameter('ev_pmsm_drive/Battery','Vnom', num2str(p.inv.Vdc));

end
