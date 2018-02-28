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

import pyrogue             as pr
import surf.axi            as axi
import surf.devices.micron as micron
import surf.xilinx         as xilinx

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
        
        self.add(micron.AxiMicronN25Q(
            offset = (9*devStride),
            expand = False,
        ))
        