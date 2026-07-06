%% pmsm_current_ref.m ─ 운전점 dq 전류지령 해석 계산 (MTPA + 약자속)
%  토크 T·속도 n_rpm에서, 스위칭/FOC 시뮬 없이 기본파 상전류(id,iq,I_rms)를
%  물리식으로 구한다. IPMSM 토크식 + 전압/전류 한계로 MTPA와 약자속을 자동 판정.
%      토크 : T = 1.5·p·[λpm·iq + (Ld−Lq)·id·iq]
%      전압 : vd = Rs·id − ωe·Lq·iq,  vq = Rs·iq + ωe·(Ld·id + λpm)
%      한계 : |V|≤Vmax=Vdc/√3(SVPWM),  |I|=√(id²+iq²)≤Imax
%
%  사용:  c = pmsm_current_ref(T_Nm, n_rpm, params());
%  반환:  구조체 (id, iq, I_pk, I_rms, Vs, Vmax, fe, we, region, feasible)
%         region: 'MTPA' | 'FW'(약자속),  feasible: 전압·전류 한계 내 달성 여부

function out = pmsm_current_ref(T, n_rpm, p)

pp  = p.mot.pole_pairs;
Rs  = p.mot.Rs;   Ld = p.mot.Ld;   Lq = p.mot.Lq;
lam = p.mot.lambda_pm;   Imax = p.mot.Imax_pk;
Vdc = p.inv.Vdc;   Vmax = Vdc/sqrt(3);      % SVPWM 선형영역 상전압 피크 한계

wm = n_rpm*2*pi/60;   we = pp*wm;   fe = we/(2*pi);

% 전압 크기 (dq)
Vs_of = @(id,iq) hypot(Rs.*id - we.*Lq.*iq, Rs.*iq + we.*(Ld.*id + lam));

% ── 1) MTPA 해 (전압한계 무시한 최소전류 해) ──
if abs(Ld-Lq) < 1e-12
    iq = T/(1.5*pp*lam);   id = 0;                 % 비돌극(표면형): id=0
else
    idmtpa = @(x) (lam - sqrt(lam^2 + 8*(Lq-Ld)^2.*x.^2))./(4*(Lq-Ld));
    tq     = @(x) 1.5*pp*(lam.*x + (Ld-Lq).*idmtpa(x).*x);
    iq = fzero(@(x) tq(x)-T, T/(1.5*pp*lam));      % 등가토크 iq를 MTPA 궤적에서 탐색
    id = idmtpa(iq);
end
region = 'MTPA';   feasible = true;

% ── 2) 약자속 판정: MTPA 해가 전압한계를 넘으면 음의 id로 자속 약화 ──
if Vs_of(id,iq) > Vmax
    region = 'FW';
    iq_of = @(idv) T ./ (1.5*pp*(lam + (Ld-Lq).*idv));   % 등토크 곡선 iq(id)
    g     = @(idv) Vs_of(idv, iq_of(idv)) - Vmax;        % =0 되는 id 탐색
    id_lo = -Imax;                                       % 최대 약자속(전류한계) 하한
    if g(id_lo) > 0
        % 이 속도에서 요구 토크는 전압+전류 한계로 달성 불가 → 하한으로 클립
        id = id_lo;   feasible = false;
    else
        id = fzero(g, [id_lo, id]);                      % Vs=Vmax 지점
    end
    iq = iq_of(id);
end

I_pk = hypot(id, iq);
if I_pk > Imax*(1+1e-6), feasible = false; end
I_rms = I_pk/sqrt(2);

out = struct('id',id, 'iq',iq, 'I_pk',I_pk, 'I_rms',I_rms, ...
             'Vs',Vs_of(id,iq), 'Vmax',Vmax, 'fe',fe, 'we',we, ...
             'region',region, 'feasible',feasible);
end
