%% get_phase_current.m ─ 시뮬레이션 결과에서 3상 고정자 전류 추출 (모델 무관)
%  레퍼런스 예제마다 로깅 방식이 달라, 여러 관례를 순서대로 탐색해 [N x 3] 전류와
%  시간벡터를 반환한다. 실패 시 명확한 안내 에러.
%
%  입력:
%    simOut : sim() 반환 (Simulink.SimulationOutput) 또는 logsout
%    names  : (옵션) 찾을 신호명 후보 셀배열. 기본 관례 목록 사용
%  출력:
%    iabc : [N x 3] 상전류 [A]
%    t    : [N x 1] 시간 [s]

function [iabc, t] = get_phase_current(simOut, names)

if nargin < 2 || isempty(names)
    % 흔한 3상 전류 신호명 관례 (대소문자 무시 부분일치)
    names = {'i_abc','iabc','is_abc','i_s_abc','stator_current', ...
             'phase_current','iphase','i_stator'};
end

% ── logsout 취득 (기본 이름 'logsout'이 없으면 'logsout_*' 자동탐색 —
%    모델의 SignalLoggingName이 기본값이 아닌 경우 대응) ──
ls = [];
if isa(simOut,'Simulink.SimulationOutput')
    try, ls = simOut.logsout; catch, end
    if isempty(ls)
        try
            avail = simOut.who;
            idx = find(strncmpi(avail,'logsout',7), 1);
            if ~isempty(idx), ls = simOut.get(avail{idx}); end
        catch
        end
    end
    if isempty(ls) || (isa(ls,'Simulink.SimulationData.Dataset') && ls.numElements==0)
        % yout(신호로깅) 대안
        try, ls = simOut.yout; catch, end
    end
elseif isa(simOut,'Simulink.SimulationData.Dataset')
    ls = simOut;
end

% ── 1) 3상 묶음 신호 먼저 탐색 ──
if ~isempty(ls) && isa(ls,'Simulink.SimulationData.Dataset')
    elemNames = cell(1, ls.numElements);
    for n = 1:ls.numElements
        elemNames{n} = ls{n}.Name;
    end
    for c = 1:numel(names)
        idx = find(contains(lower(elemNames), lower(names{c})), 1);
        if ~isempty(idx)
            sig = local_get_values(ls{idx});
            [iabc, t] = local_to_matrix(sig);
            if size(iabc,2) >= 3
                iabc = iabc(:,1:3); return
            end
        end
    end

    % ── 2) 개별 상(ia/ib/ic) 탐색 후 결합 ──
    trip = {{'ia','i_a','isa','is_a'}, {'ib','i_b','isb','is_b'}, {'ic','i_c','isc','is_c'}};
    cols = cell(1,3); tt = [];
    for ph = 1:3
        for c = 1:numel(trip{ph})
            idx = find(strcmpi(elemNames, trip{ph}{c}) | ...
                       contains(lower(elemNames), lower(trip{ph}{c})), 1);
            if ~isempty(idx)
                [v, tt] = local_to_matrix(local_get_values(ls{idx}));
                cols{ph} = v(:,1); break
            end
        end
    end
    if all(~cellfun(@isempty, cols))
        iabc = [cols{1} cols{2} cols{3}]; t = tt; return
    end
end

error(['상전류 신호를 찾지 못했습니다. 모델에서 3상 고정자 전류를 로깅(신호 로깅 또는 ', ...
       'To Workspace)하고, 신호명을 i_abc 또는 ia/ib/ic 로 지정하거나 ', ...
       'get_phase_current(simOut, {''your_signal_name''}) 처럼 명시하세요.']);

end

% ── Dataset 원소 → 실제 신호값 추출 (Simulink.SimulationData.Signal로
%    감싸져 있으면 .Values, 아니면(순수 timeseries 등) 그대로) ──
function sig = local_get_values(el)
if isobject(el) && isprop(el,'Values')
    sig = el.Values;
elseif isstruct(el) && isfield(el,'Values')
    sig = el.Values;
else
    sig = el;
end
end

% ── timeseries/구조체 → 행렬 변환 ──
function [v, t] = local_to_matrix(sig)
if isa(sig,'timeseries')
    v = squeeze(sig.Data); t = sig.Time(:);
elseif isstruct(sig) && isfield(sig,'Data')
    v = squeeze(sig.Data); t = sig.Time(:);
else
    % 시간정보가 없는 원시 배열. 벡터라면 먼저 열벡터로 고정해두지 않으면
    % (예: 1xN 행벡터) size(v,1)이 1이 되어 아래에서 파생하는 t도 길이 1짜리로
    % 잘못 만들어진다.
    v = squeeze(sig);
    if isvector(v), v = v(:); end
    t = (0:size(v,1)-1).';
end
% [N x m] 정렬: 시간벡터 길이(t)를 기준 삼아 방향을 정한다. 단순히 "행이 더
% 많은 쪽이 시간축"으로 추정하면 샘플 수가 3개 미만(m=3상)일 때 잘못
% 뒤집힐 수 있다.
if size(v,1) ~= numel(t) && size(v,2) == numel(t)
    v = v.';
end
end
