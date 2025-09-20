%% BatchColoc  Imaris batch for fluorescent signal colocalization
%
% A custom MATLAB script for proliferated cancer cell fluorescent signal 
% colocalization. 
% 
% This script works independently from Imaris as an Imaris extention. It 
% requires the user to have a good level of familiarity with Imaris.
% The general workflow can be summaried as follows:
%   - Preprocessing: background subtration
%   - Create surfaces for fluorescent signals from each channel
%   - Create masks from Surfaces created above
%   - Create surfaces for colocalized signals (both double and triple coloc)
%   - Export statistics 
%
% Parameters:
%   - Users need to modify parameters in section "Create surfaces for each
%     channel" and "Create colocalization surfaces" accordingly.

% Preconditions:
%   - ImarisLib.jar (which normally locates in the XTensions folder in the
%     Imaris installation directory) needs to be put in the same folder.
%   - Imaris needs to be running when executing the following code. 

%% 
clc; clear
%% Get the image folder. Only read *.ims images.
infolder = uigetdir;
if strcmp(computer, 'MACI64')
    files = [infolder '/*.ims'];
elseif strcmp(computer, 'PCWIN64')
    files = [infolder '\*.ims'];
else
    err('not Windows or Mac')
end
listing = dir(files);
nfiles = size(listing,1);

%% Open files in Imaris sequentially
for i = 1:nfiles
    if strcmp(computer, 'MACI64')
        filename = [infolder '/' listing(i).name];
        filename = sprintf(filename);
    elseif strcmp(computer, 'PCWIN64')
        filename = [infolder '\' listing(i).name];
        filename = string(filename);
    end
    
    vImarisApplication = StartImaris;
    vImarisApplication.FileOpen(filename,'');
    
    %Get dataset in Matlab
    vDataSet = vImarisApplication.GetDataSet;
    
    %Get dataset size
	aSizeC = vDataSet.GetSizeC;	% number of channels
	aSizeX = vDataSet.GetSizeX; % number of pixels
	aSizeY = vDataSet.GetSizeY;	
	aSizeZ = vDataSet.GetSizeZ;
	aSizeT = vDataSet.GetSizeT; % number of time points
	aExtendMinX = vDataSet.GetExtendMinX;
	aExtendMinY = vDataSet.GetExtendMinY;
	aExtendMinZ = vDataSet.GetExtendMinZ;
	aExtendMaxX = vDataSet.GetExtendMaxX;
	aExtendMaxY = vDataSet.GetExtendMaxY;
	aExtendMaxZ = vDataSet.GetExtendMaxZ;
	
    %% Preprocessing: Apply background subtraciton
    %Caution: this will directly replace the current dataset with the filtered one in vImarisApplication.GetDataSet.
    vSigma=512;
    vChannelIndex = 0;
    vImarisApplication.GetImageProcessing.SubtractBackgroundChannel(vDataSet,vChannelIndex,vSigma);
    
    %% Create surfaces for each channel
    ip = vImarisApplication.GetImageProcessing;
    
    %Create Surfaces for red
    ROI = []; %process the entire image
    ChannelIndex = 0;
    SmoothFilterWidth = 1;
    LocalContrastFilterWidth = 10;
    IntensityThresholdAuto = 0;
    IntensityThresholdManual = 500;
    SeedsEstimateDiameter = 9.5;
    SeedsSubtractBackground = 1; 
    SeedsFiltersString = '"Quality" above 288';
    SurfaceFiltersString = '"Area" between 100 um^2 and 1062 um^2';
    vNewSurfaces_red = ip.DetectSurfacesRegionGrowing(vDataSet, ROI, ChannelIndex, SmoothFilterWidth, ...
        LocalContrastFilterWidth, IntensityThresholdAuto, IntensityThresholdManual, ...
        SeedsEstimateDiameter, SeedsSubtractBackground, SeedsFiltersString, SurfaceFiltersString);
    vNewSurfaces_red.SetName(sprintf('Surface for red channel'));
    vImarisApplication.GetSurpassScene.AddChild(vNewSurfaces_red,-1);

    %Create Surfaces for green
    ChannelIndex = 1;
    SmoothFilterWidth = 2;
    LocalContrastFilterWidth = 15;
    IntensityThresholdAuto = 0;
    IntensityThresholdManual = 250;
    SeedsEstimateDiameter = 13;
    SeedsSubtractBackground = 1;
    SeedsFiltersString = '"Quality" above 54.1';
    SurfaceFiltersString = ['"Number of Voxels" above 100', '"Intensity Mean Ch=2" above 700'];
    vNewSurfaces_green = ip.DetectSurfacesRegionGrowing(vDataSet, ROI, ChannelIndex, SmoothFilterWidth, ...
        LocalContrastFilterWidth, IntensityThresholdAuto, IntensityThresholdManual, ...
        SeedsEstimateDiameter, SeedsSubtractBackground, SeedsFiltersString, SurfaceFiltersString);    
    vNewSurfaces_green.SetName(sprintf('Surface for green channel'));
    vImarisApplication.GetSurpassScene.AddChild(vNewSurfaces_green,-1);
    
    %Create Surfaces for blue
    ChannelIndex = 2;
    SmoothFilterWidth = 3;
    LocalContrastFilterWidth = 20;
    IntensityThresholdAuto = 0;
    IntensityThresholdManual = 80;
    SeedsEstimateDiameter = 15;
    SeedsSubtractBackground = 1;
    SeedsFiltersString = '"Quality" above 93.8';
    SurfaceFiltersString = '"Number of Voxels" above 100';
    vNewSurfaces_blue = ip.DetectSurfacesRegionGrowing(vDataSet, ROI, ChannelIndex, SmoothFilterWidth, ...
        LocalContrastFilterWidth, IntensityThresholdAuto, IntensityThresholdManual, ...
        SeedsEstimateDiameter, SeedsSubtractBackground, SeedsFiltersString, SurfaceFiltersString);    
    vNewSurfaces_blue.SetName(sprintf('Surface for blue channel'));
    vImarisApplication.GetSurpassScene.AddChild(vNewSurfaces_blue,-1);
    
	%% Add additional channel for masking
	vImarisApplication.GetDataSet.SetSizeC(aSizeC+2);
    vDataSet = vImarisApplication.GetDataSet;
    TotalNumberofChannels = aSizeC+2;
    vGreenMaskChannel = TotalNumberofChannels-2;
    vRedMaskChannel = TotalNumberofChannels-1;
	vDataSet.SetChannelName(vGreenMaskChannel,'Mask_for_green');
	vDataSet.SetChannelName(vRedMaskChannel,'Mask_for_red');
    
    %Create mask from Surfaces for all time points
	for vTimeIndex = 0:aSizeT-1
		vMask_green = vNewSurfaces_green.GetMask(aExtendMinX,aExtendMinY,aExtendMinZ,aExtendMaxX,aExtendMaxY,aExtendMaxZ,aSizeX,aSizeY,aSizeZ,vTimeIndex); 
        vGreenMaskCh = vMask_green.GetDataVolumeBytes(0,vTimeIndex);
        vGreenMaskCh = vGreenMaskCh.*255;
        vMask_red = vNewSurfaces_red.GetMask(aExtendMinX,aExtendMinY,aExtendMinZ,aExtendMaxX,aExtendMaxY,aExtendMaxZ,aSizeX,aSizeY,aSizeZ,vTimeIndex); 
        vRedMaskCh = vMask_red.GetDataVolumeBytes(0,vTimeIndex);
        vRedMaskCh = vRedMaskCh.*255;
        vDataSet.SetDataSubVolumeBytes(vGreenMaskCh, 0, 0, 0, vGreenMaskChannel, vTimeIndex);
        vDataSet.SetDataSubVolumeBytes(vRedMaskCh, 0, 0, 0, vRedMaskChannel, vTimeIndex);
    end
    
    %% Create colocalization surfaces
    %Create Surfaces for DAPI colocalized with green (ch4)
    ChannelIndex = 2;
    SmoothFilterWidth = 3;
    LocalContrastFilterWidth = 20;
    IntensityThresholdAuto = 0;
    IntensityThresholdManual = 80;
    SeedsEstimateDiameter = 15;
    SeedsSubtractBackground = 1;
    SeedsFiltersString = '"Quality" above 93.8';
    SurfaceFiltersString = ['"Number of Voxels" above 100', '"Intensity Sum Ch=4" above 2.00e4'];
    vNewSurfaces_DAPI_green = ip.DetectSurfacesRegionGrowing(vDataSet, ROI, ChannelIndex, SmoothFilterWidth, ...
        LocalContrastFilterWidth, IntensityThresholdAuto, IntensityThresholdManual, ...
        SeedsEstimateDiameter, SeedsSubtractBackground, SeedsFiltersString, SurfaceFiltersString);    
    vNewSurfaces_DAPI_green.SetName(sprintf('Surface for blue colocalized with green'));
    vImarisApplication.GetSurpassScene.AddChild(vNewSurfaces_DAPI_green,-1);

    %Create Surfaces for DAPI colocalized with red (ch5)
    ChannelIndex = 2;
    SmoothFilterWidth = 3;
    LocalContrastFilterWidth = 20;
    IntensityThresholdAuto = 0;
    IntensityThresholdManual = 80;
    SeedsEstimateDiameter = 15;
    SeedsSubtractBackground = 1;
    SeedsFiltersString = '"Quality" above 93.8';
    SurfaceFiltersString = ['"Number of Voxels" above 100', '"Intensity Sum Ch=5" above 7000'];
    vNewSurfaces_DAPI_red = ip.DetectSurfacesRegionGrowing(vDataSet, ROI, ChannelIndex, SmoothFilterWidth, ...
        LocalContrastFilterWidth, IntensityThresholdAuto, IntensityThresholdManual, ...
        SeedsEstimateDiameter, SeedsSubtractBackground, SeedsFiltersString, SurfaceFiltersString);    
    vNewSurfaces_DAPI_red.SetName(sprintf('Surface for blue colocalized with red'));
    vImarisApplication.GetSurpassScene.AddChild(vNewSurfaces_DAPI_red,-1);
    
    %Create Surfaces for DAPI colocalized with green and red (ch4 and ch5)
    ChannelIndex = 2;
    SmoothFilterWidth = 3;
    LocalContrastFilterWidth = 20;
    IntensityThresholdAuto = 0;
    IntensityThresholdManual = 80;
    SeedsEstimateDiameter = 15;
    SeedsSubtractBackground = 1;
    SeedsFiltersString = '"Quality" above 93.8';
    SurfaceFiltersString = ['"Number of Voxels" above 100', '"Intensity Sum Ch=5" above 7000', '"Intensity Sum Ch=4" above 2.00e4'];
    vNewSurfaces_DAPI_red_green = ip.DetectSurfacesRegionGrowing(vDataSet, ROI, ChannelIndex, SmoothFilterWidth, ...
        LocalContrastFilterWidth, IntensityThresholdAuto, IntensityThresholdManual, ...
        SeedsEstimateDiameter, SeedsSubtractBackground, SeedsFiltersString, SurfaceFiltersString);    
    vNewSurfaces_DAPI_red_green.SetName(sprintf('Surface for blue colocalized with green and red'));
    vImarisApplication.GetSurpassScene.AddChild(vNewSurfaces_DAPI_red_green,-1);   
    %% Get statistics
	%get Surface stats 
    vSurpassComponent = vImarisApplication.GetSurpassSelection;
    vImarisObject = vImarisApplication.GetFactory.ToSurfaces(vSurpassComponent);
    vAllStatistics = vImarisObject.GetStatistics;
    
    vNames = cell(vAllStatistics.mNames);
    vValues = vAllStatistics.mValues;
    
    %All avaialable statistics 
    vUniqueName = unique(vNames);
    
    %Overall statistics
    vTotalSurfaceNumber = vValues(strmatch('Total Number of Surfaces', vNames),:);

%% Output .csv stats
    [file_path, file_name] = fileparts(filename);
    csv_DiameterX = strcat(file_path,'\',file_name,'_DiameterX.csv');
    writetable(DiameterX,csv_DiameterX);
    
    csv_IntensityMedian = strcat(file_path,'\',file_name,'_IntensityMedian.csv');
    writetable(IntensityMedian,csv_IntensityMedian);   
    
    csv_TrackDuration = strcat(file_path,'\',file_name,'_TrackDuration.csv');
    writetable(TrackDuration,csv_TrackDuration);      
    
    csv_TrackDisplacementLength = strcat(file_path,'\',file_name,'_TrackDisplacementLength.csv');
    writetable(TrackDisplacementLength,csv_TrackDisplacementLength);      
   
    csv_OverallStats = strcat(file_path,'\',file_name,'_OverallStats.csv');
    TotalNumOfSpotsVector = zeros(length(vSpotPerTime),1);
    TotalNumOfSpotsVector(1) = vTotalSpotNumber;
    sz = [length(vSpotPerTime) 2];
    varTypes = {'double', 'double'};
    OverallStats = table('Size', sz, ... 
                         'VariableTypes', varTypes, ...
                         'VariableNames',{'NumberOfSpotsPerTimepoint','TotalNumberOfSpots'});
    OverallStats(:,1) = num2cell(vSpotPerTime);
    OverallStats(:,2) = num2cell(TotalNumOfSpotsVector);
    writetable(OverallStats,csv_OverallStats); 
    
    %save ims file
    newFilename = strcat(filename(1:end-4),'new.ims');
    vImarisApplication.FileSave(newFilename,'');
    
    pause(5);     
end

%% Quit Imaris Application after all is done
vImarisApplication.SetVisible(~vImarisApplication.GetVisible);
vImarisApplication.Quit;
%%
function aImarisApplication = StartImaris
    javaaddpath ImarisLib.jar;
    vImarisLib = ImarisLib;
    server = vImarisLib.GetServer();
    id = server.GetObjectID(0);
    aImarisApplication = vImarisLib.GetApplication(id);
end
