% REWARMINGCONSTAMP
% 
% Script for ultrasonic rewarming with Tx driven at a constant amplitude 
% by a keysight signal generator, amplified with an E&I 1020L 200W 
% amplifier, with the electrical power monitored by a Rhode & Schwarz power 
% reflection meter, and the cryovial temperature monitored with the PICO 
% TC-08 data logger
%
% This script will either continuously heat until the timer reaches the
% defined 'maximum time', or until the cryovial contents reach the defined
% 'maximum temperature'
%
% ABOUT:
%     Author: Rui Xu
%     Date: 08/11/24
%     Last Modified: 13/01/25

clearvars; close all;

%% connect to thermocouple via TC-08 data logger, requires download:
% https://uk.mathworks.com/matlabcentral/fileexchange/41800-pico-technology-tc-08-usb-data-acquisition
addpath(genpath('usbtc08'));
numthermocouples = 4;
thermostring = '';
for i = 1:numthermocouples
    thermostring  = append(thermostring, 'T');
end
t_handle = usbtc08connect(thermostring, 'C:\Program Files\Pico Technology\SDK');

%% connect to keysight signal generator (Keysight 33500B series waveform
% generator)
waveformGenerator = KeysightConnection();
initialVoltage = 0.1;   % [V]
DesiredPower = 20;      % [W]
if DesiredPower ~= 0
    insertionVoltage = GetVoltageForPower(DesiredPower); % [V]
else
    insertionVoltage = 0; % [V]
end
% set signal generator parameters
freq = 474000; % [Hz]
writeline(waveformGenerator, ['SOUR1:VOLT ' num2str(initialVoltage)]);
writeline(waveformGenerator, ['SOUR1:FREQ ' num2str(freq) ]);

%% connect to Rhode & Schwarz power meter
NRT = NRT_Connection();
fprintf(NRT, ['SENS0:FREQUENCY ' num2str(freq)]);
fprintf(NRT, 'SENS0:FUNCTION:ON "POWER:FORWARD:AVERAGE"');

% Initialize loop variables
cryovialInsertion = 0;  % initiate script before inserting cryovial
Ts = 0.5;               % Sampling period [s]
loopNum = 1;
% allocate empty array for recording variables
dataArray = zeros(1e3, 3 + numthermocouples); 

% Turn on waveform generatioin
disp('Source Turned On');
writeline(waveformGenerator, 'OUTPUT1 ON');

% Define warming time
max_time = 200; % [s]

% Define maximum cryovial temperature
max_cryovialtemp = 5;
cryovialtemp = 0;

% start timer
tic;

%% Main control loop for warming
figure; hold on; xlabel('Time [s]'); ylabel('Temperature');
while toc < max_time && cryovialtemp < max_cryovialtemp

    % trigger themocouple measurement
    tdat = usbtc08query(t_handle);

    % read from thermocouple datalogger and from power meter
    if ~isnan(sum(tdat(1:numthermocouples)))
        time = toc;
        % plot thermocouple data
        t_vec = [];
        for i = 1:numthermocouples
            t_vec = [t_vec time];
        end
        scatter(t_vec, tdat(1:numthermocouples));

        % set cryovial temperature to what is measured
        if tdat(2) ~= tdat(1)
            cryovialtemp = tdat(2);
        end

        % Query power meter, wait for response
        fprintf(NRT, 'TRIG;*WAI');
        % read power measurement (average absorbed power)
        if cryovialInsertion == 1
            fprintf(NRT, 'SENS0:DATA? "POW:ABS:AVER"');
            absorbedPower = cell2mat(scanstr(NRT, ','));
            forwardPower = 0;
        else
            fprintf(NRT, 'SENS0:DATA? "POWER:FORWARD:AVERAGE"');
            forwardPower = cell2mat(scanstr(NRT, ','));
            absorbedPower = 0;
        end

        % insert pause if needed
        if (toc - time) <= Ts
            pause(Ts - (toc-time));
        end
    end

    % record time, power, and temperature data
    dataArray(loopNum, :) = [time, forwardPower, absorbedPower, ...
        tdat(1:numthermocouples)'];
    
    if loopNum > 1 && cryovialInsertion == 0 && toc > 5 % let power stabilize
        
        % if change in absorbed power greater than 15%, initiate constant
        % amplitude rewarming
        if (abs(dataArray(loopNum,2) - dataArray(loopNum-1,2)) / abs(dataArray(loopNum-1,2))) > 0.15 

            % set flag indicating that cryovial has been inserted
            cryovialInsertion = 1;
            
            % measure absorbed power now
            fprintf(NRT, 'SENS0:FUNC:OFF "POWER:FORWARD:AVERAGE"');
            fprintf(NRT, 'SENS0:FUNC:ON "POW:ABS:AVER"'); % want to measure absorbed power
            
            % set drive voltage to 'rewarming' value
            writeline(waveformGenerator, ['SOUR1:VOLT ' num2str(insertionVoltage)]);    % Set amplitude [V]

            % reset warming time 
            tic;
        end
    end

    % iterate loop number
    loopNum = loopNum + 1;
end

% turn waveform generator off
writeline(waveformGenerator, 'OUTPUT1 OFF');
disp('Source Turned Off');

% disconnect from thermocouple, signal generator, power measurement
clear waveformGenerator;
usbtc08disconnect(t_handle);
fclose(NRT); clear NRT;