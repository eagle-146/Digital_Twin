%% ac_copper_loss.m ─ 상전류 스펙트럼 기반 AC 동손 계산 (프로젝트 코어)
%  스위칭 시뮬에서 얻은 상전류 시계열을 FFT로 분해하고, 각 고조파에
%  주파수·온도 의존 AC 저항 Rac(f,T)를 곱해 합산한다.
%      P_ACcu = n_phase * Σ_h  Rac(f_h, T) · I_h,rms^2
%  기본파 AC손(표피·근접)과 PWM 고조파손을 동시에 잡는다. 툴박스 무관(fft는 기본 MATLAB).
%
%  입력:
%    i_phase : 상전류 시계열 [A]. 벡터(1상) 또는 [N x m] (m상). 균형 3상이면 1상만 줘도 됨.
%    t       : 균일 시간벡터 [s] (i_phase와 길이 일치)
%    RacFun  : 함수핸들 Rac = RacFun(f_Hz, T_cu)  → 상당 AC저항 [Ohm] (rac_placeholder 또는 FEA맵)
%    T_cu    : 구리온도 [℃]
%  옵션 (name-value):
%    'nPhase'   : 상수 (기본 3). 1상 입력 시 이 값으로 전체 손실 스케일
%    'fMax'     : 고려할 최대 주파수 [Hz] (기본 Nyquist)
%    'ampThresh': 무시할 고조파 진폭 임계 (기본파 대비 비율, 기본 1e-4)
%
%  출력:
%    P_ac    : 총 AC 동손 [W] (전체 상 합)
%    info    : 세부 (표.harmonics: f, Irms, Rac, P / DC분 / Rac_Rdc비 / 기본파분 / 고조파분)

function [P_ac, info] = ac_copper_loss(i_phase, t, RacFun, T_cu, varargin)

ip = inputParser;
ip.addParameter('nPhase', 3, @(x)isscalar(x)&&x>0);
ip.addParameter('fMax', [], @(x)isempty(x)||isscalar(x));
ip.addParameter('ampThresh', 1e-4, @isscalar);
ip.parse(varargin{:});
opt = ip.Results;

% ── 1상 대표 처리: 여러 상이면 상별 계산 후 합 ──
i_phase = squeeze(i_phase);
if ~isvector(i_phase)
    % [N x m] 다상: 각 상 개별 처리 후 합, nPhase는 1로 (이미 실제 상수만큼 열이 있음)
    P_ac = 0; harmAll = [];
    acc = struct('P_dc_W',0,'P_fund_W',0,'P_harm_W',0);
    for c = 1:size(i_phase,2)
        [Pc, ic] = ac_copper_loss(i_phase(:,c), t, RacFun, T_cu, ...
            'nPhase',1,'fMax',opt.fMax,'ampThresh',opt.ampThresh);
        P_ac = P_ac + Pc; harmAll = [harmAll; ic.harmonics]; %#ok<AGROW>
        acc.P_dc_W   = acc.P_dc_W   + ic.P_dc_W;
        acc.P_fund_W = acc.P_fund_W + ic.P_fund_W;
        acc.P_harm_W = acc.P_harm_W + ic.P_harm_W;
        lastInfo = ic;   % 마지막 상의 스칼라 지표(Rac/Rdc 등)는 상 공통이므로 대표로 사용
    end
    info = lastInfo;               % Rac_Rdc_fund, f_fund, Rdc 등 상 공통 지표 승계
    info.harmonics = harmAll;
    info.P_total_W = P_ac;
    info.P_dc_W    = acc.P_dc_W;
    info.P_fund_W  = acc.P_fund_W;
    info.P_harm_W  = acc.P_harm_W;
    info.note      = 'multi-phase summed';
    return
end

i_phase = i_phase(:);
t = t(:);

if numel(t) < 4 || numel(t) ~= numel(i_phase)
    error('ac_copper_loss:badInput', ...
        'i_phase/t 샘플 수가 너무 적거나(<4) 서로 길이가 다릅니다 (t: %d, i_phase: %d).', ...
        numel(t), numel(i_phase));
end

% 가변스텝 솔버는 zero-crossing 등 이벤트 경계에서 같은 시각이 중복 기록될
% 수 있다 — interp1은 엄격히 단조증가하는 t를 요구하므로 중복시각은 마지막
% 값을 남기고 정리한다.
[t, uidx] = unique(t, 'last');
i_phase = i_phase(uidx);
if numel(t) < 4
    error('ac_copper_loss:badInput', '중복시각 제거 후 샘플이 4개 미만입니다.');
end

% ── 균일 시간격자로 재보간 (가변스텝 솔버 대응) ──
%  Simulink 가변스텝 솔버(VariableStepAuto 등)로 로깅된 신호는 샘플 간격이
%  불균일하다. FFT는 균일 샘플링을 전제하므로, 재보간 없이 그대로 fft()에
%  넣으면 스펙트럼이 왜곡되어(특히 고조파 쪽으로 에너지가 잘못 몰려) 완전히
%  틀린 결과가 나온다. 요청한 fMax(기본 Nyquist)를 넉넉히 만족하도록
%  균일 dt를 정하고 선형보간한다.
dt_orig = median(diff(t));
if isempty(opt.fMax)
    dt = dt_orig;
else
    dt = min(dt_orig, 1/(4*opt.fMax));
end
t_u = (t(1):dt:t(end))';
i_phase = interp1(t, i_phase, t_u, 'linear');
t = t_u;
N  = numel(i_phase);
Fs = 1/dt;

% ── FFT → 단측 진폭 스펙트럼 (Hann 윈도우로 스펙트럼 누설 억제) ──
%  윈도우 없이(사각창) FFT하면 신호 길이가 정수 주기에 정확히 맞아떨어지지
%  않는 한 각 톤의 에너지가 주변 빈으로 넓게 번져(spectral leakage), 실제로는
%  존재하지 않는 수많은 미세 "고조파"가 잡힌다. Hann 윈도우를 곱해 누설을
%  크게 줄이고, 진폭보정계수(ACF=1/mean(w))로 감쇠분을 보정한다.
w   = 0.5*(1 - cos(2*pi*(0:N-1)'/N));   % Hann(주기형), Signal Processing Toolbox 없이 직접 계산
acf = 1/mean(w);
Y   = fft(i_phase .* w);
f  = (0:N-1)'*(Fs/N);
half = 1:floor(N/2)+1;
f  = f(half);
amp = abs(Y(half))/N * acf;
amp(2:end-1) = 2*amp(2:end-1);        % 단측 보정 (DC·Nyquist 제외)

if isempty(opt.fMax), opt.fMax = Fs/2; end
keep = f <= opt.fMax;
f = f(keep); amp = amp(keep);

% ── 각 성분: RMS = 진폭/√2 (DC는 그대로) ──
Irms = amp/sqrt(2);
Irms(f==0) = amp(f==0);

% 유효 고조파만: 국소 최댓값(local maxima)만 채택.
%  Hann 윈도우는 각 톤의 진폭을 중심 빈에서 정확히 복원하도록 ACF로
%  보정되어 있는데, 그 바로 옆(좌우 1~2빈)에도 같은 톤의 에너지가 소량
%  새어나간다(윈도우 자체의 스펙트럼 모양 때문 — DC조차 예외 아님). 그 누설
%  빈까지 "별도 고조파"로 합산하면 이미 ACF로 복원된 톤의 에너지를
%  이중으로 세게 된다. 국소최댓값만 남기면 실제 톤 하나당 정확히 한 빈만
%  채택되어 이중계산을 피한다.
isPeak = false(size(amp));
if numel(amp) > 2
    isPeak(2:end-1) = amp(2:end-1) > amp(1:end-2) & amp(2:end-1) > amp(3:end);
end
isPeak(1) = true;                              % DC는 항상 자기 자신이 대표
if numel(amp) > 1
    isPeak(end) = amp(end) > amp(end-1);        % Nyquist 경계
end

posPeakIdx = find(f>0 & isPeak);
if isempty(posPeakIdx)
    posPeakIdx = find(f>0);                     % 극단적으로 짧은 신호 등 예외 폴백
end
[~, i0] = max(amp(posPeakIdx));
fund_amp = amp(posPeakIdx(i0));
sig = isPeak & (amp >= opt.ampThresh*fund_amp);
sig(f==0) = true;                    % DC 항상 포함

fs   = f(sig);
Irms = Irms(sig);

% ── 각 성분 손실: Rac(f,T)·Irms^2 ──
Rac = arrayfun(@(ff) RacFun(ff, T_cu), fs);
Pk  = Rac .* Irms.^2;

P_ac = opt.nPhase * sum(Pk);

% ── 세부 정보 ──
harm = table(fs, Irms, Rac, opt.nPhase*Pk, 'VariableNames', ...
             {'f_Hz','Irms_A','Rac_Ohm','P_W'});
harm = sortrows(harm,'f_Hz');

Rdc = RacFun(0, T_cu); if Rdc==0, Rdc = RacFun(1e-3,T_cu); end
% 기본파 = 진폭이 가장 큰 양주파수 피크 (위에서 구한 i0/posPeakIdx 재사용 —
%  "가장 낮은 유효 주파수"로 잘못 고르면 미세한 저주파 성분을 기본파로
%  오인해 P_fund가 거의 0으로 나오는 버그가 있었음). sig가 이미 국소최댓값만
%  담고 있으므로 정확히 그 빈 하나만 기본파로 매칭하면 된다(이웃 누설빈은
%  애초에 sig에서 제외됨).
f_fund = f(posPeakIdx(i0));
mask_fund = (fs==f_fund);
mask_dc   = (fs==0);
mask_harm = ~mask_fund & ~mask_dc & (fs>0);

info.harmonics = harm;
info.P_total_W = P_ac;
info.P_dc_W    = opt.nPhase*sum(Pk(mask_dc));
info.P_fund_W  = opt.nPhase*sum(Pk(mask_fund));
info.P_harm_W  = opt.nPhase*sum(Pk(mask_harm));
info.f_fund_Hz = f_fund;
info.Rdc_Ohm   = Rdc;
info.Rac_fund_Ohm = RacFun(f_fund, T_cu);
info.Rac_Rdc_fund = info.Rac_fund_Ohm / Rdc;
info.T_cu_C    = T_cu;

end
