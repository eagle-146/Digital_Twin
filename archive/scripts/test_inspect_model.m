%% test_inspect_model.m ─ inspect_model.m / enable_signal_logging.m 회귀테스트
%  Simscape 없이 기본 Simulink 블록만으로 신호로깅 감지·Step값 표시가
%  올바른지 확인한다. (실측으로 get_param('...','DataLogging')이 조용히
%  실패해 "로깅된 신호 없음"으로 잘못 보고되는 버그가 있었음 — 재발 방지용)
%
%  사용: test_inspect_model

function test_inspect_model()

nPass = 0; nTotal = 0;

[nTotal, nPass] = check(nTotal, nPass, 'enable_signal_logging + inspect_model detects it', @() sub_logging_detected());
[nTotal, nPass] = check(nTotal, nPass, 'Step block value shown (Time/Before/After)', @() sub_step_value());

fprintf('\n=== test_inspect_model: %d/%d 통과 ===\n', nPass, nTotal);
if nPass < nTotal
    error('test_inspect_model:failed', '%d개 테스트 실패', nTotal-nPass);
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

    function sub_logging_detected()
        mdl = local_fresh_model('t_ac_log_a');
        add_block('simulink/Sources/Sine Wave', [mdl '/i_abc_src']);
        add_block('simulink/Sinks/Scope', [mdl '/Scope1']);
        add_line(mdl, 'i_abc_src/1', 'Scope1/1');
        enable_signal_logging([mdl '/i_abc_src'], 1, 'i_abc');

        txt = evalc('inspect_model(mdl)');
        close_system(mdl, 0);

        assert(contains(txt, 'i_abc'), 'inspect_model 출력에 로깅된 신호명(i_abc)이 안 보임');
        assert(~contains(txt, '로깅된 신호 없음'), '실제로 로깅을 켰는데 "없음"으로 보고됨');
    end

    function sub_step_value()
        mdl = local_fresh_model('t_ac_log_b');
        add_block('simulink/Sources/Step', [mdl '/speed_ref']);
        set_param([mdl '/speed_ref'], 'Time','0', 'Before','0', 'After','12345');
        add_block('simulink/Sinks/Scope', [mdl '/Scope1']);
        add_line(mdl, 'speed_ref/1', 'Scope1/1');

        txt = evalc('inspect_model(mdl)');
        close_system(mdl, 0);

        assert(contains(txt, '12345'), 'Step 블록의 After 값(12345)이 출력에 안 보임');
        assert(contains(txt, 'Time='), 'Step 블록 파라미터명이 안 보임 (Value만 찾던 예전 버그 재발?)');
    end

    function mdl = local_fresh_model(mdl)
        if bdIsLoaded(mdl), close_system(mdl, 0); end
        new_system(mdl);
        open_system(mdl);
    end

end
