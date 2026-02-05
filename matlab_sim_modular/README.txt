本压缩包提供“宽/窄带融合自适应通信系统”MATLAB 仿真框架的模块化版本。
- 目标：在 AWGN/衰落/频偏/突发干扰场景下，比较 wide-only / narrow-only / adaptive 三种策略的 BER、PER、吞吐率、切换次数。
- 说明：代码以你现有脚本为核心算法（同步字+梳状导频+两级滤波+相位补偿+Turbo译码）进行模块化封装。
- 依赖：LTE Toolbox（lteTurboEncode/lteTurboDecode）；你已有的 cacode_503、fir7、fir8 函数。

运行入口：
1) 先把 cacode_503.m, fir7.m, fir8.m 放到同一目录或 MATLAB path。
2) 运行 main_simulate.m


当前默认体制参数：
- 窄带：QPSK + 1 kSym/s + 30 Hz 频偏
- 宽带：16QAM + 13.75 MSym/s + 1030 Hz 频偏
- 导频密度可在 default_config.m 中按模式独立修改（pilot_density 或 pilot_distance）。
