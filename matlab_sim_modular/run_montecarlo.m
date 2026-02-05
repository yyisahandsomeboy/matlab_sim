
function [BER, PER, THR, SwitchCount] = run_montecarlo(cfg, EbN0dB, Nframes, scenario, mode_sel)

BER = zeros(size(EbN0dB));
PER = zeros(size(EbN0dB));
THR = zeros(size(EbN0dB));
SwitchCount = zeros(size(EbN0dB));

for ei = 1:numel(EbN0dB)
    ebn0 = EbN0dB(ei);

    % 自适应模式初始为 wide
    ctrl_state = init_controller(cfg);

    err_bits = 0; total_bits = 0;
    err_pkts = 0; total_pkts = 0;
    thr_sum = 0;
    swcnt = 0;

    for f = 1:Nframes
        % 选择模式
        if mode_sel == "adaptive"
            cur_mode = ctrl_state.mode;
        else
            cur_mode = mode_sel;
        end

        % 生成并发送一帧
        [tx, meta] = tx_frame(cfg, cur_mode);

        % 按场景补齐信道参数
        meta = make_channel_meta_profile(meta, scenario);

        % 信道
        rx = channel_model(cfg, tx, ebn0, scenario, meta);

        % 接收
        [dec_bits, metrics] = rx_frame(cfg, rx, meta);

        % 统计
        total_bits = total_bits + numel(meta.info_bits);
        err_bits   = err_bits + sum(dec_bits(:) ~= meta.info_bits(:));

        total_pkts = total_pkts + 1;
        pkt_err = any(dec_bits(:) ~= meta.info_bits(:));
        err_pkts = err_pkts + pkt_err;

        % 吞吐率（考虑导频开销与PER）
        thr_sum = thr_sum + metrics.throughput;

        % 自适应控制更新
        if mode_sel == "adaptive"
            prev_mode = ctrl_state.mode;
            ctrl_state = update_controller(cfg, ctrl_state, metrics);
            if ctrl_state.mode ~= prev_mode
                swcnt = swcnt + 1;
            end
        end
    end

    BER(ei) = err_bits / total_bits;
    PER(ei) = err_pkts / total_pkts;
    THR(ei) = thr_sum / Nframes;
    SwitchCount(ei) = swcnt;

    fprintf("EbN0=%g dB: BER=%.3e, PER=%.3e, THR=%.3e, SW=%d\n", ebn0, BER(ei), PER(ei), THR(ei), swcnt);
end

end
