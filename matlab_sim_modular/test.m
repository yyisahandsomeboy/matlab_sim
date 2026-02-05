clear;
N = 10000;
bits = randi([0 1], 4*N, 1);

x = mod_16qam_gray(bits);     % 你的映射
I = real(x);
Q = imag(x);
i_llr = gen_llr_dynamic_threshold(I,0);  % 你的解映射（你自己实现）
q_llr = gen_llr_dynamic_threshold(Q,0);  % 你的解映射（你自己实现）
b1=i_llr(:,1);
b2=i_llr(:,2);
b3=q_llr(:,1);
b4=q_llr(:,2);
bits_hat = reshape([b1, b2, b3, b4].', [], 1);
bits_hat =bits_hat>0;
ber = mean(bits_hat(:) ~= bits(:));
fprintf("Self-check BER (no noise) = %.3e\n", ber);