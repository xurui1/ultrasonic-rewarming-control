% MEASUREPOWERVOLTAGE
%
% Use this script to obtain the empirical measurements of drive voltage 
% versus absorbed electrical power, at a given frequency and transducer
% temperature. Save quadratic fit to data as 'VoltageToPower.mat'
% 
% This script requires the R & S absorbed power meter, Keysight signal
% generator, and thermocouple datalogger. 
%
% ABOUT:
%     Author: Rui Xu
%     Date: 12/11/2024
%     Last Modified: 13/01/25

clearvars;

% connect to thermocouple
addpath(genpath('usbtc08'));
t_handle = usbtc08connect('TTT', 'C:\Program Files\Pico Technology\SDK');
warning('off','all'); % TC-08 sampling rate is limited to 5 Hz, warnings


% connect to Keysight 33500B series waveform generator, set parameters
waveformGenerator = KeysightConnection();
voltages = 0.01:0.01:0.37; % [V]
warmingvoltage = 0.2;  % [V]
freq = 474e3; % [Hz]
writeline(waveformGenerator, ['SOUR1:FREQ ' num2str(freq)]);

% set transducer characterisation temperature (+/- 0.5 degC)
txTemp = 33; % [degC] 

% connect to NRT powermeter
NRT = NRT_Connection();
fprintf(NRT, ['SENS0:FREQ:CW ' num2str(freq)]);
fprintf(NRT, 'SENS0:FUNCTION:OFF "POWER:REVERSE"');
fprintf(NRT, 'SENS0:FUNCTION:OFF "POWER:FORWARD:AVERAGE"');
fprintf(NRT, 'SENS0:FUNC:ON "POW:ABS:AVER"'); % want to measure absorbed power

% allocate empty arrays
AbsorbedPower = zeros(length(voltages), 1); TxTemperature = AbsorbedPower;

%% loop through voltages
tic; loopnum = 1; txThermo = [];
for voltagenum = 1:length(voltages)

    % heat transducer if needed
    tdat = usbtc08query(t_handle);
    if ~isnan(tdat(1))
        txThermo = tdat(1); % connected to third port
    else
        txThermo = tdat(1);
        while isnan(txThermo)
            tdat = usbtc08query(t_handle);
            txThermo = tdat(1); % connected to third port
        end

    end

    if txThermo < txTemp - 0.5 % lower bound of transducer temperature
        % turn transducer on to warming voltage
        % Set amplitude [V]
        writeline(waveformGenerator, ['SOUR1:VOLT ' num2str(warmingvoltage)]);    
        writeline(waveformGenerator, 'OUTPUT1 ON');

        while txThermo < txTemp - 0.5
            % set temp measurement to approx 1 Hz

            % measure transducer temperature
            tdat = usbtc08query(t_handle);
            if ~isnan(tdat(1))
                txThermo = tdat(1); % connected to third port
                dataset(loopnum,:) = [toc, txThermo];

                % display time and temperature
                disp(['Heating ' num2str(dataset(loopnum,:))]);

                loopnum = loopnum + 1;
                pause(1);
            end
        end
        writeline(waveformGenerator, 'OUTPUT1 OFF');

    end

    % wait for transducer to cool if needed
    while txThermo > txTemp + 0.5 % upper bound of transducer temperature
        pause(1);
        % measure transducer temperature
        tdat = usbtc08query(t_handle);
        if ~isnan(tdat(1))
            txThermo = tdat(1); % connected to third port
            dataset(loopnum,:) = [toc, txThermo];
            disp(['Cooling ' num2str(dataset(loopnum,:))])
            loopnum = loopnum + 1;
        end
    end

    % turn transducer on to query voltage
    % Set amplitude [V]
    writeline(waveformGenerator, ['SOUR1:VOLT ' num2str(voltages(voltagenum))]);    
    writeline(waveformGenerator, 'OUTPUT1 ON');
    pause(2); % wait for signal to stabilize


    % read power measurement from NRT
    fprintf(NRT, 'TRIG;*WAI'); %
    fprintf(NRT, 'SENS0:DATA? "POW:ABS:AVER"');
    AbsorbedPower(voltagenum) = cell2mat(scanstr(NRT, ','));
    TxTemperature(voltagenum) = txThermo; % use last temperature measurement


    % turn transducer off
    writeline(waveformGenerator, 'OUTPUT1 OFF');

    % wait for sound to dissipate
    pause(2);
end


% close connection to signal generator and to NRT and TC-08
clear waveformGenerator;
fclose(NRT);
usbtc08disconnect(t_handle);

clear NRT t_handle tdat voltagenum loopnum

% plot voltage vs. power, and temperature at time of Tx query
figure;
subplot(2,1,1)
plot(voltages, AbsorbedPower);
xlabel('Voltage [V]'); ylabel('Absorbed Power [W]');

subplot(2,1,2);
plot(voltages, TxTemperature);
xlabel('Voltage V'); ylabel('Temperature at Query');