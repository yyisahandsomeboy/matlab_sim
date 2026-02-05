%% 　程序描述：cacode函数用来产生CA码
%%　Author: Wang Xuan  Email:wangxuan198623@163.com
%%　Copyright:@SysLab,BIT,北京理工大学信息系统实验室
%% 
function  cacode=cacode_503(svnum)
%generate C/A  code 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%本程序要求输入卫星的编号
% svnum=input('enter the number of the satellite:');
%C/A码的延时g2s
% svnum=5;
g2s =[5;6;7;8;17;18;139;140;141;251;252;254;255;256;257;258;469;...
    470;471; 472;473;474;509;512;513;514;515;516;859;860;861;862]; %%每一颗卫星对应的CA码延时
g2shift=g2s(svnum,1);
%reg =-1*ones(1,10);   %将1～10号寄存器的初始值设为-1   1111111000
% reg=[-1,-1,-1,-1,-1,-1,-1,1,1,1];
reg=[-1,-1,-1,-1,-1,-1,-1,-1,-1,-1];
%将10号寄存器的输出作为G1码
%并将10号寄存器与3号寄存器输出模二相加后反馈给1号寄存器

g1=zeros(1,1023);
for  i = 1:1023
    g1(i) = reg(10);
    slave1 = reg(3)*reg(10);
%     slave1=reg(2)*reg(3)*reg(6)*reg(8)*reg(9)*reg(10);
    reg(1,2:10) = reg(1:1:9);
    reg(1) = slave1;
end

% g1=zeros(1,1023);
% reg10=repmat(reg(10),1,length(g1));
%     g1 = reg10;
%     slave1 = reg(3)*reg(10);
%     reg(1,2:10) = reg(1:1:9);
%     reg(1) = slave1;


%reg = -1*ones(1,10); 		%将1～10号寄存器的初始值设为-1   1001001000
% reg=[-1,1,1,-1,1,1,-1,1,1,1];
reg=[-1,-1,-1,-1,-1,-1,-1,-1,-1,-1];
%将10号寄存器的输出作为G2码
%并将10、 9、 8、 6、 3、 2寄存器输出模二相加后反馈给1号寄存器

% g2=zeros(1,1023);
for i = 1:1023
   g2(i) = reg(10);
   save2 = reg(2)*reg(3)*reg(6)*reg(8)*reg(9)*reg(10);
%    save2=reg(3)*reg(10);
   reg(1,2:10) = reg(1:1:9);
   reg(1) = save2;
end


% g2=zeros(1,1023);
% reg10=repmat(reg(10),1,length(g2));
%    save2 = reg(2)*reg(3)*reg(6)*reg(8)*reg(9)*reg(10);
%    reg(1,2:10) = reg(1:1:9);
%    reg(1) = save2;

% g2tmp(1,1:g2shift)=g2(1,1023-g2shift+1:1023);
% g2tmp(1,g2shift+1:1023)=g2(1,1:1023-g2shift);
% g2 = g2tmp; 
%G1和G2卷积后得到C/A码
ss_ca=g1.*g2;
ca=ss_ca;
%在C/A码的序列中找出-1并转换为0， 找出1并转换为1
ind1=find(ca==-1);
ind2=find(ca==1);
ca(ind1)=ones(1,length(ind1));
ca(ind2)=zeros(1,length(ind2));
cacode=ca;

% save cacode.mat cacode;
%%%%%%%%% %%%%%%%%%%%画出仿真结果图%%%%%%%%%%%%%%%%%
% plot(cacode);
% % axis([0   length(x)+5  0   1.5]); 
% % grid on; 




