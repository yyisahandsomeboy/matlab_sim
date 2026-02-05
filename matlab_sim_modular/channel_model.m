function [rx, truth] = channel_model(cfg, tx, EbN0dB, scenario, meta)
%CHANNEL_MODEL 论文级、可复现、可扩展的单载波复基带信道模型
%
% 函数签名：
%   [rx, truth] = channel_model(cfg, tx, EbN0dB, scenario, meta)
%
% 设计要点：
% 1) tx 输入可行/列，输出 rx 始终为列向量 N x 1。
% 2) 显式参数检查：meta 至少包含 Fs/Fs_over/M/Rc/fd。
% 3) 每个 scenario 独立分支，便于扩展。
% 4) 信道效应顺序：衰落/卷积/干扰/CFO/相噪 -> 最后加 AWGN。
% 5) 默认采用 Es/N0 标定；可选 measured_snr（不使用 awgn 函数）。
%
% -------------------------------------------------------------------------
% Demo（注释示例）
% -------------------------------------------------------------------------
% % 共用设置
% meta = struct();
% meta.Fs = 55e6;
% meta.Fs_over = 4;
% meta.M = 16;
% meta.Rc = 1/3;
% meta.fd = 1030;
% meta.norm_tx = true;
%
% % 1) AWGN + CFO
% [rx1, truth1] = channel_model([], tx, 8, 'awgn_cfo', meta);
%
% % 2) Rayleigh 平坦衰落（块衰落）
% meta.fade_mode = 'block';
% [rx2, truth2] = channel_model([], tx, 8, 'rayleigh_flat', meta);
%
% % 3) Rayleigh TDL（多径）
% % 注意：延迟单位是“样点”，Fs 越高（宽带Rs高时通常Fs也高），
% % 同样的样点延迟对应更短绝对时延，但相对符号周期仍可能造成更强ISI/频率选择性。
% % Rs 低（窄带）时，符号周期长，相同物理时延对应的样点延迟通常更小，链路更接近平坦衰落。
% meta.taps_delay_samples = [0 2 5 9];
% meta.taps_gain_dB = [0 -3 -8 -12];
% [rx3, truth3] = channel_model([], tx, 8, 'rayleigh_tdl', meta);
%
% % 4) Burst Jam（突发噪声干扰）
% meta.jam_prob = 0.05;
% meta.burst_len_range = [64 512];
% meta.jam_amp = 2.5;
% meta.jam_type = 'noise';
% [rx4, truth4] = channel_model([], tx, 8, 'burst_jam', meta);
%

% ----------------------- 参数检查 -----------------------
assert(nargin >= 5, 'channel_model requires cfg, tx, EbN0dB, scenario, meta'); %#ok<NASGU>
assert(isvector(tx) && ~isempty(tx), 'tx must be a non-empty vector');
assert(ischar(scenario) || isstring(scenario), 'scenario must be char/string');
required_fields = {'Fs','Fs_over','M','Rc','fd'};
for k = 1:numel(required_fields)
    assert(isfield(meta, required_fields{k}), 'meta.%s is required', required_fields{k});
end
assert(meta.M >= 2, 'meta.M must be >=2');
assert(meta.Rc > 0 && meta.Rc <= 1, 'meta.Rc must be in (0,1]');
assert(meta.Fs > 0, 'meta.Fs must be positive');

% 统一列向量，确保输出规范
x = tx(:);
N = numel(x);
Fs = meta.Fs;

% ----------------------- 可选参数默认值 -----------------------
if ~isfield(meta, 'fd_residual'), meta.fd_residual = 0; end
if ~isfield(meta, 'enable_phase_noise'), meta.enable_phase_noise = false; end
if ~isfield(meta, 'phase_noise_sigma'), meta.phase_noise_sigma = 0; end
if ~isfield(meta, 'norm_tx'), meta.norm_tx = false; end
if ~isfield(meta, 'noise_mode'), meta.noise_mode = 'esn0'; end

% ----------------------- 发射信号归一化（可选） -----------------------
scale = 1;
if meta.norm_tx
    pwr = mean(abs(x).^2);
    assert(pwr > 0, 'Input tx has zero average power, cannot normalize');
    scale = sqrt(pwr); % x_norm = x / scale
    x = x ./ scale;
end

% ----------------------- 逐场景信道主干 -----------------------
sc = lower(string(scenario));
y = x;
truth_h = 1;
burst_mask = false(N,1);

switch sc
    case 'awgn'
        % 纯 AWGN，不加 CFO/衰落/干扰

    case {'awgn_cfo','awgn_freqoffset'}
        % 仅 CFO + 可选相噪（再加 AWGN）

    case {'rayleigh_flat','rayleigh'}
        % 平坦 Rayleigh：支持块衰落与慢变衰落
        if ~isfield(meta, 'fade_mode')
            meta.fade_mode = 'block';
        end
        fm = lower(string(meta.fade_mode));
        switch fm
            case 'block'
                h = (randn + 1j*randn) / sqrt(2);
                y = h .* y;
                truth_h = h;

            case 'slow'
                % 一阶 AR 慢变近似
                if ~isfield(meta, 'fade_rho'), meta.fade_rho = 0.995; end
                rho = meta.fade_rho;
                assert(rho >= 0 && rho < 1, 'meta.fade_rho must be in [0,1)');
                w = (randn(N,1) + 1j*randn(N,1)) / sqrt(2);
                h = zeros(N,1);
                h(1) = w(1);
                a = sqrt(1 - rho^2);
                for n = 2:N
                    h(n) = rho*h(n-1) + a*w(n);
                end
                y = h .* y;
                truth_h = h;

            otherwise
                error('Unsupported meta.fade_mode for rayleigh_flat: %s', meta.fade_mode);
        end

    case 'rician_flat'
        % 平坦 Rician：K 因子（dB）
        assert(isfield(meta,'K_dB'), 'meta.K_dB required for rician_flat');
        K = 10^(meta.K_dB/10);
        h_los = sqrt(K/(K+1));
        h_nlos = sqrt(1/(K+1)) * (randn + 1j*randn)/sqrt(2);
        h = h_los + h_nlos;
        y = h .* y;
        truth_h = h;

    case 'rayleigh_tdl'
        % 多径 Rayleigh TDL（延迟单位：样点）
        assert(isfield(meta,'taps_delay_samples'), 'meta.taps_delay_samples required');
        assert(isfield(meta,'taps_gain_dB'), 'meta.taps_gain_dB required');

        dly = meta.taps_delay_samples(:);
        gdB = meta.taps_gain_dB(:);
        assert(numel(dly)==numel(gdB), 'taps_delay_samples and taps_gain_dB size mismatch');
        assert(all(dly>=0) && all(mod(dly,1)==0), 'taps_delay_samples must be non-negative integers');

        Lh = max(dly) + 1;
        h = zeros(Lh,1);
        p_lin = 10.^(gdB/10);
        p_lin = p_lin / sum(p_lin); % 归一化总功率

        for k = 1:numel(dly)
            tap = sqrt(p_lin(k)) * (randn + 1j*randn)/sqrt(2);
            h(dly(k)+1) = h(dly(k)+1) + tap;
        end

        y = conv(y, h, 'same');
        truth_h = h;

    case 'impulsive'
        % 点状脉冲：随机时刻叠加强干扰
        assert(isfield(meta,'imp_prob') && isfield(meta,'imp_amp'), ...
            'meta.imp_prob/meta.imp_amp required for impulsive');
        assert(meta.imp_prob >= 0 && meta.imp_prob <= 1, 'meta.imp_prob must be in [0,1]');

        imp_mask = rand(N,1) < meta.imp_prob;
        imp = (randn(N,1) + 1j*randn(N,1))/sqrt(2);
        y(imp_mask) = y(imp_mask) + meta.imp_amp * imp(imp_mask);

    case 'burst_jam'
        % 突发段干扰：noise/tone
        jf = {'jam_prob','burst_len_range','jam_amp','jam_type'};
        for k = 1:numel(jf)
            assert(isfield(meta, jf{k}), 'meta.%s required for burst_jam', jf{k});
        end

        assert(meta.jam_prob>=0 && meta.jam_prob<=1, 'meta.jam_prob must be in [0,1]');
        len_range = meta.burst_len_range;
        assert(numel(len_range)==2 && all(len_range>=1), 'meta.burst_len_range must be [min max], >=1');
        Lmin = round(min(len_range));
        Lmax = round(max(len_range));

        n = 1;
        while n <= N
            if rand < meta.jam_prob
                Lb = randi([Lmin Lmax],1,1);
                idx2 = min(N, n + Lb - 1);
                idx = n:idx2;
                burst_mask(idx) = true;

                jt = lower(string(meta.jam_type));
                if jt == "noise"
                    j = (randn(numel(idx),1) + 1j*randn(numel(idx),1))/sqrt(2);
                    y(idx) = y(idx) + meta.jam_amp * j;
                elseif jt == "tone"
                    assert(isfield(meta,'jam_tone_freq'), 'meta.jam_tone_freq required for tone jammer');
                    tloc = (idx(:)-1)/Fs;
                    tone = exp(1j*2*pi*meta.jam_tone_freq*tloc);
                    y(idx) = y(idx) + meta.jam_amp * tone;
                else
                    error('Unsupported meta.jam_type: %s', meta.jam_type);
                end
                n = idx2 + 1;
            else
                n = n + 1;
            end
        end

    otherwise
        error('Unsupported scenario: %s', scenario);
end

% ----------------------- CFO + 可选相噪 -----------------------
fd_used = meta.fd + meta.fd_residual;
t = (0:N-1).' / Fs;
cfo_rot = exp(1j*2*pi*fd_used*t);
phase_noise_used = false(N,1);

if meta.enable_phase_noise
    dphi = meta.phase_noise_sigma * randn(N,1);
    phi = cumsum(dphi);               % Wiener 相位噪声
    pn_rot = exp(1j*phi);
    y = y .* cfo_rot .* pn_rot;
    phase_noise_used = phi;
else
    y = y .* cfo_rot;
end

% ----------------------- 最后一步：AWGN -----------------------
switch lower(string(meta.noise_mode))
    case 'esn0'
        Es = mean(abs(x).^2); % 若 norm_tx=true，此时 Es≈1
        EsN0dB = EbN0dB + 10*log10(log2(meta.M)*meta.Rc);
        sigma2 = Es / (2 * 10^(EsN0dB/10)); % 每维方差
        w = sqrt(sigma2) * (randn(N,1) + 1j*randn(N,1));
        rx = y + w;

    case 'measured_snr'
        assert(isfield(meta,'SNRdB'), 'meta.SNRdB required when noise_mode=measured_snr');
        sigp = mean(abs(y).^2);
        snr_lin = 10^(meta.SNRdB/10);
        sigma2 = sigp / (2*snr_lin);
        w = sqrt(sigma2) * (randn(N,1) + 1j*randn(N,1));
        rx = y + w;

    otherwise
        error('Unsupported meta.noise_mode: %s', meta.noise_mode);
end

% ----------------------- truth 输出 -----------------------
truth = struct();
truth.h = truth_h;
truth.sigma2 = sigma2;
truth.burst_mask = burst_mask;
truth.scale = scale;
truth.fd_used = fd_used;
truth.phase_noise_used = phase_noise_used;

% 输出强制列向量
rx = rx(:);
end
