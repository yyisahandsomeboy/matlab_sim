function [coded_tx, rm] = turbo_rate_match(coded_mother, Rc)
%TURBO_RATE_MATCH 标准化Turbo码率匹配（打孔）
% 输入:
%   coded_mother : LTE Turbo母码输出（约1/3码率）
%   Rc           : 目标码率（当前支持1/3与1/2）
% 输出:
%   coded_tx     : 发送比特序列
%   rm           : 速率匹配信息（供接收端恢复）
%
% 说明：
% - Rc=1/3: 不打孔，直接发送母码。
% - Rc=1/2: 对系统位+校验位采用标准交织后的周期打孔：
%   保留全部系统位，校验位按 parity1/parity2 交替保留。
% - 尾比特（12比特）全部保留，保证译码终止约束。

c = coded_mother(:);
N = numel(c);

assert(N >= 12, 'Turbo mother code length too short');
assert(abs(Rc-1/3) < 1e-12 || abs(Rc-1/2) < 1e-12, ...
    'Only Rc=1/3 or Rc=1/2 is supported');

rm = struct();
rm.N_mother = N;
rm.Rc = Rc;
rm.mode = 'none';

if abs(Rc-1/3) < 1e-12
    coded_tx = c;
    rm.N_tx = numel(coded_tx);
    return;
end

% Rc = 1/2
rm.mode = 'puncture_sys_altparity';
K = (N - 12) / 3;
assert(abs(K - round(K)) < 1e-12, 'Mother code length is inconsistent with LTE turbo framing');
K = round(K);

main = c(1:3*K);
tail = c(3*K+1:end);  % 12比特
tri = reshape(main, 3, K).'; % [sys p1 p2]

sys = tri(:,1);
p1 = tri(:,2);
p2 = tri(:,3);

keep_parity = zeros(K,1);
odd_idx = 1:2:K;
even_idx = 2:2:K;
keep_parity(odd_idx) = p1(odd_idx);
keep_parity(even_idx) = p2(even_idx);

coded_tx = [sys; keep_parity; tail];
rm.K = K;
rm.N_tx = numel(coded_tx);
end
