%% inspect_model.m ─ 레퍼런스 모델 구조 자동분석 (하네스 설정용 정보 수집)
%  레퍼런스 예제의 속도지령·전류신호·PMSM 파라미터 위치를 찾아 출력한다.
%  이 출력을 공유하면 run_ac_loss_sweep 의 cfg 를 정확히 맞출 수 있다.
%
%  사용:  inspect_model('ev_pmsm_drive')   % 저장한 모델명

function inspect_model(modelName)

load_system(modelName);
fprintf('\n======== 모델 분석: %s ========\n', modelName);

% ── 1) 기계(PMSM/동기기) 블록 ──
fprintf('\n[1] PMSM/동기기 블록\n');
blks = find_system(modelName,'LookUnderMasks','all','FollowLinks','on','type','block');
machKW = {'PMSM','Permanent Magnet','Synchronous Machine','FEM-Parameterized'};
found = false;
for i = 1:numel(blks)
    nm = get_param(blks{i},'Name');
    bt = get_param(blks{i},'BlockType');
    mt = ''; try, mt = get_param(blks{i},'MaskType'); catch, end
    tag = [nm ' ' bt ' ' mt];
    if any(cellfun(@(k) contains(tag,k,'IgnoreCase',true), machKW))
        fprintf('   • %s   (MaskType: %s)\n', blks{i}, mt);
        found = true;
    end
end
if ~found, fprintf('   (자동탐색 실패 — 수동 확인 필요)\n'); end

% ── 2) 속도지령 후보 (이름에 speed/ref/w/rpm) ──
fprintf('\n[2] 속도지령 후보 블록 (Constant/Step/Ramp/Inport)\n');
srcTypes = {'Constant','Step','Ramp','Inport','SignalBuilder','FromWorkspace'};
kw = {'speed','ref','wref','w_ref','rpm','omega','n_ref','spd'};
for i = 1:numel(blks)
    bt = get_param(blks{i},'BlockType');
    nm = lower(get_param(blks{i},'Name'));
    if any(strcmp(bt, srcTypes)) && any(cellfun(@(k)contains(nm,k), kw))
        val = local_source_value_str(blks{i}, bt);
        fprintf('   • %s  [%s]  %s\n', blks{i}, bt, val);
    end
end

% ── 3) 로깅 표시된 신호 ──
fprintf('\n[3] 로깅(signal logging) 표시된 신호\n');
% ⚠ DataLogging* 계열 파라미터는 get_param()으로 읽으면 "그런 파라미터
%   없음" 에러가 나는 버전 제약이 있다(기본 Simulink에서도 재현됨).
%   generic get()/set()은 정상 동작하므로 이 계열은 반드시 get()으로 읽는다.
lines = find_system(modelName,'FindAll','on','LookUnderMasks','all','type','line');
nlog = 0;
for i = 1:numel(lines)
    dl = false; try, dl = get(lines(i),'DataLogging'); catch, end
    if isequal(dl,true) || isequal(dl,1) || strcmpi(dl,'on')
        nm = ''; try, nm = get_param(lines(i),'Name'); catch, end
        if isempty(nm)
            try, nm = get(lines(i),'DataLoggingName'); catch, end
        end
        if isempty(nm)
            try, nm = get(lines(i),'UserSpecifiedLogName'); catch, end
        end
        src = ''; try, sp = get_param(lines(i),'SrcBlockHandle'); src = get_param(sp,'Name'); catch, end
        fprintf('   • 신호명: "%s"   (출처 블록: %s)\n', nm, src);
        nlog = nlog + 1;
    end
end
if nlog==0, fprintf('   (로깅된 신호 없음 — 3상 전류선 우클릭 > Log Signals 필요)\n'); end

% ── 4) 시뮬 설정 ──
fprintf('\n[4] 솔버/시간 설정\n');
fprintf('   StopTime = %s,  Solver = %s,  Type = %s\n', ...
    get_param(modelName,'StopTime'), get_param(modelName,'Solver'), ...
    get_param(modelName,'SolverType'));

fprintf('\n======== 분석 끝 — 위 [1]~[3] 출력을 공유해 주세요 ========\n\n');
end

% ── 소스 블록 타입별 실제 값 파라미터 조회 ──
%  'Value'는 Constant 블록에만 있다. Step/Ramp 등은 이름이 달라 그냥
%  get_param(blk,'Value')를 쓰면 항상 실패(try/catch로 조용히 빈칸) —
%  실제로 이 프로젝트에서 속도지령이 Step 블록이었는데 Value만 찾다가
%  못 찾은 적이 있어 블록타입별로 맞는 파라미터를 조회하도록 한다.
function s = local_source_value_str(blk, blockType)
try
    switch blockType
        case 'Constant'
            s = sprintf('Value=%s', get_param(blk,'Value'));
        case 'Step'
            s = sprintf('Time=%s Before=%s After=%s', ...
                get_param(blk,'Time'), get_param(blk,'Before'), get_param(blk,'After'));
        case 'Ramp'
            s = sprintf('Slope=%s Start=%s InitialOutput=%s', ...
                get_param(blk,'slope'), get_param(blk,'start'), get_param(blk,'InitialOutput'));
        otherwise
            s = '(Inport/SignalBuilder 등 — 값은 워크스페이스/외부 입력에 의해 결정)';
    end
catch e
    s = sprintf('(값 조회 실패: %s)', e.message);
end
end
