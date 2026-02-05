function [tx_os, meta] = tx_frame(cfg, mode_sel)
%TX_FRAME 生成一帧发射信号
% mode_sel 支持：
% - 字符串/字符："wide"|"narrow"
% - 数值：MCS索引 0..4

mcs_id = resolve_mcs_id(mode_sel);
entry = cfg.mcs_table(mcs_id+1);

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
coded_all = lteTurboEncode(info_bits');
coded_all = double(coded_all(:));

% 注：LTE Turbo编码默认约1/3码率。
% 为兼容固定MCS表中的Rc=1/2档，这里采用简化截断近似实现等效码率。
% 若需论文级严谨，请替换为标准速率匹配/打孔方案。
Ncoded_tgt = max(8, floor(numel(info_bits) / entry.Rc));
Ncoded_tgt = min(Ncoded_tgt, numel(coded_all));
coded = coded_all(1:Ncoded_tgt);

% ---- 调制 ----
if entry.M == 4
    sym = mod_qpsk(coded);
elseif entry.M == 16
    sym = mod_16qam_gray(coded);
else
    error('Unsupported M in mcs table: %g', entry.M);
end

% ---- 插入导频 ----
[payload, pilot_num, ndata_zero] = insert_pilots(sym, cfg.pilot_word, pilot_distance);

% ---- 拼帧 ----
frame = [sync_word; payload(:)];   % 符号级（无过采样）

% ---- 过采样（简单重复，保持与你现有代码一致） ----
tx_os = repelem(frame, Fs_over);

% ---- meta ----
meta = struct();
meta.mode = char(entry.name);
meta.mcs = mcs_id;
meta.Fs = Fs;
meta.Fs_over = Fs_over;
meta.symbolrate = symbolrate;
meta.pilot_distance = pilot_distance;
meta.pilot_density = pilot_density;
meta.pilot_num = pilot_num;
meta.ndata_zero = ndata_zero;
meta.info_bits = info_bits;
if mode.mod == "QPSK"
    meta.M = 4;
elseif mode.mod == "16QAM"
    meta.M = 16;
end
meta.Rc = 1/3;
meta.fd = mode.fd;
end
