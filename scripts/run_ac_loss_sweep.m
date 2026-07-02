%% run_ac_loss_sweep.m ─ 정속 운전점 스윕 → AC 동손 산출 (레퍼런스 모델 하네스)
%  레퍼런스 FOC PMSM 스위칭 모델을 각 정속 운전점(100/120/140 km/h)에서 돌리고,
%  로깅된 3상 전류를 ac_copper_loss.m 에 넣어 AC 동손을 계산·정리한다.
%
%  사용:
%    r = run_ac_loss_sweep('mcb_pmsm_foc_sim');           % 기본 설정
%    r = run_ac_loss_sweep(modelName, cfg);               % 설정 지정
%
%  ── 모델에 맞춰 조정할 지점(cfg) ─────────────────────────────
%    cfg.speedVar   : 모델이 속도지령으로 참조하는 워크스페이스 변수명 (기본 'Speed_Ref')
%    cfg.speedUnit  : 'rpm' | 'rad/s'  (기본 'rpm')
%    cfg.stopTime   : 각 실행 시뮬 시간 [s] (기본: 정상상태 도달 + FFT창)
%    cfg.currentSig : 상전류 신호명 후보 (기본: get_phase_current 기본목록)
%    cfg.applyParams: @(simIn,p) ... 모터 dq 파라미터를 모델에 주입하는 함수핸들(옵션)
%    cfg.T_cu       : 구리온도 [℃] (기본 100)
%    cfg.RacFun     : Rac(f,T) 함수핸들 (기본 rac_placeholder — FEA맵으로 교체)

function results = run_ac_loss_sweep(modelName, cfg)

if nargin < 2, cfg = struct(); end
if ~isfield(cfg,'speedVar'),   cfg.speedVar   = 'Speed_Ref'; end
if ~isfield(cfg,'speedUnit'),  cfg.speedUnit  = 'rpm';       end
if ~isfield(cfg,'currentSig'), cfg.currentSig = {};          end
if ~isfield(cfg,'T_cu'),       cfg.T_cu       = 100;         end
if ~isfield(cfg,'RacFun'),     cfg.RacFun     = rac_placeholder(); end

p  = params();
op = operating_points(p);
n  = numel(op);

if ~isfield(cfg,'stopTime')
    % 정상상태 대기 + FFT창 (가장 낮은 fe 기준으로 넉넉히)
    fe_min = min([op.f_elec_Hz]);
    cfg.stopTime = p.scen.settle_s + p.scen.fft_periods/fe_min;
end

load_system(modelName);

rows = struct('speed_kmh',{},'n_rpm',{},'f_elec_Hz',{}, ...
              'P_ac_W',{},'P_fund_W',{},'P_harm_W',{},'Rac_Rdc',{});

for k = 1:n
    % 속도지령 값(단위 변환)
    if strcmpi(cfg.speedUnit,'rpm')
        spd = op(k).n_motor_rpm;
    else
        spd = op(k).n_motor_rpm*2*pi/60;
    end

    simIn = Simulink.SimulationInput(modelName);
    simIn = simIn.setVariable(cfg.speedVar, spd);
    simIn = simIn.setModelParameter('StopTime', num2str(cfg.stopTime));
    % 신호 로깅 보장
    simIn = simIn.setModelParameter('SignalLogging','on');
    if isfield(cfg,'applyParams') && ~isempty(cfg.applyParams)
        simIn = cfg.applyParams(simIn, p);   % 모터 dq 파라미터 주입(모델별)
    end

    fprintf('[%d/%d] %d km/h  (n=%.0f rpm, fe=%.1f Hz) 시뮬 중...\n', ...
            k, n, op(k).speed_kmh, spd, op(k).f_elec_Hz);
    simOut = sim(simIn);

    % 상전류 추출 → 정상상태 구간만 사용
    [iabc, t] = get_phase_current(simOut, cfg.currentSig);
    mask = t >= p.scen.settle_s;
    iabc = iabc(mask,:);  t = t(mask);

    [P_ac, info] = ac_copper_loss(iabc, t, cfg.RacFun, cfg.T_cu, ...
                                  'nPhase', 1, 'fMax', 3*p.inv.f_sw);
    % nPhase=1: iabc가 이미 3상 열을 담고 있으므로 상별 합산됨

    rows(k) = struct('speed_kmh',op(k).speed_kmh, 'n_rpm',spd, ...
        'f_elec_Hz',op(k).f_elec_Hz, 'P_ac_W',P_ac, ...
        'P_fund_W',info.P_fund_W, 'P_harm_W',info.P_harm_W, ...
        'Rac_Rdc',info.Rac_Rdc_fund);
end

results = struct2table(rows);

% 저장
if ~exist('results','dir'), mkdir('results'); end
save(fullfile('results','ac_loss_sweep.mat'),'results');
writetable(results, fullfile('results','ac_loss_sweep.csv'));

% 플롯
figure('Name','AC 동손 vs 정속');
bar([results.P_fund_W results.P_harm_W],'stacked');
set(gca,'XTickLabel',compose('%d km/h',results.speed_kmh));
ylabel('AC 동손 [W]'); legend('기본파','PWM 고조파','Location','northwest');
title('정속별 AC 동손 (기본파 + PWM 고조파)'); grid on;

disp(results);
end
