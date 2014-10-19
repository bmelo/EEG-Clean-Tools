function [EEG, highPassOut] = highPassFilter(EEG, highPassIn)
% Perform a high-pass filter using EEGLAB pop_eegfiltnew FIR filter
%
% EEG = highPassFilter(EEG)
% [EEG, highPassOut = highPassFilter(EEG, highPassIn)
%
% Input:
%   EEG               Structure that requires .data and .srate fields 
%   highPassIn        Input structure with fields described below
% 
% Structure parameters (highPassIn):
%   highPassCutoff    High pass cutoff (default is 1 Hz)
%   highPassChannels  Vector of channels to filter
%
% Output:
%   EEG               Revised EEG structure channels filtered
%   highPassOut       Structure with the following items described below:
% 
% Structure parameters (highPassOut):
%   highPassCutoff    High pass cutoff (default is 1 Hz)
%   highPassChannels  Vector of channels to filter
%
%% Check the parameters
if nargin < 1 || ~isstruct(EEG)
    error('highPassFilter:NotEnoughArguments', 'first argument must be a structure');
elseif nargin < 2 || ~exist('highPassIn', 'var') || isempty(highPassIn)
    highPassIn = struct();
end
if ~isstruct(highPassIn)
    error('highPassFilter:NoData', 'second argument must be a structure')
end

highPassOut = struct('highPassChannels', [], 'highPassCutoff', [], ...
                     'highPassFilterCommand', []);
highPassOut.highPassChannels =  ...
    getStructureParameters(highPassIn, 'highPassChannels', 1:size(EEG.data, 1));
highPassOut.highPassCutoff =  ...
    getStructureParameters(highPassIn, 'highPassCutoff', 1);

%% Compute the high pass filter
EEG1 = EEG;
EEG1.data = EEG.data(highPassOut.highPassChannels, :);
[EEG1, highPassOut.highPassFilterCommand] = ...
    pop_eegfiltnew(EEG1, highPassOut.highPassCutoff, []);
EEG.data(highPassOut.highPassChannels, :) = EEG1.data;


