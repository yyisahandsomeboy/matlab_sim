
function [tx_os, meta] = tx_frame(cfg, mode_name)
% 输出：过采样后的复基带帧 tx_os
% meta：记录信息比特、模式、导频参数等，供接收端与统计使用

mode = cfg.mode.(mode_name);

% ---- 参数派生 ----
Fs_over  = cfg.Fs_over;
symbolrate = mode.symbolrate;
Fs = Fs_over * symbolrate;

% 导频密度灵活配置：优先 pilot_density（例如 1/32），
% 也支持直接给 pilot_distance（例如 32）
if isfield(mode, "pilot_density")
    pilot_density = mode.pilot_density;
    if pilot_density <= 0 || pilot_density > 1
        error("pilot_density must be in (0,1]");
    end
    pilot_distance = max(2, round(1/pilot_density));
elseif isfield(mode, "pilot_distance")
    pilot_distance = mode.pilot_distance;
    pilot_density = 1 / pilot_distance;
else
    error("Mode config must provide pilot_density or pilot_distance");
end

% ---- 同步字 ----
sync_word = gen_syncword(cfg);      % 符号级同步字

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
meta.pilot_density = pilot_density;
meta.pilot_num = pilot_num;
meta.ndata_zero = ndata_zero;
meta.info_bits = info_bits;
meta.fd = mode.fd;
end
