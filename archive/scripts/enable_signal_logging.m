%% enable_signal_logging.m ─ 신호선에 로깅을 스크립트로 켜기 (GUI 불필요)
%  Simulink 신호선의 DataLogging 계열 파라미터는 set_param()으로는
%  "line에 이름이 'DataLogging'인 파라미터가 없음" 에러가 나는 경우가 있다
%  (실측: 기본 Simulink만으로도 재현됨, 버전 한정 API 제약으로 보임).
%  반면 MATLAB 공용 set()/get()으로는 정상 동작한다. 이 함수는 그 방법을
%  감싸서, 매번 GUI에서 신호선 우클릭 > 신호 기록을 누르지 않아도 되게 한다.
%
%  사용:
%    lineH = enable_signal_logging('model/Block', 1, 'i_abc');   % Outport 1번 신호선
%    enable_signal_logging(lineHandle, [], 'i_abc');             % 이미 얻은 라인 핸들
%
%  입력:
%    blockOrLine : 'model/Block' 경로문자열(해당 블록의 Outport에서 로깅 설정) 또는
%                  이미 구한 신호선(line) 핸들
%    outportIdx  : blockOrLine이 블록 경로일 때 사용할 Outport 번호 (기본 1)
%    sigName     : 로깅 신호명 (get_phase_current 등에서 찾을 이름)
%  출력:
%    lineH       : 로깅을 켠 신호선 핸들

function lineH = enable_signal_logging(blockOrLine, outportIdx, sigName)

if nargin < 2 || isempty(outportIdx), outportIdx = 1; end
if nargin < 3, sigName = ''; end

if ischar(blockOrLine) || isstring(blockOrLine)
    ph = get_param(char(blockOrLine), 'PortHandles');
    if numel(ph.Outport) < outportIdx
        error('enable_signal_logging:noPort', ...
            '%s 에 Outport %d 번이 없습니다 (Outport 개수=%d).', ...
            blockOrLine, outportIdx, numel(ph.Outport));
    end
    lineH = get_param(ph.Outport(outportIdx), 'Line');
    if lineH == -1
        error('enable_signal_logging:noLine', ...
            '%s 의 Outport %d 번이 아직 다른 블록에 연결되지 않았습니다.', ...
            blockOrLine, outportIdx);
    end
else
    lineH = blockOrLine;   % 이미 라인 핸들이 주어진 경우
end

set(lineH, 'DataLogging', true);
if ~isempty(sigName)
    set(lineH, 'DataLoggingNameMode', 'Custom');
    set(lineH, 'DataLoggingName', sigName);
end

end
