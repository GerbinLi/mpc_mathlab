%**************************************************************************
 % @file       		mpc_control_test.m
 % @company         SZU
 % @author     		�����
 % @Software 		Matlab2016a
 % @Target         `����MPC���ټ򵥹켣����
 % @date            2022-3-1
 % All rights reserved
%**************************************************************************

clear;clc;
close all;

%% ѡ���Ƿ�����gif
gif_generate_flag = 0;                                                     %��Ҫ���������Ϊgif���򽫸�flag��1
pic_num = 1;

%% ��������趨
dt = 0.01;                                                                 % ��ɢʱ����
num_step = 1500;                                                           % ���沽��
t = (0:num_step-1)*dt;                                                     % ���ɷ���ʱ������

%% �˶�ѧ�����趨
L = 1;                                                                     %���
%���òο�����(�ο��ٶ�vel_ref�Ͳο�ǰ��ת��delta_ref)
%u_ref = [3;0]*ones(1,num_step);                                           %��Ӧ�ο��켣Ϊֱ��
u_ref = [1;0.5]*ones(1,num_step);                                          %��Ӧ�ο��켣ΪԲ                                        

%�趨�ο�״̬�����ο��켣��state_ref�����зֱ�洢x_ref��y_ref��theta_ref 
state_ref = zeros(3,num_step);                                              
for k = 2:num_step
    last_theta = state_ref(3,k-1);
    state_ref(:,k) = state_ref(:,k-1)+[cos(last_theta),0;sin(last_theta),0;0,1]*u_ref(:,k-1)*dt;
end

%�趨��ʼ״̬�ͳ�ʼ����
state_real = zeros(3,num_step);                                            %��ʼ��ʵ��״̬����
state_real(:,1) = [1;-1;0];                                                %�趨��ʼ״̬
state_error = zeros(3,num_step);                                           %��ʼ��״̬�������
u_real = zeros(2,num_step);                                                %��ʼ��ʵ����������
u_real(:,1) = [0;0];                                                       %�趨��ʼ����
u_error = zeros(2,num_step);                                               %��ʼ�������������

%% MPC�����������趨
N = 10;                                                                    %Ԥ������
Q = diag([1,1,0.5]);                                                       %״̬��Ȩ��
R = diag([0.1,0.1]);                                                       %������Ȩ��
%����Q_bar��R_bar��Ȩ�ؾ���
Q_bar = kron(eye(N+1),Q);
R_bar = kron(eye(N),R);

%% �������Ż������ã�ʹ�� interior-point-convex �㷨������ʾ�������̣�
options = optimoptions('quadprog',...
    'Algorithm','interior-point-convex','Display','off');

%% �����Ż�
tic;                                                                       %��ʼ��ʱ
figure(1);
hold on;
xlabel('x(m)');
ylabel('y(m)');
%Ϊ�˲��������N��ʱ�̵����������ѭ��ֻ���е� num_step-N
for k = 1:num_step-N
   %�̻�ÿ��ʱ�̵Ĳο�λ�ú�ʵʱλ��
   plot(state_real(1,k),state_real(2,k),'b.');
   plot(state_ref(1,k),state_ref(2,k),'r.');
   drawnow;                                                                %ʵʱ��ʾ�켣
   %¼��gif��ͼ
   if gif_generate_flag
       F=getframe(gcf);
        I=frame2im(F);
        [I,map]=rgb2ind(I,256);
        if pic_num == 1
            imwrite(I,map,'MPC_test.gif','gif', 'Loopcount',inf,'DelayTime',0.00);
        else
            imwrite(I,map,'MPC_test.gif','gif','WriteMode','append','DelayTime',0.00);
        end
        pic_num = pic_num + 1;
   end
   %���㵱ǰʱ�̵�״̬���
   state_error(:,k) = state_real(:,k) - state_ref(:,k);
   %����A��B
   theta_ref = state_ref(3,k);
   A = eye(3)+dt*[0,0,-u_ref(1,k)*sin(theta_ref);0,0,u_ref(1,k)*cos(theta_ref);0,0,0];
   B = dt*[cos(theta_ref),0;sin(theta_ref),0;tan(u_ref(2,k))/L,u_ref(1,k)*(sec(u_ref(2,k)))^2/L];
   n = size(A,1);                                                          %A��nxn�������n
   p = size(B,2);                                                          %BΪnxp�������p
   %����M��C
   M = [eye(n);zeros(N*n,n)];                                              %��ʼ��M����
   C = zeros((N+1)*n,N*p);                                                 %��ʼ��C����
   tmp = eye(n);
   for i=1:N
       rows=i*n+(1:n);                                                     %���嵱ǰ��������i*n�п�ʼ����n��
       C(rows,:) = [tmp*B,C(rows-n,1:end-p)];                              %��װC���󣬺�벿�ִ����ǽ�ǰn�е����ݸ��Ʋ�ɾ�ӵ���ǰn�еĺ�
       tmp = A*tmp;
       M(rows,:) = tmp;                                                    %��װM����
   end
   %����G,E,H
   G = M'*Q_bar*M;
   E = M'*Q_bar*C;
   H = C'*Q_bar*C+R_bar;
   %���� quadprog ������������Ż�
   f = ((state_error(:,k))'*E)';
   [U_k,fval,exitflag,output,lambda] = quadprog(H,f,[],[],[],[],[],[],[],options);
   u_error(:,k)= U_k(1:2);                                                 %ֻȡU_k�ĵ�һ���֣�ǰ����õ��������
   u_real(:,k) = u_ref(:,k) + u_error(:,k);                                %ʵ������ = �ο����� + �������
   state_error(:,k+1) = A*state_error(:,k)+B*u_error(:,k);                 %�ɵ�ǰʱ�̵�״̬�����������������һʱ�̵�Ԥ��״̬���
   state_real(:,k+1) = state_ref(:,k+1) + state_error(:,k+1);              %��һʱ��״̬ = ��һʱ�̲ο�״̬ + Ԥ�����״̬
end
toc;                                                                       %������ʱ
