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

use work.StdRtlPkg.all;

package LsstPwrCtrlPkg is

   ----------------
   -- Revision Log:
   ----------------
   -- 02/14/2018 (0x01000000): https://github.com/slaclab/lsst-pwr-ctrl-core/releases/tag/v1.0.0
   -- 02/27/2018 (0x01000100): https://github.com/slaclab/lsst-pwr-ctrl-core/releases/tag/v1.0.1
   -- 02/28/2018 (0x01000200): https://github.com/slaclab/lsst-pwr-ctrl-core/releases/tag/v1.0.2
   -- 02/28/2018 (0x01000300): https://github.com/slaclab/lsst-pwr-ctrl-core/releases/tag/v1.0.3
   -- 03/28/2018 (0x01010000): https://github.com/slaclab/lsst-pwr-ctrl-core/releases/tag/v1.1.0
   -- 04/03/2018 (0x01010100): https://github.com/slaclab/lsst-pwr-ctrl-core/releases/tag/v1.1.1
   -- 04/04/2018 (0x01020000): https://github.com/slaclab/lsst-pwr-ctrl-core/releases/tag/v1.2.0
   constant LSST_PWR_CORE_VERSION_C : slv(31 downto 0) := x"01_02_00_00";

end package LsstPwrCtrlPkg;
