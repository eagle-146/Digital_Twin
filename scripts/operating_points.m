%% operating_points.m ─ 정속 운전점 산출 (2단 아키텍처의 1단, 순수 대수계산)
%  각 정속에서 도로부하 → 모터 토크·회전수·기본 전기주파수를 계산한다.
%  Simulink/툴박스 불필요 — 스위칭 시뮬(2단)에 넣을 운전점을 미리 확보하는 용도.
%
%  사용 예:
%    op = operating_points(params());
%    disp(struct2table(op))

function op = operating_points(p)

if nargin < 1, p = params(); end
v = p.veh;

speeds_ms = p.scen.speeds_kmh / 3.6;              % [m/s]
n = numel(speeds_ms);
op = struct('speed_kmh',{},'F_road',{},'P_wheel_kW',{}, ...
            'T_motor',{},'n_motor_rpm',{},'f_elec_Hz',{});

for k = 1:n
    vk = speeds_ms(k);

    % 도로부하: 구름저항 + 공기저항 (정속이므로 가속저항·구배 0)
    F_roll = v.Crr * v.mass * v.g;
    F_aero = 0.5 * v.rho_air * v.Cd * v.Af * vk^2;
    F_road = F_roll + F_aero;                      % [N]

    P_wheel = F_road * vk;                          % 휠 요구동력 [W]

    % 휠 → 모터 (감속비·구동계효율)
    w_wheel  = vk / v.r_tire;                       % 휠 각속도 [rad/s]
    w_motor  = w_wheel * v.gear;                    % 모터 각속도 [rad/s]
    n_motor  = w_motor * 60/(2*pi);                 % [rpm]
    T_motor  = (F_road * v.r_tire) / (v.gear * v.eta_dl);  % 모터 토크 [N·m]

    % 기본 전기주파수
    f_elec = n_motor/60 * p.mot.pole_pairs;         % [Hz]

    op(k).speed_kmh   = p.scen.speeds_kmh(k);
    op(k).F_road      = F_road;
    op(k).P_wheel_kW  = P_wheel/1e3;
    op(k).T_motor     = T_motor;
    op(k).n_motor_rpm = n_motor;
    op(k).f_elec_Hz   = f_elec;
end

end
