function [llr, thr_hist, state] = gen_llr_dynamic_threshold(rx_branch, alpha, state_in)
%GEN_LLR_DYNAMIC_THRESHOLD  动态门限追踪生成LLR-like软信息（适用于16QAM的I或Q路）
%
% 功能：
%   对输入的一路实值接收序列（I 路或 Q 路）做一阶IIR门限追踪，并输出两路软信息：
%     llr(:,1)：符号位(sign bit)软信息，直接用 rx_branch
%     llr(:,2)：幅度位(mag bit)软信息，threshold - |rx_branch|
%
% 输入：
%   rx_branch : (N x 1) double，接收端 I 或 Q 路抽样值（实数）
%   alpha     : 遗忘因子 [0,1]，越大跟踪越快但抖动更大
%   state_in  : (可选) struct，支持跨帧连续处理
%               state_in.threshold : 上一帧结束时的门限值
%
% 输出：
%   llr       : (N x 2) double，LLR-like 软信息（未做噪声方差归一化）
%   thr_hist  : (N x 1) double，门限追踪历史
%   state     : struct，返回更新后的门限状态，用于下一帧 state_in
%
% 备注：
%   1) 这不是严格意义上的 log-likelihood ratio，只是“可用于软判决”的度量。
%   2) 若已知噪声方差 sigma2，可做尺度归一化： llr = llr / sigma2;

    % -------- 参数检查/整形 --------
    if nargin < 2
        error("gen_llr_dynamic_threshold:MissingInput", "Need rx_branch and alpha.");
    end
    if isempty(rx_branch)
        llr = zeros(0,2);
        thr_hist = zeros(0,1);
        state = struct("threshold", 0);
        return;
    end
    if alpha < 0 || alpha > 1
        error("gen_llr_dynamic_threshold:BadAlpha", "alpha must be in [0,1].");
    end

    rx_branch = double(rx_branch(:));  % 强制列向量
    N = length(rx_branch);

    % -------- 状态初始化/继承 --------
    if nargin >= 3 && isstruct(state_in) && isfield(state_in, "threshold")
        thr = double(state_in.threshold);
    else
        thr = 2/sqrt(10);
    end

    % -------- 输出预分配 --------
    llr = zeros(N, 2);
    thr_hist = zeros(N, 1);

    % -------- 核心：IIR门限 + 软信息 --------
    for k = 1:N
        abs_val = abs(rx_branch(k));

        % 一阶 IIR: thr[n] = (1-a)*thr[n-1] + a*|x[n]|
        thr = (1 - alpha) * thr + alpha * abs_val;
        thr_hist(k) = thr;

        % LLR-like soft bits
        llr(k, 1) = rx_branch(k);       % sign bit soft metric
        llr(k, 2) = thr - abs_val;      % magnitude bit soft metric
    end

    % -------- 返回状态 --------
    state = struct("threshold", thr);
end
