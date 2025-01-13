%% Script to heat cryovial for set time at set signal amplitude and record 
% transducer temperature. Script uses the Rohde & Schwarz power reflection 
% meter and the Keysight 33500B waveform generator
%
% Author: Rui Xu
% Last Modified: 12/11/2024
clearvars;

% connect to keysight signal generator (Keysight 33500B series waveform
% generator)
waveformGenerator = KeysightConnection();
initAmplitude = 0.2;    % [V]
txFreq = 474000;        % [Hz]
% Set amplitude [V]
writeline(waveformGenerator, ['SOUR1:VOLT ' num2str(initAmplitude)]);    
writeline(waveformGenerator, ['SOUR1:FREQ ' num2str(txFreq)]);

% connect to thermocouple
addpath(genpath('usbtc08'));
t_handle = usbtc08connect('TTT', 'C:\Program Files\Pico Technology\SDK');
warning('off','all'); % TC-08 sampling rate is limited to 5 Hz

% define Tx temperature
txTemp = 33; % [deg C]
txThermo = 0; % [deg C]

% record tx heating rate
dataset = zeros(1000,2);

%% turn transducer on until temp threshold met
writeline(waveformGenerator, 'OUTPUT1 ON');
tic; loopnum = 1;
while txThermo < txTemp
    % set temp measurement to approx 1 Hz
    pause(1);

    % measure transducer temperature
    tdat = usbtc08query(t_handle);
    txThermo = tdat(1); % connected to third port
    dataset(loopnum,:) = [toc, txThermo];
    
    % display time and temperature
    disp(dataset(loopnum,:));

    loopnum = loopnum + 1;
    pause(1);
end

% turn transducer off
writeline(waveformGenerator, 'OUTPUT1 OFF');

% close connection to signal generator and to NRT
clear waveformGenerator;
usbtc08disconnect(t_handle);