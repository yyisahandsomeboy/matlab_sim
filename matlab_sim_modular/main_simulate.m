
clear; clc; close all;

cfg = default_config();

% 三种模式：wide-only / narrow-only / adaptive
modes = ["wide","narrow","adaptive"];

EbN0dB = 0:0.1:10;
Nframes = 10;   % 可按算力调整
scenario = "awgn_cfo"; % "awgn"|"awgn_cfo"|"rayleigh_flat"|"rician_flat"|"rayleigh_tdl"|"impulsive"|"burst_jam"

results = struct();
for mi = 1:numel(modes)
    mode = modes(mi);
    fprintf("=== Simulating mode: %s ===\n", mode);

    [ber, per, thr, swcnt] = run_montecarlo(cfg, EbN0dB, Nframes, scenario, mode);
    results.(mode).EbN0dB = EbN0dB;
    results.(mode).BER = ber;
    results.(mode).PER = per;
    results.(mode).THR = thr;
    results.(mode).SwitchCount = swcnt;
end

figure; semilogy(EbN0dB, results.wide.BER, '-o'); hold on;
semilogy(EbN0dB, results.narrow.BER, '-s');
semilogy(EbN0dB, results.adaptive.BER, '-^');
grid on; xlabel("Eb/N0 (dB)"); ylabel("BER");
legend("wide-only","narrow-only","adaptive");

figure; plot(EbN0dB, results.wide.THR, '-o'); hold on;
plot(EbN0dB, results.narrow.THR, '-s');
plot(EbN0dB, results.adaptive.THR, '-^');
grid on; xlabel("Eb/N0 (dB)"); ylabel("Throughput (bit/s)");
legend("wide-only","narrow-only","adaptive");
