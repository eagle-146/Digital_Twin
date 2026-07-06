%% test_rac_dowell.m ─ Dowell AC저항비 검증 (신뢰성 재점검)
%  손계산 가능한 기준값·극한·단조성으로 물리 정확성을 확인한다.

function test_rac_dowell()

% (1) 알려진 값: Δ=1, 단일층(m=1) → 표피효과만 → Rac/Rdc ≈ 1.0857
r11 = dowell_ratio(1, 1);
assert(abs(r11 - 1.0857) < 2e-3, 'Dowell(Δ=1,m=1)=%.4f, 기대 1.0857', r11);

% (2) 알려진 값: Δ=1, 4층 → 근접효과 포함 → Rac/Rdc ≈ 2.6875
r14 = dowell_ratio(1, 4);
assert(abs(r14 - 2.6875) < 2e-3, 'Dowell(Δ=1,m=4)=%.4f, 기대 2.6875', r14);

% (3) 저주파 극한: Δ→0 → 1
assert(abs(dowell_ratio(0, 6) - 1) < 1e-9, 'Δ=0 극한이 1 아님');
assert(abs(dowell_ratio(1e-6, 6) - 1) < 1e-6, 'Δ~0 근방 연속성 실패');

% (4) 단조 증가: 주파수(Δ)↑ → 저항비↑
assert(dowell_ratio(2,6) > dowell_ratio(1,6), 'Δ에 대해 단조증가 아님');
% 층수↑ → 저항비↑ (근접효과)
assert(dowell_ratio(1,8) > dowell_ratio(1,4), '층수에 대해 단조증가 아님');

% (5) rac_dowell: DC(f=0)=Rdc(T), 온도↑ → Rdc↑
Rac = rac_dowell();
p = params();
Rdc100 = Rac(0, 100);
Rdc20  = Rac(0, 20);
assert(abs(Rdc20 - p.mot.Rdc_20) < 1e-12, 'f=0,20℃ 에서 Rdc_20과 불일치');
assert(Rdc100 > Rdc20, '온도↑인데 Rdc 증가 안함');
% 운전점 주파수에서 Rac/Rdc > 1 (AC효과 존재)
assert(Rac(675,100)/Rdc100 > 1.5, '675Hz에서 AC효과가 비현실적으로 작음');

fprintf('test_rac_dowell 통과 (기준값·극한·단조성·온도의존 OK)\n');
end
