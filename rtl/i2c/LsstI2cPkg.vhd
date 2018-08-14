-----------------------------------------------------------------
--                                                             --
-----------------------------------------------------------------
--
--      LsstDcPduPkg.vhd -
--
--      Copyright(c) SLAC National Accelerator Laboratory 2000
--
--      Author: Jeff Olsen
--      Created on: 2/14/2018 12:23:56 PM
--      Last change: JO 3/15/2018 2:11:35 PM
--
-------------------------------------------------------------------------------
-- This file is part of 'LSST Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'LSST Firmware', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library work;
use work.I2cPkg.all;
use work.StdRtlPkg.all;

package LsstI2cPkg is

   constant SYS_CLK_FREQ_C : real := 125.0E+6;
   type Lsst5VDcPdu_i2c_in is array (19 downto 0) of i2c_in_type;
   type Lsst5VDcPdu_i2c_out is array (19 downto 0) of i2c_out_type;

   type Lsst24VDcPdu_i2c_in is array (11 downto 0) of i2c_in_type;
   type Lsst24VDcPdu_i2c_out is array (11 downto 0) of i2c_out_type;

   type jjo_I2cRegMasterInType is record
      i2cAddr     : slv(9 downto 0);
      tenbit      : sl;
      regAddr     : slv(31 downto 0);
      regWrData   : slv(31 downto 0);
      regOp       : sl;
      regAddrSkip : sl;
      regAddrSize : slv(1 downto 0);
      regDataSize : slv(7 downto 0);
      regReq      : sl;
      busReq      : sl;
      endianness  : sl;
      repeatStart : sl;
   end record;

   type I2cByteMasterOutType is record
      regAck      : sl;                 -- Last byte data is available
      regFail     : sl;
      regFailCode : slv(7 downto 0);
      regRdData   : slv(7 downto 0);    -- Byte data
      regRdDav    : sl;                 -- New byte data is available
   end record;

   type I2cByteMasterInType is record   -- same as I2CRegMasterInType, datasize is 8 not 2
      i2cAddr     : slv(9 downto 0);
      tenbit      : sl;
      regAddr     : slv(31 downto 0);
      regWrData   : slv(31 downto 0);
      regOp       : sl;
      regAddrSkip : sl;
      regAddrSize : slv(1 downto 0);
      regDataSize : slv(7 downto 0);
      regReq      : sl;
      busReq      : sl;
      endianness  : sl;
      repeatStart : sl;
   end record;

end LsstI2cPkg;
