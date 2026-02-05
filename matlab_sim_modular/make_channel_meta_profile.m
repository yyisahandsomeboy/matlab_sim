function meta = make_channel_meta_profile(meta, scenario)
%MAKE_CHANNEL_META_PROFILE 为不同信道场景填充/覆盖 meta 参数
% 说明：
% - 该函数在每帧调用，便于按场景统一配置 channel_model 所需参数。
% - 若调用前 meta 已含同名字段，将优先保留已有值（仅缺失时补默认）。

sc = lower(string(scenario));

% 通用默认
if ~isfield(meta, 'norm_tx'), meta.norm_tx = true; end
if ~isfield(meta, 'noise_mode'), meta.noise_mode = 'esn0'; end
if ~isfield(meta, 'fd_residual'), meta.fd_residual = 0; end
if ~isfield(meta, 'enable_phase_noise'), meta.enable_phase_noise = false; end
if ~isfield(meta, 'phase_noise_sigma'), meta.phase_noise_sigma = 0; end

switch sc
    case 'awgn'
        % 纯 AWGN：可选关闭 CFO（默认 fd 保持 tx_frame 的模式值）

    case {'awgn_cfo','awgn_freqoffset'}
        % 默认使用 tx_frame 中 meta.fd

    case {'rayleigh_flat','rayleigh'}
        if ~isfield(meta, 'fade_mode'), meta.fade_mode = 'block'; end
        if ~isfield(meta, 'fade_rho'), meta.fade_rho = 0.995; end

    case 'rician_flat'
        if ~isfield(meta, 'K_dB'), meta.K_dB = 6; end

    case 'rayleigh_tdl'
        % 关键：延迟以“样点”为单位，随 Fs 变化。
        % 这里给一个和带宽相关的默认模板：
        % - 宽带（高 Rs / 高 Fs）给更长抽头延迟，体现更明显频率选择性与ISI。
        % - 窄带（低 Rs / 低 Fs）给更短抽头延迟，更接近平坦衰落。
        if ~isfield(meta, 'taps_delay_samples')
            if meta.symbolrate >= 1e6
                meta.taps_delay_samples = [0 2 5 9];
                meta.taps_gain_dB = [0 -3 -8 -12];
            else
                meta.taps_delay_samples = [0 1];
                meta.taps_gain_dB = [0 -6];
            end
        elseif ~isfield(meta, 'taps_gain_dB')
            error('When taps_delay_samples is set, taps_gain_dB must also be set.');
        end

    case 'impulsive'
        if ~isfield(meta, 'imp_prob'), meta.imp_prob = 0.01; end
        if ~isfield(meta, 'imp_amp'),  meta.imp_amp = 5; end

    case 'burst_jam'
        if ~isfield(meta, 'jam_prob'), meta.jam_prob = 0.03; end
        if ~isfield(meta, 'burst_len_range'), meta.burst_len_range = [64 256]; end
        if ~isfield(meta, 'jam_amp'), meta.jam_amp = 3; end
        if ~isfield(meta, 'jam_type'), meta.jam_type = 'noise'; end
        if string(meta.jam_type) == "tone" && ~isfield(meta, 'jam_tone_freq')
            meta.jam_tone_freq = 1e3;
        end

    otherwise
        error('Unsupported scenario profile: %s', scenario);
end
end
