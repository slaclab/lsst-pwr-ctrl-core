-------------------------------------------------------------------------------
-- File       : LsstPwrCtrlEth.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: LSST's Common Power Controller Core: Ethernet Wrapper
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

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.EthMacPkg.all;

library lsst_pwr_ctrl_core;

library unisim;
use unisim.vcomponents.all;

entity LsstPwrCtrlEth is
   generic (
      TPD_G          : time                  := 1 ns;
      SIMULATION_G   : boolean               := false;
      NUM_LANE_G     : positive range 1 to 4 := 1;
      NUM_PORT_G     : positive range 1 to 4 := 2;
      SYS_CLK_FREQ_G : real                  := 125.0E+6);
   port (
      -- Register Interface
      axilClk          : out sl;
      axilRst          : out sl;
      axilReadMasters  : out AxiLiteReadMasterArray(NUM_LANE_G*NUM_PORT_G-1 downto 0);
      axilReadSlaves   : in  AxiLiteReadSlaveArray(NUM_LANE_G*NUM_PORT_G-1 downto 0);
      axilWriteMasters : out AxiLiteWriteMasterArray(NUM_LANE_G*NUM_PORT_G-1 downto 0);
      axilWriteSlaves  : in  AxiLiteWriteSlaveArray(NUM_LANE_G*NUM_PORT_G-1 downto 0);
      -- Misc. Signals
      extRstL          : in  sl;
      ethLinkUp        : out slv(NUM_LANE_G-1 downto 0);
      rssiLinkUp       : out slv(NUM_LANE_G*NUM_PORT_G-1 downto 0);
      efuse            : out slv(31 downto 0);
      -- Overriding the LsstPwrCtrlEthConfig.vhd MAC/IP addresses Interface
      overrideEthCofig : in  sl;
      overrideMacAddr  : in  slv(47 downto 0);
      overrideIpAddr   : in  slv(31 downto 0);
      -- 1GbE Ports
      ethClkP          : in  sl;
      ethClkN          : in  sl;
      ethRxP           : in  slv(NUM_LANE_G-1 downto 0);
      ethRxN           : in  slv(NUM_LANE_G-1 downto 0);
      ethTxP           : out slv(NUM_LANE_G-1 downto 0);
      ethTxN           : out slv(NUM_LANE_G-1 downto 0));
end LsstPwrCtrlEth;

architecture mapping of LsstPwrCtrlEth is

   constant DHCP_C          : boolean := false;  -- false = static address, true = DHCP
   constant RSSI_C          : boolean := false;  -- false = UDP only, true = RUDP
   constant APP_ILEAVE_EN_C : boolean := false;  -- false = RSSI uses AxiStreamPacketizer1, true = RSSI uses AxiStreamPacketizer2

   constant SERVER_PORTS_C : PositiveArray(3 downto 0) := (
      0 => 8192,
      1 => 8193,
      2 => 8194,
      3 => 8195);

   constant AXIS_CONFIG_C     : AxiStreamConfigArray(0 downto 0)            := (0      => EMAC_AXIS_CONFIG_C);
   constant PHY_AXIS_CONFIG_C : AxiStreamConfigArray(NUM_LANE_G-1 downto 0) := (others => EMAC_AXIS_CONFIG_C);

   signal obMacMasters : AxiStreamMasterArray(NUM_LANE_G-1 downto 0);
   signal obMacSlaves  : AxiStreamSlaveArray(NUM_LANE_G-1 downto 0);
   signal ibMacMasters : AxiStreamMasterArray(NUM_LANE_G-1 downto 0);
   signal ibMacSlaves  : AxiStreamSlaveArray(NUM_LANE_G-1 downto 0);

   signal obServerMasters : AxiStreamMasterArray(NUM_LANE_G*NUM_PORT_G-1 downto 0);
   signal obServerSlaves  : AxiStreamSlaveArray(NUM_LANE_G*NUM_PORT_G-1 downto 0);
   signal ibServerMasters : AxiStreamMasterArray(NUM_LANE_G*NUM_PORT_G-1 downto 0);
   signal ibServerSlaves  : AxiStreamSlaveArray(NUM_LANE_G*NUM_PORT_G-1 downto 0);

   signal appIbMasters : AxiStreamMasterArray(NUM_LANE_G*NUM_PORT_G-1 downto 0);
   signal appIbSlaves  : AxiStreamSlaveArray(NUM_LANE_G*NUM_PORT_G-1 downto 0);
   signal appObMasters : AxiStreamMasterArray(NUM_LANE_G*NUM_PORT_G-1 downto 0);
   signal appObSlaves  : AxiStreamSlaveArray(NUM_LANE_G*NUM_PORT_G-1 downto 0);

   signal localMac : Slv48Array(NUM_LANE_G-1 downto 0);
   signal dmaClk   : slv(NUM_LANE_G-1 downto 0);
   signal dmaRst   : slv(NUM_LANE_G-1 downto 0);

   signal ethClk     : sl;
   signal ethRst     : sl;
   signal extRst     : sl;
   signal rssiStatus : Slv7Array(NUM_LANE_G*NUM_PORT_G-1 downto 0) := (others => (others => '0'));

   signal efuseMac : slv(47 downto 0);
   signal efuseIp  : slv(31 downto 0);

   signal ethMac : slv(47 downto 0);
   signal ethIp  : slv(31 downto 0);


   signal gtClk  : sl;
   signal clkIn  : slv(6 downto 0);
   signal rstIn  : slv(6 downto 0);
   signal clkout : slv(5 downto 0);
   signal rstout : slv(5 downto 0);


begin

   axilClk <= ethClk;
   axilRst <= ethRst;
   extRst  <= not(extRstL) or rstout(5);

   ETH_GEN : if (not SIMULATION_G) generate

      -------------------------
      -- Ethernet Configuration
      -------------------------
      U_Config : entity lsst_pwr_ctrl_core.LsstPwrCtrlEthConfig
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Clock and Reset
            clk   => ethClk,
            rst   => ethRst,
            -- MAC and IP address
            mac   => efuseMac,
            ip    => efuseIp,
            efuse => efuse);

      -- Select either EFUSE or external IP/MAC addresses
      ethMac <= efuseMac when(overrideEthCofig = '0') else overrideMacAddr;
      ethIp  <= efuseIp  when(overrideEthCofig = '0') else overrideIpAddr;

      -----------------------------
      -- Clock Jitter/Glitch Filter
      -----------------------------
      U_IBUFDS_GTE2 : IBUFDS_GTE2
         port map (
            I     => ethClkP,
            IB    => ethClkN,
            CEB   => '0',
            ODIV2 => open,
            O     => gtClk);

      U_BUFG : BUFG
         port map (
            I => gtClk,
            O => clkIn(0));

      U_PwrUpRst : entity surf.PwrUpRst
         generic map (
            TPD_G => TPD_G)
         port map (
            clk    => clkIn(0),
            rstOut => rstIn(0));

      GEN_PLL :
      for i in 5 downto 0 generate

         U_PLL : entity surf.ClockManager7
            generic map(
               TPD_G             => TPD_G,
               TYPE_G            => "PLL",
               INPUT_BUFG_G      => false,
               FB_BUFG_G         => false,
               RST_IN_POLARITY_G => '1',
               NUM_CLOCKS_G      => 1,
               -- MMCM attributes
               CLKIN_PERIOD_G    => 8.0,  -- 125MHz
               DIVCLK_DIVIDE_G   => 1,    -- 125 MHz = (125 MHz/1)
               CLKFBOUT_MULT_G   => 8,    -- 1 GHz = (8 x 125 MHz)
               CLKOUT0_DIVIDE_G  => 8)    -- 125 MHz = (1.0 GHz/8)
            port map(
               clkIn     => clkIn(i),
               rstIn     => rstIn(i),
               clkOut(0) => clkOut(i),
               rstOut(0) => rstOut(i));

         clkIn(i+1) <= clkOut(i);
         rstIn(i+1) <= rstOut(i);

      end generate GEN_PLL;

      ------------------------
      -- GigE Core for ARTIX-7
      ------------------------
      U_PHY_MAC : entity surf.GigEthGtp7Wrapper
         generic map (
            TPD_G              => TPD_G,
            NUM_LANE_G         => NUM_LANE_G,
            -- Clocking Configurations
            USE_GTREFCLK_G     => true,  --  FALSE: gtClkP/N,  TRUE: gtRefClk
            CLKIN_PERIOD_G     => 8.0,   -- 125MHz
            DIVCLK_DIVIDE_G    => 1,     -- 125 MHz = (125 MHz/1)
            CLKFBOUT_MULT_F_G  => 8.0,   -- 1 GHz = (8 x 125 MHz)
            CLKOUT0_DIVIDE_F_G => 8.0,   -- 125 MHz = (1.0 GHz/8)
            -- AXI Streaming Configurations
            AXIS_CONFIG_G      => PHY_AXIS_CONFIG_C)
         port map (
            -- Local Configurations
            localMac     => localMac,
            -- Streaming DMA Interface
            dmaClk       => dmaClk,
            dmaRst       => dmaRst,
            dmaIbMasters => obMacMasters,
            dmaIbSlaves  => obMacSlaves,
            dmaObMasters => ibMacMasters,
            dmaObSlaves  => ibMacSlaves,
            -- Misc. Signals
            extRst       => extRst,
            ethClk125    => ethClk,
            ethRst125    => ethRst,
            phyReady     => ethLinkUp,
            -- MGT Ports
            gtRefClk     => clkout(5),
            gtTxP        => ethTxP,
            gtTxN        => ethTxN,
            gtRxP        => ethRxP,
            gtRxN        => ethRxN);


      localMac <= (others => ethMac);
      dmaClk   <= (others => ethClk);
      dmaRst   <= (others => ethRst);

   end generate;

   GEN_LANE : for i in 0 to NUM_LANE_G-1 generate

      ETH_GEN : if (not SIMULATION_G) generate

         ----------------------
         -- IPv4/ARP/UDP Engine
         ----------------------
         U_UDP : entity surf.UdpEngineWrapper
            generic map (
               -- Simulation Generics
               TPD_G          => TPD_G,
               -- UDP Server Generics
               SERVER_EN_G    => true,
               SERVER_SIZE_G  => NUM_PORT_G,
               SERVER_PORTS_G => SERVER_PORTS_C,
               -- UDP Client Generics
               CLIENT_EN_G    => false,
               -- General IPv4/ARP/DHCP Generics
               DHCP_G         => DHCP_C,
               CLK_FREQ_G     => SYS_CLK_FREQ_G,
               COMM_TIMEOUT_G => 30)
            port map (
               -- Local Configurations
               localMac        => ethMac,
               localIp         => ethIp,
               -- Interface to Ethernet Media Access Controller (MAC)
               obMacMaster     => obMacMasters(i),
               obMacSlave      => obMacSlaves(i),
               ibMacMaster     => ibMacMasters(i),
               ibMacSlave      => ibMacSlaves(i),
               -- Interface to UDP Server engine(s)
               obServerMasters => obServerMasters(i*NUM_PORT_G+(NUM_PORT_G-1) downto i*NUM_PORT_G),
               obServerSlaves  => obServerSlaves(i*NUM_PORT_G+(NUM_PORT_G-1) downto i*NUM_PORT_G),
               ibServerMasters => ibServerMasters(i*NUM_PORT_G+(NUM_PORT_G-1) downto i*NUM_PORT_G),
               ibServerSlaves  => ibServerSlaves(i*NUM_PORT_G+(NUM_PORT_G-1) downto i*NUM_PORT_G),
               -- Clock and Reset
               clk             => ethClk,
               rst             => ethRst);


         GEN_PORTS : for j in 0 to NUM_PORT_G-1 generate

            GEN_RSSI : if (RSSI_C = true) generate
               ---------------------------------------------------------------
               -- Wrapper for RSSI + AXIS Packetizer
               -- Documentation: https://confluence.slac.stanford.edu/x/1IyfD
               ---------------------------------------------------------------
               U_RssiServer : entity surf.RssiCoreWrapper
                  generic map (
                     TPD_G               => TPD_G,
                     APP_ILEAVE_EN_G     => APP_ILEAVE_EN_C,
                     MAX_SEG_SIZE_G      => 1024,
                     SEGMENT_ADDR_SIZE_G => 7,
                     APP_STREAMS_G       => 1,
                     APP_STREAM_ROUTES_G => (0 => "--------"),
                     CLK_FREQUENCY_G     => SYS_CLK_FREQ_G,
                     TIMEOUT_UNIT_G      => 1.0E-3,  -- In units of seconds
                     SERVER_G            => true,
                     RETRANSMIT_ENABLE_G => true,
                     BYPASS_CHUNKER_G    => false,
                     WINDOW_ADDR_SIZE_G  => 3,
                     PIPE_STAGES_G       => 1,
                     APP_AXIS_CONFIG_G   => AXIS_CONFIG_C,
                     TSP_AXIS_CONFIG_G   => EMAC_AXIS_CONFIG_C,
                     INIT_SEQ_N_G        => 16#80#)
                  port map (
                     clk_i                => ethClk,
                     rst_i                => ethRst,
                     openRq_i             => '1',
                     -- Transport Layer Interface
                     sTspAxisMaster_i     => obServerMasters(i*NUM_PORT_G+j),
                     sTspAxisSlave_o      => obServerSlaves(i*NUM_PORT_G+j),
                     mTspAxisMaster_o     => ibServerMasters(i*NUM_PORT_G+j),
                     mTspAxisSlave_i      => ibServerSlaves(i*NUM_PORT_G+j),
                     -- Application Layer Interface
                     sAppAxisMasters_i(0) => appIbMasters(i*NUM_PORT_G+j),
                     sAppAxisSlaves_o(0)  => appIbSlaves(i*NUM_PORT_G+j),
                     mAppAxisMasters_o(0) => appObMasters(i*NUM_PORT_G+j),
                     mAppAxisSlaves_i(0)  => appObSlaves(i*NUM_PORT_G+j),
                     -- Internal statuses
                     statusReg_o          => rssiStatus(i*NUM_PORT_G+j));

               rssiLinkUp(i*NUM_PORT_G+j) <= rssiStatus(i*NUM_PORT_G+j)(0);

            end generate;

            BYP_RSSI : if (RSSI_C = false) generate

               ---------------------------
               -- No UDP reliability Layer
               ---------------------------
               appObMasters(i*NUM_PORT_G+j)    <= obServerMasters(i*NUM_PORT_G+j);
               obServerSlaves(i*NUM_PORT_G+j)  <= appObSlaves(i*NUM_PORT_G+j);
               ibServerMasters(i*NUM_PORT_G+j) <= appIbMasters(i*NUM_PORT_G+j);
               appIbSlaves(i*NUM_PORT_G+j)     <= ibServerSlaves(i*NUM_PORT_G+j);
               rssiLinkUp(i*NUM_PORT_G+j)      <= '0';

            end generate;

         end generate;

         SIMULATION_GEN : if (SIMULATION_G) generate

            ethClk <= ethClkP;

            U_PwrUpRst : entity surf.PwrUpRst
               generic map (
                  TPD_G         => TPD_G,
                  SIM_SPEEDUP_G => true)
               port map (
                  clk    => ethClk,
                  rstOut => ethRst);

            U_RogueStreamSimWrap_1 : entity surf.RogueStreamSimWrap
               generic map (
                  TPD_G               => TPD_G,
                  DEST_ID_G           => 0,
                  USER_ID_G           => i*NUM_PORT_G+j,
                  COMMON_MASTER_CLK_G => true,
                  COMMON_SLAVE_CLK_G  => true,
                  AXIS_CONFIG_G       => EMAC_AXIS_CONFIG_C)
               port map (
                  clk         => ethClk,
                  rst         => ethRst,
                  sAxisClk    => ethClk,
                  sAxisRst    => ethRst,
                  sAxisMaster => appIbMasters(i*NUM_PORT_G+j),
                  sAxisSlave  => appIbSlaves(i*NUM_PORT_G+j),
                  mAxisClk    => ethClk,
                  mAxisRst    => ethRst,
                  mAxisMaster => appObMasters(i*NUM_PORT_G+j),
                  mAxisSlave  => appObSlaves(i*NUM_PORT_G+j));

         end generate SIMULATION_GEN;

         ---------------------------------------------------------------
         -- SLAC Register Protocol Version 3, AXI-Lite Interface
         -- Documentation: https://confluence.slac.stanford.edu/x/cRmVD
         ---------------------------------------------------------------
         U_SRPv3 : entity surf.SrpV3AxiLite
            generic map (
               TPD_G               => TPD_G,
               SLAVE_READY_EN_G    => true,
               GEN_SYNC_FIFO_G     => true,
               AXIL_CLK_FREQ_G     => SYS_CLK_FREQ_G,
               AXI_STREAM_CONFIG_G => EMAC_AXIS_CONFIG_C)
            port map (
               -- Streaming Slave (Rx) Interface (sAxisClk domain)
               sAxisClk         => ethClk,
               sAxisRst         => ethRst,
               sAxisMaster      => appObMasters(i*NUM_PORT_G+j),
               sAxisSlave       => appObSlaves(i*NUM_PORT_G+j),
               -- Streaming Master (Tx) Data Interface (mAxisClk domain)
               mAxisClk         => ethClk,
               mAxisRst         => ethRst,
               mAxisMaster      => appIbMasters(i*NUM_PORT_G+j),
               mAxisSlave       => appIbSlaves(i*NUM_PORT_G+j),
               -- Master AXI-Lite Interface (axilClk domain)
               axilClk          => ethClk,
               axilRst          => ethRst,
               mAxilReadMaster  => axilReadMasters(i*NUM_PORT_G+j),
               mAxilReadSlave   => axilReadSlaves(i*NUM_PORT_G+j),
               mAxilWriteMaster => axilWriteMasters(i*NUM_PORT_G+j),
               mAxilWriteSlave  => axilWriteSlaves(i*NUM_PORT_G+j));

      end generate GEN_PORT;

   end generate GEN_LANE;

end mapping;
