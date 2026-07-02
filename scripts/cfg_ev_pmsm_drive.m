%% cfg_ev_pmsm_drive.m ─ 'ev_pmsm_drive'(Simscape Electrical PMSM 예제) 전용 실행설정
%  inspect_model('ev_pmsm_drive') / inspect_model2('ev_pmsm_drive') 결과를 바탕으로
%  run_ac_loss_sweep 의 cfg를 이 모델에 맞게 구성한다.
%
%  모델 쪽 확인된 대응관계:
%    속도지령 : 최상위 'Step' 블록 (Time/Before/After) — 워크스페이스 변수 아님, 블록파라미터로 직접 덮어씀
%    모터 파라미터 : 워크스페이스 변수 Rs/Ld/Lq/N/PM 이 PMSM 블록 마스크에 그대로 바인딩됨
%    DC 링크 전압 : Battery 블록의 Vnom (기본 48V, 리터럴 값 — setBlockParameter로 덮어씀)
%    상전류 신호 : 'Sensing currents/Current Sensor (Three-Phase)' 출력
%
%  ⚠ 사용 전 필수(모델에서 1회, GUI로): 위 전류 신호선에 신호 로깅을 켜고
%    신호명을 'i_abc'로 지정한 뒤 모델을 저장할 것. 로깅 안 하면 get_phase_current가
%    상전류를 찾지 못해 에러가 난다.
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
