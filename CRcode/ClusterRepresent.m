% Incremental multi-graph matching
% rawMat: initial global matching n(N+1)*n(N+1), n: node size, N: graph
% rawMat contains only the initial matching within each cluster, and it's
% the composition of previous IMGM result and the new graph
% affMat: edge affinity/similarity
% number, the N+1th is new graph
% affScore: affinity score matrix for each pair of graphs, size N*N
% param: structure storing extra parameters
%        param.method: partition method (1: AP, 2: DPP, 3: random)

function M = ClusterRepresent(affScore, rawMat, param)
    global affinity
    [a,b]=size(affScore);
    if a~=b
        error('The similarity matrix must be square!');
    end
    isDPP = 1; isAP = 2; isRand = 3; isTIP = 4;% DPP, AP or random clustering
    n=param.n; N=param.N+1;
    massOutlierMode = 0;
    nCluster = 2;
    inlierMask =  zeros(n,N);
    nDivide = ones([1 N])*n;
    
    Matching = mat2cell(rawMat,nDivide,nDivide);% divide Matching into blocks
    maxScore = max(affScore(:));
    Similarity = arrayfun(@(x) x/maxScore,affScore);
    Similarity = (Similarity*1).^2;
    medianSimilarity = median(Similarity(:));
    p = ones([1 N])*medianSimilarity;
    %%%%%%%%%%%% visualize graphs if specified %%%%%%%%%%%%%%%%
    if param.visualization == 1
        maxSim = max(Similarity(:));
        tmpSimilarity = Similarity + eye(N)*1.05*maxSim;
        tmpSimilarity = ones(N,N)*1.05*maxSim - tmpSimilarity;
        pointMDS = mdscale(tmpSimilarity.^2, 2);
    end
    %%%%%%%%%%%%%%%%% generating the topology of hypergraph %%%%%%%%%%%%%%%
    if param.method == isAP
        %tic;
        [idx,~,~,~]=apcluster(-Similarity,-p); % perform AP-clustering
        idx = idx + 1;
        C_index = unique(idx);
        %toc
    end
    
    if param.method == isDPP
        %tic;
        affMax = max(affScore(:));
        affScoreTmp = affScore + eye(a)*(affMax*1.1);
        affMin = min(affScoreTmp(:));
        affScoreTmp = affScoreTmp - affMin*0.9;
        affScoreTmp = affScoreTmp/max(affScoreTmp(:));
        [idx, ~] = dpp_graph_partition(affScoreTmp,nCluster);
        C_index = unique(idx);
        if length(idx) ~= N
            fprintf('wrong size of DPP\n');
        end
        %toc
    end
    
    if param.method == isRand
        %tic;
        tmpPartitionSize = floor(a/nCluster);
        res = a - nCluster*tmpPartitionSize;
        if res == 0
            PartitionSize = ones(nCluster,1)*tmpPartitionSize;
        else
            PartitionSize = ones(nCluster,1)*tmpPartitionSize;
            for i=1:res
                PartitionSize(i) = PartitionSize(i)+1;
            end
        end
        aPerm = randperm(a);
        idx = zeros(a,1);
        for i = 1:nCluster
            idx(aPerm(1:PartitionSize(i))) = i;
            aPerm(1:PartitionSize(i)) = [];
        end
        C_index = unique(idx);
        %toc
    end
    
    if param.method == isTIP
        C_index = 1:a;
        idx = C_index;
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%     CAO multi-graph matching on each cluster          %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    nCluster = length(C_index);
    ClusterPosition = cell(nCluster,1);
    ClusterSize = zeros(nCluster,1);
    for i = 1:nCluster
        tmpClusterPosition = find(idx == C_index(i));           % find the indices of graphs which belongs to i-th cluster
        ClusterPosition{i} = tmpClusterPosition;
        iClusterSize = length(tmpClusterPosition);              % iClusterSize records the i-th cluster's size 
        ClusterSize(i) = iClusterSize;                          % ClusterSize records the sizes of all clusters
        affinityCrop = cropAffinity(tmpClusterPosition);        % crop the affinity of i-th cluster
        targetCrop = cropTarget(tmpClusterPosition);            % crop the target of i-th cluster
        tmpRawMat = cell2mat(Matching(tmpClusterPosition, tmpClusterPosition));
        affScoreCurrent = affScore(tmpClusterPosition,tmpClusterPosition);
        scrDenom = max(max(affScoreCurrent(1:end,1:end)));
        tmpMatching = CAO_local(tmpRawMat, n, iClusterSize, param.iterMax, scrDenom, affinityCrop, targetCrop, 'exact',1);      % perform CAO_pc
        iDivide = ones([1 iClusterSize]) * n;
        Matching(tmpClusterPosition, tmpClusterPosition) = mat2cell(tmpMatching,iDivide,iDivide);                               % record the i-th cluster's matching result in Machting
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%     Choose Representation by finding the graph with     %%%
    %%%     max consistency in each cluster. And match them     %%%
    %%%     together by multi-graph matching algorithm          %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %%%%%%%%%%%  find all the representations %%%%%%%%%%%%%%%%%%%%%
    Representation = zeros(nCluster,1);
    for i = 1 : nCluster
        tmpClusterPosition = cell2mat(ClusterPosition(i));
        iMatching = cell2mat(Matching(tmpClusterPosition,tmpClusterPosition));
        tmpConsistency = cal_single_graph_consistency(iMatching, n, ClusterSize(i), massOutlierMode, inlierMask);                % compute the consistency of graph j
        [~, maxIdx] = max(tmpConsistency);                      % find the Representation and record it in Representation(i)
        Representation(i) = tmpClusterPosition(maxIdx);
    end
    
    %%%%%%%%%%%  match all the representations  %%%%%%%%%%%%%%%%%%%
    affinityCrop = cropAffinity(Representation);                % crop the affinity of Representation
    targetCrop = cropTarget(Representation);                    % crop the target of Representation
    tmpRawMat = cell2mat(Matching(Representation, Representation));
    affScoreCurrent = affScore(Representation, Representation);
    scrDenom = max(max(affScoreCurrent(1:end,1:end)));
    tmpMatching = CAO_local(tmpRawMat, n, length(Representation), param.iterMax, scrDenom, affinityCrop, targetCrop, 'exact',1); % perform CAO_pc
    iDivide = ones([1 length(Representation)]) * n;
    Matching(Representation, Representation) = mat2cell(tmpMatching,iDivide,iDivide);                                            % record the matching result in Machting
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%     Construct all the matching by X_ab = X_aiX_ij_Xjb     %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    for i = 1 : N 
        for j = 1 : N
            if (idx(i) ~= idx(j))
                Matching{i, j} = Matching{i,Representation(idx(i))} * Matching{Representation(idx(i)), Representation(idx(j))} * Matching{Representation(idx(j)), j};
            end
        end
    end
    M = cell2mat(Matching);
end