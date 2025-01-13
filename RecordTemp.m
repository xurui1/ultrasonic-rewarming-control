%% Feedback loop script for ultrasonic rewarming with Tx driven by a keysight
% signal generator, amplified with an E&I 1020L 200W amplifier, with the
% electrical power monitored by a Rhode & Schwarz power reflection meter,
% and the cryovial temperature monitored with the PICO TC-08 data logger
%
% Author: Rui Xu
% Last Modified: 08/11/2024
clearvars; close all;


%% connect to thermocouple via TC-08 data logger, requires download:
% https://uk.mathworks.com/matlabcentral/fileexchange/41800-pico-technology-tc-08-usb-data-acquisition
addpath(genpath('usbtc08'));
addpath(genpath('./Results/ConstAmp/RateEXP/')); % for voltage to power
numthermocouples = 4;
thermostring = '';
for i = 1:numthermocouples
    thermostring  = append(thermostring, 'T');
end
t_handle = usbtc08connect(thermostring, 'C:\Program Files\Pico Technology\SDK');

% Initialize loop variables
Ts = 1;           % Sampling period [s]
loopNum = 1;

% allocate empty array for recording variables
dataArray = zeros(1e3, 1 + numthermocouples); 

% Define warming time
max_time = 1200; % [s]

% start timer
tic;

%% Main loop for temperature recording
figure; hold on; xlabel('Time [s]'); ylabel('Temperature');
cryovialtemp = 0;
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

        % record time, power, signal amplitude, and temperature data
        dataArray(loopNum, :) = [time, tdat(1:numthermocouples)'];

        % iterate loop number
        loopNum = loopNum + 1;
    end
end

% disconnect from thermocouple
usbtc08disconnect(t_handle);