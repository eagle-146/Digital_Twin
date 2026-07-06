%% dowell_ratio.m ─ Dowell AC/DC 저항비 (표피 + 근접효과)
%  Dowell(1966) 해석식. 직사각형 도체(헤어핀에 적합)의 1D AC저항비.
%      Rac/Rdc = Δ·[ (sinh2Δ+sin2Δ)/(cosh2Δ−cos2Δ)              ← 표피효과
%                    + (2/3)(m²−1)·(sinhΔ−sinΔ)/(coshΔ+cosΔ) ]   ← 근접효과
%  Δ = h/δ (도체높이/표피깊이),  m = 슬롯당 도체 층수.
%  Δ→0(저주파) → 1,  m·Δ 커질수록 급증(근접효과 ∝ m²).
%
%  입력 Δ는 스칼라/벡터 모두 가능. m은 스칼라.

function r = dowell_ratio(Delta, m)

Delta = max(Delta, 0);
r = ones(size(Delta));
big = Delta >= 1e-4;                 % 저주파 극한(Δ~0)에서 0/0 회피
d = Delta(big);

skin = (sinh(2*d) + sin(2*d)) ./ (cosh(2*d) - cos(2*d));
prox = (sinh(d)   - sin(d))   ./ (cosh(d)   + cos(d));
r(big) = d .* ( skin + (2/3)*(m.^2 - 1).*prox );

% 저주파측 미소항 전개 (연속성): Rac/Rdc ≈ 1 + (m²-1)/9·Δ⁴
small = ~big;
r(small) = 1 + (m.^2 - 1)/9 .* Delta(small).^4;
end
