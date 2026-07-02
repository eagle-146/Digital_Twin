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
%  ⚠ 이전에 "컨트롤러 포화"로 의심했던 문제의 실제 원인(해결됨):
%    "PMSM Current Reference Generator" 마스크를 get_param(...,'MaskNames'/
%    'MaskValues')로 덤프해보니, Rs/Ld/Lq 외에도 Tmax/Pmax/Vnom과 —
%    PMSM 블록의 극쌍수 변수 N과는 별개인 — 자체 극쌍수 변수 p 를 워크스페이스에서
%    참조하고 있었다. 즉 플랜트(PMSM 블록)만 160kW 모터로 바꾸고 컨트롤러의
%    토크/전력 정격(Tmax=27Nm, Pmax≈2.8kW 등 작은 모터 기본값)은 그대로 둔
%    상태였던 것 — 5000rpm이든 15000rpm이든 컨트롤러가 여전히 27Nm/2.8kW
%    한도에서 토크지령을 잘라내니 상전류가 똑같게 나온 것이었다. 아래
%    applyParams에 Tmax/Pmax/Imax/Vnom/p를 추가로 주입해 해결한다.
%    (PI 게인 Kp_w/Ki_w 등은 아직 원래(작은 모터) 튜닝값 그대로 — 정격은
%    맞았으니 응답속도/오버슈트가 이상하면 다음으로 살펴볼 지점.)
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

% 모터 dq 파라미터 + DC 링크 전압 + 컨트롤러 정격 주입
% (params.m → 모델 워크스페이스 변수명 매핑. p/Tmax/Pmax/Imax/Vnom은
%  플랜트가 아니라 컨트롤러(Current Reference Generator)가 참조하는
%  "정격" 변수들 — 이걸 안 맞추면 플랜트만 큰 모터로 바뀌고 컨트롤러는
%  여전히 작은 모터 정격으로 토크를 잘라내는 불일치가 생긴다.)
cfg.applyParams = @(simIn, p) simIn ...
    .setVariable('Rs', p.mot.Rs) ...
    .setVariable('Ld', p.mot.Ld) ...
    .setVariable('Lq', p.mot.Lq) ...
    .setVariable('PM', p.mot.lambda_pm) ...
    .setVariable('N',  p.mot.pole_pairs) ...
    .setVariable('p',  p.mot.pole_pairs) ...   % Current Reference Generator 자체 극쌍수 변수(N과 별개)
    .setVariable('Tmax', p.mot.T_peak) ...
    .setVariable('Pmax', p.mot.P_peak) ...
    .setVariable('Imax', p.mot.Imax_pk) ...
    .setVariable('Vnom', p.inv.Vdc) ...
    .setBlockParameter('ev_pmsm_drive/Battery','Vnom', num2str(p.inv.Vdc));

end
