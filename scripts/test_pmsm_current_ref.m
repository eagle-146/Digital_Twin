%% test_pmsm_current_ref.m ─ dq 전류지령(MTPA+약자속) 회귀테스트
%  물리 검증: (1) 산출 (id,iq)가 요구 토크를 정확히 생성, (2) 약자속 영역에서
%  전압이 한계 이내(≈Vmax), (3) 저속·중부하는 MTPA / 고속·경부하는 FW 판정.

function test_pmsm_current_ref()

p  = params();
pp = p.mot.pole_pairs; Ld = p.mot.Ld; Lq = p.mot.Lq; lam = p.mot.lambda_pm;
torque = @(c) 1.5*pp*(lam*c.iq + (Ld-Lq)*c.id*c.iq);

% (1) 저속·중부하 → MTPA, 전압 여유, 토크 일치
c1 = pmsm_current_ref(100, 2000, p);
assert(abs(torque(c1) - 100) < 1e-3, '토크 불일치(MTPA): %.4f', torque(c1));
assert(strcmp(c1.region,'MTPA'), '저속 중부하인데 MTPA 아님: %s', c1.region);
assert(c1.Vs <= c1.Vmax*(1+1e-6), '저속에서 전압한계 초과');
assert(c1.feasible, '저속 중부하가 비가능으로 나옴');

% (2) 고속·경부하 → FW, 토크 일치, 전압 ≈ Vmax
c2 = pmsm_current_ref(20, 11000, p);
assert(abs(torque(c2) - 20) < 1e-3, '토크 불일치(FW): %.4f', torque(c2));
assert(strcmp(c2.region,'FW'), '고속 경부하인데 FW 아님: %s', c2.region);
assert(c2.Vs <= c2.Vmax*(1+1e-4), 'FW인데 전압한계 초과: %.2f>%.2f', c2.Vs, c2.Vmax);
assert(c2.Vs >= c2.Vmax*(1-1e-3), 'FW인데 전압한계에 미도달(전압여유 남음)');
assert(c2.id < 0, 'FW인데 id가 음수가 아님: %.2f', c2.id);

% (3) 무부하 고속도 약자속 필요(역기전력 억제) — 토크≈0, id<0
c3 = pmsm_current_ref(0, 11000, p);
assert(abs(c3.iq) < 1e-6, '무부하인데 iq≠0');
assert(c3.id < 0 && strcmp(c3.region,'FW'), '무부하 고속인데 약자속 아님');

fprintf('test_pmsm_current_ref 통과 (MTPA/FW 판정·토크·전압한계 OK)\n');
end
