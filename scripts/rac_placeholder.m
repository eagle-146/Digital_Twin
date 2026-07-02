%% rac_placeholder.m ─ Rac(f,T) 임시 모델 (FEA 맵 확보 전 파이프라인 검증용)
%  ANSYS(Motor-CAD/Maxwell)에서 실제 Rac(f,T) 맵을 얻기 전까지, 물리적으로
%  타당한 경향의 근사식을 제공한다. 헤어핀 도체의 표피효과 상승을 단순 모사.
%      Rac(f,T) = Rdc(T) * [ 1 + k * (f/f_ref)^2 ]      (근접효과 저주파 근사)
%  ※ 실제 헤어핀은 근접효과가 지배적이고 도체·슬롯 형상에 강하게 의존하므로,
%    이 식은 "형태 확인용"일 뿐 정량 신뢰용이 아니다. FEA 맵으로 반드시 교체.
%
%  사용:
%    RacFun = @(f,T) rac_placeholder(f, T, Rdc20, T_ref, alpha_cu, k, f_ref);
%    또는 기본값:  RacFun = rac_placeholder();   % 함수핸들 반환
%
%  Rdc20    : DC 상저항 @기준온도 [Ohm]
%  T        : 구리온도 [℃]
%  T_ref    : Rdc 기준온도 [℃]
%  alpha_cu : 구리 온도계수 [1/℃]
%  k, f_ref : 표피/근접 상승 계수 및 기준주파수 [Hz]

function out = rac_placeholder(f, T, Rdc20, T_ref, alpha_cu, k, f_ref)

if nargin == 0
    % 인자 없이 호출 → 대표 기본값으로 함수핸들 반환
    Rdc20d = 12e-3;   % 12 mOhm (헤어핀 상저항 대략치, 설계 확정 시 교체)
    T_refd = 20; alphad = 3.93e-3;
    kd = 0.6; f_refd = 1000;   % 1kHz에서 Rac/Rdc ~1.6 수준(예시)
    out = @(ff,TT) rac_placeholder(ff, TT, Rdc20d, T_refd, alphad, kd, f_refd);
    return
end

Rdc_T = Rdc20 .* (1 + alpha_cu .* (T - T_ref));   % 온도 보정 DC 저항
skin  = 1 + k .* (f./f_ref).^2;                   % 주파수 상승 (근사)
out   = Rdc_T .* skin;

end
