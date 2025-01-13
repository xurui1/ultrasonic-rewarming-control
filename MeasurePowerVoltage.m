%% Script to heat cryovial for set time at set signal amplitude and record temperature
% transducer using the Rohde & Schwarz power reflection meter and the
% Keysight 33500B waveform generator
%
% Author: Rui Xu
% Last modified: 12/11/2024
clearvars;

% connect to thermocouple
addpath(genpath('usbtc08'));
t_handle = usbtc08connect('TTT', 'C:\Program Files\Pico Technology\SDK');
warning('off','all'); % TC-08 sampling rate is limited to 5 Hz, warnings


% connect to keysight signal generator (Keysight 33500B series waveform
% generator)
waveformGenerator = KeysightConnection();
voltages = 0.01:0.01:0.37; % [V]
warmingvoltage = 0.2;  % [V]
freq = 474e3; % [Hz]
txTemp = 33; % [degC] heat to approx this
writeline(waveformGenerator, ['SOUR1:FREQ ' num2str(freq)]);

% connect to NRT powermeter
NRT = NRT_Connection();
fprintf(NRT, ['SENS0:FREQ:CW ' num2str(freq)]);
fprintf(NRT, 'SENS0:FUNCTION:OFF "POWER:REVERSE"');
fprintf(NRT, 'SENS0:FUNCTION:OFF "POWER:FORWARD:AVERAGE"');
fprintf(NRT, 'SENS0:FUNC:ON "POW:ABS:AVER"'); % want to measure absorbed power

% allocate empty arrays
AbsorbedPower = zeros(length(voltages), 1); TxTemperature = AbsorbedPower;

%% loop through frequencies and heat, record heating
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

    if txThermo < txTemp - 0.5
        % turn transducer on to warming voltage
        writeline(waveformGenerator, ['SOUR1:VOLT ' num2str(warmingvoltage)]);    % Set amplitude [V]
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
    while txThermo > txTemp + 0.5
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
    writeline(waveformGenerator, ['SOUR1:VOLT ' num2str(voltages(voltagenum))]);    % Set amplitude [V]
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

figure;
subplot(2,1,1)
plot(voltages, AbsorbedPower);
xlabel('Voltage [V]'); ylabel('Absorbed Power [W]');

subplot(2,1,2);
plot(voltages, TxTemperature);
xlabel('Voltage V'); ylabel('Temperature at Query');