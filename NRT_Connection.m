function NRT = NRT_Connection()
% Code written to connect to Rohde&Schwarz NRT Power Reflection Meter via
% GPIB
%
% Author: Rui Xu
%
% Last Modified: 08/11/24

% create GPIB object with correct address, open it
NRT = gpib('agilent', 7, 12); 
fopen(NRT);

fprintf(NRT, '*CLS');
fprintf(NRT, '*RST;*WAI');

% check that identity is correct
fprintf(NRT, '*IDN?');
Identity = scanstr(NRT, ',');
disp('Connected to:')
for i = 1:length(Identity)
    disp(string(Identity{i}));
end

fprintf(NRT, 'SENS0:FUNC:CONC OFF'); % Non-concurrent functions

ends