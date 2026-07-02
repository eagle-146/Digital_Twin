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
        val = ''; try, val = get_param(blks{i},'Value'); catch, end
        fprintf('   • %s  [%s]  Value=%s\n', blks{i}, bt, val);
    end
end

% ── 3) 로깅 표시된 신호 ──
fprintf('\n[3] 로깅(signal logging) 표시된 신호\n');
lines = find_system(modelName,'FindAll','on','LookUnderMasks','all','type','line');
nlog = 0;
for i = 1:numel(lines)
    dl = ''; try, dl = get_param(lines(i),'DataLogging'); catch, end
    if strcmpi(dl,'on') || isequal(dl,1) || isequal(dl,true)
        nm = ''; try, nm = get_param(lines(i),'Name'); catch, end
        if isempty(nm)
            try, nm = get_param(lines(i),'DataLoggingNameMode'); catch, end
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
