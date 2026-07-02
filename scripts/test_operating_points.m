%% test_operating_points.m ─ operating_points.m 회귀테스트
%  단순 대수계산이라 이론값을 직접 손계산해 비교할 수 있다.
%
%  사용: test_operating_points

function test_operating_points()

nPass = 0; nTotal = 0;

[nTotal, nPass] = check(nTotal, nPass, 'default params: 3 operating points, expected order', @() sub_default());
[nTotal, nPass] = check(nTotal, nPass, 'torque/power monotonically increase with speed', @() sub_monotonic());
[nTotal, nPass] = check(nTotal, nPass, 'f_elec matches n_motor*pole_pairs/60 exactly', @() sub_felec_consistency());
[nTotal, nPass] = check(nTotal, nPass, 'hand-calculated torque at 100 km/h matches', @() sub_hand_calc());

fprintf('\n=== test_operating_points: %d/%d 통과 ===\n', nPass, nTotal);
if nPass < nTotal
    error('test_operating_points:failed', '%d개 테스트 실패', nTotal-nPass);
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

    function sub_default()
        p = params();
        op = operating_points(p);
        assert(numel(op) == numel(p.scen.speeds_kmh), '운전점 개수가 speeds_kmh와 다름');
        assert(isequal([op.speed_kmh], p.scen.speeds_kmh), '속도 순서가 scen.speeds_kmh와 다름');
    end

    function sub_monotonic()
        p = params();
        op = operating_points(p);
        assert(all(diff([op.T_motor]) > 0), '속도가 오를수록 토크가 증가해야 함(공력저항)');
        assert(all(diff([op.n_motor_rpm]) > 0), '속도가 오를수록 rpm이 증가해야 함');
        assert(all(diff([op.f_elec_Hz]) > 0), '속도가 오를수록 전기주파수가 증가해야 함');
    end

    function sub_felec_consistency()
        p = params();
        op = operating_points(p);
        for k = 1:numel(op)
            expected = op(k).n_motor_rpm/60 * p.mot.pole_pairs;
            assert(abs(op(k).f_elec_Hz - expected) < 1e-9, ...
                sprintf('k=%d: f_elec=%.4f expected=%.4f', k, op(k).f_elec_Hz, expected));
        end
    end

    function sub_hand_calc()
        p = params();
        p.scen.speeds_kmh = 100;   % 단일 운전점으로 단순화
        op = operating_points(p);
        v = p.veh;
        vk = 100/3.6;
        F_roll_theory = v.Crr * v.mass * v.g;
        F_aero_theory = 0.5 * v.rho_air * v.Cd * v.Af * vk^2;
        T_theory = (F_roll_theory + F_aero_theory) * v.r_tire / (v.gear * v.eta_dl);
        assert(abs(op.T_motor - T_theory) < 1e-9, ...
            sprintf('T_motor=%.6f theory=%.6f', op.T_motor, T_theory));
        n_theory = (vk / v.r_tire) * v.gear * 60/(2*pi);
        assert(abs(op.n_motor_rpm - n_theory) < 1e-6, ...
            sprintf('n_motor_rpm=%.4f theory=%.4f', op.n_motor_rpm, n_theory));
    end

end
