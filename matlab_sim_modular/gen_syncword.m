
function sync_word = gen_syncword(cfg)
% 生成 CA 码同步字（复用你脚本的逻辑）

ca = cacode_503(5);
sync_word_128 = ca(1:cfg.sync_len);
sync_mod = 2*sync_word_128 - 1;   % BPSK

ss0 = ca(101:356);
SS0 = 2*ss0 - 1;

sync_ss_pre = reshape(repmat(sync_mod, 2, 1), 1, 2*numel(sync_mod));
sync_ss = sync_ss_pre .* SS0;     % 扩频
sync_word = [sync_ss sync_ss].';  % 复制形成帧头（与你原脚本一致）

end
