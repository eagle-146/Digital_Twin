%% test_compare_winding_variants.m ─ 설계변주 비교 회귀테스트
%  물리 방향성 검증: 도체를 얇게/층수를 줄이면 AC 동손이 감소해야 한다.

function test_compare_winding_variants()

v = struct('name',{'기준','얇게','층↓'}, ...
           'cond_h',{2.5e-3, 1.5e-3, 2.5e-3}, ...
           'n_layers',{6, 6, 3});
T = compare_winding_variants(v, 100, false);   % 플롯 off

% 얇은 도체 → AC손 감소
assert(T.Pac_total_W(2) < T.Pac_total_W(1), '도체를 얇게 했는데 AC손이 안 줄어듦');
% 층수 감소 → AC손 감소 (근접효과 ∝ m²)
assert(T.Pac_total_W(3) < T.Pac_total_W(1), '층수를 줄였는데 AC손이 안 줄어듦');
% 저감률: 기준 0%, 나머지 양수
assert(abs(T.reduction_pct(1)) < 1e-9, '기준 저감률이 0이 아님');
assert(all(T.reduction_pct(2:3) > 0), '저감률이 양수가 아님');

fprintf('test_compare_winding_variants 통과 (얇게·층↓ → AC손 감소 OK)\n');
end
