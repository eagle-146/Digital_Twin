%% rac_dowell.m ─ 물리 기반 Rac(f,T) (Dowell 표피·근접 모델)
%  권선 형상(도체높이 h, 층수 m)과 온도로 상 AC저항을 계산.
%      δ(T,f) = √(ρ(T)/(π·f·μ0))       표피깊이
%      Δ = h/δ,   Rac = Rdc(T)·dowell_ratio(Δ, m)
%  rac_placeholder(임의식)와 달리, 파라미터가 실제 물리량이라 직관적 조정·비교 가능.
%  FEA 맵이 오면 이 함수를 맵 보간으로 교체하면 됨(인터페이스 동일: @(f,T)→Rac).
%
%  사용:
%    RacFun = rac_dowell();            % params 권선형상 기반 함수핸들
%    Rac    = RacFun(675, 100);        % 675Hz, 100℃에서 상 AC저항 [Ω]
%    Rac    = rac_dowell(f, T, geom);  % geom 직접 지정(비교용)
%      geom 필드: Rdc20,T_ref,alpha,h,m,rho20

function out = rac_dowell(f, T, geom)

mu0 = 4*pi*1e-7;

if nargin == 0
    p = params();
    geom = struct('Rdc20',p.mot.Rdc_20, 'T_ref',p.mot.T_ref, ...
                  'alpha',p.mot.alpha_cu, 'h',p.mot.cond_h, ...
                  'm',p.mot.n_layers, 'rho20',p.mot.rho_cu20);
    out = @(ff,TT) rac_dowell(ff, TT, geom);
    return
end

Rdc_T = geom.Rdc20 .* (1 + geom.alpha.*(T - geom.T_ref));   % 온도보정 DC 상저항
rho_T = geom.rho20 .* (1 + geom.alpha.*(T - geom.T_ref));   % 온도보정 비저항

delta = sqrt(rho_T ./ (pi .* max(f, eps) .* mu0));          % 표피깊이 (f=0 보호)
Delta = geom.h ./ delta;
ratio = dowell_ratio(Delta, geom.m);
ratio(f==0) = 1;                                            % DC는 정확히 1

out = Rdc_T .* ratio;
end
