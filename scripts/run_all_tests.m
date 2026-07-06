%% run_all_tests.m ─ scripts/의 모든 test_*.m 회귀테스트를 순서대로 실행
%  Simulink 모델(.slx) 없이 순수 MATLAB/기본 Simulink만으로 도는 것들만 모음.
%  하나라도 실패하면 마지막에 실패 목록과 함께 error()로 알려준다.
%
%  사용: run_all_tests

function run_all_tests()

tests = {'test_ac_copper_loss', 'test_operating_points', ...
         'test_pmsm_current_ref', 'test_rac_dowell', ...
         'test_compare_winding_variants'};

failed = {};
for i = 1:numel(tests)
    fprintf('\n========== %s ==========\n', tests{i});
    try
        feval(tests{i});
    catch e
        failed{end+1} = tests{i}; %#ok<AGROW>
        fprintf('*** %s 실패: %s\n', tests{i}, e.message);
    end
end

fprintf('\n=================================\n');
if isempty(failed)
    fprintf('전체 통과: %d/%d 테스트 스크립트\n', numel(tests), numel(tests));
else
    fprintf('실패한 스크립트(%d개): %s\n', numel(failed), strjoin(failed, ', '));
    error('run_all_tests:failed', '일부 테스트 실패');
end

end
