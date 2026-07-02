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
    for c = 1:size(i_phase,2)
        [Pc, ic] = ac_copper_loss(i_phase(:,c), t, RacFun, T_cu, ...
            'nPhase',1,'fMax',opt.fMax,'ampThresh',opt.ampThresh);
        P_ac = P_ac + Pc; harmAll = [harmAll; ic.harmonics]; %#ok<AGROW>
    end
    info.harmonics = harmAll; info.note = 'multi-phase summed';
    return
end

i_phase = i_phase(:);
N  = numel(i_phase);
dt = mean(diff(t));
Fs = 1/dt;

% ── FFT → 단측 진폭 스펙트럼 ──
Y  = fft(i_phase);
f  = (0:N-1)'*(Fs/N);
half = 1:floor(N/2)+1;
f  = f(half);
amp = abs(Y(half))/N;
amp(2:end-1) = 2*amp(2:end-1);        % 단측 보정 (DC·Nyquist 제외)

if isempty(opt.fMax), opt.fMax = Fs/2; end
keep = f <= opt.fMax;
f = f(keep); amp = amp(keep);

% ── 각 성분: RMS = 진폭/√2 (DC는 그대로) ──
Irms = amp/sqrt(2);
Irms(f==0) = amp(f==0);

% 유효 고조파만 (기본파 대비 임계 이상)
[~, i0] = max(amp(f>0));            % 기본파 인덱스(양의 주파수 중 최대)
posIdx = find(f>0);
fund_amp = amp(posIdx(i0));
sig = amp >= opt.ampThresh*fund_amp;
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
% 기본파 = 최소 양주파수 성분
f_fund = min(fs(fs>0));
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
