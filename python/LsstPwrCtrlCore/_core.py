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
# This file is part of the 'LSST Firmware'. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the 'LSST Firmware', including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue             as pr
import pyrogue.interfaces.simulation
import pyrogue.protocols
import surf.axi            as axi
import surf.devices.micron as micron
import surf.xilinx         as xilinx

AXIL_STRIDE = 0x40000
AXIL_OFFSETS = [x*AXIL_STRIDE for x in range(10)]

class LsstPwrCtrlCore(pr.Device):                         
    def __init__( self,       
        expand      = False,
        offset      = 0x0,
        **kwargs):
        
        super().__init__(
            expand      = expand, 
            offset      = 0x0, # This module assume offset 0x0
            **kwargs)      

        self.add(axi.AxiVersion(
            offset = AXIL_OFFSETS[7],
            expand = False,
        ))
        
        self.add(xilinx.Xadc(
            offset = AXIL_OFFSETS[8],
            expand = False,
        ))
        
        self.add(micron.AxiMicronN25Q(
            offset   = AXIL_OFFSETS[9],
            addrMode =  False, # Assume 24-bit address support only
            hidden   =  True,
        ))        
        
        self.add(pr.RemoteVariable(   
            name         = 'LSST_PWR_CORE_VERSION_C',
            description  = 'See LsstPwrCtrlPkg.vhd for definitions',
            offset       = AXIL_OFFSETS[7] + 0x400, # 0x1C0400
            base         = pr.UInt,
            mode         = 'RO',
        )) 

        self.add(pr.RemoteVariable(   
            name         = 'BOARD_ID',
            description  = 'eFuse[7:0] value',
            offset       = AXIL_OFFSETS[7] + 0x404, # 0x1C0404
            base         = pr.UInt,
            bitSize      = 8,
            mode         = 'RO',
        )) 

        self.add(pr.RemoteVariable(   
            name         = 'NUM_LANE_G',
            description  = 'Number of Ethernet lanes',
            offset       = AXIL_OFFSETS[7] + 0x408, # 0x1C0408
            base         = pr.UInt,
            mode         = 'RO',
        )) 
        

class LsstPwrCtrlRoot(pr.Root):
    def __init__(self,
                 hwEmu = False,
                 rssiEn = False,
                 ip = '192.168.1.10',
                 **kwargs):
        super().__init__(**kwargs)

        # Check if emulating the GUI interface
        if (hwEmu):
            # Create emulated hardware interface
            print ("Running in Hardware Emulation Mode")
            self.srp = pyrogue.interfaces.simulation.MemEmulate()
            
        else:        
            # Create srp interface
            self.srp = rogue.protocols.srp.SrpV3()
            
            # Check for RSSI
            if (rssiEn):
                # UDP + RSSI
                udp = pyrogue.protocols.UdpRssiPack( host=ip, port=8192, size=1500 )
                # Connect the SRPv3 to tDest = 0x0
                pyrogue.streamConnectBiDir( srp, udp.application(dest=0x0) )
            else:        
                # UDP only
                udp = rogue.protocols.udp.Client(  ip, 8192, 1500 )
                # Connect the SRPv3 to UDP
                pyrogue.streamConnectBiDir( self.srp, udp )


