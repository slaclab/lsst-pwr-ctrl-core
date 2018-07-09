#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# This file is part of the 'LSST Firmware'. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the 'LSST Firmware', including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr
import rogue

import LsstPwrCtrlCore as board

import argparse
import time
import sys

# Set the argument parser
parser = argparse.ArgumentParser()

# Add arguments
parser.add_argument(
    "--mcs", 
    type     = str,
    required = True,
    help     = "path to mcs file",
)

parser.add_argument(
    "--ip", 
    type     = str,
    required = True,
    help     = "IP address",
)  

# Get the arguments
args = parser.parse_args()

# Set base
base = pr.Root(name='base',description='')    

# Create srp interface
srp = rogue.protocols.srp.SrpV3()

# UDP only
udp = rogue.protocols.udp.Client( args.ip, 8192, 1500 )

# Connect the SRPv3 to UDP
pr.streamConnectBiDir( srp, udp )            

# Add Base Device
base.add(board.Core(
    memBase = srp,
    offset  = 0x00000000, 
))

# Start the system
base.start(pollEn=False)

# Create useful pointers
AxiVersion = base.Core.AxiVersion
MicronN25Q = base.Core.AxiMicronN25Q

# Token write to scratchpad to RAW UDP connection
AxiVersion._rawWrite(0x4,1)

# Unlock the AxiMicronN25Q for PROM erase/programming
MicronN25Q._rawWrite(0x0,0xDEADBEEF)

print ( '###################################################')
print ( '#                 Old Firmware                    #')
print ( '###################################################')
AxiVersion.printStatus()

# Program the FPGA's PROM
MicronN25Q.LoadMcsFile(args.mcs)

if(MicronN25Q._progDone):
    print('\nReloading FPGA firmware from PROM ....')
    AxiVersion.FpgaReload()
    time.sleep(10)
    print('\nReloading FPGA done')

    print ( '###################################################')
    print ( '#                 New Firmware                    #')
    print ( '###################################################')
    AxiVersion.printStatus()
else:
    print('Failed to program FPGA')

base.stop()
exit() 