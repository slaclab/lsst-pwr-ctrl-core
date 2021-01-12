-----------------------------------------------------------------
--                                                             --
-----------------------------------------------------------------
--
--      LambdaI2CCore.vhd -
--
--      Copyright(c) SLAC 2000
--
--      Author: Jeff Olsen
--      Created on: 2/4/2008 1:32:47 PM
--      Last change: JO 3/20/2018 10:59:44 AM
--
----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    16:30:20 01/31/2008
-- Design Name:
-- Module Name:    LambdaI2CCore - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
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

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

library surf;
use surf.StdRtlPkg.all;
use surf.I2cPkg.all;

library lsst_pwr_ctrl_core;
use lsst_pwr_ctrl_core.LsstI2cPkg.all;

entity LambdaI2CCore is
   generic (
      TPD_G           : time            := 1 ns;
      ADDR_WIDTH_G    : positive        := 16;
      POLL_TIMEOUT_G  : positive        := 16;
      I2C_ADDR_G      : slv(6 downto 0) := "1010000";
      I2C_SCL_FREQ_G  : real            := 100.0E+3;  -- units of Hz
      I2C_MIN_PULSE_G : real            := 100.0E-9;  -- units of seconds
      AXI_CLK_FREQ_G  : real            := 156.25E+6  -- units of Hz

      );
   port (
      Clock          : in  sl;
      Reset          : in  sl;
      StartRead      : in  sl;
-- Serial interface
      i2ci           : in  i2c_in_type;
      i2co           : out i2c_out_type;
-- Fifo Interface for writes
      WrStrb         : in  sl;
      DataIn         : in  slv(31 downto 0);
-- Dual Port memory for output
      RdMemAddr      : in  slv(4 downto 0);
      MemDout        : out slv(31 downto 0);
      -- I2C Fault
      LambdaComFault : out sl

      );
end LambdaI2CCore;

architecture Behavioral of LambdaI2CCore is

   -- Note: PRESCALE_G = (clk_freq / (5 * i2c_freq)) - 1
   --       FILTER_G = (min_pulse_time / clk_period) + 1
   constant I2C_SCL_5xFREQ_C : real    := 5.0 * I2C_SCL_FREQ_G;
   constant PRESCALE_C       : natural := (getTimeRatio(AXI_CLK_FREQ_G, I2C_SCL_5xFREQ_C)) - 1;
   constant FILTER_C         : natural := natural(AXI_CLK_FREQ_G * I2C_MIN_PULSE_G) + 1;

   constant ADDR_SIZE_C : slv(1 downto 0) := toSlv(wordCount(ADDR_WIDTH_G, 8) - 1, 2);
--  constant DATA_SIZE_C : slv(1 downto 0) := toSlv(wordCount(32, 8) - 1, 2);
   constant I2C_ADDR_C  : slv(9 downto 0) := ("000" & I2C_ADDR_G);
   constant TIMEOUT_C   : natural         := (getTimeRatio(AXI_CLK_FREQ_G, 200.0)) - 1;  -- 5 ms timeout

   constant MY_I2C_BYTE_MASTER_IN_INIT_C : I2cByteMasterInType := (
      i2cAddr     => I2C_ADDR_C,
      tenbit      => '0',
      regAddr     => (others => '0'),
      regWrData   => (others => '0'),
      regOp       => '0',               -- 1 for write, 0 for read
      regAddrSkip => '0',
      regAddrSize => ADDR_SIZE_C,
      regDataSize => x"00",
      regReq      => '0',
      busReq      => '0',
      endianness  => '1',               -- Big endian
      repeatStart => '1'
      );


   type StateType is (
      IDLE_S,
      READ_ACK_S,
      NEXT_BYTE_S
      );

   type RegType is record
      timer         : natural range 0 to TIMEOUT_C;
      RnW           : sl;
      startReadLast : sl;
      DelAck        : sl;
      WrdCnt        : integer range 0 to 24;  -- Current Word
      RegAddr       : integer range 1 to 49;  -- Address in LTC
      DelCnt        : integer range 0 to 16384;
      StoreWrd      : sl;
      DpRamAddr     : slv(4 downto 0);
      byteShift     : slv(31 downto 0);
      byteCnt       : slv(1 downto 0);        -- Wrap every 4 bytes to store 32bit values
      regIn         : I2cByteMasterInType;
      state         : StateType;
   end record;

   constant REG_INIT_C : RegType := (
      timer         => 0,
      RnW           => '0',
      DelAck        => '0',
      startReadLast => '0',
      WrdCnt        => 0,
      RegAddr       => 1,
      DelCnt        => 0,
      StoreWrd      => '0',
      DpRamAddr     => (others => '0'),
      byteShift     => (others => '0'),
      byteCnt       => "00",
      regIn         => MY_I2C_BYTE_MASTER_IN_INIT_C,
      state         => IDLE_S
      );

   signal r         : RegType := REG_INIT_C;
   signal rin       : RegType;
   signal regOut    : I2cByteMasterOutType;
   signal FifoDin   : slv(31 downto 0);
   signal FifoDout  : slv(31 downto 0);
   signal FifoEmpty : sl;
   signal DpDout    : slv(31 downto 0);
   signal LTCData   : slv(31 downto 0);
   signal RamIn     : slv(31 downto 0);

   type Bytes2Read_t is array (9 downto 0) of integer range 1 to 20;
   constant Bytes2Read : Bytes2Read_t :=
      (
         3, 8, 12, 1, 2, 2, 2, 4, 4, 20
         );

begin

   FifoDin        <= DataIn;
   MemDout        <= DpDout;
   LambdaComFault <= regOut.regFail;

   comb : process (r, Reset, StartRead, RegOut) is
      variable v : RegType;
   begin
      v := r;

      v.StoreWrd  := '0';
      v.DpRamAddr := conv_std_logic_vector(r.wrdCnt, 5);
      v.DelAck    := regOut.regAck;

      v.startReadLast := StartRead;

      if (regout.regRdDav = '1') then
         v.byteShift(31 downto 0) := r.byteShift(23 downto 0) & regout.regRdData;
         if (r.byteCnt = "11") then
            v.WrdCnt   := r.WrdCnt + 1;
            v.StoreWrd := '1';
            v.byteCnt  := "00";
         else
            v.byteCnt := r.byteCnt + 1;
         end if;
      elsif (r.DelAck = '1') then
         v.byteShift := (others => '0');
         v.byteCnt   := "00";
      end if;

      case r.State is
         when IDLE_s =>
            v.WrdCnt  := 0;
            v.RegAddr := 1;             -- Lambda supply does not have a register 0
            -- Set the flag
            v.RnW     := '0';

            if regOut.regAck = '0' then
               if (StartRead = '1') and r.startReadLast = '0' then
                  -- Send read transaction to I2cRegMaster
                  v.regIn.regReq                           := '1';
                  v.regIn.regOp                            := '0';
                  v.regIn.repeatStart                      := '1';
                  v.regIn.regAddr(ADDR_WIDTH_G-1 downto 0) := conv_std_logic_vector(r.RegAddr, ADDR_WIDTH_G);
                  v.regIn.regDataSize                      := conv_std_logic_vector(Bytes2Read(r.RegAddr-1)-1, 8);
                  -- v.regIn.regDataSize                      := "00";

                  -- Next state
                  v.state := READ_ACK_S;

               end if;
            end if;

         when Read_ACK_S =>
            -- Wait for completion
            if (regOut.regAck = '1') then
               -- Reset the flag
               v.regIn.regReq := '0';
               v.StoreWrd     := '1';
-- Lambda reads many bytes from 1 address!
-- Only increment the address by 1
--          v.RegAddr      := r.RegAddr + Bytes2Read(r.WrdCnt);
               v.RegAddr      := r.RegAddr + 1;
               v.WrdCnt       := r.WrdCnt + 1;

-- if r.RnW = '0' then
               -- Currenty no write operation

               -- read operation
               --
               -- Check for I2C failure
               if (regOut.regFail = '1') then
                  v.state := IDLE_S;
               elsif (r.RegAddr = 9) then
                  v.state := IDLE_S;
               else
                  v.DelCnt := 5;
                  v.state  := NEXT_BYTE_S;
               end if;
            end if;

         when NEXT_BYTE_S =>
            --       if regOut.regAck = '0' then
            v.regIn.regAddr(ADDR_WIDTH_G-1 downto 0) := conv_std_logic_vector(r.RegAddr, ADDR_WIDTH_G);
            v.regIn.regDataSize                      := conv_std_logic_vector(Bytes2Read(r.RegAddr-1)-1, 8);

            if (R.DelCnt = 0) then
               v.regIn.regReq := '1';
               v.state        := READ_ACK_S;
            else
               v.DelCnt := r.DelCnt - 1;
            end if;
      --       end if;
      end case;

      if (Reset = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

   end process comb;

   seq : process (Clock) is
   begin
      if (rising_edge(Clock)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_I2cByteMaster : entity lsst_pwr_ctrl_core.I2cByteMaster
      generic map(
         TPD_G                => TPD_G,
         OUTPUT_EN_POLARITY_G => 0,
         FILTER_G             => FILTER_C,
         PRESCALE_G           => PRESCALE_C
         )
      port map (
         -- Clock and Reset
         clk    => clock,
         srst   => reset,
         -- I2C Register Interface
         regIn  => r.regIn,
         regOut => regOut,
         -- I2C Port Interface
         i2ci   => i2ci,
         i2co   => i2co

         );

   u_Ram : entity surf.SimpleDualPortRam
      generic map (
         TPD_G          => 1 ns,        -- Simulated propagation delay 1 ns;
         RST_POLARITY_G => '1',         -- '1' for active high rst, '0' for active low
         MEMORY_TYPE_G  => "distributed",
         DOB_REG_G      => false,       -- Extra reg on doutb (folded into BRAM)
         BYTE_WR_EN_G   => false,
         DATA_WIDTH_G   => 32,
         BYTE_WIDTH_G   => 8,           -- If BRAM, should be multiple or 8 or 9
         ADDR_WIDTH_G   => 5,
         INIT_G         => "0"
         )
      port map (
         -- Port A
         clka    => Clock,
         ena     => '1',
         wea     => r.StoreWrd,
         weaByte => "1111",
         addra   => r.DpRamAddr,
         dina    => r.byteShift,
         -- Port
         clkb    => Clock,
         enb     => '1',
         rstb    => Reset,
         addrb   => RdMemAddr(4 downto 0),
         doutb   => DpDout
         );

   u_Fifo : entity surf.Fifo
      generic map (
         TPD_G           => 1 ns,
         RST_POLARITY_G  => '1',        -- '1' for active high rst, '0' for active low
         RST_ASYNC_G     => false,
         GEN_SYNC_FIFO_G => true,
         MEMORY_TYPE_G   => "block",
         FWFT_EN_G       => false,
         SYNC_STAGES_G   => 3,
         PIPE_STAGES_G   => 0,
         DATA_WIDTH_G    => 32,
         ADDR_WIDTH_G    => 5,
         INIT_G          => "0",
         FULL_THRES_G    => 1,
         EMPTY_THRES_G   => 1
         )
      port map (
         -- Resets
         rst    => Reset,
         --Write Ports (wr_clk domain)
         wr_clk => Clock,
         wr_en  => WrStrb,
         din    => FifoDin,
--      wr_data_count => open,
         --     wr_ack       => open,
--      overflow      => open,
--      prog_full    => open,
--      almost_full   => open,
--      full          => open,
--      not_full      => open,
         --Read Ports (rd_clk domain)
         rd_clk => '0',                 --unused if GEN_SYNC_FIFO_G = true
         rd_en  => '1',
         dout   => FifoDout,
--      rd_data_count => open,
--      valid         => open,
--      underflow     => open,
--      prog_empty    => open,
--      almost_empty => open,
         empty  => FifoEmpty
         );



end Behavioral;

