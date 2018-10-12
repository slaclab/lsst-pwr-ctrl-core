-------------------------------------------------------------------------------
-- File       : LsstPwrCtrlEthConfig.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-05-01
-- Last update: 2018-08-17
-------------------------------------------------------------------------------
-- Description: LSST's Common Power Controller Core: Ethernet Configurations
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity LsstPwrCtrlEthConfig is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and Reset
      clk   : in  sl;
      rst   : in  sl;
      -- MAC and IP address
      mac   : out slv(47 downto 0);     -- big endian SLV
      ip    : out slv(31 downto 0);     -- big endian SLV
      efuse : out slv(31 downto 0));
end LsstPwrCtrlEthConfig;

architecture rtl of LsstPwrCtrlEthConfig is

   function ConvertMac (word : slv(47 downto 0)) return slv is
      variable retVar : slv(47 downto 0);
   begin
      retVar(47 downto 40) := word(7 downto 0);
      retVar(39 downto 32) := word(15 downto 8);
      retVar(31 downto 24) := word(23 downto 16);
      retVar(23 downto 16) := word(31 downto 24);
      retVar(15 downto 8)  := word(39 downto 32);
      retVar(7 downto 0)   := word(47 downto 40);
      return retVar;
   end function;

   function ConvertIp (word : slv(31 downto 0)) return slv is
      variable retVar : slv(31 downto 0);
   begin
      retVar(31 downto 24) := word(7 downto 0);
      retVar(23 downto 16) := word(15 downto 8);
      retVar(15 downto 8)  := word(23 downto 16);
      retVar(7 downto 0)   := word(31 downto 24);
      return retVar;
   end function;

   type EthConfigType is record
      mac : slv(47 downto 0);
      ip  : slv(31 downto 0);
   end record;
   type EthConfigArray is array (natural range <>) of EthConfigType;

   -----------------------------------------------------------------------------
   -- https://confluence.slac.stanford.edu/display/~leosap/IP+address+allocation
   -----------------------------------------------------------------------------

   constant ETH_CFG_SIZE_C : positive := 80;
   constant ETH_CFG_C : EthConfigArray(ETH_CFG_SIZE_C-1 downto 0) := (
      -----------------------------------------------------------------------------------------------------------
      0  => (mac => ConvertMac(x"000000000000"), ip => x"00000000"),  -- Reserved
      1  => (mac => ConvertMac(x"000000000000"), ip => x"00000000"),  -- Reserved
      2  => (mac => ConvertMac(x"000000000000"), ip => x"00000000"),  -- Reserved
      3  => (mac => ConvertMac(x"000000000000"), ip => x"00000000"),  -- Reserved
      4  => (mac => ConvertMac(x"000000000000"), ip => x"00000000"),  -- Reserved
      5  => (mac => ConvertMac(x"000000000000"), ip => x"00000000"),  -- Reserved
      6  => (mac => ConvertMac(x"08005600474c"), ip => x"4C01A8C0"),  -- MAC = 08:00:56:00:47:4c, IP = 192.168.1.76
      7  => (mac => ConvertMac(x"080056004827"), ip => x"2701A8C0"),  -- MAC = 08:00:56:00:48:27, IP = 192.168.1.39
      8  => (mac => ConvertMac(x"080056004828"), ip => x"2801A8C0"),  -- MAC = 08:00:56:00:48:28, IP = 192.168.1.40
      9  => (mac => ConvertMac(x"080056004829"), ip => x"2901A8C0"),  -- MAC = 08:00:56:00:48:29, IP = 192.168.1.41
      10 => (mac => ConvertMac(x"08005600482a"), ip => x"2a01A8C0"),  -- MAC = 08:00:56:00:48:2a, IP = 192.168.1.42
      11 => (mac => ConvertMac(x"08005600482b"), ip => x"2b01A8C0"),  -- MAC = 08:00:56:00:48:2b, IP = 192.168.1.43
      12 => (mac => ConvertMac(x"08005600482c"), ip => x"2c01A8C0"),  -- MAC = 08:00:56:00:48:2c, IP = 192.168.1.44
      13 => (mac => ConvertMac(x"08005600482d"), ip => x"2d01A8C0"),  -- MAC = 08:00:56:00:48:2d, IP = 192.168.1.45
      14 => (mac => ConvertMac(x"08005600482e"), ip => x"2e01A8C0"),  -- MAC = 08:00:56:00:48:2e, IP = 192.168.1.46
      15 => (mac => ConvertMac(x"08005600482f"), ip => x"2f01A8C0"),  -- MAC = 08:00:56:00:48:2f, IP = 192.168.1.47
      -----------------------------------------------------------------------------------------------------------
      16 => (mac => ConvertMac(x"080056004830"), ip => x"3001A8C0"),  -- MAC = 08:00:56:00:48:30, IP = 192.168.1.48
      17 => (mac => ConvertMac(x"080056004831"), ip => x"3101A8C0"),  -- MAC = 08:00:56:00:48:31, IP = 192.168.1.49      
      18 => (mac => ConvertMac(x"080056004832"), ip => x"3201A8C0"),  -- MAC = 08:00:56:00:48:32, IP = 192.168.1.50
      19 => (mac => ConvertMac(x"080056004833"), ip => x"3301A8C0"),  -- MAC = 08:00:56:00:48:33, IP = 192.168.1.51
      20 => (mac => ConvertMac(x"080056004834"), ip => x"3401A8C0"),  -- MAC = 08:00:56:00:48:34, IP = 192.168.1.52
      21 => (mac => ConvertMac(x"080056004835"), ip => x"3501A8C0"),  -- MAC = 08:00:56:00:48:35, IP = 192.168.1.53
      22 => (mac => ConvertMac(x"080056004836"), ip => x"3601A8C0"),  -- MAC = 08:00:56:00:48:36, IP = 192.168.1.54
      23 => (mac => ConvertMac(x"080056004837"), ip => x"3701A8C0"),  -- MAC = 08:00:56:00:48:37, IP = 192.168.1.55
      24 => (mac => ConvertMac(x"080056004838"), ip => x"3801A8C0"),  -- MAC = 08:00:56:00:48:38, IP = 192.168.1.56
      25 => (mac => ConvertMac(x"080056004839"), ip => x"3901A8C0"),  -- MAC = 08:00:56:00:48:39, IP = 192.168.1.57
      26 => (mac => ConvertMac(x"08005600483a"), ip => x"3a01A8C0"),  -- MAC = 08:00:56:00:48:3a, IP = 192.168.1.58
      27 => (mac => ConvertMac(x"08005600483b"), ip => x"3b01A8C0"),  -- MAC = 08:00:56:00:48:3b, IP = 192.168.1.59
      28 => (mac => ConvertMac(x"08005600483c"), ip => x"3c01A8C0"),  -- MAC = 08:00:56:00:48:3c, IP = 192.168.1.60
      29 => (mac => ConvertMac(x"08005600483d"), ip => x"3d01A8C0"),  -- MAC = 08:00:56:00:48:3d, IP = 192.168.1.61
      30 => (mac => ConvertMac(x"08005600483e"), ip => x"3e01A8C0"),  -- MAC = 08:00:56:00:48:3e, IP = 192.168.1.62
      31 => (mac => ConvertMac(x"08005600483f"), ip => x"3f01A8C0"),  -- MAC = 08:00:56:00:48:3f, IP = 192.168.1.63
      -----------------------------------------------------------------------------------------------------------
      32 => (mac => ConvertMac(x"080056004840"), ip => x"4001A8C0"),  -- MAC = 08:00:56:00:48:40, IP = 192.168.1.64
      33 => (mac => ConvertMac(x"080056004841"), ip => x"4101A8C0"),  -- MAC = 08:00:56:00:48:41, IP = 192.168.1.65
      34 => (mac => ConvertMac(x"080056004842"), ip => x"4201A8C0"),  -- MAC = 08:00:56:00:48:42, IP = 192.168.1.66
      35 => (mac => ConvertMac(x"080056004843"), ip => x"4301A8C0"),  -- MAC = 08:00:56:00:48:43, IP = 192.168.1.67
      36 => (mac => ConvertMac(x"080056004844"), ip => x"4401A8C0"),  -- MAC = 08:00:56:00:48:44, IP = 192.168.1.68
      37 => (mac => ConvertMac(x"080056004845"), ip => x"4501A8C0"),  -- MAC = 08:00:56:00:48:45, IP = 192.168.1.69
      38 => (mac => ConvertMac(x"080056004846"), ip => x"4601A8C0"),  -- MAC = 08:00:56:00:48:46, IP = 192.168.1.70
      39 => (mac => ConvertMac(x"080056004847"), ip => x"4701A8C0"),  -- MAC = 08:00:56:00:48:47, IP = 192.168.1.71
      40 => (mac => ConvertMac(x"080056004848"), ip => x"4801A8C0"),  -- MAC = 08:00:56:00:48:48, IP = 192.168.1.72
      41 => (mac => ConvertMac(x"080056004849"), ip => x"4901A8C0"),  -- MAC = 08:00:56:00:48:49, IP = 192.168.1.73
      42 => (mac => ConvertMac(x"08005600484a"), ip => x"4a01A8C0"),  -- MAC = 08:00:56:00:48:4a, IP = 192.168.1.74
      43 => (mac => ConvertMac(x"08005600484b"), ip => x"4b01A8C0"),  -- MAC = 08:00:56:00:48:4b, IP = 192.168.1.75
      44 => (mac => ConvertMac(x"08005600484c"), ip => x"00000000"),  -- MAC = 08:00:56:00:48:4c, IP = Undefined
      45 => (mac => ConvertMac(x"08005600484d"), ip => x"4d01A8C0"),  -- MAC = 08:00:56:00:48:4d, IP = 192.168.1.77
      46 => (mac => ConvertMac(x"08005600484e"), ip => x"4e01A8C0"),  -- MAC = 08:00:56:00:48:4e, IP = 192.168.1.78
      47 => (mac => ConvertMac(x"08005600484f"), ip => x"4f01A8C0"),  -- MAC = 08:00:56:00:48:4f, IP = 192.168.1.79
      -----------------------------------------------------------------------------------------------------------
      48 => (mac => ConvertMac(x"080056004850"), ip => x"5001A8C0"),  -- MAC = 08:00:56:00:48:50, IP = 192.168.1.80
      49 => (mac => ConvertMac(x"080056004851"), ip => x"5101A8C0"),  -- MAC = 08:00:56:00:48:51, IP = 192.168.1.81      
      50 => (mac => ConvertMac(x"080056004852"), ip => x"5201A8C0"),  -- MAC = 08:00:56:00:48:52, IP = 192.168.1.82
      51 => (mac => ConvertMac(x"080056004853"), ip => x"5301A8C0"),  -- MAC = 08:00:56:00:48:53, IP = 192.168.1.83
      52 => (mac => ConvertMac(x"080056004854"), ip => x"5401A8C0"),  -- MAC = 08:00:56:00:48:54, IP = 192.168.1.84
      53 => (mac => ConvertMac(x"080056004855"), ip => x"5501A8C0"),  -- MAC = 08:00:56:00:48:55, IP = 192.168.1.85
      54 => (mac => ConvertMac(x"080056004856"), ip => x"5601A8C0"),  -- MAC = 08:00:56:00:48:56, IP = 192.168.1.86
      55 => (mac => ConvertMac(x"080056004857"), ip => x"5701A8C0"),  -- MAC = 08:00:56:00:48:57, IP = 192.168.1.87
      56 => (mac => ConvertMac(x"080056004858"), ip => x"5801A8C0"),  -- MAC = 08:00:56:00:48:58, IP = 192.168.1.88
      57 => (mac => ConvertMac(x"080056004859"), ip => x"5901A8C0"),  -- MAC = 08:00:56:00:48:59, IP = 192.168.1.89
      58 => (mac => ConvertMac(x"08005600485a"), ip => x"5a01A8C0"),  -- MAC = 08:00:56:00:48:5a, IP = 192.168.1.90
      59 => (mac => ConvertMac(x"08005600485b"), ip => x"5b01A8C0"),  -- MAC = 08:00:56:00:48:5b, IP = 192.168.1.91
      60 => (mac => ConvertMac(x"08005600485c"), ip => x"5c01A8C0"),  -- MAC = 08:00:56:00:48:5c, IP = 192.168.1.92
      61 => (mac => ConvertMac(x"08005600485d"), ip => x"5d01A8C0"),  -- MAC = 08:00:56:00:48:5d, IP = 192.168.1.93
      62 => (mac => ConvertMac(x"08005600485e"), ip => x"5e01A8C0"),  -- MAC = 08:00:56:00:48:5e, IP = 192.168.1.94
      63 => (mac => ConvertMac(x"08005600485f"), ip => x"5f01A8C0"),  -- MAC = 08:00:56:00:48:5f, IP = 192.168.1.95    
      -----------------------------------------------------------------------------------------------------------
      64 => (mac => ConvertMac(x"080056004860"), ip => x"6001A8C0"),  -- MAC = 08:00:56:00:48:60, IP = 192.168.1.96
      65 => (mac => ConvertMac(x"080056004861"), ip => x"6101A8C0"),  -- MAC = 08:00:56:00:48:61, IP = 192.168.1.97
      66 => (mac => ConvertMac(x"080056004862"), ip => x"6201A8C0"),  -- MAC = 08:00:56:00:48:62, IP = 192.168.1.98
      67 => (mac => ConvertMac(x"080056004863"), ip => x"6301A8C0"),  -- MAC = 08:00:56:00:48:63, IP = 192.168.1.99
      68 => (mac => ConvertMac(x"080056004864"), ip => x"6401A8C0"),  -- MAC = 08:00:56:00:48:64, IP = 192.168.1.100
      69 => (mac => ConvertMac(x"080056004865"), ip => x"6501A8C0"),  -- MAC = 08:00:56:00:48:65, IP = 192.168.1.101
      70 => (mac => ConvertMac(x"080056004866"), ip => x"6601A8C0"),  -- MAC = 08:00:56:00:48:66, IP = 192.168.1.102
      71 => (mac => ConvertMac(x"080056004867"), ip => x"6701A8C0"),  -- MAC = 08:00:56:00:48:67, IP = 192.168.1.103
      72 => (mac => ConvertMac(x"080056004868"), ip => x"6801A8C0"),  -- MAC = 08:00:56:00:48:68, IP = 192.168.1.104
      73 => (mac => ConvertMac(x"080056004869"), ip => x"6901A8C0"),  -- MAC = 08:00:56:00:48:69, IP = 192.168.1.105
      74 => (mac => ConvertMac(x"08005600486a"), ip => x"6a01A8C0"),  -- MAC = 08:00:56:00:48:6a, IP = 192.168.1.106
      75 => (mac => ConvertMac(x"08005600486b"), ip => x"6b01A8C0"),  -- MAC = 08:00:56:00:48:6b, IP = 192.168.1.107
      76 => (mac => ConvertMac(x"08005600486c"), ip => x"6c01A8C0"),  -- MAC = 08:00:56:00:48:6c, IP = 192.168.1.108
      77 => (mac => ConvertMac(x"08005600486d"), ip => x"6d01A8C0"),  -- MAC = 08:00:56:00:48:6d, IP = 192.168.1.109
      78 => (mac => ConvertMac(x"08005600486e"), ip => x"6e01A8C0"),  -- MAC = 08:00:56:00:48:6e, IP = 192.168.1.110
      79 => (mac => ConvertMac(x"08005600486f"), ip => x"6f01A8C0"));  -- MAC = 08:00:56:00:48:6f, IP = 192.168.1.111         

   type RegType is record
      idx   : natural range 0 to ETH_CFG_SIZE_C-1;
      efuse : slv(31 downto 0);
      mac   : slv(47 downto 0);
      ip    : slv(31 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
      idx   => 0,
      efuse => x"0000_0000",
      mac   => x"00_00_00_56_00_08",
      ip    => x"0000_0000");

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch               : string;
   -- attribute dont_touch of r          : signal is "TRUE";

   signal efuseValue : slv(31 downto 0);

   attribute rom_style                : string;
   attribute rom_style of ETH_CFG_C   : constant is "distributed";
   attribute rom_extract              : string;
   attribute rom_extract of ETH_CFG_C : constant is "TRUE";
   attribute syn_keep                 : string;
   attribute syn_keep of ETH_CFG_C    : constant is "TRUE";

begin

   ------------------------------------
   -- Local MAC Address stored in eFUSE
   ------------------------------------
   U_EFuse : EFUSE_USR
      port map (
         EFUSEUSR => efuseValue);

   comb : process (efuseValue, r, rst) is
      variable v : regType;
   begin
      -- Latch the current value
      v := r;

      -- Register the value
      v.efuse := efuseValue;

      v.mac(23 downto 0)  := x"56_00_08";  -- 08:00:56:XX:XX:XX (big endian SLV)
      v.mac(47 downto 24) := r.efuse(31 downto 8);  -- big endian SLV

      -- Increment the counter
      if (r.idx = ETH_CFG_SIZE_C-1) then
         v.idx := 0;
      else
         v.idx := r.idx + 1;
      end if;

      -- Check for matching MAC address
      if (r.mac = ETH_CFG_C(r.idx).mac) then
         -- Register the corresponding IP address
         v.ip := ETH_CFG_C(r.idx).ip;
      end if;

      -- Synchronous Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      mac   <= r.mac;
      ip    <= r.ip;
      efuse <= r.efuse;

   end process comb;

   seq : process (clk) is
   begin
      if (rising_edge(clk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
