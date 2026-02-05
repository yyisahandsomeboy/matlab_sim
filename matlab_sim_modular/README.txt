# 宽/窄带融合自适应通信系统 MATLAB 仿真说明

本目录提供“宽/窄带融合自适应通信系统”的模块化仿真框架。

- 目标：在不同信道场景下比较 `wide-only` / `narrow-only` / `adaptive` 三种策略的 BER、PER、吞吐率、切换次数。
- 算法主链路：同步字 + 梳状导频 + 两级滤波 + 相位补偿 + Turbo 译码。

---

## 1. 依赖与入口

### 1.1 依赖
1) LTE Toolbox（`lteTurboEncode` / `lteTurboDecode`）
2) 你已有函数：`cacode_503.m`、`fir7.m`、`fir8.m`

### 1.2 运行入口
在 MATLAB 当前目录切到 `matlab_sim_modular/` 后运行：

```matlab
main_simulate
```

---

## 2. 当前默认体制参数（已按你的定义）

在 `default_config.m` 中：

- 窄带：`QPSK + 1 kSym/s + 30 Hz CFO`
- 宽带：`16QAM + 13.75 MSym/s + 1030 Hz CFO`
- 导频密度：按模式独立配置，支持
  - `pilot_density`（推荐，例如 `1/32`）
  - `pilot_distance`（兼容旧配置）

---

## 3. 如何切换“不同信道场景”仿真

### 3.1 在哪里改场景
`main_simulate.m` 里这一行控制信道类型：

```matlab
scenario = "awgn_freqoffset";
```

可改成：

- `"awgn"`
- `"awgn_cfo"`（兼容 `"awgn_freqoffset"`）
- `"rayleigh_flat"`（兼容 `"rayleigh"`）
- `"rician_flat"`
- `"rayleigh_tdl"`
- `"impulsive"`
- `"burst_jam"`

### 3.2 场景参数怎么传入
当前工程在 `run_montecarlo.m` 中每帧调用：

```matlab
meta = make_channel_meta_profile(meta, scenario);
rx = channel_model(cfg, tx, ebn0, scenario, meta);
```

也就是说：
- `tx_frame` 先给出基础 `meta`（`Fs/Fs_over/M/Rc/fd/...`）。
- `make_channel_meta_profile` 按 `scenario` 自动补充缺省参数。
- `channel_model` 使用这些参数生成对应信道。

---

## 4. 每种信道的含义与参数

下表是 `channel_model.m` 支持的场景与关键 `meta` 字段。

### 4.1 `awgn`
- 含义：纯 AWGN
- 关键参数：
  - `M`、`Rc`（用于 Eb/N0 -> Es/N0 噪声标定）
  - `noise_mode='esn0'`（默认）或 `'measured_snr'`

### 4.2 `awgn_cfo` / `awgn_freqoffset`
- 含义：AWGN + 载波频偏
- 关键参数：
  - `fd`（Hz）
  - 可选 `fd_residual`
  - 可选相位噪声：`enable_phase_noise`、`phase_noise_sigma`

### 4.3 `rayleigh_flat` / `rayleigh`
- 含义：平坦 Rayleigh 衰落
- 关键参数：
  - `fade_mode='block'`（每帧一个复系数）
  - 或 `fade_mode='slow'`（一阶 AR 慢变）
  - `fade_rho`（slow 模式相关系数）

### 4.4 `rician_flat`
- 含义：平坦 Rician 衰落
- 关键参数：
  - `K_dB`（莱斯 K 因子）

### 4.5 `rayleigh_tdl`
- 含义：多径 Rayleigh TDL（抽头延迟线）
- 关键参数：
  - `taps_delay_samples`（**样点**单位）
  - `taps_gain_dB`

> 说明（宽带 vs 窄带差异）：
> 本模型中延迟用“样点”定义，`Fs` 越高，同样长度信号内可解析的时延结构越细；当 `Rs` 高（宽带）时，多径对相邻符号影响更容易体现为明显 ISI/频率选择性；当 `Rs` 低（窄带）时，通常更接近平坦衰落。工程里 `make_channel_meta_profile.m` 已给出宽带/窄带不同默认抽头模板。

### 4.6 `impulsive`
- 含义：点状脉冲干扰
- 关键参数：
  - `imp_prob`（脉冲出现概率）
  - `imp_amp`（脉冲幅度）

### 4.7 `burst_jam`
- 含义：突发段干扰（整段污染）
- 关键参数：
  - `jam_prob`（触发突发概率）
  - `burst_len_range=[Lmin Lmax]`
  - `jam_amp`
  - `jam_type='noise'|'tone'`
  - 若 `tone`，还需 `jam_tone_freq`

---

## 5. 噪声标定方式（重要）

`channel_model` 默认使用 `Es/N0` 标定（论文常用且可复现）：

1) 若 `meta.norm_tx=true`，先归一化发射信号（`Es≈1`）并记录 `truth.scale`
2) `EsN0dB = EbN0dB + 10*log10(log2(M)*Rc)`
3) 复高斯噪声方差：
   \[
   \sigma^2 = \frac{E_s}{2\cdot 10^{EsN0/10}}
   \]

可选：`meta.noise_mode='measured_snr'`，此时使用 `meta.SNRdB` 直接控制输出 SNR。

---

## 6. 结果怎么看

运行 `main_simulate` 后会输出并绘图：

- BER 曲线（wide/narrow/adaptive）
- 吞吐率曲线（wide/narrow/adaptive）
- 自适应模式切换次数 `SwitchCount`

其中自适应策略在 `update_controller.m`：
- 基于 `snr_est` 与 `per` 做门限+迟滞切换
- 支持“紧急降级”机制

---

## 7. 常见使用示例

### 示例 A：只测 AWGN（无 CFO）
```matlab
scenario = "awgn";
main_simulate
```

### 示例 B：测 AWGN+CFO
```matlab
scenario = "awgn_cfo";
main_simulate
```

### 示例 C：测平坦 Rayleigh 慢变
在 `make_channel_meta_profile.m` 的 `rayleigh_flat` 分支中设置：
```matlab
meta.fade_mode = 'slow';
meta.fade_rho = 0.995;
```
然后：
```matlab
scenario = "rayleigh_flat";
main_simulate
```

### 示例 D：测多径 TDL（观察宽窄带差异）
```matlab
scenario = "rayleigh_tdl";
main_simulate
```
可在 `make_channel_meta_profile.m` 里自定义抽头：
```matlab
meta.taps_delay_samples = [0 2 5 9];
meta.taps_gain_dB = [0 -3 -8 -12];
```

### 示例 E：测突发干扰
```matlab
scenario = "burst_jam";
main_simulate
```
可在 `make_channel_meta_profile.m` 设置：
```matlab
meta.jam_prob = 0.05;
meta.burst_len_range = [128 512];
meta.jam_amp = 3;
meta.jam_type = 'noise';   % 或 'tone'
```

---

## 8. 文件分工建议

- `default_config.m`：系统体制与控制参数
- `tx_frame.m`：发帧与 meta 基础字段生成
- `make_channel_meta_profile.m`：场景参数模板（推荐先改这里）
- `channel_model.m`：具体信道实现
- `rx_frame.m`：接收与性能指标
- `run_montecarlo.m`：总仿真循环与统计

