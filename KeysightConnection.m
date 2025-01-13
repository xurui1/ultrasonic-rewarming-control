function waveformGenerator = KeysightConnection()
% KEYSIGHTCONNECTION
%
% function to connect to a Keysight oscilloscope using Matlab's visadev
% method, and set the signal generator properties up for continuous wave
% signal generation
%
% INPUT: empty, may be modified for instrument address
%
% OUTPUT: 
%     waveformGenerator: visadev object for communication
%
% ABOUT:
%     Author: Rui Xu
%     Date: 08/12/24
%     Last Modified: 13/01/25

% Create a VISA-USB object
waveformGenerator = visadev('USB0::2391::11271::MY52814863::0::INSTR');

% Set communication properties
waveformGenerator.Timeout = 10;

% Query the instrument's identification string
writeline(waveformGenerator, '*IDN?');
idn = readline(waveformGenerator);

disp(['Connected to: ', idn]);

% Set up instrument for continuous wave driving
writeline(waveformGenerator, 'BURSt:STAT OFF');       % ensure CW signal 
writeline(waveformGenerator, 'SOUR1:AM:DSSC OFF');    % turn off modulation
writeline(waveformGenerator, 'SOUR1:SWEEP:STATE OFF');% turn off freq sweep
writeline(waveformGenerator, 'SOUR1:FUNCTION SIN');   % Set to sine wave
writeline(waveformGenerator, 'SOUR1:FREQ 474000');    % Set frequency [Hz]

end