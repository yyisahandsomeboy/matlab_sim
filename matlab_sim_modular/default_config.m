function cfg = default_config()
% 默认配置：
% 窄带：QPSK + 1 kSym/s + 30 Hz 频偏
% 宽带：16QAM + 13.75 MSym/s + 1030 Hz 频偏
% 导频密度可灵活配置（pilot_density 或 pilot_distance 二选一，优先 pilot_density）

cfg = struct();

% ---- 基本采样 ----
cfg.Fs_over  = 4;            % 过采样率（每符号采样点）
        

% ---- 同步/导频 ----
cfg.pilot_word = (1+1j);     % 导频符号
cfg.sync_len   = 128;        % 同步字长度(基础)
cfg.ca_len     = 503;        % CA码长度

% ---- 载荷 ----
cfg.payload_bits = 1920;     % 信息比特数

% ---- 模式参数 ----
cfg.mode.wide.mod  = "16QAM";
cfg.mode.wide.symbolrate = 13.75e6; % 宽带符号速率：13.75 MHz
cfg.mode.wide.pilot_density = 1/32; % 导频密度（可改）
cfg.mode.wide.fd       = 1030;      % 宽带频偏：1030 Hz

cfg.mode.narrow.mod  = "QPSK";
cfg.mode.narrow.symbolrate = 1e3;   % 窄带符号速率：1 kSym/s
cfg.mode.narrow.pilot_density = 1/2;% 导频密度（可改）
cfg.mode.narrow.fd       = 30;      % 窄带频偏：30 Hz
% ---- 自适应切换参数 ----
cfg.ctrl.gamma_dn = 6;   % SNR降级阈值(dB): wide->narrow
cfg.ctrl.gamma_up = 10;  % SNR升级阈值(dB): narrow->wide (迟滞)
cfg.ctrl.N_hold   = 3;   % 连续满足条件的帧数
cfg.ctrl.emerg_per = 0.2; % 紧急降级 PER 阈值
cfg.ctrl.fd       = 1030;%宽带时不需要补偿频偏

m = struct();
m.name = char(name);
m.M = M;
m.Rs = Rs;
m.Rc = Rc;
m.pilot_distance = pilot_distance;
m.fd = fd;
m.eta = eta;
end
