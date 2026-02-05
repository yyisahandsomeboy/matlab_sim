function [tx_os, meta] = tx_frame(cfg, mode_sel)
%TX_FRAME 生成一帧发射信号
% mode_sel 支持：
% - 字符串/字符："wide"|"narrow"
% - 数值：MCS索引 0..4

mcs_id = resolve_mcs_id(mode_sel);
entry = cfg.mcs_table(mcs_id+1);

% ---- 参数派生 ----
Fs_over  = cfg.Fs_over;
symbolrate = entry.Rs;
Fs = Fs_over * symbolrate;
pilot_distance = entry.pilot_distance;
pilot_density = 1 / pilot_distance;

% ---- 同步字 ----
sync_word = gen_syncword(cfg);

% ---- 数据 ----
info_bits = randi([0 1], cfg.payload_bits, 1);
coded_mother = lteTurboEncode(info_bits');
coded_mother = double(coded_mother(:));

% 论文级严谨：使用标准化速率匹配/打孔
[coded, rm] = turbo_rate_match(coded_mother, entry.Rc);

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

% ---- 拼帧与过采样 ----
frame = [sync_word; payload(:)];
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
meta.M = entry.M;
meta.Rc = entry.Rc;
meta.fd = entry.fd;
meta.eta = entry.eta;
meta.turbo_rm = rm;
meta.turbo_N_mother = rm.N_mother;
meta.turbo_N_tx = rm.N_tx;
end
