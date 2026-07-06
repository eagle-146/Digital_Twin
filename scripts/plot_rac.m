%% plot_rac.m ─ Rac/Rdc vs 주파수 곡선 (직관적 확인·조정용)
%  현재 params 권선형상(h, m)에서 온도별 AC저항비 곡선을 그리고, 운전점
%  주파수를 표시한다. params.mot.cond_h / n_layers 를 바꿔 다시 실행하면
%  AC손이 어떻게 달라지는지 눈으로 바로 비교 가능.
%
%  사용:  plot_rac              % 온도 40/100/160℃
%         plot_rac([25 150])

function plot_rac(T_list)

if nargin < 1, T_list = [40 100 160]; end
p   = params();
Rac = rac_dowell();
op  = operating_points(p);

f = linspace(0, 1300, 400);
figure('Name','Rac/Rdc vs 주파수 (Dowell)'); hold on; grid on;

for T = T_list
    Rdc = Rac(0, T);
    r   = arrayfun(@(ff) Rac(ff, T), f) / Rdc;
    plot(f, r, 'LineWidth', 1.6, 'DisplayName', sprintf('%d℃', T));
end

% 운전점 주파수 표시
yl = ylim;
for k = 1:numel(op)
    fe = op(k).f_elec_Hz;
    plot([fe fe], yl, 'k--', 'HandleVisibility','off');
    text(fe, yl(1)+0.05*diff(yl), sprintf(' %dkm/h', op(k).speed_kmh), ...
         'Rotation',90, 'VerticalAlignment','bottom', 'FontSize',8);
end

xlabel('전기주파수 [Hz]'); ylabel('R_{ac}/R_{dc}');
title(sprintf('헤어핀 AC저항비  (도체높이 %.1fmm, %d층)', ...
      p.mot.cond_h*1e3, p.mot.n_layers));
legend('Location','northwest');
end
