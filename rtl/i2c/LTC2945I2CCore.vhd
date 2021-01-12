-----------------------------------------------------------------
--                                                             --
-----------------------------------------------------------------
--
--      LTC2945I2CCore.vhd -
--
--      Copyright(c) SLAC 2000
--
--      Author: Jeff Olsen
--      Created on: 2/4/2008 1:32:47 PM
--      Last change: JO 3/25/2018 10:39:26 AM
--
----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    16:30:20 01/31/2008
-- Design Name:
-- Module Name:    LTC2945I2CCore - Behavioral
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
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;
use surf.I2cPkg.all;

library lsst_pwr_ctrl_core;
use lsst_pwr_ctrl_core.LsstI2cPkg.all;

entity LTC2945I2CCore is
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
      Clock           : in  sl;
      Reset           : in  sl;
      StartRead       : in  sl;
      -- Serial interface
      i2ci            : in  i2c_in_type;
      i2co            : out i2c_out_type;
      -- Fifo Interface for writes
      WrStrb          : in  sl;
      DataIn          : in  slv(31 downto 0);
      -- Dual Port memory for output
      RdMemAddr       : in  slv(4 downto 0);
      MemDout         : out slv(31 downto 0);
      -- I2C Fault
      LTC2945ComFault : out sl

      );
end LTC2945I2CCore;

architecture Behavioral of LTC2945I2CCore is

   -- Note: PRESCALE_G = (clk_freq / (5 * i2c_freq)) - 1
   --       FILTER_G = (min_pulse_time / clk_period) + 1
   constant I2C_SCL_5xFREQ_C : real    := 5.0 * I2C_SCL_FREQ_G;
   constant PRESCALE_C       : natural := (getTimeRatio(AXI_CLK_FREQ_G, I2C_SCL_5xFREQ_C)) - 1;
   constant FILTER_C         : natural := natural(AXI_CLK_FREQ_G * I2C_MIN_PULSE_G) + 1;

   constant ADDR_SIZE_C : slv(1 downto 0) := toSlv(wordCount(ADDR_WIDTH_G, 8) - 1, 2);
--  constant DATA_SIZE_C : slv(1 downto 0) := toSlv(wordCount(32, 8) - 1, 2);
   constant I2C_ADDR_C  : slv(9 downto 0) := ("000" & I2C_ADDR_G);
   constant TIMEOUT_C   : natural         := (getTimeRatio(AXI_CLK_FREQ_G, 200.0)) - 1;  -- 5 ms timeout

   constant MY_I2C_REG_MASTER_IN_INIT_C : I2cRegMasterInType := (
      i2cAddr     => I2C_ADDR_C,
      tenbit      => '0',
      regAddr     => (others => '0'),
      regWrData   => (others => '0'),
      regOp       => '0',               -- 1 for write, 0 for read
      regAddrSkip => '0',
      regAddrSize => ADDR_SIZE_C,
      regDataSize => "00",
      regReq      => '0',
      busReq      => '0',
      endianness  => '1',               -- Big endian
      repeatStart => '1'
      );


   type StateType is (
      IDLE_S,
      READ_ACK_S,
      NEXT_REG_S,
      FIFO_DEL_S,
      WRITE_DATA_S,
      WRITE_ACK_S,
      WRITE_DONE_S
      );

   type RegType is record
      timer      : natural range 0 to TIMEOUT_C;
      FifoRdStrb : sl;
      d_StartRd  : sl;
      RamIn      : slv(31 downto 0);
      WrdCnt     : integer range 0 to 24;  -- Current Word
      RegAddr    : integer range 0 to 49;  -- Address in LTC
      DelCnt     : integer range 0 to 16535;
      StoreWrd   : sl;
      DpRamAddr  : slv(4 downto 0);
      byteShift  : slv(31 downto 0);
      regIn      : I2cRegMasterInType;
      state      : StateType;
   end record;

   constant REG_INIT_C : RegType := (
      timer      => 0,
      FifoRdStrb => '0',
      d_StartRd  => '0',
      RamIn      => (others => '0'),
      WrdCnt     => 0,
      RegAddr    => 0,
      DelCnt     => 0,
      StoreWrd   => '0',
      DpRamAddr  => (others => '0'),
      byteShift  => (others => '0'),
      regIn      => MY_I2C_REG_MASTER_IN_INIT_C,
      state      => IDLE_S
      );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal regOut : I2cRegMasterOutType;

   signal FifoDin   : slv(31 downto 0);
   signal FifoDout  : slv(31 downto 0);
   signal FifoEmpty : sl;
   signal DpDout    : slv(31 downto 0);
   signal LTCData   : slv(31 downto 0);


   type Bytes2Read_t is array (24 downto 0) of integer range 1 to 3;
   constant Bytes2Read : Bytes2Read_t :=
      (
         2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 1, 1, 1, 1, 1
         );

   type Addr2Write_t is array (24 downto 0) of integer range 0 to 48;
   constant Addr2Write : Addr2Write_t :=
      (
--      x"30", x"2E", x"2C", x"2A", x"28", x"26", x"24", x"22", x"20", x"1E", x"1C,
--      x"1A", x"18", x"16", x"14", x"11", x"0E", x"0B", x"08", x"05", x"04", x"03,
--      x"02", x"01", x"00"
         48, 46, 44, 42, 40, 38, 36, 34, 32, 30, 28,
         26, 24, 22, 20, 17, 14, 11, 8, 5, 4, 3, 2, 1, 0
         );

begin

   FifoDin         <= DataIn;
   MemDout         <= DpDout;
   LTC2945ComFault <= regOut.regFail;

   comb : process (r, Reset, StartRead, RegOut, FifoDout, FifoEmpty, LTCData) is
      variable v     : RegType;
      variable WAddr : integer range 0 to 24;
   begin

      v     := r;
      WAddr := to_integer(unsigned(FifoDout(31 downto 24)));


-- 12 bit data is stored left justified
--
-- Shifting the data on writes does not seem to work, remove the shift
--

      if (WAddr < 10) then
         LTCData <= x"00" & FifoDout(23 downto 0);
      else
         LTCData <= x"0000" & FifoDout(11 downto 0) & x"0";
      end if;

      v.FifoRdStrb := '0';
      v.d_StartRd  := StartRead;
      v.StoreWrd   := '0';

      -- 12 bit data is stored left justified
      --
      if (r.wrdcnt < 10) then
         v.RamIn := regout.regRdData(31 downto 0);
      else
         v.RamIn := x"00000" & regout.regRdData(15 downto 4);
      end if;

      case r.State is

         when IDLE_s =>
            v.WrdCnt                                 := 0;
            v.RegAddr                                := 0;
            v.regIn.regOp                            := '0';  -- Read operation
            v.regIn.repeatStart                      := '1';
            v.regIn.regAddr(ADDR_WIDTH_G-1 downto 0) := toslv(r.RegAddr, ADDR_WIDTH_G);
            v.regIn.regDataSize                      := toslv(Bytes2Read(r.WrdCnt)-1, 2);
            v.DpRamAddr                              := toslv(r.wrdCnt, 5);

            if regOut.regAck = '0' then
               if ((StartRead = '1') and (r.d_StartRd = '0')) then
                  -- Send read transaction to I2cRegMaster
                  v.regIn.regReq := '1';

                  -- Next state
                  v.state := READ_ACK_S;

               elsif (FifoEmpty = '0') then
                  -- Set the flag
                  -- Send write transaction to I2cRegMaster
                  v.FifoRdStrb := '1';

                  -- Next state
                  v.state := FIFO_DEL_S;

               end if;
            end if;

         when Read_ACK_S =>
            v.DpRamAddr := toslv(r.wrdCnt, 5);
            -- Wait for completion
            if (regOut.regAck = '1') then
               -- Reset the flag
               v.regIn.regReq := '0';
               v.RegAddr      := r.RegAddr + Bytes2Read(r.WrdCnt);

               v.StoreWrd := '1';
               v.wrdCnt   := r.wrdCNt + 1;

               -- Check for I2C failure
               if (regOut.regFail = '1') then
                  v.state := IDLE_S;
               elsif (r.WrdCnt = 24) then
                  v.state := IDLE_S;
               else
                  v.DelCnt := 5;  -- this is probably not necessary. I used it to make a gap in the scope display
                  v.state  := NEXT_REG_S;
               end if;
            end if;

         when NEXT_REG_S =>
            if regOut.regAck = '0' then
               v.regIn.regAddr(ADDR_WIDTH_G-1 downto 0) := toslv(r.RegAddr, ADDR_WIDTH_G);
               v.regIn.regDataSize                      := toslv(Bytes2Read(r.WrdCnt)-1, 2);

               if (R.DelCnt = 0) then
                  v.regIn.regReq := '1';
                  v.state        := READ_ACK_S;
               else
                  v.DelCnt := r.DelCnt - 1;
               end if;
            end if;

         when FIFO_DEL_S =>
            v.state := WRITE_DATA_S;

         when WRITE_DATA_S =>
            v.regIn.regReq                           := '1';
            v.regIn.regOp                            := '1';  -- Write operation
            v.regIn.repeatStart                      := '1';
            v.regIn.regAddr(ADDR_WIDTH_G-1 downto 0) := toslv(Addr2Write(WAddr), ADDR_WIDTH_G);
            v.regIn.regDataSize                      := toslv(Bytes2Read(WAddr)-1, 2);

            v.regIn.regWrData := LTCData;
            v.state           := WRITE_ACK_S;


         when WRITE_ACK_S =>

            -- Wait for completion
            if regOut.regAck = '1' then
               -- Reset the flag
               v.regIn.regReq := '0';
               -- Check for I2C failure
               if regOut.regFail = '1' then
                  -- Next state
                  v.state := IDLE_S;
               else
                  -- Next state
                  v.state := WRITE_DONE_S;
               end if;
            end if;

         when WRITE_DONE_S =>
            if regOut.regAck = '0' then
               -- Next state
               v.state := IDLE_S;
            end if;

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

   U_I2cRegMaster : entity surf.I2cRegMaster
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
         BRAM_EN_G      => false,
         DOB_REG_G      => false,       -- Extra reg on doutb (folded into BRAM)
         ALTERA_SYN_G   => false,
         ALTERA_RAM_G   => "M9K",
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
         dina    => r.ramin,
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
         BRAM_EN_G       => true,
         FWFT_EN_G       => false,
         USE_DSP48_G     => "no",
         ALTERA_SYN_G    => false,
         ALTERA_RAM_G    => "M9K",
         USE_BUILT_IN_G  => false,  --if set to true, this module is only xilinx compatible only!!!
         XIL_DEVICE_G    => "7SERIES",  --xilinx only generic parameter
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
--      wr_ack        => open,
--      overflow      => open,
--      prog_full     => open,
--      almost_full   => open,
--      full          => open,
--      not_full      => open,
         --Read Ports (rd_clk domain)
         rd_clk => '0',                 --unused if GEN_SYNC_FIFO_G = true
         rd_en  => r.FifoRdStrb,
         dout   => FifoDout,
--      rd_data_count => open,
--      valid         => open,
--      underflow     => open,
--      prog_empty    => open,
--      almost_empty => open,
         empty  => FifoEmpty
         );



end Behavioral;

