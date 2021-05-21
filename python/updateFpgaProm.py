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

import rogue
import argparse
import time
import os
import pyrogue         as pr
import LsstPwrCtrlCore as board

#################################################################
if __name__ == "__main__":

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

    #################################################################

    # Try to ping the remote device
    while (os.system("ping -c 1 " + args.ip) != 0):
        print ( "\nTrying to ping the AMC carrier....\n" )
        time.sleep(5)

    # Set base
    base = board.LsstPwrCtrlRoot(ip=args.ip)

    # Start the system
    base.start()

    # Read all the variables
    base.ReadAll()

    # Create useful pointers
    AxiVersion = base.Core.AxiVersion
    MicronN25Q = base.Core.AxiMicronN25Q

    #################################################################

    # Token write to scratchpad to RAW UDP connection
    AxiVersion.ScratchPad.post(0x1)

    # Unlock the AxiMicronN25Q for PROM erase/programming
    MicronN25Q.PasswordLock.set(0xDEADBEEF)

    #################################################################

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

    #################################################################

    base.stop()
    exit()
