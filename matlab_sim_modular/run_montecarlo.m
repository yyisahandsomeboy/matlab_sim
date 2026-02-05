function [BER, PER, THR, SwitchCount] = run_montecarlo(cfg, EbN0dB, Nframes, scenario, mode_sel)

BER = zeros(size(EbN0dB));
PER = zeros(size(EbN0dB));
THR = zeros(size(EbN0dB));
SwitchCount = zeros(size(EbN0dB));

for ei = 1:numel(EbN0dB)
    ebn0 = EbN0dB(ei);

    % 自适应模式初始MCS0（连通性优先）
    ctrl_state = init_mcs_controller(cfg);
    per_hist = [];

    err_bits = 0; total_bits = 0;
    err_pkts = 0; total_pkts = 0;
    thr_sum = 0;
    swcnt = 0;

    for f = 1:Nframes
        % 选择MCS
        if strcmpi(char(mode_sel), 'adaptive')
            cur_sel = ctrl_state.mcs;
        elseif strcmpi(char(mode_sel), 'narrow')
            cur_sel = 0;
        elseif strcmpi(char(mode_sel), 'wide')
            cur_sel = 4;
        else
            cur_sel = mode_sel;
        end

        % 生成并发送一帧
        [tx, meta] = tx_frame(cfg, cur_sel);

        % 按场景补齐信道参数
        meta = make_channel_meta_profile(meta, scenario);

        % 按场景补齐信道参数
        meta = make_channel_meta_profile(meta, scenario);

        % 信道
        rx = channel_model(cfg, tx, ebn0, scenario, meta);

        % 接收
        [dec_bits, metrics] = rx_frame(cfg, rx, meta);

        % 本帧PER
        pkt_err = any(dec_bits(:) ~= meta.info_bits(:));
        per_hist = [per_hist, pkt_err]; %#ok<AGROW>
        if numel(per_hist) > cfg.ctrl.per_window
            per_hist = per_hist(end-cfg.ctrl.per_window+1:end);
        end

        % 统计
        total_bits = total_bits + numel(meta.info_bits);
        err_bits   = err_bits + sum(dec_bits(:) ~= meta.info_bits(:));

        total_pkts = total_pkts + 1;
        err_pkts = err_pkts + pkt_err;
        thr_sum = thr_sum + metrics.throughput;

        % 自适应控制更新（SNR + PER滑窗）
        if strcmpi(char(mode_sel), 'adaptive')
            prev_mcs = ctrl_state.mcs;
            ctrl_metrics = struct();
            ctrl_metrics.snr_est = metrics.snr_est;
            ctrl_metrics.per = mean(per_hist);
            ctrl_metrics.sync_fail = 0;
            ctrl_metrics.eq_fail = 0;

            [ctrl_state, ~] = update_mcs_controller(cfg, ctrl_state, ctrl_metrics);
            if ctrl_state.mcs ~= prev_mcs
                swcnt = swcnt + 1;
            end
        end
    end

    BER(ei) = err_bits / total_bits;
    PER(ei) = err_pkts / total_pkts;
    THR(ei) = thr_sum / Nframes;
    SwitchCount(ei) = swcnt;

    fprintf('EbN0=%g dB: BER=%.3e, PER=%.3e, THR=%.3e, SW=%d\n', ...
        ebn0, BER(ei), PER(ei), THR(ei), swcnt);
end

end
