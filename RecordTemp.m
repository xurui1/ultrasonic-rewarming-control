% RECORDTEMP
%
% Script to record thermocouple temperature measurements across a
% predetermined timespan. Requires the PICO T-08 data logger and associated
% code on the path
%
% ABOUT:    
%     Author: Rui Xu
%     Date: 08/11/2024
%     Last Modified: 13/01/25

clearvars;


%% connect to thermocouple via TC-08 data logger, requires download:
% https://uk.mathworks.com/matlabcentral/fileexchange/41800-pico-technology-tc-08-usb-data-acquisition
addpath(genpath('usbtc08'));
numthermocouples = 4;
thermostring = '';
for i = 1:numthermocouples
    thermostring  = append(thermostring, 'T');
end
t_handle = usbtc08connect(thermostring, 'C:\Program Files\Pico Technology\SDK');

% Initialize loop variables
Ts = 1;           % Sampling period [s]

% allocate empty array for recording variables
dataArray = zeros(2e3, 1 + numthermocouples); 

% Define warming time
max_time = 1200; % [s]

% start timer
tic;

%% Main loop for temperature recording
figure; hold on; xlabel('Time [s]'); ylabel('Temperature');
loopNum = 1;
while toc < max_time 

    % trigger themocouple measurement
    tdat = usbtc08query(t_handle);
    if ~isnan(sum(tdat(1:numthermocouples)))
        time = toc;
        % plot thermocouple data
        t_vec = [];
        for i = 1:numthermocouples
            t_vec = [t_vec time];
        end
        scatter(t_vec, tdat(1:numthermocouples));

        % insert pause if needed
        if (toc - time) <= Ts
            pause(Ts - (toc-time));
        end

        % record temperature data
        dataArray(loopNum, :) = [time, tdat(1:numthermocouples)'];

        % iterate loop number
        loopNum = loopNum + 1;
    end
end

% disconnect from thermocouple
usbtc08disconnect(t_handle);