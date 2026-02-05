
function cfg = default_config()
% 默认配置：窄带以你现有参数为基准；宽带在此基础上调整导频密度/调制阶数等。

cfg = struct();

% ---- 基本速率/采样 ----
cfg.wo = 13.75e6;      % info bit rate (示例值)
cfg.Fs_over  = 4;            % 过采样率
        

% ---- 同步/导频 ----
cfg.pilot_word = (1+1j);     % 导频符号
cfg.sync_len   = 128;        % 同步字长度(基础)
cfg.ca_len     = 503;        % CA码长度

% ---- 载荷 ----
cfg.payload_bits = 1920;     % 信息比特数

% ---- 模式参数 ----
cfg.mode.wide.mod  = "16QAM";  % 宽带：更高阶调制（可改 QPSK/16QAM）
cfg.mode.wide.pilot_distance = 32;
cfg.mode.wide.fd       = 1030;%宽带时不需要补偿频偏

cfg.mode.narrow.mod  = "QPSK"; % 窄带：QPSK
cfg.mode.narrow.pilot_distance = 2;
cfg.mode.narrow.fd       = 30;%窄带时需要补偿频偏1khz
% ---- 自适应切换参数 ----
cfg.ctrl.gamma_dn = 6;   % SNR降级阈值(dB): wide->narrow
cfg.ctrl.gamma_up = 10;  % SNR升级阈值(dB): narrow->wide (迟滞)
cfg.ctrl.N_hold   = 3;   % 连续满足条件的帧数
cfg.ctrl.emerg_per = 0.2; % 紧急降级 PER 阈值
cfg.ctrl.fd       = 1030;%宽带时不需要补偿频偏

end
