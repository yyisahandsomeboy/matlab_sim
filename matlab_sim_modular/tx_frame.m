
function [tx_os, meta] = tx_frame(cfg, mode_name)
% 输出：过采样后的复基带帧 tx_os
% meta：记录信息比特、模式、导频参数等，供接收端与统计使用

mode = cfg.mode.(mode_name);

% ---- 参数派生 ----
datarate = cfg.datarate;
Fs_over  = cfg.Fs_over;
symbolrate = datarate/2*3;          % 沿用你原脚本的符号速率定义
Fs = 4*datarate;                   % 采样频率（与原脚本一致）
pilot_distance = mode.pilot_distance;

% ---- 同步字 ----
sync_word = gen_syncword(cfg);      % 符号级同步字
sync_os   = repelem(sync_word, Fs_over);

% ---- 数据 ----
info_bits = randi([0 1], cfg.payload_bits, 1);
coded = lteTurboEncode(info_bits');    % 输出行向量
coded = double(coded(:));              % 列向量

% ---- 调制 ----
if mode.mod == "QPSK"
    sym = mod_qpsk(coded);
elseif mode.mod == "16QAM"
    sym = mod_16qam_gray(coded);
else
    error("Unsupported modulation");
end
% ---- 插入导频 ----
[payload, pilot_num, ndata_zero] = insert_pilots(sym, cfg.pilot_word, pilot_distance);
% ---- 拼帧 ----
frame = [sync_word; payload(:)];   % 符号级（无过采样）
% ---- 过采样（简单重复，保持与你现有代码一致） ----
tx_os = repelem(frame, Fs_over);

% ---- meta ----
meta = struct();
meta.mode = mode_name;
meta.Fs = Fs;
meta.Fs_over = Fs_over;
meta.symbolrate = symbolrate;
meta.pilot_distance = pilot_distance;
meta.pilot_num = pilot_num;
meta.ndata_zero = ndata_zero;
meta.info_bits = info_bits;
meta.fd = mode.fd;
end
