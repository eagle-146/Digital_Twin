%% Model a Three-Phase PMSM Drive
% 
% This example shows a permanent magnet synchronous machine (PMSM) in 
% wye-wound and delta-wound configuration and an inverter sized for use 
% in a typical hybrid vehicle. The inverter connects directly to the 
% vehicle battery, but you can also implement a DC-DC converter stage in 
% between. Use this model to design the PMSM controller by selecting the 
% architecture and gains to achieve the desired performance. To check the 
% turn-on and turn-off timing of the IGBT, replace the IGBT devices with 
% the more detailed N-Channel IGBT block. For complete vehicle modeling, 
% use the Motor & Drive (System Level) block to abstract the PMSM, 
% inverter, and controller with an energy-based model. 
% 

% Copyright 2014-2026 The MathWorks, Inc.


%% Open Model

open_system('PMSMDrive')

set_param(find_system('PMSMDrive','FindAll', 'on','type','annotation','Tag','ModelFeatures'),'Interpreter','off')

%% View Simulation Results from Simscape Logging
%%
%
% This plot shows the requested and measured rotor speed for the
% test and the torque in the electric drive.
%


PMSMDrivePlotMotorSpeed;


%%
