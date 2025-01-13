%% Script to record forward/absorbed/reflected power at a range of device
% driving frequencies. Ensure that the device is at the operating
% temperature and insert a cryovial with relevant contents into the centre
% of the cavity to ensure that the measurements are relevant to rewarming
% sonications. Time-averaged power should be adjusted with 'initAmplitude'
% to maintain approximately 4 W to maintain the transducer temperature
%
% Author: Rui Xu
% Last Modified: 12/11/24


clearvars;
%
% connect to keysight signal generator 
waveformGenerator = KeysightConnection();
initAmplitude = 0.1; % [V]
% Set amplitude [V]
writeline(waveformGenerator, ['SOUR1:VOLT ' num2str(initAmplitude)]);    

% connect to thermocouple
addpath(genpath('usbtc08'));
t_handle = usbtc08connect('T', 'C:\Program Files\Pico Technology\SDK');
warning('off','all'); % TC-08 sampling rate is limited to 5 Hz

% connect to NRT powermeter
NRT = NRT_Connection();

% define frequency range
freqrange = 450e3:1e3:500e3;

% allocate empty arrays
AbsorbedPower = zeros(length(freqrange), 1); 
ForwardPower = AbsorbedPower;
ReflectedPower = AbsorbedPower;

%% loop through frequencies and heat, record heating
figure; hold on; xlabel('Frequency [Hz]');
ylabel('Power [W]')
for freqnum = 1:length(freqrange)
    
    % set frequency
    fprintf(NRT, ['SENS0:FREQUENCY ' num2str(freqrange(freqnum))]);
    writeline(waveformGenerator, ['SOUR1:FREQ ' num2str(freqrange(freqnum))]);
    disp(['Starting ' num2str(freqrange(freqnum)) ' Hz Test']);

    % measure transducer temperature
    tdat = usbtc08query(t_handle);
    txTemperature(freqnum) = tdat(1);

    % start signal generator
    writeline(waveformGenerator, 'OUTPUT1 ON');
    loopnum = 1;
    pause(0.5);
    
    fprintf(NRT, ['SENS0:FREQUENCY ' num2str(freqrange(freqnum)) ]);

    % read power measurement from NRT
    fprintf(NRT, 'SENS0:FUNCTION:OFF "POWER:REVERSE"');
    fprintf(NRT, 'SENS0:FUNC:ON "POW:ABS:AVER"'); % want to measure absorbed power
    fprintf(NRT, 'TRIG;*WAI'); % 
    fprintf(NRT, 'SENS0:DATA? "POW:ABS:AVER"');
    AbsorbedPower(freqnum) = cell2mat(scanstr(NRT, ','));

    % read forward power
    fprintf(NRT, 'SENS0:FUNC:OFF "POW:ABS:AVER"'); % want to measure absorbed power
    fprintf(NRT, 'SENS0:FUNCTION:OFF "POWER:REVERSE"');
    fprintf(NRT, 'SENS0:FUNCTION:ON "POWER:FORWARD:AVERAGE"');
    fprintf(NRT, 'TRIG;*WAI');
    fprintf(NRT, 'SENS0:DATA?');
    ForwardPower(freqnum) = cell2mat(scanstr(NRT, ','));

    fprintf(NRT, 'SENS0:FUNC:OFF "POW:ABS:AVER"'); % want to measure absorbed power
    fprintf(NRT, 'SENS0:FUNCTION:OFF "POWER:FORWARD:AVERAGE"'); % Non-concurrent functions
    fprintf(NRT, 'SENS0:FUNCTION:ON "POWER:REVERSE"');
    fprintf(NRT, 'TRIG;*WAI');
    fprintf(NRT, 'SENS0:DATA?');
    ReflectedPower(freqnum) = cell2mat(scanstr(NRT, ','));


    % turn source off
    writeline(waveformGenerator, 'OUTPUT1 OFF');

    % plot data
    scatter(freqrange(freqnum), AbsorbedPower(freqnum), 'ko');
    scatter(freqrange(freqnum), ForwardPower(freqnum), 'ro');
    scatter(freqrange(freqnum), ReflectedPower(freqnum), 'bo');
    legend('Absorbed', 'Forward', 'Reflected');
    drawnow;

end

% close connection to signal generator, NRT, and thermocouple datalogger
clear waveformGenerator;
usbtc08disconnect(t_handle);
fclose(NRT);
clear NRT;

figure;
plot(freqrange, txTemperature)
xlabel('Frequency [Hz]'); ylabel('Transducer Temperature [degC]')

