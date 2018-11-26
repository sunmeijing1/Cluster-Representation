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
            
            if cur_assign == prev_assign % ˵���õ��˲���ĵ�����
                if cur_assign'*M*cur_assign >= cur_score
                cur_score = cur_assign'*M*cur_assign;
                final_assign = cur_assign;
                end
                bCont = 1;
        %�����ⲿ��ѭ�� ���� cur prev prev2 ��ֵ�ֱ�Ϊ�� cur   prev prev2
        %                                               X     Y     X 
        %���1�����XtMX >= YtMY ��������ֵ����Ϊ�� cur       prev prev2  ��ʱM�Ѹ���
        %                                         X->find     X     Y
        %���2�����YtMY >= XtMX ��������ֵ����Ϊ�� cur       prev prev2  ��ʱM�Ѹ���
        %                                         Y->find     Y     Y
        %                                    or:  cur       prev prev2  ��ʱM�Ѹ���
        %                                         Y->find     Y     X
        %�������2�����ַ��� ��������M���º�����µĵ������� ���Ҽ����ǲ��������� X-Yѭ��
        %����Ȼ��� M���º�û������X-Yѭ�� �����2 �ĺ�һ�ַ�����Щ ���Y-find = X ��һ�ַ����ڵ�һʱ�䷢��û������
        %X-Yѭ�� ��ǰһ�� ����Ҫ Y-find = X �� X-find = Y ���ܷ���û������ X-Y ѭ��
        
        %Ϊʲô��һ������X-Yѭ�������� YtMZ-->XtMY, X != Z, ���� YtMZ = YtMX
        %�������M��Ԫ����Ч������С�����eλ ���ھ���M��n^2��Ԫ���зֱ𸽼� pow(2, -4e),
        %pow(2,-4e-1),...pow(2,-4e-n^2), ����YtMZ�Ͳ��ٵ���YtMX ��Ϊ����ֵǰ���ϵ��Ϊ-1,0,1
        %���ǵĺͲ������0 ��Ҳ˵����������ʱ��ʵ�ָ��ӵĲ��� ���԰� elseif ���ж�������Ϊcur'*M*prev =
        %prev'*M*prev2; ������ cur �� prev����������M��ĵ������� ���߸��ٵ����е�X->Y->Z..�ҵ���õ�
        
%     elseif cur_assign == prev_assign2 % ˵�������� cur-prevѭ��
%             if prev_assign'*M*prev_assign > cur_assign'*M*cur_assign %��cur-prev��ȡ��õ� ����cur
%                 cur_assign = prev_assign;
%             end
%             M = M + lambda*I; % ͨ�����ӶԽ� ��ͼ����ѭ��
%             prev_assign2 = prev_assign;
%             prev_assign = cur_assign;
            elseif cur_assign == prev_assign2 % ˵�������� cur-prevѭ��
                if prev_assign'*M*prev_assign > cur_assign'*M*cur_assign % YtMY > XtMX ����ط���M�Ϳ��� ���ó�problem.M ��Ϊ�Ͳ��������
                    cur_assign = prev_assign;
                else % XtMX > YtMY
                    prev_assign2 = prev_assign;
                    prev_assign = cur_assign;
                end
                if cur_assign'*M*cur_assign >= cur_score
                    cur_score = cur_assign'*M*cur_assign;
                    final_assign = cur_assign;
                end
                M2 = M2 + lam*I; % ͨ�����ӶԽ� ��ͼ����ѭ��
            else
                prev_assign2 = prev_assign;
                prev_assign = cur_assign;
            end
        end
        result = final_assign;
    end
%%
% Ҫʵ�ֵķ�����  1.XtMX-->(������)YtMZ Ȼ���� 1.(M+Lambda*I)Y-->...ֱ������
%                                              2.(M+Lambda*I)Z-->...ֱ������ 
%                2.XtMX-->1.��������һ����YtMX Ȼ���� (M+Lambda*I)Y-->...ֱ������
%                         2.��Soft Assign��YtMX Ȼ���� (M+Lambda*I)Y-->...ֱ������
%                3.Lambda ���� 1.�̶�����
%                              2. ����Ӧ+�̶�����
%                4.���Կ���Xt(M+Lambda*D)X��D������֮��Ľ��ƶ�


%X = reshape(final_assign, n1, n2);% cur_assign_mat; % ����Ǹ��õĽ� ��ʹ浽cur_assign_mat�� ���ص��Ǿ�����ʽ ������������ʽ

