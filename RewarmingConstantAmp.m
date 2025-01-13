%% Feedback loop script for ultrasonic rewarming with Tx driven by a keysight
% signal generator, amplified with an E&I 1020L 200W amplifier, with the
% electrical power monitored by a Rhode & Schwarz power reflection meter,
% and the cryovial temperature monitored with the PICO TC-08 data logger
%
% Author: Rui Xu
% Last modified: 08/11/24

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
max_time = 300; % [s]
% start timer
tic;

%% Main control loop for warming
figure; hold on; xlabel('Time [s]'); ylabel('Temperature');
cryovialtemp = 0;
while toc < max_time && cryovialtemp < 5

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

    % record time, power, signal amplitude, and temperature data
    dataArray(loopNum, :) = [time, forwardPower, absorbedPower, ...
        tdat(1:numthermocouples)'];
    
    if loopNum > 1 && cryovialInsertion == 0 && toc > 5 % let power stabilize
        % if change in absorbed power greater than 15%, enact PID algorithm
        if (abs(dataArray(loopNum,2) - dataArray(loopNum-1,2)) / abs(dataArray(loopNum-1,2))) > 0.15 
            % turn on feedback control
            cryovialInsertion = 1;
            % reset warming time 
            % measure absorbed power now
            fprintf(NRT, 'SENS0:FUNC:OFF "POWER:FORWARD:AVERAGE"');
            fprintf(NRT, 'SENS0:FUNC:ON "POW:ABS:AVER"'); % want to measure absorbed power
            % set new diriving voltage
            writeline(waveformGenerator, ['SOUR1:VOLT ' num2str(insertionVoltage)]);    % Set amplitude [V]
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

% save results
filename = 'EFGH.mat';
save(filename);