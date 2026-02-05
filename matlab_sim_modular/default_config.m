function cfg = default_config()
%DEFAULT_CONFIG 系统默认配置（多档MCS + SNR/PER自适应控制）
% 说明：
% 1) 窄带定义：MCS0；宽带定义：MCS4。
% 2) 自适应模式在 MCS0..MCS4 之间切换。
% 3) eta 为帧效率估计：同时考虑导频、同步头等固定开销。

cfg = struct();

% ---- 基本参数 ----
cfg.Fs_over = 4;                 % 每符号采样点数（SPS）
cfg.pilot_word = (1+1j);
cfg.sync_len = 128;
cfg.ca_len = 503;
cfg.payload_bits = 1920;

% ---- MCS表（固定5档）----
% 字段：name, M, Rs, Rc, pilot_distance, fd, eta
mcs = repmat(struct('name','', 'M',0, 'Rs',0, 'Rc',0, ...
    'pilot_distance',0, 'fd',0, 'eta',0), 5, 1);

mcs(1) = make_mcs_entry("MCS0", 4, 1e3,    1/3, 2, 30,   cfg);
mcs(2) = make_mcs_entry("MCS1", 4, 200e3,  1/3, 4, 120,  cfg);
mcs(3) = make_mcs_entry("MCS2", 4, 3200e3, 1/2, 32, 400,  cfg);
mcs(4) = make_mcs_entry("MCS3", 4, 13.5e6, 1/2, 32, 900,  cfg);
mcs(5) = make_mcs_entry("MCS4", 16,13.5e6, 1/2, 32, 1030, cfg);

cfg.mcs_table = mcs;

% 为旧代码保留映射（narrow/wide）
cfg.mode.narrow = mcs(1);
cfg.mode.wide = mcs(5);

% ---- 自适应控制参数（初始可用值，建议离线标定）----
ctrl = struct();
ctrl.per_window = 10;            % PER滑窗长度（帧）
ctrl.fail_K = 2;                 % 连续sync/eq失败触发紧急降级门限
ctrl.ema_snr_alpha = 0.2;
ctrl.ema_per_alpha = 0.2;
ctrl.per_tgt = 0.1;
ctrl.emerg_per = 0.35;
ctrl.N_up = 3;                   % 升级需要连续满足帧数
ctrl.N_dn = 2;                   % 降级需要连续触发帧数
ctrl.lock_len_emerg = 5;         % 紧急降级后升级锁定帧数
ctrl.lock_len_switch = 2;        % 常规切换后的锁定帧数
ctrl.goodput_hyst = 0.08;        % 升级吞吐增益门限
ctrl.use_goodput_gate = true;

% 每个MCS的门限（长度=5）
% 注意：以下为初始化值，需通过离线 sweep 做标定。
ctrl.gamma_dn = [0, 4, 8, 12, 16];
ctrl.gamma_up = [1.5, 6, 10, 14, 18];
ctrl.per_max  = [0.35, 0.30, 0.25, 0.20, 0.15];
cfg.ctrl = ctrl;

end

function m = make_mcs_entry(name, M, Rs, Rc, pilot_distance, fd, cfg)
% eta估计：
% - pilot_distance 越小，导频越密，eta越低，但跟踪更稳。
% - eta这里包含导频+同步头固定开销，供控制器goodput门控。
k = log2(M);
Ns_data = cfg.payload_bits / max(k*Rc, eps);    % 估计有效编码符号数
pilot_overhead = 1 / pilot_distance;            % comb导频开销
Ns_with_pilot = Ns_data / max(1 - pilot_overhead, eps);
Nsync = 2*cfg.sync_len;
eta = Ns_data / (Ns_with_pilot + Nsync);

m = struct();
m.name = char(name);
m.M = M;
m.Rs = Rs;
m.Rc = Rc;
m.pilot_distance = pilot_distance;
m.fd = fd;
m.eta = eta;
end
