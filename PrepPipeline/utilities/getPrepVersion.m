function [versionString, changeLog] = getPrepVersion()

versionString = 'PrepPipeline0.55.0'; 

changeLog = { ...
['Changed the EEG.etc.noiseDetection.reference structure to distinguish ' ...
  'between bad channels and interpolated channels (allow option to not ' ...
  'interpolate)']};