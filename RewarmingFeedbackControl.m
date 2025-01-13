% REWARMINGFEEDBACKCONTROL
% 
% Feedback loop script for ultrasonic rewarming with Tx driven by a keysight
% signal generator, amplified with an E&I 1020L 200W amplifier, with the
% electrical power monitored by a Rhode & Schwarz power reflection meter,
% and the cryovial temperature monitored with the PICO TC-08 data logger
%
% ABOUT:
%     Author: Rui Xu
%     Date: 08/11/24
%     Last Modified: 13/01/25

clearvars;

%% connect to thermocouple via TC-08 data logger, requires download:
% https://uk.mathworks.com/matlabcentral/fileexchange/41800-pico-technology-tc-08-usb-data-acquisition
addpath(genpath('usbtc08'));
addpath(genpath('./')); % for voltage to power
numthermocouples = 4;
thermostring = '';
for i = 1:numthermocouples
    thermostring  = append(thermostring, 'T');
end
t_handle = usbtc08connect(thermostring, 'C:\Program Files\Pico Technology\SDK');

%% connect to keysight signal generator and set sonication parameters
waveformGenerator = KeysightConnection();
initialVoltage = 0.1; % [V] cryovial sensing voltage
desiredPower = 20;    % [W]

% get initial driving voltage that corresponds to the desired power
rewarmVoltage = GetVoltageForPower(desiredPower); % [V] 

% set threshold for oscillation around assumed voltage required for desired 
% power (avoids excessive corrections that may damage device)
minVoltage = 0.8 * rewarmVoltage;
maxVoltage = 1.2 * rewarmVoltage;

% choose device frequency
freq = 474e3; % [Hz]

% set device voltage and amplitude
writeline(waveformGenerator, ['SOUR1:VOLT ' num2str(initialVoltage)]);    
writeline(waveformGenerator, ['SOUR1:FREQ ' num2str(freq) ]);

%% connect to Rhode & Schwarz power meter
NRT = NRT_Connection();
fprintf(NRT, ['SENS0:FREQUENCY ' num2str(freq)]);
fprintf(NRT, 'SENS0:FUNCTION:ON "POWER:FORWARD:AVERAGE"');

%% Define the feedback loop parameters (PID algorithm)
Kp = 0.0002;           % Proportional gain
Ki = 0.0001;          % Integral gain
Kd = 0.0001;         % Derivative gain (damping)
Ts = 0.6;           % Sampling time [s]

% Initialize PID variables
errorIntegral = 0; previousError = 0; controlSignal = 0; adjustedVoltage = 0; cryovialInsertion = 0;
feedbackControl = 0; % only turn on feedback control if object inserted, changing power
loopNum = 1;
dataArray = zeros(1e3, 8); % empty array for recording variables

% Turn on waveform generation
disp('Source Turned On');
writeline(waveformGenerator, 'OUTPUT1 ON');

% Define warming time
rw_time = 88; % [s] high power time

% start timer
tic;

%% Main control loop for warming
figure; hold on; xlabel('Time [s]'); ylabel('Temperature');
while toc < rw_time % [s]

    % trigger themocouple measurement
    tdat = usbtc08query(t_handle);
    if ~isnan(tdat(1)+tdat(2)+tdat(3))
        time = toc;
        thermo1 = tdat(1); % thermocouples placed at positions 1 & 2
        thermo2 = tdat(2); 
        thermo3 = tdat(3); % thermocouple on transducer
        % plot thermocouple data
        scatter([time time time], tdat(1:3));

        % Query power meter, wait for response
        fprintf(NRT, 'TRIG;*WAI');
        % read power measurement (average absorbed power)
        if feedbackControl == 1
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
    dataArray(loopNum, :) = [time, forwardPower, absorbedPower, controlSignal, ...
                            adjustedVoltage, thermo1, thermo2, thermo3];
    
    % trigger for cryovial insertion - assumes that it takes longer than 5s
    % between initiating the algorithm and inserting the cryovial, avoids
    % false insertion positives
    if loopNum > 1 && feedbackControl == 0 && toc > 5 % let settle for 5s 
        % if change in absorbed power greater than 15%, enact PID algorithm
        if (abs(dataArray(loopNum,2) - dataArray(loopNum-1,2)) / abs(dataArray(loopNum-1,2))) > 0.15 
            % turn on feedback control
            feedbackControl = 1;
            % reset warming time 
            writeline(waveformGenerator, ['SOUR1:VOLT ' num2str(rewarmVoltage)]);    % Set amplitude [V]
            % measure absorbed power instead of roward power
            fprintf(NRT, 'SENS0:FUNC:OFF "POWER:FORWARD:AVERAGE"');
            fprintf(NRT, 'SENS0:FUNC:ON "POW:ABS:AVER"'); % want to measure absorbed power
            tic;
        end
    end
   
    %% Run Feeback Control Algorithm if change (cryovial insertion) detected
    if feedbackControl == 1 && toc > 2 % let settle for 3s
        % Calculate error
        error = desiredPower - absorbedPower;

        % Update integral and derivative terms
        if loopNum == 1
            errorIntegral = errorIntegral + error * dataArray(loopNum, 1); %  replaced Ts with actual timing
            derivativeTerm = (error - previousError) / dataArray(loopNum, 1); %  replaced Ts with actual timing
        else
            errorIntegral = errorIntegral + error * (dataArray(loopNum, 1) - dataArray(loopNum-1, 1)); %  replaced Ts with actual timing
            derivativeTerm = (error - previousError) / (dataArray(loopNum, 1) - dataArray(loopNum-1, 1)); %  replaced Ts with actual timing
        end

        % Calculate control signal
        controlSignal = Kp * error + Ki * errorIntegral + Kd * derivativeTerm;
        adjustedVoltage = rewarmVoltage + controlSignal;

        % Control signal cannot be over limit
        if adjustedVoltage > maxVoltage % max input to amplifier is 1V, being safe here
            adjustedVoltage = maxVoltage;
        end

        % or under limit
        if adjustedVoltage < minVoltage
            adjustedVoltage = minVoltage;
        end

        % Adjust signal generator amplitude based on control signal
        writeline(waveformGenerator, ['SOUR1:VOLT ' num2str(adjustedVoltage)]);  

        % update initial voltage and previous error
        rewarmVoltage = adjustedVoltage;
        previousError = error;
    end

    % iterate loop number
    loopNum = loopNum + 1;
end

% turn source off
writeline(waveformGenerator, 'OUTPUT1 OFF');
disp('Source Turned Off');
disp('Remove Cryovial');

% disconnect from thermocouple, signal generator, power measurement
clear waveformGenerator;
usbtc08disconnect(t_handle);
fclose(NRT);