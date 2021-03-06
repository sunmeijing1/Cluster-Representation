function [ X ] = LRGA( M, group1, group2, M1, varargin )
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
%%
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
if 1
    I = eye(nMatch);
else
    I = (M1+eye(nMatch))/2;
end
d = max(max(M));
lambda = d/500*sqrt(nMatch);

input = ones(nMatch,1)/nMatch;
result = zeros(nMatch,1);
%M_minus = M-d/1.5*eye(nMatch);
M_minus = M;
Iter = 0;
%IterMax = 100;
IterMax = 50;
b_iter = 0;
while b_iter == 0 && Iter < IterMax
    Iter = Iter+1;
    result = CR( M_minus, E12, input, nSize, I, lambda, full);
    %result = CR( M_minus, E12, input, nSize, I, lambda);
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
    %function [result] = CR( M, E12, input, nSize, I, lambda)

        lam = lambda;
        bCont = 0;
        iter = 0;
        iterMax = 500;
        
        prev_assign = input;
        prev_assign2 = 0;
        final_assign = input;
        final_assign2 = 0;
        cur_assign = input;
        cur_score = input'*M*input;
		
 		[a,b] = size(E12);
        Nn = 0.2*min(a,b);  
		
        M2 = M;
        while 0 == bCont && iter < iterMax
            iter = iter+1;
            cur_result = M2*prev_assign;
%             cur_assign1 = postHungarian(E12,cur_result);
%             cur_assign = reshape(cur_assign1,nSize,1); 
            cur_temp = zeros(nSize,1);
            for i = 1:length(full_vec)
                cur_temp(full_vec(i,1),1) = cur_result(i,1);
            end
            cur_mat = postHungarian( E12, cur_temp);
            cur_assign_temp = reshape(cur_mat, nSize, 1);
            for i = 1:length(full_vec)
                cur_assign(i,1) = cur_assign_temp(full_vec(i,1),1);
            end
            
            sumCurAssign = sum(cur_assign); % normalization of sum 1
            if sumCurAssign>0, cur_assign = cur_assign./sumCurAssign; end
            if cur_assign'*M*cur_assign > cur_score
                final_assign = cur_assign;
                final_assign2 = prev_assign;
            end
            %if cur_assign == prev_assign % 说明得到了不变的迭代解
			if sum(abs(cur_assign-prev_assign)) <= Nn
                bCont = 1;
            %elseif cur_assign == prev_assign2 % 说明进入了 cur-prev循环
			else if sum(abs(cur_assign-prev_assign2)) <= Nn
                prev_assign = final_assign;
                prev_assign2 = final_assign2;
                M2 = M2 + lam*I; % 通过增加对角 试图跳出循环
            else
                prev_assign2 = prev_assign;
                prev_assign = cur_assign;
            end
        end
        result = final_assign;
        end