%% demo_ac_loss.m ─ AC 동손 파이프라인 자체검증 (합성 상전류)
%  실제 스위칭 모델이 완성되기 전, 합성 상전류(기본파 + PWM 사이드밴드)로
%  ac_copper_loss.m 파이프라인이 물리적으로 타당하게 동작하는지 확인한다.
%  MATLAB Online에서 repo pull 후 바로 실행 가능:  demo_ac_loss
%
%  기대: 기본파 AC손이 대부분, 20kHz 부근 PWM 고조파손이 소량 추가되고
%        Rac/Rdc(기본파) > 1 로 나오면 파이프라인 정상.

function demo_ac_loss()

p  = params();
op = operating_points(p);

k = 2;                      % 120 km/h 운전점 사용
f_e  = op(k).f_elec_Hz;     % 기본 전기주파수 [Hz]
Torque = op(k).T_motor;

% 대략적 상전류 진폭 (경부하): 토크상수 가정으로 간단 추정 (검증용 근사)
kt   = 0.9;                 % 토크상수 [N·m/A_pk] (예시, 설계값으로 교체)
Ipk  = Torque / kt;         % 기본파 피크전류 [A]

% ── 합성 상전류: 기본파 + PWM 사이드밴드 ──
f_sw = p.inv.f_sw;
dt   = p.sim.dt_sw;         % 0.5 us
T_end= p.scen.fft_periods / f_e;     % 정수 기본주기 창
t    = (0:dt:T_end).';

i = Ipk*sin(2*pi*f_e*t);                             % 기본파
% PWM 1차 사이드밴드(f_sw ± 2 f_e), 2차 고조파대(2 f_sw ± f_e) — 진폭은 예시치
i = i + 0.04*Ipk*sin(2*pi*(f_sw-2*f_e)*t) ...
      + 0.04*Ipk*sin(2*pi*(f_sw+2*f_e)*t) ...
      + 0.02*Ipk*sin(2*pi*(2*f_sw-f_e)*t) ...
      + 0.02*Ipk*sin(2*pi*(2*f_sw+f_e)*t);

% ── AC 동손 계산 ──
RacFun = rac_placeholder();           % 임시 Rac(f,T) — FEA 맵으로 교체 예정
T_cu   = 100;                         % 구리온도 [℃]

[P_ac, info] = ac_copper_loss(i, t, RacFun, T_cu, 'nPhase', 3, 'fMax', 3*f_sw);

% ── 결과 출력 ──
fprintf('\n=== AC 동손 파이프라인 검증 (%d km/h) ===\n', op(k).speed_kmh);
fprintf('기본 전기주파수 f_e   : %.1f Hz\n', f_e);
fprintf('기본파 피크전류 Ipk   : %.1f A (근사)\n', Ipk);
fprintf('구리온도 T_cu         : %.0f ℃\n', T_cu);
fprintf('-----------------------------------------\n');
fprintf('총 AC 동손 P_ac       : %.1f W\n', P_ac);
fprintf('  ├ 기본파분          : %.1f W\n', info.P_fund_W);
fprintf('  └ PWM 고조파분      : %.2f W\n', info.P_harm_W);
fprintf('Rac/Rdc (기본파)      : %.3f\n', info.Rac_Rdc_fund);
fprintf('-----------------------------------------\n');
disp('유효 고조파 성분:');
disp(info.harmonics);

end
