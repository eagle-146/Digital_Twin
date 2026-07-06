function PMSMDriveSetWindingType(mdlname,type)
% Code to set winding type for PMSMDrive

% Copyright 2020-2026 The MathWorks, Inc.

if (strcmp(type,'Wye-wound'))
    if strcmp(get_param([mdlname '/PMSM'],'winding_type'), 'ee.enum.statorconnection.delta') || strcmp(get_param([mdlname '/PMSM'],'winding_type'), '2') 

        set_param([mdlname '/PMSM'],'winding_type','ee.enum.statorconnection.wye')    
        set_param([mdlname '/PMSM controller/PMSM Field-Oriented Control'],'winding_type','Wye-wound')
        set_param([mdlname '/Sensing currents/Gain'],'commented','through')
    else
        % do nothing
    end
else % 'Delta-wound'
    if strcmp(get_param([mdlname '/PMSM'],'winding_type'), 'ee.enum.statorconnection.wye') || strcmp(get_param([gcs '/PMSM'],'winding_type'), '1')
        set_param([mdlname '/PMSM'],'winding_type','ee.enum.statorconnection.delta')
        set_param([mdlname '/PMSM controller/PMSM Field-Oriented Control'],'winding_type','Delta-wound')
        set_param([mdlname '/Sensing currents/Gain'],'commented','off')
    else
        % do nothing
    end
end

