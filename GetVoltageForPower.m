%% function for getting voltage for an input power
function voltage = GetVoltageForPower(power)
%
% Author: Rui Xu
% Last Modified: 08/11/24

% load file
load('VoltageToPower.mat', 'fitcryo');

% solve for voltage using quadratic formula (assumption: a is not 0)
voltage = sqrt(4 * fitcryo.a * power + fitcryo.b^2) - fitcryo.b;

voltage = voltage / (2 * fitcryo.a);

end
