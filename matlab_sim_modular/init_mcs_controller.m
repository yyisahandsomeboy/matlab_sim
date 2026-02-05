function st = init_mcs_controller(cfg)
%INIT_MCS_CONTROLLER 初始化多档MCS控制器状态

st = struct();
st.mcs = 0;                      % 初始连通性优先，从MCS0起步
st.snr_f = -inf;
st.per_f = 0;
st.up_cnt = 0;
st.dn_cnt = 0;
st.lock = 0;
st.reason = "init";

st.sync_fail_cnt = 0;
st.eq_fail_cnt = 0;
st.per_hist = [];
st.per_hist_by_mcs = cell(5,1);  % 防止跨MCS PER污染
st.hist_mcs = st.mcs;
st.per_window = cfg.ctrl.per_window;
end
