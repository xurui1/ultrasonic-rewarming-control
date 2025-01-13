% DEGASSWATER
%
% Script to use high pressure ultrasound to quickly degass the coupling 
% fluid volume. This has only been tested with water coupling, with the
% listed signal generator driving amplitude and a 200W 53dB
% amplifier. Increased driving voltages may result damage, proceed at your 
% own risk. The transducer should be heated to the usual operating 
% temperature before initiating this script.
%
% ABOUT:   
%     Author: Rui Xu
%     Date: 08/11/24
%     Last Modified: 13/01/25

clearvars;

% connect to keysight signal generator (Keysight 33500B series waveform
% generator)
waveformGenerator = KeysightConnection();
initAmplitude = 0.36;   % [V]
txFreq = 474000;        % [Hz]

% Set amplitude and frequency
writeline(waveformGenerator, ['SOUR1:VOLT ' num2str(initAmplitude)]);    
writeline(waveformGenerator, ['SOUR1:FREQ ' num2str(txFreq)]);

% define sonication time (keep small to avoid excessive transducer heating)
degasstime = 5; % [s]

%% turn transducer on until temp threshold met
writeline(waveformGenerator, 'OUTPUT1 ON');
tic; loopnum = 1;
while toc < degasstime

    % leave transducer on, no recording of parameters

end

% turn transducer off
writeline(waveformGenerator, 'OUTPUT1 OFF');

% close connection to signal generator and to NRT
clear waveformGenerator;