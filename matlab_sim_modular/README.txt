# MATLAB 单载波复基带仿真说明（多档 MCS 自适应控制）

本工程已升级为：**基于 SNR + PER 的 5 档 MCS 自适应切换控制器**，目标是“优先保证连通性，在满足误包率约束下平稳切换、避免抖动”。

---

## 1. 依赖与入口

### 1.1 依赖
- LTE Toolbox：`lteTurboEncode` / `lteTurboDecode`
- 本目录内函数：`cacode_503.m`, `fir7.m`, `fir8.m`

### 1.2 运行入口
```matlab
cd matlab_sim_modular
main_simulate
```

---

## 2. MCS 固定档位定义（0..4）

由 `default_config.m` 中 `cfg.mcs_table` 定义：

- MCS0: QPSK, Rs=1e3,    Rc=1/3, pilot_distance=2
- MCS1: QPSK, Rs=200e3,  Rc=1/3, pilot_distance=4
- MCS2: QPSK, Rs=3200e3, Rc=1/2, pilot_distance=32
- MCS3: QPSK, Rs=13.5e6, Rc=1/2, pilot_distance=32
- MCS4: 16QAM,Rs=13.5e6, Rc=1/2, pilot_distance=32

定义：
- **窄带** = MCS0
- **宽带** = MCS4
- **自适应模式** = 在 MCS0..MCS4 之间切换

---

## 3. 自适应控制器设计

核心函数：
```matlab
[st, dbg] = update_mcs_controller(cfg, st, metrics)
```

### 3.1 状态 `st`
- `st.mcs`：当前 MCS（0..4）
- `st.snr_f`, `st.per_f`：EMA 平滑后的 SNR/PER
- `st.up_cnt`, `st.dn_cnt`：升级/降级确认计数
- `st.lock`：冷却计数（`lock>0` 禁止升级）
- `st.reason`：最近切换原因

### 3.2 输入 `metrics`
每帧更新一次，包含：
- `metrics.snr_est`：当前帧 SNR 估计
- `metrics.per`：当前滑窗 PER（推荐最近 W 帧）
- `metrics.sync_fail`：同步失败标志（可选）
- `metrics.eq_fail`：均衡失败标志（可选）

### 3.3 策略
A) **紧急降级（连通性优先）**
- 若 `per_f > emerg_per` 或连续 `sync_fail/eq_fail >= K`，立即降级（严重失锁直接 MCS0）。

B) **正常选择（可行集合 + goodput 最大化）**
- 可行条件：`snr_f >= gamma_dn(i)` 且 `per_f <= per_max(i)`。
- 计算：
  `raw_rate_i = Rs_i * log2(M_i) * Rc_i * eta_i`
  `goodput_i  = raw_rate_i * (1 - per_f)`
- 取可行集中 goodput 最大的候选 MCS。

C) **平稳切换（防抖）**
- 升级：需 `lock==0` 且更严格门限（`gamma_up`），并连续 `N_up` 帧确认。
- 降级：连续 `N_dn` 帧确认（比升级更快）。
- 切换后设置 `lock_len_switch`，防止立刻反向切回。

---

## 4. 关键配置参数（`cfg.ctrl`）

在 `default_config.m`：
- `ema_snr_alpha`, `ema_per_alpha`
- `per_tgt`, `emerg_per`
- `N_up`, `N_dn`
- `lock_len_emerg`, `lock_len_switch`
- `goodput_hyst`, `use_goodput_gate`
- `gamma_up[1x5]`, `gamma_dn[1x5]`, `per_max[1x5]`
- `per_window`, `fail_K`

> 注意：`gamma_up/gamma_dn/per_max` 目前是初始值，建议通过离线 sweep 标定。

---

## 5. 信道场景使用（`scenario`）

在 `main_simulate.m` 中配置：
```matlab
scenario = "awgn_cfo";
```

支持：
- `awgn`
- `awgn_cfo`（兼容 `awgn_freqoffset`）
- `rayleigh_flat`
- `rician_flat`
- `rayleigh_tdl`
- `impulsive`
- `burst_jam`

每帧会自动调用：
```matlab
meta = make_channel_meta_profile(meta, scenario);
rx = channel_model(cfg, tx, ebn0, scenario, meta);
```

---

## 6. 导频与 eta（帧效率）

- `pilot_distance` 越小，导频越密，估计/跟踪更稳，但开销更大、`eta` 更低。
- 本工程在 `cfg.mcs_table` 中预置 `eta`，用于控制器 goodput 评估。
- `eta` 是结合导频密度与同步头固定开销的估计值。

---

## 7. 重要工程注意事项（已在代码处理）

1) **PER 滑窗混合污染**：
   控制器为每个 MCS 维护独立历史 `per_hist_by_mcs`，切换后使用新 MCS 窗口。

2) **门限离线标定**：
   `gamma_up/gamma_dn/per_max` 仅为起始建议，需按链路目标做 sweep。

3) **计数按帧统一**：
   `N_up/N_dn/lock` 均为“帧”为单位，避免不同 Rs 下逻辑失真。

4) **字符串兼容性**：
   模式判断统一使用 `strcmpi/string`，避免 `==` 造成兼容问题。

---

## 8. 文件分工

- `default_config.m`：MCS 表 + 控制参数
- `init_mcs_controller.m`：控制器状态初始化
- `update_mcs_controller.m`：多档 MCS 切换策略核心
- `run_montecarlo.m`：仿真主循环 + 控制器调用
- `tx_frame.m`：按 MCS 组帧（支持 0..4 / narrow / wide）
- `resolve_mcs_id.m`：模式到 MCS 索引解析（独立函数，便于复用）
- `rx_frame.m`：接收与性能统计（按 `meta.M/meta.Rc` 计算吞吐）
- `channel_model.m`：多场景信道实现
- `make_channel_meta_profile.m`：场景参数模板

