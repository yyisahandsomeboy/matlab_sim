
function x = mod_qpsk(bits)
bits = bits(:);
bits = bits(1:2*floor(numel(bits)/2));
b = reshape(bits, 2, []);
aI = 2*b(1,:) - 1;
aQ = 2*b(2,:) - 1;
x = (aI + 1j*aQ).';
end
