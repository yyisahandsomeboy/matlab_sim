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
end

function mcs_id = resolve_mcs_id(mode_sel)
if isnumeric(mode_sel)
    mcs_id = round(mode_sel);
elseif isstring(mode_sel) || ischar(mode_sel)
    s = lower(string(mode_sel));
    if s == "narrow"
        mcs_id = 0;
    elseif s == "wide"
        mcs_id = 4;
    elseif startsWith(s, "mcs")
        mcs_id = str2double(extractAfter(s, 3));
    else
        error('Unsupported mode string: %s', string(mode_sel));
    end
else
    error('Unsupported mode_sel type');
end

if isnan(mcs_id) || mcs_id < 0 || mcs_id > 4
    error('MCS id must be in [0,4]');
end
end
