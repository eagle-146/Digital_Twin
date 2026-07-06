%% test_get_phase_current.m ─ get_phase_current.m 회귀테스트
%  실제 시뮬레이션 없이 Simulink.SimulationData.Dataset을 직접 구성해
%  신호명 탐색 로직(번들 3상 / 개별상 결합 / 실패 에러)을 검증한다.
%
%  사용: test_get_phase_current

function test_get_phase_current()

nPass = 0; nTotal = 0;

[nTotal, nPass] = check(nTotal, nPass, 'bundled i_abc signal', @() sub_bundled());
[nTotal, nPass] = check(nTotal, nPass, 'individual ia/ib/ic signals', @() sub_individual());
[nTotal, nPass] = check(nTotal, nPass, 'no matching signal -> clear error', @() sub_notfound());
[nTotal, nPass] = check(nTotal, nPass, 'custom signal name override', @() sub_customname());
[nTotal, nPass] = check(nTotal, nPass, 'short row-vector raw signal not mis-oriented', @() sub_shortrowvector());

fprintf('\n=== test_get_phase_current: %d/%d 통과 ===\n', nPass, nTotal);
if nPass < nTotal
    error('test_get_phase_current:failed', '%d개 테스트 실패', nTotal-nPass);
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

    function sub_bundled()
        t = (0:0.001:0.01)';
        data = [sin(t) cos(t) -sin(t)];
        ds = Simulink.SimulationData.Dataset;
        ds = ds.addElement(timeseries(data, t), 'i_abc');
        [iabc, tt] = get_phase_current(ds);
        assert(isequal(size(iabc), [numel(t) 3]), 'shape mismatch');
        assert(max(abs(iabc(:,1)-sin(t))) < 1e-10, 'phase A mismatch');
        assert(max(abs(tt-t)) < 1e-12, 'time vector mismatch');
    end

    function sub_individual()
        t = (0:0.001:0.01)';
        ia = sin(t); ib = sin(t-2*pi/3); ic = sin(t+2*pi/3);
        ds = Simulink.SimulationData.Dataset;
        ds = ds.addElement(timeseries(ia, t), 'ia');
        ds = ds.addElement(timeseries(ib, t), 'ib');
        ds = ds.addElement(timeseries(ic, t), 'ic');
        [iabc, tt] = get_phase_current(ds);
        assert(isequal(size(iabc), [numel(t) 3]), 'shape mismatch');
        assert(max(abs(iabc(:,1)-ia)) < 1e-10, 'phase A mismatch');
        assert(max(abs(iabc(:,2)-ib)) < 1e-10, 'phase B mismatch');
        assert(max(abs(iabc(:,3)-ic)) < 1e-10, 'phase C mismatch');
        assert(max(abs(tt-t)) < 1e-12, 'time vector mismatch');
    end

    function sub_notfound()
        t = (0:0.001:0.01)';
        ds = Simulink.SimulationData.Dataset;
        ds = ds.addElement(timeseries(sin(t), t), 'some_unrelated_signal');
        threw = false;
        try
            get_phase_current(ds);
        catch e
            threw = true;
            assert(contains(e.message, '상전류'), '에러 메시지가 안내문이 아님');
        end
        assert(threw, '신호를 못 찾았는데 에러가 안 났음');
    end

    function sub_customname()
        t = (0:0.001:0.01)';
        data = [sin(t) cos(t) -sin(t)];
        ds = Simulink.SimulationData.Dataset;
        ds = ds.addElement(timeseries(data, t), 'my_weird_current_name');
        [iabc, ~] = get_phase_current(ds, {'my_weird_current_name'});
        assert(isequal(size(iabc), [numel(t) 3]), 'shape mismatch with custom name');
    end

    function sub_shortrowvector()
        % Dataset 원소가 timeseries/struct로 안 감싸진 순수 배열(1x3 행벡터,
        % 3샘플뿐)인 경우. 예전 코드는 이 경우 시간벡터를 길이 1짜리로 잘못
        % 유도해 [N x 3] 결합 시 길이가 안 맞았다.
        ds = Simulink.SimulationData.Dataset;
        ds = ds.addElement([1 2 3], 'ia');
        ds = ds.addElement([4 5 6], 'ib');
        ds = ds.addElement([7 8 9], 'ic');
        [iabc, t] = get_phase_current(ds);
        assert(isequal(size(iabc), [3 3]), sprintf('shape=%s expected [3 3]', mat2str(size(iabc))));
        assert(numel(t) == 3, sprintf('t 길이=%d expected 3', numel(t)));
        assert(isequal(iabc(:,1), [1;2;3]), 'phase A 값 불일치');
        assert(isequal(iabc(:,2), [4;5;6]), 'phase B 값 불일치');
        assert(isequal(iabc(:,3), [7;8;9]), 'phase C 값 불일치');
    end

end
