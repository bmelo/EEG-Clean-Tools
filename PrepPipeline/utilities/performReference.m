function [signal, referenceOut] = performReference(signal, referenceIn)
% Perform the specified reference
%
% In
pop_editoptions('option_single', false, 'option_savetwofiles', false);
%% Check the input parameters
if nargin < 1
    error('performReference:NotEnoughArguments', 'requires at least 1 argument');
elseif isstruct(signal) && ~isfield(signal, 'data')
    error('performReference:NoDataField', 'requires a structure data field');
elseif size(signal.data, 3) ~= 1
    error('performReference:DataNotContinuous', 'signal data must be a 2D array');
elseif size(signal.data, 2) < 2
    error('performReference:NoData', 'signal data must have multiple points');
elseif ~exist('referenceIn', 'var') || isempty(referenceIn)
    referenceIn = struct();
end
if ~isstruct(referenceIn)
    error('performReference:NoData', 'second argument must be a structure')
end

%% Set the defaults and initialize as needed
referenceOut = getReferenceStructure();
defaults = getPipelineDefaults(signal, 'reference');
[referenceOut, errors] = checkDefaults(referenceIn, referenceOut, defaults);
if ~isempty(errors)
    error('performReference:BadParameters', ['|' sprintf('%s|', errors{:})]);
end
defaults = getPipelineDefaults(signal, 'detrend');
[referenceOut, errors] = checkDefaults(referenceIn, referenceOut, defaults);
if ~isempty(errors)
    error('performReference:BadParameters', ['|' sprintf('%s|', errors{:})]);
end
referenceOut.rereferencedChannels = sort(referenceOut.rereferencedChannels);
referenceOut.referenceChannels = sort(referenceOut.referenceChannels);
referenceOut.evaluationChannels = sort(referenceOut.evaluationChannels);

%% Calculate the reference for the original signal
if isempty(referenceOut.referenceChannels) || ...
        strcmpi(referenceOut.referenceType, 'none')  
    referenceOut.referenceSignalOriginal = ...
        zeros(1, size(signal.data, 2));
else
    referenceOut.referenceSignalOriginal = ...
        nanmean(signal.data(referenceOut.referenceChannels, :), 1);
end
%% Make sure that reference channels have locations for interpolation
chanlocs = referenceOut.channelLocations(referenceOut.evaluationChannels);
if ~(length(cell2mat({chanlocs.X})) == length(chanlocs) && ...
     length(cell2mat({chanlocs.Y})) == length(chanlocs) && ...
     length(cell2mat({chanlocs.Z})) == length(chanlocs)) && ...
   ~(length(cell2mat({chanlocs.theta})) == length(chanlocs) && ...
     length(cell2mat({chanlocs.radius})) == length(chanlocs))
   error('performReference:NoChannelLocations', ...
         'evaluation channels must have locations');
end

%% Now perform the particular combinations
if  strcmpi(referenceOut.referenceType, 'robust') && ...
        strcmpi(referenceOut.interpolationOrder, 'post-reference') 
    doRobustPost();
elseif  strcmpi(referenceOut.referenceType, 'robust') && ...
        strcmpi(referenceOut.interpolationOrder, 'pre-reference') 
    doRobustPre();
else
    referenceOut.referenceSignal = referenceOut.referenceSignalOriginal;
end


    function [] = doRobustPre()
        % Use the bad channels accumulated from reference search
        referenceOut = robustReference(signal, referenceOut);
        referenceOut.noisyStatisticsBeforeInterpolation = ...
                                        referenceOut.noisyStatistics;
        noisy = referenceOut.interpolatedChannels.all;
        if isempty(noisy)   %No noisy channels -- ordinary ref
            referenceOut.referenceSignal = ...
                nanmean(signal.data(referenceOut.referenceChannels, :), 1);
        else
            bad = signal.data(noisy, :); 
            sourceChannels = setdiff(referenceOut.evaluationChannels, noisy);
            signal = interpolateChannels(signal, noisy, sourceChannels);
            referenceOut.referenceSignal = ...
                nanmean(signal.data(referenceOut.referenceChannels, :), 1);
            referenceOut.badSignalsUninterpolated = ...
                bad - repmat(referenceOut.referenceSignal, length(noisy), 1);
        end

        signal = removeReference(signal, referenceOut.referenceSignal, ...
            referenceOut.rereferencedChannels);     
        referenceOut.noisyStatistics = ...
            findNoisyChannels(removeTrend(signal, referenceOut), referenceOut);
    end

   function [] = doRobustPost()
        % Robust reference with interpolation afterwards
        referenceOut = robustReference(signal, referenceOut);
        noisy = referenceOut.interpolatedChannels.all;
        if isempty(noisy)   %No noisy channels -- ordinary ref
            referenceOut.referenceSignal = ...
                nanmean(signal.data(referenceOut.referenceChannels, :), 1);
        else
            sourceChannels = setdiff(referenceOut.evaluationChannels, noisy);
            signalNew = interpolateChannels(signal, noisy, sourceChannels);
            referenceOut.referenceSignal = ...
                nanmean(signalNew.data(referenceOut.referenceChannels, :), 1);
            clear signalNew;
        end
        signal = removeReference(signal, referenceOut.referenceSignal, ...
                                 referenceOut.rereferencedChannels);
        referenceOut.noisyStatistics  = ...
                findNoisyChannels(removeTrend(signal, referenceOut), referenceOut);
 
        referenceOut.noisyStatisticsBeforeInterpolation = ...
                referenceOut.noisyStatistics;
        %% Bring forward unusable channels from original data
        noisy = referenceOut.noisyStatisticsOriginal.noisyChannels;
        unusableChans = union(noisy.badChannelsFromNaNs, ...
             union(noisy.badChannelsFromNoData, ...
             noisy.badChannelsFromLowSNR));
        intChans = referenceOut.noisyStatistics.noisyChannels;
        chans = union(intChans.all, unusableChans);
        intChans.all = chans(:)';    
        chans = union(intChans.badChannelsFromNaNs, noisy.badChannelsFromNaNs);
        intChans.badChannelsFromNaNs = chans(:)';
        chans = union(intChans.badChannelsFromNoData, noisy.badChannelsFromNoData);
        intChans.badChannelsFromNoData = chans(:)';
        chans = union(intChans.badChannelsFromLowSNR, noisy.badChannelsFromLowSNR);
        intChans.badChannelsFromLowSNR = chans(:)';
        referenceOut.interpolatedChannels = intChans;
        
        %% Now find the bad channels and interpolate
        %referenceOut.noisyStatisticsForReference = noisyStatistics;
        noisyChans = referenceOut.interpolatedChannels.all;
        if isempty(noisyChans)
            return;
        end
        bad = signal.data(noisyChans, :);
        sourceChannels = setdiff(referenceOut.evaluationChannels, noisyChans);
        signal = interpolateChannels(signal, noisyChans, sourceChannels);
        newReference = nanmean(signal.data(referenceOut.referenceChannels, :), 1);
        referenceOut.badSignalsUninterpolated = ...
            bad - repmat(newReference, length(noisyChans), 1);
        referenceOut.referenceSignal = referenceOut.referenceSignal + newReference;
        signal = removeReference(signal, newReference, ...
                                 referenceOut.rereferencedChannels);
        referenceOut.noisyStatistics  = ...
            findNoisyChannels(removeTrend(signal, referenceOut), referenceOut);
   end

end
