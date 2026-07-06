%% inspect_model2.m ─ 레퍼런스 모델 상세분석 v2 (설정코드 작성용 핵심정보)
%  ① 컨트롤러 입력포트별 최상위 소스(속도지령·전류피드백 위치)
%  ② PMSM 블록 파라미터 변수 바인딩
%  ③ DC 전압원 / 전류센서 / 최상위 블록
%
%  사용:  inspect_model2('ev_pmsm_drive')

function inspect_model2(model)

load_system(model);
ctl = [model '/PMSM controller'];
fprintf('\n======== 상세분석 v2: %s ========\n', model);

% ── [A] 컨트롤러 입력포트 → 최상위 소스 매핑 ──
fprintf('\n[A] "PMSM controller" 입력포트별 연결 소스\n');
try
    ph = get_param(ctl,'PortHandles'); inp = ph.Inport;
    inBlks = find_system(ctl,'SearchDepth',1,'BlockType','Inport');
    pmap = containers.Map('KeyType','double','ValueType','char');
    for i=1:numel(inBlks)
        pmap(str2double(get_param(inBlks{i},'Port'))) = get_param(inBlks{i},'Name');
    end
    for i=1:numel(inp)
        pn = ''; if isKey(pmap,i), pn = pmap(i); end
        lh = get_param(inp(i),'Line'); srcName='(연결없음)'; srcType='';
        if lh ~= -1
            sb = get_param(lh,'SrcBlockHandle');
            if sb ~= -1
                srcName = getfullname(sb);
                srcType = get_param(sb,'BlockType');
            end
        end
        fprintf('   포트%d "%s"  ←  %s  [%s]\n', i, pn, srcName, srcType);
    end
catch e
    fprintf('   (분석 실패: %s)\n', e.message);
end

% ── [B] PMSM 블록 파라미터 (변수 바인딩) ──
fprintf('\n[B] PMSM 블록 파라미터 (MaskName = 값/변수)\n');
try
    pmsm = [model '/PMSM'];
    nm = get_param(pmsm,'MaskNames'); vl = get_param(pmsm,'MaskValues');
    for i=1:numel(nm), fprintf('   %-28s = %s\n', nm{i}, vl{i}); end
catch e
    fprintf('   (실패: %s)\n', e.message);
end

% ── [C] DC 전압원 / 배터리 ──
fprintf('\n[C] DC 전압원 / 배터리 블록\n');
% FollowLinks 없이는 라이브러리 링크 서브시스템 내부(Simscape 컴포넌트 등)를
% 못 들어갈 수 있어 inspect_model.m과 동일하게 켠다.
blks = find_system(model,'LookUnderMasks','all','FollowLinks','on','type','block');
for i=1:numel(blks)
    mt=''; try, mt=get_param(blks{i},'MaskType'); catch, end
    if contains(mt,'DC Voltage','IgnoreCase',true) || contains(mt,'Battery','IgnoreCase',true)
        fprintf('   • %s  [%s]\n', blks{i}, mt);
        try
            nm=get_param(blks{i},'MaskNames'); vl=get_param(blks{i},'MaskValues');
            for j=1:numel(nm), fprintf('        %-20s = %s\n', nm{j}, vl{j}); end
        catch, end
    end
end

% ── [D] 전류 센서 / 측정 ──
fprintf('\n[D] 전류 센서/측정 블록\n');
nfound=0;
for i=1:numel(blks)
    mt=''; try, mt=get_param(blks{i},'MaskType'); catch, end
    nm=get_param(blks{i},'Name');
    if contains(mt,'Current Sensor','IgnoreCase',true) || ...
       (contains(lower(nm),'current') && contains(mt,'Sensor','IgnoreCase',true))
        fprintf('   • %s  [%s]\n', blks{i}, mt); nfound=nfound+1;
    end
end
if nfound==0, fprintf('   (전용 전류센서 미발견 — 전류피드백은 [A] 포트 소스 참고)\n'); end

% ── [E] 최상위(root) 블록 ──
fprintf('\n[E] 최상위(root) 블록 목록\n');
rb = find_system(model,'SearchDepth',1,'type','block');
for i=1:numel(rb)
    bt=get_param(rb{i},'BlockType'); mt=''; try, mt=get_param(rb{i},'MaskType'); catch, end
    fprintf('   • %-38s  [%s%s]\n', get_param(rb{i},'Name'), bt, ...
            ternary(isempty(mt),'',[' / ' mt]));
end

fprintf('\n======== 끝 — [A][B][C] 출력을 공유해 주세요 ========\n\n');
end

function s = ternary(c,a,b), if c, s=a; else, s=b; end, end
