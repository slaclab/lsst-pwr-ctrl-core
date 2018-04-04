-------------------------------------------------------------------------------
-- File       : LsstPwrCtrlPkg.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: LSST's Common Power Controller Core VHDL package
-------------------------------------------------------------------------------
-- This file is part of 'LSST Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'LSST Firmware', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

package LsstPwrCtrlPkg is

   ----------------
   -- Revision Log:
   ----------------
   -- 02/14/2018 (0x01000000): https://github.com/slaclab/lsst-pwr-ctrl-core/releases/tag/v1.0.0
   -- 02/27/2018 (0x01000100): https://github.com/slaclab/lsst-pwr-ctrl-core/releases/tag/v1.0.1
   -- 02/28/2018 (0x01000200): https://github.com/slaclab/lsst-pwr-ctrl-core/releases/tag/v1.0.2
   -- 02/28/2018 (0x01000300): https://github.com/slaclab/lsst-pwr-ctrl-core/releases/tag/v1.0.3
   -- 03/28/2018 (0x01010000): https://github.com/slaclab/lsst-pwr-ctrl-core/releases/tag/v1.1.0
   -- 04/03/2018 (0x01010000): https://github.com/slaclab/lsst-pwr-ctrl-core/releases/tag/v1.1.1
   constant LSST_PWR_CORE_VERSION_C : slv(31 downto 0) := x"01_01_01_00";

   -----------------------------------------------------------
   -- Application: Configurations, Constants and Records Types
   -----------------------------------------------------------
   subtype AppType is slv(31 downto 0);
   
   constant PDU_00_C : AppType := x"0000_0000"; -- 0x00000000 
   constant PDU_01_C : AppType := x"1000_0000"; -- 0x10000000 
   constant PDU_02_C : AppType := x"2000_0000"; -- 0x20000000 
   constant PDU_03_C : AppType := x"3000_0000"; -- 0x30000000 
   constant PDU_04_C : AppType := x"4000_0000"; -- 0x40000000 
   constant PDU_05_C : AppType := x"5000_0000"; -- 0x50000000 
   constant PDU_06_C : AppType := x"6000_0000"; -- 0x60000000 
   constant PDU_07_C : AppType := x"7000_0000"; -- 0x70000000 

   constant APP_NULL_TYPE_C : AppType := toSlv(0, 32);  -- Zero = undefined application

   constant APP_PROTOTYPE_REB_PWR_TYPE_C  : AppType := toSlv(10834, 32);  -- LCA-10834: Prototype REB Power Board 
   constant APP_PRODUCTION_REB_PWR_TYPE_C : AppType := toSlv(15092, 32);  -- LCA-15092: REB Power Supply (Production Version)
   constant APP_ION_PUMP_CTRL_TYPE_C      : AppType := toSlv(15111, 32);  -- LCA-15111: Ion Pump Main Control Board
   constant APP_24V_48V_PDU_DISTR_TYPE_C  : AppType := toSlv(15764, 32);  -- LCA-15764: 24/48V DC PDU Power Distribution Board
   constant APP_5V_PDU_DISTR_TYPE_C       : AppType := toSlv(15768, 32);  -- LCA-15768: 5V DC PDU Power Distribution Board
   constant APP_HEATER_CTRL_TYPE_C        : AppType := toSlv(15772, 32);  -- LCA-15772: REB Heater Control Board

end package LsstPwrCtrlPkg;
