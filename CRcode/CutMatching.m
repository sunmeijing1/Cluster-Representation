% CutMatching computes normalized graph cut and graph matching in a unified
% framework
% suppose n is the number of nodes 
% affinity: n^2*n^2 node and edge affinity scores
% graphLap: Laplacian of the graph
% param.X_initial: initial matching
% param.y_initial: initial cut
% param.iterCnt: maximal iteration count
% Note graphWeight is inversely proportional to cost
%%%%%%%%%%%%%%%%%%%%%%%% coded by Tianshu Yu @IBM @ASU %%%%%%%%%%%%%%%%%%%%

function [Matching, Cut] = CutMatching(affinity, graphWeight, param)
    [nodeCnt,~]=size(graphWeight);
%     if ~exist('param.X_initial')
%         algpar.iterMax1 = 100; % default max iter count
%         param.X_initial = RRWM(affinity, nodeCnt, nodeCnt, algpar); % initial matching using RRWM
%     end
%     if ~exist('param.lambda_1') param.lambda_1=0.5; end % refer to paper
%     if ~exist('param.lambda_2') param.lambda_2=0.2; end % refer to paper
%     if ~exist('param.typeL') param.typeL=1; end % standard graph cut by default
%     if ~exist('param.discrete') param.discrete=0; end % if discretilize the matching and cut or not
    X_next = param.X_initial;
    
    %%%%%%%%%%%%%%%%%% Initialization %%%%%%%%%%%%%%%%%%%%%%%
    % mask = ones(size(X_next))-eye(size(X_next,1));
    % X_next = BregmanBiStochZero(X_cur,20);
    
    
    for iter = 1:param.iterCnt
        X_prev = BregmanBiStochZero(X_next,20);
        %%%%%%%%%%%%%%%%%%% updata cut %%%%%%%%%%%%%%%%%%%%%%%%%
        y_update = RayQotCutMatching(graphWeight, X_prev, param.lambda_1, param.lambda_2, param.typeL);
        % X_old = X_cur;
        if iter ==1, X_prev = BregmanBiStochCut(X_prev,y_update,40); end
        %%%%%%%%%%%%%%%%%%% updata matching %%%%%%%%%%%%%%%%%%%%
        X_next = IBGP(X_prev(:), affinity, y_update, param.lambda_2, 0.002, 200, 200,1);
        X_next = reshape(X_next,[nodeCnt nodeCnt]);
        % X_prev = X_next;
       a = 1;
    end
    Matching = X_next;
    Cut = y_update;
end