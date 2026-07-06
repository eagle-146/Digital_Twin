%% compare_winding_variants.m ─ 권선 설계변주별 AC 동손 비교 (목표 ③)
%  여러 권선 형상(도체 높이·층수)에 대해 각 운전점의 AC 동손을 계산·비교한다.
%  전류(id,iq)는 운전점만으로 정해져 변주와 무관 → 변주는 Rac(f,T)만 바꾸므로
%  "AC 효과의 설계 저감량"을 순수하게 분리해서 볼 수 있다.
%
%  ※ 단순화 가정: 변주 간 Rdc(구리량) 동일로 두고 AC 저항비만 비교한다. 실제
%    도체 단면 변화에 따른 Rdc·점적률 트레이드오프는 FEA/설계에서 반영.
%
%  사용:
%    T = compare_winding_variants;                 % 기본 변주 4종, 100℃
%    T = compare_winding_variants(variants, 120);  % 사용자 변주, 온도지정
%      variants: struct array (필드 name, cond_h[m], n_layers)
%
%  반환: 변주×지표 표 (운전점별 P_ac, 총합, 기준 대비 저감률%)

function Tout = compare_winding_variants(variants, T_cu, doPlot)

if nargin < 2 || isempty(T_cu),   T_cu = 100;  end
if nargin < 3 || isempty(doPlot), doPlot = true; end
p  = params();
op = operating_points(p);

if nargin < 1 || isempty(variants)
    variants = struct( ...
      'name',     {'기준 2.5mm/6층','얇은도체 1.8mm/6층','적은층수 2.5mm/4층','얇고적게 1.8mm/4층'}, ...
      'cond_h',   {2.5e-3, 1.8e-3, 2.5e-3, 1.8e-3}, ...
      'n_layers', {6, 6, 4, 4});
end
nv = numel(variants);  ns = numel(op);

% ── 운전점 전류 (변주 무관, 1회 계산) ──
Irms = zeros(1,ns);  fe = zeros(1,ns);
for s = 1:ns
    c = pmsm_current_ref(op(s).T_motor, op(s).n_motor_rpm, p);
    Irms(s) = c.I_rms;  fe(s) = c.fe;
end

% ── 변주별 AC 동손 ──
Pac = zeros(nv, ns);
for v = 1:nv
    geom = struct('Rdc20',p.mot.Rdc_20, 'T_ref',p.mot.T_ref, 'alpha',p.mot.alpha_cu, ...
                  'h',variants(v).cond_h, 'm',variants(v).n_layers, 'rho20',p.mot.rho_cu20);
    for s = 1:ns
        Pac(v,s) = 3 * rac_dowell(fe(s), T_cu, geom) * Irms(s)^2;
    end
end
Ptot      = sum(Pac, 2);
reduction = (Ptot(1) - Ptot) / Ptot(1) * 100;    % 기준(1행) 대비 저감률 [%]

Tout = table({variants.name}', [variants.cond_h]'*1e3, [variants.n_layers]', ...
    Pac(:,1), Pac(:,2), Pac(:,3), Ptot, reduction, 'VariableNames', ...
    {'variant','cond_h_mm','n_layers','Pac_100W','Pac_120W','Pac_140W','Pac_total_W','reduction_pct'});

fprintf('\n=== 권선 설계변주별 AC 동손 비교 (구리 %d℃) ===\n', T_cu);
disp(Tout);
[bestR, bi] = max(reduction);
fprintf('최대 저감: "%s" — 기준 대비 %.1f%%\n\n', variants(bi).name, bestR);

if doPlot
    figure('Name','설계변주별 AC 동손 비교');
    bar([op.speed_kmh], Pac'); grid on;
    xlabel('정속 [km/h]'); ylabel('AC 반영 동손 P_{ac} [W]');
    legend({variants.name}, 'Location','northwest');
    title(sprintf('권선 설계변주별 운전점 AC 동손 (%d℃)', T_cu));
end

end
