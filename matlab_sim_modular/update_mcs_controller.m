function [st, dbg] = update_mcs_controller(cfg, st, metrics)
%UPDATE_MCS_CONTROLLER 基于 SNR + PER 的多档MCS自适应控制器
% 接口：
%   [st, dbg] = update_mcs_controller(cfg, st, metrics)
%
% 关键策略：
% A) 连通性优先（紧急降级）
% B) 正常模式：可行集合 + goodput最大化
% C) 平稳切换：滞回 + N次确认 + lock 冷却
%
% 重要注意事项（已规避）：
% 1) PER滑窗混合污染：使用 st.per_hist_by_mcs 对每个MCS独立维护历史，
%    并在切换后切到对应MCS历史窗口。
% 2) 门限需要离线标定：gamma_up/gamma_dn/per_max 仅初始化值。
% 3) N_up/N_dn/lock 按“帧”计数，与符号率解耦。
% 4) string/char 比较使用 strcmpi/string，避免 "==" 字符串坑。

% ---------------- 参数读取与兼容 ----------------
snr_est = metrics.snr_est;
per_in = metrics.per;
sync_fail = get_metric_flag(metrics, 'sync_fail');
eq_fail = get_metric_flag(metrics, 'eq_fail');

if isempty(st.per_hist_by_mcs{st.mcs+1})
    st.per_hist_by_mcs{st.mcs+1} = [];
end

% 如发生MCS变化，切换到该MCS独立窗口，避免旧MCS PER污染
if ~isfield(st, 'hist_mcs') || st.hist_mcs ~= st.mcs
    st.hist_mcs = st.mcs;
    if isempty(st.per_hist_by_mcs{st.mcs+1})
        st.per_hist = [];
    else
        st.per_hist = st.per_hist_by_mcs{st.mcs+1};
    end
end

% 当前MCS窗口更新
st.per_hist = [st.per_hist(:).', per_in];
if numel(st.per_hist) > cfg.ctrl.per_window
    st.per_hist = st.per_hist(end-cfg.ctrl.per_window+1:end);
end
st.per_hist_by_mcs{st.mcs+1} = st.per_hist;
per_win = mean(st.per_hist);

% EMA平滑
if ~isfinite(st.snr_f)
    st.snr_f = snr_est;
else
    st.snr_f = (1-cfg.ctrl.ema_snr_alpha)*st.snr_f + cfg.ctrl.ema_snr_alpha*snr_est;
end
st.per_f = (1-cfg.ctrl.ema_per_alpha)*st.per_f + cfg.ctrl.ema_per_alpha*per_win;

% 连续失败计数
if sync_fail > 0, st.sync_fail_cnt = st.sync_fail_cnt + 1; else, st.sync_fail_cnt = 0; end
if eq_fail > 0, st.eq_fail_cnt = st.eq_fail_cnt + 1; else, st.eq_fail_cnt = 0; end

% lock倒计时
if st.lock > 0
    st.lock = st.lock - 1;
end

% debug信息
dbg = struct();
dbg.feasible = false(1,5);
dbg.goodput = -inf(1,5);
dbg.target_mcs = st.mcs;
dbg.per_win = per_win;

% ---------------- A) 紧急降级 ----------------
emerg_fail = (st.per_f > cfg.ctrl.emerg_per) || ...
             (st.sync_fail_cnt >= cfg.ctrl.fail_K) || ...
             (st.eq_fail_cnt >= cfg.ctrl.fail_K);

if emerg_fail
    if st.sync_fail_cnt >= cfg.ctrl.fail_K || st.eq_fail_cnt >= cfg.ctrl.fail_K
        st.mcs = 0;  % 严重失锁直接回MCS0保链路
    else
        st.mcs = max(st.mcs - 1, 0);
    end
    st.lock = cfg.ctrl.lock_len_emerg;
    st.up_cnt = 0;
    st.dn_cnt = 0;
    st.reason = "emergency";

    st.hist_mcs = st.mcs;
    if isempty(st.per_hist_by_mcs{st.mcs+1})
        st.per_hist = [];
    else
        st.per_hist = st.per_hist_by_mcs{st.mcs+1};
    end
    dbg.target_mcs = st.mcs;
    return;
end

% ---------------- B) 可行集合 + goodput ----------------
for i = 0:4
    idx = i+1;
    ok = (st.snr_f >= cfg.ctrl.gamma_dn(idx)) && ...
         (st.per_f <= cfg.ctrl.per_max(idx)) && ...
         (st.sync_fail_cnt < cfg.ctrl.fail_K) && ...
         (st.eq_fail_cnt < cfg.ctrl.fail_K);
    dbg.feasible(idx) = ok;

    if ok
        entry = cfg.mcs_table(idx);
        raw_rate = entry.Rs * log2(entry.M) * entry.Rc * entry.eta;
        dbg.goodput(idx) = raw_rate * (1 - st.per_f);
    end
end

S = find(dbg.feasible) - 1;
if isempty(S)
    % 无可行集合，强制降级
    st.mcs = max(st.mcs-1, 0);
    st.up_cnt = 0;
    st.dn_cnt = 0;
    st.reason = "no_feasible";
    st.lock = cfg.ctrl.lock_len_switch;
    dbg.target_mcs = st.mcs;
    return;
end

[~, best_loc] = max(dbg.goodput(dbg.feasible));
best_set = S(best_loc);
cur = st.mcs;
idx_cur = cur+1;
idx_best = best_set+1;
dbg.target_mcs = best_set;

% ---------------- C) 平稳切换 ----------------
if best_set > cur
    % 升级：需要 lock==0 + 更严条件 + N_up
    entry_cur = cfg.mcs_table(idx_cur);
    gp_cur = entry_cur.Rs * log2(entry_cur.M) * entry_cur.Rc * entry_cur.eta * (1 - st.per_f);
    gp_new = dbg.goodput(idx_best);

    up_ok = (st.lock == 0) && ...
            (st.snr_f >= cfg.ctrl.gamma_up(idx_best)) && ...
            (st.per_f <= cfg.ctrl.per_max(idx_best));

    if cfg.ctrl.use_goodput_gate
        up_ok = up_ok && (gp_new > gp_cur * (1 + cfg.ctrl.goodput_hyst));
    end

    if up_ok
        st.up_cnt = st.up_cnt + 1;
    else
        st.up_cnt = 0;
    end
    st.dn_cnt = 0;

    if st.up_cnt >= cfg.ctrl.N_up
        st.mcs = best_set;
        st.lock = cfg.ctrl.lock_len_switch;
        st.up_cnt = 0;
        st.dn_cnt = 0;
        st.reason = "upgrade";
        st.hist_mcs = st.mcs;
        if isempty(st.per_hist_by_mcs{st.mcs+1})
            st.per_hist = [];
        else
            st.per_hist = st.per_hist_by_mcs{st.mcs+1};
        end
    end

elseif best_set < cur
    % 降级：更快响应，N_dn确认
    st.dn_cnt = st.dn_cnt + 1;
    st.up_cnt = 0;

    if st.dn_cnt >= cfg.ctrl.N_dn
        st.mcs = best_set;
        st.lock = cfg.ctrl.lock_len_switch;
        st.up_cnt = 0;
        st.dn_cnt = 0;
        st.reason = "downgrade";
        st.hist_mcs = st.mcs;
        if isempty(st.per_hist_by_mcs{st.mcs+1})
            st.per_hist = [];
        else
            st.per_hist = st.per_hist_by_mcs{st.mcs+1};
        end
    end
else
    % 保持不变
    st.up_cnt = 0;
    st.dn_cnt = 0;
    st.reason = "hold";
end

end

function v = get_metric_flag(metrics, field_name)
if isfield(metrics, field_name)
    v = double(metrics.(field_name) ~= 0);
else
    v = 0;
end
end
