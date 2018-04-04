#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue feb Module
#-----------------------------------------------------------------------------
# File       : _feb.py
# Created    : 2017-02-15
# Last update: 2017-02-15
#-----------------------------------------------------------------------------
# Description:
# PyRogue Feb Module
#-----------------------------------------------------------------------------
# This file is part of the 'Development Board Examples'. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the 'Development Board Examples', including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue     as pr
import surf.axi    as axi
import surf.xilinx as xilinx

class Core(pr.Device):                         
    def __init__( self,       
        name        = "Core",
        description = "Core Container ",
        expand      = False,
        offset      = 0x0,
        **kwargs):
        
        super().__init__(
            name        = name, 
            description = description, 
            expand      = expand, 
            offset      = 0x0, # This module assume offset 0x0
            **kwargs)      

        devStride = 0x40000    
            
        self.add(axi.AxiVersion(
            offset = (7*devStride),
            expand = False,
        ))
        
        self.add(xilinx.Xadc(
            offset = (8*devStride),
            expand = False,
        ))
        
        self.add(pr.RemoteVariable(   
            name         = 'LSST_PWR_CORE_VERSION_C',
            description  = 'See LsstPwrCtrlPkg.vhd for definitions',
            offset       = (7*devStride) + 0x400, # 0x1C0400
            base         = pr.UInt,
            mode         = 'RO',
        )) 

        self.add(pr.RemoteVariable(   
            name         = 'APP_TYPE_G',
            description  = 'See LsstPwrCtrlPkg.vhd for definitions',
            offset       = (7*devStride) + 0x404, # 0x1C0404
            base         = pr.UInt,
            mode         = 'RO',
        )) 

        self.add(pr.RemoteVariable(   
            name         = 'NUM_LANE_G',
            description  = 'Number of Ethernet lanes',
            offset       = (7*devStride) + 0x408, # 0x1C0408
            base         = pr.UInt,
            mode         = 'RO',
        )) 
        
