
function rx = channel_model(cfg, tx, EbN0dB, scenario, meta)
% 信道：频偏 + (可选)Rayleigh + (可选)突发干扰 + AWGN

Fs = meta.Fs;
N = numel(tx);
t = (0:N-1)/Fs;

% 频偏
carrier = exp(1j*2*pi*meta.fd*t);
rx = tx(:).' .* carrier;

% 衰落
switch scenario
    case {"rayleigh","burst_jam"}
        % 块衰落（每帧一个系数），可扩展为时变
        h = (randn+1j*randn)/sqrt(2);
        rx = h * rx;
    otherwise
        % awgn / awgn_freqoffset 不额外加衰落
end

% 突发干扰
if scenario == "burst_jam"
    jam_prob = 0.05;
    jam_amp  = 3;
    mask = rand(size(rx)) < jam_prob;
    rx(mask) = rx(mask) + jam_amp*(randn(sum(mask),1)+1j*randn(sum(mask),1)).';
end

% AWGN：把 Eb/N0 换算到 SNR（以平均测量功率方式喂 awgn）
% 这里给出一个“可解释”的估算：SNR ≈ EbN0 + 10log10(k*Rc) - 10log10(Fs_over)
% k=log2(M)，Rc≈1/3（Turbo）。你也可在论文中说明采用 measured-SNR 的仿真方式。
k = (meta.mode=="wide")*4 + (meta.mode=="narrow")*2; % wide 16QAM=4bit/sym, narrow QPSK=2
Rc = 1/3;
snr = EbN0dB + 10*log10(k*Rc) - 10*log10(meta.Fs_over);

rx = awgn(rx, snr, 'measured').';

end
