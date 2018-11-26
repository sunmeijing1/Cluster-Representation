function [ X ] = CR_Loop( M, group1, group2, varargin )
%Gragh Matching by impose consistency restraints
% by Yu Tian, 2011
%% Default Parameters
param = struct( ...
    'c', 0.2, ...                   % prob. for walk or reweighted jump?
    'amp_max', 30, ...              % maximum value for amplification procedure
    'iterMax', 300, ...             % maximum value for amplification procedure
    'thresConvergence', 1e-25, ...  % convergence threshold for random walks
    'tolC', 1e-3 ...                % convergence threshold for the Sinkhorn method
);
param = parseargs(param, varargin{:});

%% parameter structure -> parameter value
strField = fieldnames(param);
for i = 1:length(strField), eval([strField{i} '=param.' strField{i} ';']); end

n1 = size(group1,2);
n2 = size(group2,2);
E12 = ones(n1,n2);
nSize = n1*n2;

for i = 1:n1
    tmp1 = find(group1(:,i));
    match(tmp1,1) = i;
end
for i = 1:n2
    tmp2 = find(group2(:,i));
    match(tmp2,2) = i;
end

for i = 1:length(match)
    full(i,1) = (match(i,2)-1)*n1+match(i,1);
end

%%
nMatch = length(M);
I = eye(nMatch);
d = max(max(M));
lambda = d/500*sqrt(nMatch);

input = ones(nMatch,1)/nMatch;
result = zeros(nMatch,1);
M_minus = M;
Iter = 0;
IterMax = 500;
b_iter = 0;
while b_iter == 0 && Iter < IterMax
    Iter = Iter+1;
    result = CR( M_minus, E12, input, nSize, I, lambda, full);
    if result == input
        b_iter = 1;
    else
        input = result;
    end
end

X = result;

end

%%
    function [result] = CR( M, E12, input, nSize, I, lambda, full_vec)
%         [idx1 ID1] = make_groups(group1);
%         [idx2 ID2] = make_groups(group2);
% 
%         if ID1(end) < ID2(end)
%             [idx1 ID1 idx2 ID2 dumVal dumSize] = make_groups_slack(idx1, ID1, idx2, ID2);
%             dumDim = 1;
%         elseif ID1(end) > ID2(end)
%             [idx2 ID2 idx1 ID1 dumVal dumSize] = make_groups_slack(idx2, ID2, idx1, ID1);
%             dumDim = 2;
%         else
%             dumDim = 0; dumVal = 0; dumSize = 0;
%         end
%         idx1 = idx1-1; idx2 = idx2-1;
%         
%         nMatch = length(M);
        lam = lambda;
        bCont = 0;
        iter = 0;
        iterMax = 500;
        tolC = 1e-3;
        
        prev_assign = input;
        prev_assign2 = input;
        final_assign = input;
        cur_assign = input;
        cur_score = 0;            


        M2 = M;
        while 0 == bCont && iter < iterMax
            iter = iter+1;
            cur_result = M2*prev_assign;
            cur_temp = zeros(nSize,1);
            for i = 1:length(full_vec)
                cur_temp(full_vec(i,1),1) = cur_result(i,1);
            end
            cur_mat = postHungarian( E12, cur_temp);
            cur_assign_temp = reshape(cur_mat, nSize, 1);
            for i = 1:length(full_vec)
                cur_assign(i,1) = cur_assign_temp(full_vec(i,1),1);
            end
            
%             cur_exp = exp(1000*cur_result);
%             X_slack = [cur_exp; dumVal*ones(dumSize,1)];
%             X_slack = mexBistocNormalize_match_slack(X_slack, int32(idx1), int32(ID1), int32(idx2), int32(ID2), tolC, dumDim, dumVal, int32(1000));
%             cur_soft = X_slack(1:nMatch);
%             cur_assign = greedyMapping(cur_soft, group1, group2);
            
            sumCurAssign = sum(cur_assign); % normalization of sum 1
            if sumCurAssign>0, cur_assign = cur_assign./sumCurAssign; end
            
            if cur_assign == prev_assign % 说明得到了不变的迭代解
                if cur_assign'*M*cur_assign >= cur_score
                cur_score = cur_assign'*M*cur_assign;
                final_assign = cur_assign;
                end
                bCont = 1;
        %下面这部分循环 假设 cur prev prev2 的值分别为： cur   prev prev2
        %                                               X     Y     X 
        %情况1：如果XtMX >= YtMY 则这三个值更新为： cur       prev prev2  此时M已更新
        %                                         X->find     X     Y
        %情况2：如果YtMY >= XtMX 则这三个值更新为： cur       prev prev2  此时M已更新
        %                                         Y->find     Y     Y
        %                                    or:  cur       prev prev2  此时M已更新
        %                                         Y->find     Y     X
        %对于情况2的两种方法 都可以在M更新后进入新的迭代过程 并且检验是不是跳出了 X-Y循环
        %但显然如果 M更新后没有跳出X-Y循环 那情况2 的后一种方法好些 如果Y-find = X 后一种方法在第一时间发现没有跳出
        %X-Y循环 但前一种 方法要 Y-find = X 再 X-find = Y 才能发现没有跳出 X-Y 循环
        
        %为什么会一定进入X-Y循环：假如 YtMZ-->XtMY, X != Z, 并且 YtMZ = YtMX
        %假设矩阵M中元素有效数字是小数点后e位 我在矩阵M的n^2个元素中分别附加 pow(2, -4e),
        %pow(2,-4e-1),...pow(2,-4e-n^2), 这样YtMZ就不再等于YtMX 因为附加值前面的系数为-1,0,1
        %它们的和不会等于0 这也说明了如果编程时不实现附加的操作 可以把 elseif 的判断条件改为cur'*M*prev =
        %prev'*M*prev2; 并且用 cur 和 prev来进入增加M后的迭代过程 或者跟踪到所有的X->Y->Z..找到最好的
        
%     elseif cur_assign == prev_assign2 % 说明进入了 cur-prev循环
%             if prev_assign'*M*prev_assign > cur_assign'*M*cur_assign %从cur-prev中取最好的 赋给cur
%                 cur_assign = prev_assign;
%             end
%             M = M + lambda*I; % 通过增加对角 试图跳出循环
%             prev_assign2 = prev_assign;
%             prev_assign = cur_assign;
            elseif cur_assign == prev_assign2 % 说明进入了 cur-prev循环
                if prev_assign'*M*prev_assign > cur_assign'*M*cur_assign % YtMY > XtMX 这个地方乘M就可以 不用乘problem.M 因为就差个常数项
                    cur_assign = prev_assign;
                else % XtMX > YtMY
                    prev_assign2 = prev_assign;
                    prev_assign = cur_assign;
                end
                if cur_assign'*M*cur_assign >= cur_score
                    cur_score = cur_assign'*M*cur_assign;
                    final_assign = cur_assign;
                end
                M2 = M2 + lam*I; % 通过增加对角 试图跳出循环
            else
                prev_assign2 = prev_assign;
                prev_assign = cur_assign;
            end
        end
        result = final_assign;
    end
%%
% 要实现的方法：  1.XtMX-->(匈牙利)YtMZ 然后考虑 1.(M+Lambda*I)Y-->...直到收敛
%                                              2.(M+Lambda*I)Z-->...直到收敛 
%                2.XtMX-->1.（匈牙利一步）YtMX 然后考虑 (M+Lambda*I)Y-->...直到收敛
%                         2.（Soft Assign）YtMX 然后考虑 (M+Lambda*I)Y-->...直到收敛
%                3.Lambda 可以 1.固定步长
%                              2. 自适应+固定步长
%                4.可以考虑Xt(M+Lambda*D)X，D衡量点之间的近似度


%X = reshape(final_assign, n1, n2);% cur_assign_mat; % 如果是个好的解 早就存到cur_assign_mat了 返回的是矩阵形式 不是列向量形式


