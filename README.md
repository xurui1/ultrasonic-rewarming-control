# ultrasonic-rewarming-control
Control codes for the ultrasonic rewarming device developed at UCL for rewarming 2 ml cryovials.


This folder contains a set of scripts to optimise the control of a tubular 
transducer driven with a signal generator with the output power read by
a power meter, and with transducer (and additional temperature sensors) 
read by a TC-08 datalogger. 

Signal Generator: 33500B (Keysight)
Amplifier: E&I 1020L 200W +53dB (E&I)
Power Meter: NRT meter and NAP-Z8 powerhead (Rhode & Schwarz)
Thermocouple datalogger: TC-08 (Pico Technology)

Communication with the devices is achieved with:

Signal Generator: 
visadev (https://www.mathworks.com/help/instrument/visadev.html)

Power Meter: 
Serial commands via GPIB cable

Datalogger: https://uk.mathworks.com/matlabcentral/fileexchange/41800-pico-technology-tc-08-usb-data-acquisition

These scripts were tested and used with Matlab 2019a and a Windows computer

Author: Rui Xu
Date: 13/01/25

The workflow is as follows.

1. Use "HeatTransducer.m" to heat the transducer and coupling fluid to the 
   desired operating temperature. We used 33degC, which gave peak transducer
   temperatures below 37degC for high intensity ultrasound exposures of 
   approximately 30 seconds. This step will also slowly degass water if it
   is used as the coupling fluid. Higher driving voltages result in faster
   transducer heating, but this is less stable as less heat will have
   dissipated into the coupling medium during the heating time. 

2. Use "FreqSweepAbsorbedPower.m" to obtain the forward/reflected/absorbed
   power to select the driving frequency. The optimal driving frequency    
   (selected by maximising absorbed power while minimizing reflected power)
   is stable provided the acoustic properties of the medium within the 
   transducer cavity remain stable. This optimisation should be completed
   with a cryovial containing similar/identical media to what will be 
   rewarmed. 

3. Use "RewarmingFreqSweep.m" in a similar manner to 
   "FreqSweepAbsorbedPower.m", but optimising cryovial heating by measuring 
   cryovial heating with a thermocouple mounted within the cryovial. Can be
   time consuming and this step is not necessary.

4. Use "MeasurePowerVoltage.m" to obtain the relationship between signal
   generator voltage and the device electrical absorbed power. This is used
   in the rewarming codes to obtain a desired device power by changing the
   signal generator voltage amplitude. This code will measure the device 
   power at the intended operating temperature. This folder includes the
   VoltageToPower.mat file obtained with the system at 33degC with water
   as the coupling medium, and a 2ml cryovial containing empty alginate 
   beads inserted into the device. The file contains a polynomial fit to 
   the voltage-to-power relationship.
   
5a. Use "RewarmingConstantAmp.m" to rewarm at a constant driving amplitude.
    Use this if unsure about the stability of the PID algorithm. Use 
    "HeatTransducer.m" beforehand if the transducer temperature isn't 
    already at the operating temperature. Initiate the script before 
    inserting the cryovial into the device.

5b. Use "RewarmingFeedbackControl.m" to rewarm with improved power control. 
    Power error with PID control is approximately 70% lower than
    solely using the voltage-to-power relationship to obtain the driving
    voltage for a desired power, in our work. Use "HeatTransducer.m" 
    beforehand if the transducer temperature isn't already at the operating
    temperature. Initiate the script before inserting the cryovial into the 
    device.

Additional Scripts:

a. Use "DegassWater.m" to drive the transducer for a short period of time 
   at a high amplitude to help to degass the coupling deionized water. 
b. Use "RecordTemp.m" to record temperatures from the datalogger over a 
   specific time. 
