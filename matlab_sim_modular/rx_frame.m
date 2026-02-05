
function [dec_bits, metrics] = rx_frame(cfg, rx, meta)
% 接收端：抽样->剥离同步头->导频估计/两级滤波->相位补偿->软解调->Turbo译码

Fs_over = meta.Fs_over;

% ---- 过采样抽样（与原脚本一致：均值抽取） ----
r = reshape(rx, Fs_over, []);
r_hat = mean(r, 1);
r_hat = r_hat(:).';

% ---- 剥离同步头 ----
% 同步头长度：sync_word (符号级)长度 = length(gen_syncword(cfg))
sync_word = gen_syncword(cfg);
Ls = numel(sync_word);
payload = r_hat(Ls+1:end);
% ---- 提取导频 ----
Dp = meta.pilot_distance;
pilot_extract = payload(1:Dp:end);
% ---- 两级滤波重构信道（复用你脚本的 fir7/fir8） ----
hd1 = fir7(meta.symbolrate, Dp);
delay1 = ceil((numel(hd1)+1)/2);
tmp1 = conv(hd1, pilot_extract);
pilot_1 = tmp1(delay1:delay1+numel(pilot_extract)-1);
% 补零插入到符号速率网格
zero_data = zeros(Dp-1, meta.pilot_num);
pinjie = [pilot_1(:).'; zero_data];
pinjie = reshape(pinjie, 1, []);
pinjie = pinjie(1:((meta.pilot_num-1)*Dp+1));
% 二级滤波去镜像
hd2 = fir8(meta.symbolrate);
delay2 = ceil((numel(hd2)+1)/2);
tmp2 = conv(hd2, pinjie);
hhat = tmp2(delay2:delay2+numel(pinjie)-1);  % 信道估计（包含相位）
% ---- 相位补偿 ----
phi = angle(hhat);
phi = phi(1:numel(payload));   % 对齐长度
comp = payload(:).' .* exp(-1j*phi);

% 残余相位（示例：补 π/4，可由导频估计得到）
comp = comp * exp(1j*(pi/4));
% ---- 去导频并去掉补零 ----
comp1 = comp(1:((meta.pilot_num-1)*Dp));          % 去掉最后一个导频后可能的多余
mat = reshape(comp1, Dp, []);
data_only = reshape(mat(2:end,:), 1, []);
data_only = data_only(1:end-meta.ndata_zero);
% ---- 软解调（与原脚本一致：实/虚部作为 LLR） ----
llr = [];
if meta.mode == "narrow"   % QPSK：2bit/sym
    llr = reshape([real(data_only); imag(data_only)], 1, []);
else
    % 16QAM 的严格 LLR 需要噪声方差；这里给出简化版本（论文中需说明近似）
    % 为确保仿真可信，建议你后续把这里替换为 qamdemod(...,'OutputType','llr',...)
    I = real(data_only);
    Q = imag(data_only);
    i_llr = gen_llr_dynamic_threshold(I,0);  % 你的解映射（你自己实现）
    q_llr = gen_llr_dynamic_threshold(Q,0);  % 你的解映射（你自己实现）
    b1=i_llr(:,1);
    b2=i_llr(:,2);
    b3=q_llr(:,1);
    b4=q_llr(:,2);
    llr = reshape([b1, b2, b3, b4].', [], 1);
end

dec = lteTurboDecode(llr);
dec_bits = double(dec(:));

% ---- 指标估计 ----
% SNR估计（粗略）：用导频误差估算噪声
p = cfg.pilot_word;
pilot_est = comp(1:Dp:end);         % 补偿后的导频
e = pilot_est - p;
snr_est = 10*log10(mean(abs(p)^2) / var(e));

% 吞吐率（bit/s）：符号速率 * bits/sym * Rc * (1-导频开销) * (1-PER)
k = (meta.mode=="wide")*4 + (meta.mode=="narrow")*2;
Rc = 1/3;
Op = 1/Dp;  % comb pilot开销
PER = any(dec_bits ~= meta.info_bits);
throughput = meta.symbolrate * k * Rc * (1-Op) * (1-PER);

metrics = struct();
metrics.snr_est = snr_est;
metrics.per = PER;
metrics.throughput = throughput;

end
