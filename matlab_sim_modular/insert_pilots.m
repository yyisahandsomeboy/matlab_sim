
function [data_pilot, pilot_num, ndata_zero] = insert_pilots(data_sym, pilot_word, pilot_distance)
% comb pilot: 每 pilot_distance 插 1 个导频，其余为数据

data_sym = data_sym(:).';
pilot_num = floor((length(data_sym))/(pilot_distance-1)) + 2;
ndata_pilot = (pilot_num-1)*pilot_distance + 1;
ndata_zero  = (pilot_num-1)*(pilot_distance-1) - length(data_sym);

data_pilot = zeros(1, ndata_pilot);
for i = 0:pilot_num-1
    data_pilot(i*pilot_distance+1) = pilot_word;
    if (i <= pilot_num-3)
        data_pilot(i*pilot_distance+2:(i+1)*pilot_distance) = data_sym(i*(pilot_distance-1)+1:(i+1)*(pilot_distance-1));
    else
        if (i == pilot_num-2)
            tail = [data_sym(end-(pilot_distance-ndata_zero-2):end), zeros(1, ndata_zero)];
            data_pilot(i*pilot_distance+2:(i+1)*pilot_distance) = tail;
        end
    end
end

data_pilot = data_pilot(:);

end
