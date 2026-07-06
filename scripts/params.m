%% params.m ─ Digital Twin EV AC 동손 시뮬레이션 파라미터 정의
%  모든 파라미터를 구조체로 정의하고 params 구조체 하나로 묶어 반환/저장한다.
%  단위는 SI 기본. 다른 스크립트에서 run('scripts/params.m') 또는 params() 형태로 사용.
%
%  사용 예:
%    p = params();            % 구조체 반환
%    p.veh.mass               % 차량 시험질량 [kg]
%
%  기준 스펙 출처: README.md (승용 EV 800V, 헤어핀 IPMSM)

function p = params()

%% ── 차량 (Vehicle) : 중형 800V EV 기준 ──────────────────────────
veh.mass      = 2100;      % 시험질량(운전자·부하 포함) [kg]
veh.Cd        = 0.28;      % 공기저항계수 [-]
veh.Af        = 2.3;       % 전면투영면적 [m^2]
veh.Crr       = 0.010;     % 구름저항계수 [-]
veh.r_tire    = 0.335;     % 타이어 동하중반경 [m]
veh.gear      = 10.65;     % 단단 감속비 [-]
veh.eta_dl    = 0.97;      % 구동계 효율 [-]
veh.rho_air   = 1.20;      % 공기밀도 [kg/m^3]
veh.g         = 9.81;      % 중력가속도 [m/s^2]

%% ── 모터 (IPMSM, 헤어핀 권선) ────────────────────────────────────
mot.type      = 'IPMSM';
mot.pole_pairs= 4;         % 극쌍수 (8극)
mot.slots     = 48;        % 슬롯수
mot.winding   = 'hairpin'; % 권선 방식
mot.P_peak    = 160e3;     % 최대 출력 [W]
mot.P_cont    = 70e3;      % 연속 출력 [W]
mot.T_peak    = 350;       % 최대 토크 [N·m]
mot.n_max     = 16000;     % 최고 회전수 [rpm]
mot.n_base    = 5000;      % 기저속도 [rpm]

% ── dq 전기 파라미터 (PMSM 모델용) ──
%  ⚠ 엔지니어링 추정치 — 스펙(160kW/800V/350Nm/16000rpm)에 정합하도록 도출.
%    FEA/설계 확정 시 반드시 교체. 약자속 성립 조건 Ich=λpm/Ld ≈ Imax 근처로 맞춤.
mot.Rs        = 10e-3;     % 상저항 (DC) [Ohm]
mot.Ld        = 0.35e-3;   % d축 인덕턴스 [H]
mot.Lq        = 0.60e-3;   % q축 인덕턴스 [H] (IPM: Lq>Ld, 돌극비 ~1.7)
mot.lambda_pm = 0.13;      % 영구자석 쇄교자속 [Wb]
mot.Imax_pk   = 400;       % 최대 상전류 피크 [A]
mot.J         = 0.04;      % 회전자 관성 [kg·m^2]
mot.B_visc    = 1e-3;      % 점성마찰 [N·m·s]

% AC 동손 계산에 쓰이는 값 (설계·FEA 확정 시 갱신)
mot.Rdc_20    = mot.Rs;    % 상저항 DC @20℃ [Ohm] (= Rs 기준값 — 별도 리터럴로 두면
                           %  나중에 Rs만 바뀌고 여기는 안 바뀌어 조용히 어긋날 수 있어 참조로 묶음)
mot.T_ref     = 20;        % Rdc 기준온도 [℃]
mot.alpha_cu  = 3.93e-3;   % 구리 온도계수 [1/℃]

% ── 권선 형상 (Rac(f,T) Dowell 계산용 — ★직관적 조정 지점★) ──
%  이 세 값을 바꾸면 AC손이 물리적으로 반응한다. FEA 확정 전 대표값이며,
%  팀 설계변수와 직결됨:  cond_h=도체 크기(이동렬),  n_layers=도체 수(이동렬),
%  온도는 run_operating_ac_loss의 T_cu(정경민). FEA 맵이 오면 rac_dowell→맵으로 교체.
mot.cond_h    = 2.5e-3;    % 도체 높이(자속/반경 방향) [m] — 두꺼울수록 AC손↑ (표피·근접)
mot.n_layers  = 6;         % 슬롯당 도체 층수 [-] — 많을수록 근접효과 급증(∝ m²)
mot.rho_cu20  = 1.72e-8;   % 구리 비저항 @20℃ [Ω·m]

%% ── 인버터 (스위칭 레벨 PWM) ─────────────────────────────────────
inv.Vdc       = 800;       % DC 링크 전압 [V]  (배터리와 연동)
inv.f_sw      = 20e3;      % 스위칭 주파수 [Hz]  (16~20k, 기본 20k)
inv.modulation= 'SVPWM';   % 변조 방식
inv.deadtime  = 0.5e-6;    % 데드타임 [s]
inv.device    = 'SiC';     % 스위칭 소자

%% ── 배터리 (DC 링크) ─────────────────────────────────────────────
batt.V_nom    = 800;       % 공칭 전압 [V]
batt.model    = 'ideal';   % 'ideal'(정전압원) | 'equivalent'(등가회로)
batt.R_int    = 0.05;      % 내부저항 [Ohm] (equivalent일 때)

%% ── 제어 (FOC) ──────────────────────────────────────────────────
ctrl.scheme   = 'FOC';     % 벡터제어
ctrl.strategy = 'MTPA+FW'; % 최대토크/전류 + 약자속
ctrl.f_ctrl   = inv.f_sw;  % 전류제어 샘플링 (스위칭과 동기 가정)
ctrl.Ts_ctrl  = 1/ctrl.f_ctrl;

%% ── 주행 시나리오 (고속 정속) ────────────────────────────────────
scen.type     = 'constant_speed';
scen.speeds_kmh = [100 120 140];  % 정속 운전점 [km/h]
scen.settle_s = 2.0;       % 정상상태 도달 대기 [s]
scen.fft_periods = 10;     % AC손 산출용 FFT 창 (기본 전기주기 수)

%% ── 솔버 / 시뮬레이션 설정 ───────────────────────────────────────
sim_cfg.solver   = 'ode23tb';   % 시스템단(평균화)용, 강성
sim_cfg.dt_sw    = 5e-7;        % 스위칭단 고정스텝 [s] (0.5us, 20kHz 기준 주기당 100점)
sim_cfg.solver_sw= 'FixedStepAuto';

%% ── 묶어서 반환 ─────────────────────────────────────────────────
p.veh  = veh;
p.mot  = mot;
p.inv  = inv;
p.batt = batt;
p.ctrl = ctrl;
p.scen = scen;
p.sim  = sim_cfg;

end
