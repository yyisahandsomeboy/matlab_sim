function st = update_controller(cfg, st, metrics)
snr = metrics.snr_est;
per = metrics.per;

% 紧急降级
if per > cfg.ctrl.emerg_per
    st.mode = "narrow";
    st.up_cnt = 0; st.dn_cnt = 0;
    return;
end

if st.mode == "wide"
    if snr < cfg.ctrl.gamma_dn
        st.dn_cnt = st.dn_cnt + 1;
    else
        st.dn_cnt = 0;
    end
    if st.dn_cnt >= cfg.ctrl.N_hold
        st.mode = "narrow";
        st.dn_cnt = 0; st.up_cnt = 0;
    end
else
    if snr > cfg.ctrl.gamma_up
        st.up_cnt = st.up_cnt + 1;
    else
        st.up_cnt = 0;
    end
    if st.up_cnt >= cfg.ctrl.N_hold
        st.mode = "wide";
        st.up_cnt = 0; st.dn_cnt = 0;
    end
end
end