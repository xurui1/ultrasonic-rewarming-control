function waveformGenerator = KeysightConnection()
% function to connect to a Keysight oscilloscope using Matlab's visadev
% method
%
% Author: Rui Xu
% Last Modified: 08/12/24

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