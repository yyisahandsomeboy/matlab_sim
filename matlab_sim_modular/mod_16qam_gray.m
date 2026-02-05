
function x = mod_16qam_gray(bits)
% 简单 16QAM Gray 映射（每4比特一符号）
bits = bits(:);
bits = bits(1:4*floor(numel(bits)/4));
b = reshape(bits, 4, []).';

% Gray mapping for I/Q: 00->-3, 01->-1, 11->+1, 10->+3
map2 = containers.Map({'00','01','11','10'}, [-3,-1,1,3]);

I = zeros(size(b,1),1);
Q = zeros(size(b,1),1);
for k = 1:size(b,1)
    i2 = sprintf('%d%d', b(k,1), b(k,2));
    q2 = sprintf('%d%d', b(k,3), b(k,4));
    I(k) = map2(i2);
    Q(k) = map2(q2);
end

x = (I + 1j*Q) / sqrt(10);   % 归一化平均能量为1
end
