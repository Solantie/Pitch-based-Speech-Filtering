classdef v4_PitchMaskApp < handle
    % PitchMaskApp
    % GUI for frame-based and segment-based pitch-threshold speech masking.
    %
    % Requires: MATLAB + Audio Toolbox (pitch, detectSpeech).
    % Usage: save as PitchMaskApp.m, then run:
    %   app = PitchMaskApp;
    %
    % "Overlap" is reported in three complementary ways:
    %   1) Mask coverage: proportion of samples retained by the binary mask.
    %   2) Energy retention: output energy / original energy.
    %   3) Normalized correlation: waveform similarity between input and output.

    properties
        UIFigure                 matlab.ui.Figure
        MainGrid                 matlab.ui.container.GridLayout
        ControlPanel             matlab.ui.container.Panel
        PlotPanel                matlab.ui.container.Panel

        LoadButton               matlab.ui.control.Button
        FileLabel                matlab.ui.control.Label
        MethodDropDown           matlab.ui.control.DropDown
        PitchMethodDropDown      matlab.ui.control.DropDown
        MedianFilterField        matlab.ui.control.NumericEditField
        HRThresholdField          matlab.ui.control.NumericEditField
        TargetDropDown           matlab.ui.control.DropDown
        WindowField              matlab.ui.control.NumericEditField
        HopField                 matlab.ui.control.NumericEditField
        ThresholdField           matlab.ui.control.NumericEditField
        RunButton                matlab.ui.control.Button
        PlayOriginalButton       matlab.ui.control.Button
        PlayOutputButton         matlab.ui.control.Button
        SaveButton               matlab.ui.control.Button
        ExportAnalysisButton      matlab.ui.control.Button
        MetricsLabel             matlab.ui.control.TextArea
        StatusLabel              matlab.ui.control.Label

        WaveAxes                 matlab.ui.control.UIAxes
        PitchAxes                matlab.ui.control.UIAxes
        HRAxes                   matlab.ui.control.UIAxes
        MaskAxes                 matlab.ui.control.UIAxes

        x double = []
        fs double = []
        y double = []
        mask logical = []
        f0 double = []
        tF0 double = []
        hr double = []
        validFrames logical = []
        keepDecision logical = []
        roi double = []
        segmentInfo double = [] % [startSample endSample medianF0 keepFlag]
        audioFile char = ''
    end

    methods
        function app = v4_PitchMaskApp
            createComponents(app);
            app.StatusLabel.Text = "Load an audio file to begin.";
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure( ...
                'Name','Pitch-Based Speech Masking', ...
                'Position',[100 100 1450 850]);

            app.MainGrid = uigridlayout(app.UIFigure,[1 2]);
            app.MainGrid.ColumnWidth = {350,'1x'};
            app.MainGrid.Padding = [10 10 10 10];
            app.MainGrid.ColumnSpacing = 10;

            app.ControlPanel = uipanel(app.MainGrid,'Title','Controls','Scrollable','on');
            app.ControlPanel.Layout.Row = 1;
            app.ControlPanel.Layout.Column = 1;
            controlGrid = uigridlayout(app.ControlPanel,[22 1]);
            controlGrid.RowHeight = {28,38,18,34,18,34,18,34,18,34,18,34,18,34,18,34,18,34,38,68,'1x',140};
            controlGrid.Padding = [8 8 8 8];
            controlGrid.RowSpacing = 6;

            app.LoadButton = uibutton(controlGrid,'push', ...
                'Text','Load audio file', ...
                'ButtonPushedFcn',@(~,~)loadAudio(app));
            app.LoadButton.Layout.Row = 1;

            app.FileLabel = uilabel(controlGrid, ...
                'Text','No file selected', ...
                'WordWrap','on', ...
                'FontAngle','italic');
            app.FileLabel.Layout.Row = 2;

            uilabel(controlGrid,'Text','Masking strategy');
            app.MethodDropDown = uidropdown(controlGrid, ...
                'Items',{'Frame-based','Segment-based'}, ...
                'Value','Segment-based');

            uilabel(controlGrid,'Text','Pitch estimation algorithm');
            app.PitchMethodDropDown = uidropdown(controlGrid, ...
                'Items',{'NCF','PEF','CEP','LHS','SRH'}, ...
                'Value','NCF');

            uilabel(controlGrid,'Text','Median filter length (frames)');
            app.MedianFilterField = uieditfield(controlGrid,'numeric', ...
                'Value',10,'Limits',[1 101], ...
                'RoundFractionalValues','on');

            uilabel(controlGrid,'Text','Minimum harmonic ratio (HR)');
            app.HRThresholdField = uieditfield(controlGrid,'numeric', ...
                'Value',0.5,'Limits',[0 1]);

            uilabel(controlGrid,'Text','Speech to retain');
            app.TargetDropDown = uidropdown(controlGrid, ...
                'Items',{'Keep male voice','Keep female voice'}, ...
                'Value','Keep male voice');

            uilabel(controlGrid,'Text','Pitch window length (ms)');
            app.WindowField = uieditfield(controlGrid,'numeric', ...
                'Value',40,'Limits',[10 200], ...
                'RoundFractionalValues','on');

            uilabel(controlGrid,'Text','Pitch hop length (ms)');
            app.HopField = uieditfield(controlGrid,'numeric', ...
                'Value',10,'Limits',[1 100], ...
                'RoundFractionalValues','on');

            uilabel(controlGrid,'Text','Frequency threshold (Hz)');
            app.ThresholdField = uieditfield(controlGrid,'numeric', ...
                'Value',165,'Limits',[50 400], ...
                'RoundFractionalValues','on');

            app.RunButton = uibutton(controlGrid,'push', ...
                'Text','Run masking and plot results', ...
                'FontWeight','bold', ...
                'ButtonPushedFcn',@(~,~)runAnalysis(app));
            app.RunButton.Layout.Row = 19;

            actionGrid = uigridlayout(controlGrid,[2 2]);
            actionGrid.Layout.Row = 20;
            actionGrid.Layout.Column = 1;
            actionGrid.RowHeight = {'1x','1x'};
            actionGrid.ColumnWidth = {'1x','1x'};
            actionGrid.Padding = [0 0 0 0];
            actionGrid.RowSpacing = 6;
            actionGrid.ColumnSpacing = 6;

            app.PlayOriginalButton = uibutton(actionGrid,'push', ...
                'Text','Play original', ...
                'Enable','off', ...
                'ButtonPushedFcn',@(~,~)playOriginal(app));
            app.PlayOriginalButton.Layout.Row = 1;
            app.PlayOriginalButton.Layout.Column = 1;

            app.PlayOutputButton = uibutton(actionGrid,'push', ...
                'Text','Play masked', ...
                'Enable','off', ...
                'ButtonPushedFcn',@(~,~)playOutput(app));
            app.PlayOutputButton.Layout.Row = 1;
            app.PlayOutputButton.Layout.Column = 2;

            app.SaveButton = uibutton(actionGrid,'push', ...
                'Text','Save audio', ...
                'Enable','off', ...
                'ButtonPushedFcn',@(~,~)saveOutput(app));
            app.SaveButton.Layout.Row = 2;
            app.SaveButton.Layout.Column = 1;

            app.ExportAnalysisButton = uibutton(actionGrid,'push', ...
                'Text','Export F0/HR table', ...
                'Enable','off', ...
                'ButtonPushedFcn',@(~,~)exportAnalysisTable(app));
            app.ExportAnalysisButton.Layout.Row = 2;
            app.ExportAnalysisButton.Layout.Column = 2;

            app.MetricsLabel = uitextarea(controlGrid, ...
                'Editable','off', ...
                'Value',{'Metrics will appear here.'}, ...
                'FontName','Consolas');
            app.MetricsLabel.Layout.Row = 22;

            app.PlotPanel = uipanel(app.MainGrid,'Title','Analysis and visualization');
            app.PlotPanel.Layout.Row = 1;
            app.PlotPanel.Layout.Column = 2;
            plotGrid = uigridlayout(app.PlotPanel,[5 1]);
            plotGrid.RowHeight = {'1x','1x','0.75x','0.7x',26};
            plotGrid.Padding = [10 10 10 10];

            app.WaveAxes = uiaxes(plotGrid);
            title(app.WaveAxes,'Waveforms: original and masked output');
            xlabel(app.WaveAxes,'Time (s)');
            ylabel(app.WaveAxes,'Amplitude');
            grid(app.WaveAxes,'on');

            app.PitchAxes = uiaxes(plotGrid);
            title(app.PitchAxes,'Pitch contour and threshold');
            xlabel(app.PitchAxes,'Time (s)');
            ylabel(app.PitchAxes,'F0 (Hz)');
            grid(app.PitchAxes,'on');

            app.HRAxes = uiaxes(plotGrid);
            title(app.HRAxes,'Harmonic ratio and reliability threshold');
            xlabel(app.HRAxes,'Time (s)');
            ylabel(app.HRAxes,'HR');
            ylim(app.HRAxes,[0 1]);
            grid(app.HRAxes,'on');

            app.MaskAxes = uiaxes(plotGrid);
            title(app.MaskAxes,'Binary sample mask');
            xlabel(app.MaskAxes,'Time (s)');
            ylabel(app.MaskAxes,'Keep');
            ylim(app.MaskAxes,[-0.1 1.1]);
            yticks(app.MaskAxes,[0 1]);
            grid(app.MaskAxes,'on');

            app.StatusLabel = uilabel(plotGrid, ...
                'Text','', ...
                'HorizontalAlignment','left', ...
                'FontAngle','italic');
        end

        function loadAudio(app)
            [file,path] = uigetfile( ...
                {'*.wav;*.mp3;*.m4a;*.flac','Audio files (*.wav, *.mp3, *.m4a, *.flac)'; ...
                 '*.*','All files (*.*)'}, ...
                'Select an audio file');
            if isequal(file,0)
                return
            end

            try
                [x,fs] = audioread(fullfile(path,file));
                if size(x,2) > 1
                    x = mean(x,2); % mono mix for pitch estimation
                end
                x = x(:);
                if isempty(x) || all(x == 0)
                    uialert(app.UIFigure,'The selected file contains no usable audio samples.','Audio error');
                    return
                end
                peak = max(abs(x));
                if peak > 1
                    x = x/peak;
                end

                app.x = x;
                app.fs = fs;
                app.y = [];
                app.mask = [];
                app.f0 = [];
                app.tF0 = [];
                app.hr = [];
                app.validFrames = [];
                app.keepDecision = [];
                app.roi = [];
                app.segmentInfo = [];
                app.audioFile = fullfile(path,file);

                app.FileLabel.Text = sprintf('%s\n%.2f s, %d Hz',file,numel(x)/fs,fs);
                app.PlayOriginalButton.Enable = 'on';
                app.PlayOutputButton.Enable = 'off';
                app.SaveButton.Enable = 'off';
                app.ExportAnalysisButton.Enable = 'off';
                app.MetricsLabel.Value = {'Audio loaded. Choose parameters and run analysis.'};
                app.StatusLabel.Text = 'Audio loaded successfully.';

                plotInitialAudio(app);
            catch ME
                uialert(app.UIFigure,ME.message,'Could not load audio');
            end
        end

        function runAnalysis(app)
            if isempty(app.x)
                uialert(app.UIFigure,'Please load an audio file first.','No audio loaded');
                return
            end

            try
                winMs = app.WindowField.Value;
                hopMs = app.HopField.Value;
                threshold = app.ThresholdField.Value;
                pitchMethod = app.PitchMethodDropDown.Value;
                medianFilterLength = round(app.MedianFilterField.Value);
                hrThreshold = app.HRThresholdField.Value;

                if hopMs >= winMs
                    uialert(app.UIFigure, ...
                        'Hop length must be smaller than window length.', ...
                        'Invalid analysis parameters');
                    return
                end

                if medianFilterLength < 1
                    uialert(app.UIFigure, ...
                        'Median filter length must be at least 1 frame.', ...
                        'Invalid analysis parameters');
                    return
                end

                win = round(winMs/1000 * app.fs);
                hop = round(hopMs/1000 * app.fs);
                overlap = win - hop;

                if win < 3 || win > numel(app.x)
                    uialert(app.UIFigure, ...
                        'The selected window is not compatible with this audio duration.', ...
                        'Invalid analysis parameters');
                    return
                end

                app.StatusLabel.Text = sprintf('Estimating pitch contour with %s...',pitchMethod);
                drawnow

                [f0,idxF0] = pitch(app.x,app.fs, ...
                    Method=pitchMethod, ...
                    WindowLength=win, ...
                    OverlapLength=overlap, ...
                    Range=[50 400], ...
                    MedianFilterLength=medianFilterLength);
                f0 = f0(:);
                % pitch returns frame locations as sample indices.
                tF0 = idxF0(:)/app.fs;

                % Compute harmonic ratio with the same window and overlap as pitch,
                % then map HR values to the pitch-frame time locations.
                hrRaw = harmonicRatio(app.x,app.fs, ...
                    Window=hamming(win,'periodic'), ...
                    OverlapLength=overlap);
                hrRaw = hrRaw(:);
                hopSamples = win - overlap;
                tHR = ((0:numel(hrRaw)-1)'*hopSamples + floor(win/2)) / app.fs;
                if numel(hrRaw) == 1
                    hr = repmat(hrRaw,size(tF0));
                else
                    hr = interp1(tHR,hrRaw,tF0,'nearest','extrap');
                end

                % A pitch frame is reliable only if it has a finite positive F0
                % and sufficient harmonic structure.
                valid = isfinite(f0) & f0 > 0 & isfinite(hr) & hr >= hrThreshold;
                keepDecision = false(size(f0));
                if strcmp(app.TargetDropDown.Value,'Keep male voice')
                    keepDecision(valid) = f0(valid) <= threshold;
                else
                    keepDecision(valid) = f0(valid) >= threshold;
                end

                % Store frame-level analysis before constructing the mask so that
                % helper methods and later inspection/export use the current run.
                app.f0 = f0;
                app.tF0 = tF0;
                app.hr = hr;
                app.validFrames = valid;
                app.keepDecision = keepDecision;

                if strcmp(app.MethodDropDown.Value,'Frame-based')
                    [mask,roi,segmentInfo] = frameMask(app,keepDecision,valid,win);
                else
                    [mask,roi,segmentInfo] = segmentMask(app,f0,tF0,valid,threshold,win,overlap);
                end

                app.mask = logical(mask);
                app.y = app.x .* double(app.mask);
                app.roi = roi;
                app.segmentInfo = segmentInfo;

                plotResults(app,threshold);
                updateMetrics(app);

                app.PlayOutputButton.Enable = 'on';
                app.SaveButton.Enable = 'on';
                app.ExportAnalysisButton.Enable = 'on';
                app.StatusLabel.Text = 'Done. Use the plots to inspect the pitch decisions and final mask.';
            catch ME
                app.StatusLabel.Text = 'Analysis stopped because MATLAB returned an error.';
                uialert(app.UIFigure,ME.message,'Analysis error');
            end
        end

        function [mask,roi,segmentInfo] = frameMask(app,keepDecision,valid,win)
            n = numel(app.x);
            mask = false(n,1);
            roi = zeros(0,2);
            segmentInfo = zeros(0,4);

            % Map each F0 frame to a centered sample interval.
            centers = round(app.tF0*app.fs) + 1;
            halfWin = floor(win/2);

            for k = 1:numel(keepDecision)
                if ~valid(k) || ~keepDecision(k)
                    continue
                end
                startSamp = max(1,centers(k)-halfWin);
                endSamp = min(n,centers(k)+halfWin-1);
                mask(startSamp:endSamp) = true;
            end
        end

        function [mask,roi,segmentInfo] = segmentMask(app,f0,tF0,valid,threshold,win,overlap)
            n = numel(app.x);

            % detectSpeech uses energy and spectral-spread cues. The same
            % analysis window/hop is supplied so its temporal resolution
            % remains consistent with the displayed pitch contour.
            try
                roi = detectSpeech(app.x,app.fs, ...
                    Window=hamming(win,"periodic"), ...
                    OverlapLength=overlap, ...
                    MergeDistance=round(0.15*app.fs));
            catch
                % Compatibility fallback for releases without detectSpeech
                % or for unusually short / problematic recordings.
                roi = fallbackVAD(app,win,overlap);
            end

            if isempty(roi)
                roi = zeros(0,2);
            end

            roi = round(roi);
            roi(:,1) = max(1,roi(:,1));
            roi(:,2) = min(n,roi(:,2));
            roi = roi(roi(:,2) >= roi(:,1),:);

            mask = false(n,1);
            segmentInfo = zeros(size(roi,1),4);

            for s = 1:size(roi,1)
                startSamp = roi(s,1);
                endSamp = roi(s,2);
                startTime = (startSamp-1)/app.fs;
                endTime = (endSamp-1)/app.fs;

                % Segment-level decision: median of valid F0 values inside
                % the VAD segment. If no valid F0 exists, reject the segment.
                inSegment = (tF0 >= startTime) & (tF0 <= endTime) & valid;
                segmentF0 = f0(inSegment);

                if isempty(segmentF0)
                    medianF0 = NaN;
                    keep = false;
                else
                    medianF0 = median(segmentF0,'omitnan');
                    if strcmp(app.TargetDropDown.Value,'Keep male voice')
                        keep = medianF0 <= threshold;
                    else
                        keep = medianF0 >= threshold;
                    end
                end

                if keep
                    mask(startSamp:endSamp) = true;
                end

                segmentInfo(s,:) = [startSamp,endSamp,medianF0,double(keep)];
            end
        end

        function roi = fallbackVAD(app,win,overlap)
            hop = win - overlap;
            x = app.x;
            n = numel(x);
            starts = 1:hop:max(1,n-win+1);
            energy = zeros(numel(starts),1);

            for k = 1:numel(starts)
                idx = starts(k):min(n,starts(k)+win-1);
                energy(k) = mean(x(idx).^2);
            end

            % A simple relative-energy detector. This only runs if
            % detectSpeech is unavailable or cannot process the input.
            threshold = max(median(energy)*3, 0.02*max(energy));
            active = energy > threshold;

            roi = zeros(0,2);
            k = 1;
            while k <= numel(active)
                if ~active(k)
                    k = k + 1;
                    continue
                end
                first = k;
                while k <= numel(active) && active(k)
                    k = k + 1;
                end
                last = k - 1;
                roi(end+1,:) = [starts(first), min(n,starts(last)+win-1)]; %#ok<AGROW>
            end

            % Merge nearby active islands separated by <= 150 ms.
            mergeGap = round(0.15*app.fs);
            if size(roi,1) > 1
                merged = roi(1,:);
                for k = 2:size(roi,1)
                    if roi(k,1) - merged(end,2) <= mergeGap
                        merged(end,2) = roi(k,2);
                    else
                        merged(end+1,:) = roi(k,:); %#ok<AGROW>
                    end
                end
                roi = merged;
            end
        end

        function plotInitialAudio(app)
            t = (0:numel(app.x)-1)'/app.fs;
            cla(app.WaveAxes);
            plot(app.WaveAxes,t,app.x);
            title(app.WaveAxes,'Original waveform');
            xlabel(app.WaveAxes,'Time (s)');
            ylabel(app.WaveAxes,'Amplitude');
            grid(app.WaveAxes,'on');

            cla(app.PitchAxes);
            title(app.PitchAxes,'Pitch contour will appear after analysis');
            xlabel(app.PitchAxes,'Time (s)');
            ylabel(app.PitchAxes,'F0 (Hz)');
            grid(app.PitchAxes,'on');

            cla(app.HRAxes);
            title(app.HRAxes,'Harmonic ratio will appear after analysis');
            xlabel(app.HRAxes,'Time (s)');
            ylabel(app.HRAxes,'HR');
            ylim(app.HRAxes,[0 1]);
            grid(app.HRAxes,'on');

            cla(app.MaskAxes);
            title(app.MaskAxes,'Binary sample mask will appear after analysis');
            xlabel(app.MaskAxes,'Time (s)');
            ylabel(app.MaskAxes,'Keep');
            ylim(app.MaskAxes,[-0.1 1.1]);
            yticks(app.MaskAxes,[0 1]);
            grid(app.MaskAxes,'on');
        end

        function plotResults(app,threshold)
            t = (0:numel(app.x)-1)'/app.fs;

            % Waveform comparison
            cla(app.WaveAxes);
            plot(app.WaveAxes,t,app.x,'DisplayName','Original');
            hold(app.WaveAxes,'on');
            plot(app.WaveAxes,t,app.y,'LineWidth',1.1,'DisplayName','Masked output');
            hold(app.WaveAxes,'off');
            legend(app.WaveAxes,'Location','best');
            title(app.WaveAxes,'Waveforms: original and masked output');
            xlabel(app.WaveAxes,'Time (s)');
            ylabel(app.WaveAxes,'Amplitude');
            grid(app.WaveAxes,'on');

            % Pitch and threshold
            cla(app.PitchAxes);
            valid = isfinite(app.f0) & app.f0 > 0;
            plot(app.PitchAxes,app.tF0(valid),app.f0(valid),'.-','DisplayName','Valid F0');
            hold(app.PitchAxes,'on');
            yline(app.PitchAxes,threshold,'--','Threshold','DisplayName','Threshold');

            % Display segment medians to make segment-level decisions visible.
            if strcmp(app.MethodDropDown.Value,'Segment-based') && ~isempty(app.segmentInfo)
                centers = mean(app.segmentInfo(:,1:2),2)/app.fs;
                segF0 = app.segmentInfo(:,3);
                keep = logical(app.segmentInfo(:,4));
                good = isfinite(segF0);
                plot(app.PitchAxes,centers(good & keep),segF0(good & keep),'o', ...
                    'MarkerSize',7,'LineWidth',1.2,'DisplayName','Kept segment median F0');
                plot(app.PitchAxes,centers(good & ~keep),segF0(good & ~keep),'x', ...
                    'MarkerSize',7,'LineWidth',1.2,'DisplayName','Rejected segment median F0');
            end

            hold(app.PitchAxes,'off');
            title(app.PitchAxes,sprintf('Pitch contour — %s pitch, %s mask',app.PitchMethodDropDown.Value,app.MethodDropDown.Value));
            xlabel(app.PitchAxes,'Time (s)');
            ylabel(app.PitchAxes,'F0 (Hz)');
            ylim(app.PitchAxes,[40 420]);
            legend(app.PitchAxes,'Location','best');
            grid(app.PitchAxes,'on');

            % Harmonic ratio and reliability threshold
            cla(app.HRAxes);
            if ~isempty(app.hr)
                plot(app.HRAxes,app.tF0,app.hr,'.-','DisplayName','HR');
                hold(app.HRAxes,'on');
                yline(app.HRAxes,app.HRThresholdField.Value,'--','HR threshold', ...
                    'DisplayName','HR threshold');
                if ~isempty(app.validFrames)
                    invalid = ~app.validFrames;
                    plot(app.HRAxes,app.tF0(invalid),app.hr(invalid),'x', ...
                        'DisplayName','Invalid frame');
                end
                hold(app.HRAxes,'off');
            end
            title(app.HRAxes,'Harmonic ratio and frame validity');
            xlabel(app.HRAxes,'Time (s)');
            ylabel(app.HRAxes,'HR');
            ylim(app.HRAxes,[0 1]);
            legend(app.HRAxes,'Location','best');
            grid(app.HRAxes,'on');

            % Binary sample mask
            cla(app.MaskAxes);
            stairs(app.MaskAxes,t,double(app.mask),'LineWidth',1);
            title(app.MaskAxes,'Binary sample mask (1 = retained, 0 = muted)');
            xlabel(app.MaskAxes,'Time (s)');
            ylabel(app.MaskAxes,'Keep');
            ylim(app.MaskAxes,[-0.1 1.1]);
            yticks(app.MaskAxes,[0 1]);
            grid(app.MaskAxes,'on');
        end

        function updateMetrics(app)
            maskCoverage = 100*mean(app.mask);
            originalEnergy = sum(app.x.^2);
            outputEnergy = sum(app.y.^2);
            energyRetention = 100*outputEnergy/max(originalEnergy,eps);

            if norm(app.y) < eps || norm(app.x) < eps
                corrValue = NaN;
            else
                corrValue = (app.x' * app.y)/(norm(app.x)*norm(app.y));
            end

            if strcmp(app.MethodDropDown.Value,'Segment-based')
                nSegments = size(app.segmentInfo,1);
                nKept = sum(app.segmentInfo(:,4) > 0);
                segmentLine = sprintf('VAD segments: %d total, %d retained',nSegments,nKept);
            else
                nFrames = numel(app.f0);
                nKept = sum(app.mask) > 0; %#ok<NASGU>
                segmentLine = sprintf('Pitch frames: %d total',nFrames);
            end

            app.MetricsLabel.Value = {
                sprintf('Pitch algorithm:     %s',app.PitchMethodDropDown.Value)
                sprintf('Median filter:       %d frames',round(app.MedianFilterField.Value))
                sprintf('HR threshold:        %.2f',app.HRThresholdField.Value)
                sprintf('Valid pitch frames:  %d / %d',sum(app.validFrames),numel(app.validFrames))
                sprintf('HR threshold:        %.2f',app.HRThresholdField.Value)
                sprintf('Mask coverage:       %6.2f %%',maskCoverage)
                sprintf('Energy retention:    %6.2f %%',energyRetention)
                sprintf('Normalized correlation: %5.3f',corrValue)
                ' '
                segmentLine
                ' '
                'Correlation measures waveform similarity;'
                'energy retention shows how much signal'
                'energy remains after masking.'
                };
        end

        function playOriginal(app)
            if ~isempty(app.x)
                sound(app.x,app.fs);
                app.StatusLabel.Text = 'Playing original audio.';
            end
        end

        function playOutput(app)
            if ~isempty(app.y)
                sound(app.y,app.fs);
                app.StatusLabel.Text = 'Playing masked output.';
            end
        end

        function exportAnalysisTable(app)
            if isempty(app.f0) || isempty(app.hr) || isempty(app.validFrames)
                uialert(app.UIFigure,'Run the analysis before exporting.','No analysis available');
                return
            end

            [file,path] = uiputfile('*.csv','Export F0 / HR / valid table');
            if isequal(file,0)
                return
            end

            f0Positive = isfinite(app.f0) & app.f0 > 0;
            hrPass = isfinite(app.hr) & app.hr >= app.HRThresholdField.Value;

            T = table( ...
                app.tF0(:), ...
                app.f0(:), ...
                app.hr(:), ...
                f0Positive(:), ...
                hrPass(:), ...
                app.validFrames(:), ...
                app.keepDecision(:), ...
                'VariableNames',{'Time_s','F0_Hz','HR','F0_Positive','HR_Pass','Valid','KeepDecision'});

            try
                writetable(T,fullfile(path,file));
                app.StatusLabel.Text = sprintf('Analysis table exported: %s',fullfile(path,file));
            catch ME
                uialert(app.UIFigure,ME.message,'Could not export analysis table');
            end
        end

        function saveOutput(app)
            if isempty(app.y)
                return
            end

            [file,path] = uiputfile('*.wav','Save masked audio as');
            if isequal(file,0)
                return
            end

            try
                audiowrite(fullfile(path,file),app.y,app.fs);
                app.StatusLabel.Text = sprintf('Saved: %s',fullfile(path,file));
            catch ME
                uialert(app.UIFigure,ME.message,'Could not save audio');
            end
        end
    end
end
