%% run_operating_ac_loss.m ─ 운전점별 AC 동손 산출 (목표 ①)
%  각 고속 정속 운전점에서: dq 전류지령(MTPA+약자속) → 기본파 상전류 →
%  Rac(f,T) 적용 → 기본파 AC 동손. 스위칭 시뮬 불필요(순수 해석).
%      P_dc = 3·Rdc(T)·I_rms²           (DC 동손)
%      P_ac = 3·Rac(fe,T)·I_rms²        (AC저항 반영 총 동손)
%      ΔP_ac = P_ac − P_dc              (AC효과 추가분)
%  ※ Rac는 현재 rac_placeholder(임시). 팀 FEA의 Rac(f,T) 맵이 오면 교체하면
%    같은 스크립트로 실제 값이 나온다.
%
%  사용:  T = run_operating_ac_loss;        % 구리온도 100℃ 기본
%         T = run_operating_ac_loss(120);   % 구리온도 지정 [℃]

function Tout = run_operating_ac_loss(T_cu)

if nargin < 1, T_cu = 100; end
p  = params();
op = operating_points(p);
RacFun = rac_placeholder();          % ← FEA 맵으로 교체 지점
Rdc = RacFun(0, T_cu);

n = numel(op);
rows = struct('speed_kmh',{},'n_rpm',{},'fe_Hz',{},'region',{}, ...
              'id_A',{},'iq_A',{},'Irms_A',{},'Rac_Rdc',{}, ...
              'P_dc_W',{},'P_ac_W',{},'dP_ac_W',{});

for k = 1:n
    c   = pmsm_current_ref(op(k).T_motor, op(k).n_motor_rpm, p);
    Rac = RacFun(c.fe, T_cu);
    P_dc = 3*Rdc  *c.I_rms^2;
    P_ac = 3*Rac  *c.I_rms^2;

    rows(k) = struct('speed_kmh',op(k).speed_kmh, 'n_rpm',op(k).n_motor_rpm, ...
        'fe_Hz',c.fe, 'region',string(c.region), 'id_A',c.id, 'iq_A',c.iq, ...
        'Irms_A',c.I_rms, 'Rac_Rdc',Rac/Rdc, 'P_dc_W',P_dc, 'P_ac_W',P_ac, ...
        'dP_ac_W',P_ac-P_dc);

    if ~c.feasible
        warning('run_operating_ac_loss:infeasible', ...
            '%d km/h: 전압/전류 한계로 운전점 달성 불가(클립됨).', op(k).speed_kmh);
    end
end

Tout = struct2table(rows);

% 저장
if ~exist('results','dir'), mkdir('results'); end
writetable(Tout, fullfile('results','operating_ac_loss.csv'));

% 출력
fprintf('\n=== 운전점별 AC 동손 (구리온도 %d℃, Rac=placeholder) ===\n', T_cu);
disp(Tout);
fprintf('※ Rac는 임시값 — 팀 FEA의 Rac(f,T) 맵으로 교체 시 실제 수치가 됨.\n\n');

% 플롯: DC동손 + AC추가분 (스택), 속도별
figure('Name','운전점별 AC 동손');
bar([Tout.P_dc_W, Tout.dP_ac_W], 'stacked'); grid on;
set(gca,'XTickLabel', compose('%d km/h', Tout.speed_kmh));
ylabel('동손 [W]'); legend('DC 동손','AC 추가분','Location','northwest');
title(sprintf('정속별 동손 (구리 %d℃)', T_cu));

end
