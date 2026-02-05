function llr_mother = turbo_rate_recover(llr_rx, Rc, N_mother)
%TURBO_RATE_RECOVER Turbo码率恢复（与 turbo_rate_match 对偶）
% 输入:
%   llr_rx   : 接收软比特（对应发送码率）
%   Rc       : 发送码率（1/3或1/2）
%   N_mother : 母码长度（用于还原到1/3码率输入）
%
% 输出:
%   llr_mother : 可直接送入 lteTurboDecode 的母码LLR

llr = llr_rx(:);

assert(abs(Rc-1/3) < 1e-12 || abs(Rc-1/2) < 1e-12, ...
    'Only Rc=1/3 or Rc=1/2 is supported');

if abs(Rc-1/3) < 1e-12
    llr_mother = llr;
    if nargin >= 3 && ~isempty(N_mother) && numel(llr_mother) ~= N_mother
        llr_mother = llr_mother(1:min(end, N_mother));
    end
    return;
end

% Rc = 1/2 对偶恢复
assert(nargin >= 3 && ~isempty(N_mother), 'N_mother is required for Rc=1/2');
assert(N_mother >= 12, 'Invalid N_mother');

K = (N_mother - 12) / 3;
assert(abs(K - round(K)) < 1e-12, 'Invalid N_mother for LTE turbo framing');
K = round(K);
N_tx_expect = 2*K + 12;
assert(numel(llr) >= N_tx_expect, 'LLR length shorter than expected for Rc=1/2');
llr = llr(1:N_tx_expect);

sys_llr = llr(1:K);
par_llr = llr(K+1:2*K);
tail_llr = llr(2*K+1:end);

tri = zeros(K,3);
tri(:,1) = sys_llr;
odd_idx = 1:2:K;
even_idx = 2:2:K;
tri(odd_idx,2) = par_llr(odd_idx); % p1 被保留
tri(even_idx,3) = par_llr(even_idx); % p2 被保留
% 未发送的校验位以0LLR填充（擦除）

llr_mother = [reshape(tri.', [], 1); tail_llr];
end
