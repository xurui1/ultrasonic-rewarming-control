%% Script to optimise transducer based on maximising the heating rate of a
% thermocouple within a cryovial centered within the device cavity.
% Effectively a frequency sweep with heating as the output metric. Caution
% required for maintaining a constant device temperature. Time averaged
% power should be approximately 4 Watts.
%
% Author: Rui Xu
% Last Modified: 08/11/24

clearvars;

% connect to keysight signal generator
waveformGenerator = KeysightConnection();
initAmplitude = 0.2; % [V]
writeline(waveformGenerator, ['SOUR1:VOLT ' num2str(initAmplitude)]);    % Set amplitude [V]

% connect to thermocouple
addpath(genpath('usbtc08'));
t_handle = usbtc08connect('TT', 'C:\Program Files\Pico Technology\SDK');
warning('off','all'); % TC-08 sampling rate is limited to 5 Hz, cannot keep pace

% connect to NRT powermeter
NRT = NRT_Connection();
fprintf(NRT, 'SENS0:FUNC "POW:ABS:AVER"'); % want to measure absorbed power

% define warming time
warming_time = 5; % [s]

% define frequency range
freqrange = 400e3:1e3:500e3;

% allocate empty arrays
AbsorbedPower = zeros(length(freqrange), 1); 

%% loop through frequencies and heat, record heating
figure; hold on; xlabel('Time [s]'); ylabel('Temperature [degC]')
for freqnum = 1:length(freqrange)
    
    % set frequency
    fprintf(NRT, ['SENS0:FREQUENCY ' num2str(freqrange(freqnum))]);
    writeline(waveformGenerator, ['SOUR1:FREQ ' num2str(freqrange(freqnum))]);
    disp(['Starting ' num2str(freqrange(freqnum)) ' Hz Test']);

    % start clock and signal generator
    writeline(waveformGenerator, 'OUTPUT1 ON');
    loopnum = 1; tic;

    % trigger power measurement
    fprintf(NRT, 'TRIG'); % 

    % measure temperature and absorbed power
    while toc < warming_time
        tdat = usbtc08query(t_handle);
        if ~isnan(tdat(1)+tdat(2))
            time(freqnum, loopnum) = toc;
            thermo1(freqnum, loopnum) = tdat(1);
            thermo2(freqnum, loopnum) = tdat(2);
            pause(0.3);
            loopnum = loopnum + 1;
        end
    end

    % read power measurement from NRT
    fprintf(NRT, 'SENS0:DATA? "POW:ABS:AVER"');
    AbsorbedPower(freqnum) = cell2mat(scanstr(NRT, ','));

    % turn source off
    writeline(waveformGenerator, 'OUTPUT1 OFF');

    % plot rewarming data
    plot(time(freqnum,:), thermo1(freqnum,:));
    
    % let heat dissipate
    pause(30);
end

% close connection to signal generator and to NRT
clear waveformGenerator;
usbtc08disconnect(t_handle);
fclose(NRT);

% save data 
filename = 'XYZ.mat';
save(filename, 'AbsorbedPower', 'freqrange', 'thermo1', 'thermo2', 'time')

% plot results iteratively
 figure; 
 for i = 1:length(freqrange)
     hold on; 
     plot(time(i,1:17), thermo1(i,1:17)); 
     plot(time(i,1:17), thermo2(i,1:17)); 
     title(['Freq ' num2str(freqrange(i))]);  
     pause(1); 
     clf; 
 end

