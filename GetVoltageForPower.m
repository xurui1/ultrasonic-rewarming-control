function voltage = GetVoltageForPower(power)
% GETVOLTAGEFORPOWER
%
% INPUT: 
%     power: desired absorbed power output for device [W]
%
% OUTPUT:
%     voltage: empirical voltage to obtained desired power [V]
%
% About:
%     Author: Rui Xu
%     Date: 08/11/24
%     Last Modified: 13/01/25

% load file containing quadratic fit to empirical voltage vs. power
% measuremnts
load('VoltageToPower.mat', 'fitcryo');

% solve for voltage using quadratic formula (assumption: a is not 0)
voltage = sqrt(4 * fitcryo.a * power + fitcryo.b^2) - fitcryo.b;

voltage = voltage / (2 * fitcryo.a);

end
