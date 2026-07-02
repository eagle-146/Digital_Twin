%% test_ac_copper_loss.m ─ ac_copper_loss.m 정확성 회귀테스트
%  알려진(이론값을 계산할 수 있는) 합성 신호로 파이프라인이 물리적으로
%  올바른 값을 내는지 검증한다. 툴박스·Simulink 불필요, 순수 MATLAB.
%  실패 시 error()로 즉시 중단 — CI/커밋 전 빠른 회귀 확인용.
%
%  사용: test_ac_copper_loss

function test_ac_copper_loss()

tol = 0.02;   % 상대오차 허용치 (윈도우/보간에 의한 미세오차 감안 2%)
nPass = 0; nTotal = 0;

%% 1) 순수 사인파 단상: 이론값과 직접 비교
[nTotal, nPass] = check(nTotal, nPass, 'pure sine, DC Rac', @() sub_pure_sine());

%% 2) 3상 합성 입력이 1상×3배와 일치하는지
[nTotal, nPass] = check(nTotal, nPass, '3-phase == 3x single-phase', @() sub_three_phase_consistency());

%% 3) 기본파+한 고조파 혼합: 각 성분 전력이 이론값과 일치
[nTotal, nPass] = check(nTotal, nPass, 'fundamental+harmonic split', @() sub_fund_harmonic_split());

%% 4) 가변스텝(불균일 샘플) 입력에서도 정확도 유지
[nTotal, nPass] = check(nTotal, nPass, 'non-uniform time grid resample', @() sub_nonuniform_grid());

%% 5) DC만 있는 신호
[nTotal, nPass] = check(nTotal, nPass, 'DC-only signal', @() sub_dc_only());

fprintf('\n=== test_ac_copper_loss: %d/%d 통과 ===\n', nPass, nTotal);
if nPass < nTotal
    error('test_ac_copper_loss:failed', '%d개 테스트 실패', nTotal-nPass);
end

    function [nTotal, nPass] = check(nTotal, nPass, name, fn)
        nTotal = nTotal + 1;
        try
            fn();
            fprintf('  [PASS] %s\n', name);
            nPass = nPass + 1;
        catch e
            fprintf('  [FAIL] %s : %s\n', name, e.message);
        end
    end

    function sub_pure_sine()
        f0 = 500; Ipk = 10; Rdc = 0.02; T_cu = 25;
        fs_hz = 200e3; T = 0.02;                 % 정수 주기(=10주기) 보장
        t = (0:1/fs_hz:T-1/fs_hz)';
        i = Ipk*sin(2*pi*f0*t);
        RacFun = @(f,T) Rdc;                      % 주파수 무관 상수저항
        [P_ac, info] = ac_copper_loss(i, t, RacFun, T_cu, 'nPhase', 3);
        P_theory = 3 * Rdc * (Ipk/sqrt(2))^2;      % = 3*0.02*50 = 3.0 W
        assert(abs(P_ac-P_theory)/P_theory < 0.02, ...
            sprintf('P_ac=%.4f theory=%.4f', P_ac, P_theory));
        assert(abs(info.f_fund_Hz - f0) < 5, sprintf('f_fund=%.1f expected~%d', info.f_fund_Hz, f0));
        assert(info.P_harm_W < 0.01*P_theory, sprintf('P_harm_W=%.4f should be ~0', info.P_harm_W));
    end

    function sub_three_phase_consistency()
        f0 = 300; Ipk = 15; T_cu = 60;
        fs_hz = 100e3; T = 0.03;
        t = (0:1/fs_hz:T-1/fs_hz)';
        ia = Ipk*sin(2*pi*f0*t);
        ib = Ipk*sin(2*pi*f0*t - 2*pi/3);
        ic = Ipk*sin(2*pi*f0*t + 2*pi/3);
        RacFun = rac_placeholder();
        [P_single, ~] = ac_copper_loss(ia, t, RacFun, T_cu, 'nPhase', 3);
        [P_multi, ~]  = ac_copper_loss([ia ib ic], t, RacFun, T_cu, 'nPhase', 1);
        assert(abs(P_single-P_multi)/P_single < 0.02, ...
            sprintf('P_single(3x)=%.4f P_multi=%.4f', P_single, P_multi));
    end

    function sub_fund_harmonic_split()
        f0 = 400; I1 = 20; I3 = 4;   % 기본파 + 3고조파(진폭 20%)
        Rdc = 0.015; T_cu = 25;
        fs_hz = 300e3; T = 0.025;    % f0*T = 10 (정수주기)
        t = (0:1/fs_hz:T-1/fs_hz)';
        i = I1*sin(2*pi*f0*t) + I3*sin(2*pi*3*f0*t);
        RacFun = @(f,T) Rdc;         % 주파수무관 → 전력비는 순수 진폭비로 결정
        [P_ac, info] = ac_copper_loss(i, t, RacFun, T_cu, 'nPhase', 3);
        P_fund_theory = 3*Rdc*(I1/sqrt(2))^2;
        P_h3_theory   = 3*Rdc*(I3/sqrt(2))^2;
        assert(abs(info.P_fund_W-P_fund_theory)/P_fund_theory < 0.02, ...
            sprintf('P_fund=%.4f theory=%.4f', info.P_fund_W, P_fund_theory));
        assert(abs(info.P_harm_W-P_h3_theory)/P_h3_theory < 0.05, ...
            sprintf('P_harm=%.4f theory=%.4f', info.P_harm_W, P_h3_theory));
        assert(abs(P_ac-(P_fund_theory+P_h3_theory))/P_ac < 0.02);
    end

    function sub_nonuniform_grid()
        % Simulink 가변스텝 솔버를 흉내: 균일 신호를 불균일 시간축에 재배치
        f0 = 600; Ipk = 12; Rdc = 0.018; T_cu = 40;
        fs_hz = 400e3; T = 0.02;    % f0*T = 12 (정수주기)
        t_u = (0:1/fs_hz:T-1/fs_hz)';
        i_u = Ipk*sin(2*pi*f0*t_u);
        % 불균일 샘플: 원 신호를 무작위(그러나 단조증가) 시각으로 재샘플링
        rng(42);
        idx = sort(randperm(numel(t_u), round(numel(t_u)*0.3)))';
        t_nu = t_u(idx); i_nu = i_u(idx);
        RacFun = @(f,T) Rdc;
        [P_ac, info] = ac_copper_loss(i_nu, t_nu, RacFun, T_cu, 'nPhase', 3, 'fMax', 5000);
        P_theory = 3*Rdc*(Ipk/sqrt(2))^2;
        assert(abs(P_ac-P_theory)/P_theory < 0.05, ...
            sprintf('P_ac=%.4f theory=%.4f (nonuniform grid)', P_ac, P_theory));
        assert(abs(info.f_fund_Hz-f0) < 20, sprintf('f_fund=%.1f expected~%d', info.f_fund_Hz, f0));
    end

    function sub_dc_only()
        Rdc = 0.01; T_cu = 25; Idc = 50;
        t = (0:1e-4:0.01)';
        i = Idc*ones(size(t));
        RacFun = @(f,T) Rdc;
        [P_ac, info] = ac_copper_loss(i, t, RacFun, T_cu, 'nPhase', 3);
        P_theory = 3*Rdc*Idc^2;
        assert(abs(P_ac-P_theory)/P_theory < 0.02, sprintf('P_ac=%.4f theory=%.4f', P_ac, P_theory));
        assert(info.P_fund_W < 0.01*P_theory, 'DC-only 신호에 기본파 성분이 있으면 안 됨');
    end

end
