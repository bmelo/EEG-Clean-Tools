%% Read in the file and set the necessary parameters
datadir = 'N:\\ARLAnalysis\\RSVPStandardLevel2C';
summaryFolder = 'N:\\ARLAnalysis\\RSVPStandardLevel2ReportsC';
basename = 'rsvp';
summaryReportName = [basename '_summary.html'];
sessionFolder = '.';
reportSummary = [summaryFolder filesep summaryReportName];
if exist(reportSummary, 'file') 
   delete(reportSummary);
end

%% Run the pipeline
for k = [1:7, 9:15]
    thisFile = sprintf('%s_%02d', basename, k);
    sessionReportName = [thisFile '.pdf'];
    fname = [datadir filesep thisFile '.set'];
    load(fname, '-mat');
    publishLevel2Report(EEG, summaryFolder, summaryReportName, ...
                  sessionFolder, sessionReportName);
end
