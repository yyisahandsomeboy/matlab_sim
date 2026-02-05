function mcs_id = resolve_mcs_id(mode_sel)
%RESOLVE_MCS_ID 将输入模式解析为 MCS 索引（0..4）
% 输入支持：
% - 数值：0..4
% - 字符串/字符："narrow"|"wide"|"mcs0".."mcs4"

if isnumeric(mode_sel)
    mcs_id = round(mode_sel);
elseif isstring(mode_sel) || ischar(mode_sel)
    s = lower(strtrim(string(mode_sel)));

    if strcmpi(s, "narrow")
        mcs_id = 0;
    elseif strcmpi(s, "wide")
        mcs_id = 4;
    elseif startsWith(s, "mcs")
        tail = extractAfter(s, 3);
        mcs_id = str2double(tail);
    else
        error('Unsupported mode string: %s', string(mode_sel));
    end
else
    error('Unsupported mode_sel type');
end

if isnan(mcs_id) || mcs_id < 0 || mcs_id > 4
    error('MCS id must be in [0,4]');
end
end
