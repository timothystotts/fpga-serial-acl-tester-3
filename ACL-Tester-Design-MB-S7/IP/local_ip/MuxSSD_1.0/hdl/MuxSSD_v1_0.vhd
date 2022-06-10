library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MuxSSD_v1_0 is
	generic (
		-- Users to add parameters here
        C_SSD_CLK_RATIO : integer := 100000;
        
		-- User parameters ends
		-- Do not modify the parameters beyond this line


		-- Parameters of Axi Slave Bus Interface S00_AXI
		C_S00_AXI_DATA_WIDTH	: integer	:= 32;
		C_S00_AXI_ADDR_WIDTH	: integer	:= 4
	);
	port (
		-- Users to add ports here
  		ext_mux_clk : in std_logic;
  		ext_mux_rst : in std_logic;
 
        -- Eight Pmod jack outputs
        ssd_seg_o : out std_logic_vector(6 downto 0);
        ssd_mux_o : out std_logic; 
		-- User ports ends
		-- Do not modify the ports beyond this line

		-- Ports of Axi Slave Bus Interface S00_AXI
		s00_axi_aclk	: in std_logic;
		s00_axi_aresetn	: in std_logic;
		s00_axi_awaddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_awprot	: in std_logic_vector(2 downto 0);
		s00_axi_awvalid	: in std_logic;
		s00_axi_awready	: out std_logic;
		s00_axi_wdata	: in std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_wstrb	: in std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);
		s00_axi_wvalid	: in std_logic;
		s00_axi_wready	: out std_logic;
		s00_axi_bresp	: out std_logic_vector(1 downto 0);
		s00_axi_bvalid	: out std_logic;
		s00_axi_bready	: in std_logic;
		s00_axi_araddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_arprot	: in std_logic_vector(2 downto 0);
		s00_axi_arvalid	: in std_logic;
		s00_axi_arready	: out std_logic;
		s00_axi_rdata	: out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_rresp	: out std_logic_vector(1 downto 0);
		s00_axi_rvalid	: out std_logic;
		s00_axi_rready	: in std_logic
	);
end MuxSSD_v1_0;

architecture arch_imp of MuxSSD_v1_0 is

	-- component declaration
	component MuxSSD_v1_0_S00_AXI is
		generic (
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		C_S_AXI_ADDR_WIDTH	: integer	:= 4
		);
		port (
		reg_right_digit_o : out std_logic_vector(6 downto 0);
		reg_left_digit_o : out std_logic_vector(6 downto 0);
		S_AXI_ACLK	: in std_logic;
		S_AXI_ARESETN	: in std_logic;
		S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
		S_AXI_AWVALID	: in std_logic;
		S_AXI_AWREADY	: out std_logic;
		S_AXI_WDATA	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_WSTRB	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		S_AXI_WVALID	: in std_logic;
		S_AXI_WREADY	: out std_logic;
		S_AXI_BRESP	: out std_logic_vector(1 downto 0);
		S_AXI_BVALID	: out std_logic;
		S_AXI_BREADY	: in std_logic;
		S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
		S_AXI_ARVALID	: in std_logic;
		S_AXI_ARREADY	: out std_logic;
		S_AXI_RDATA	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_RRESP	: out std_logic_vector(1 downto 0);
		S_AXI_RVALID	: out std_logic;
		S_AXI_RREADY	: in std_logic
		);
	end component MuxSSD_v1_0_S00_AXI;

	-- A constant representing the counter maximum which is the clock enable division of the
	-- source clock, per paramter \ref C_SSD_CLK_RATIO .
	constant c_clk_max : natural := C_SSD_CLK_RATIO - 1;

	-- Clock division count, that counts from 0 to \ref c_clk_max and back again
	-- to run the divided clock enable output.
	signal s_clk_div_cnt : natural range 0 to c_clk_max;

	-- A clock enable at the source clock frequency which issues the periodic
	-- toggle of the divided clock.
	signal s_clk_div_ce : std_logic;

	-- muxing signals
	signal s_curr_disp : std_logic_vector(6 downto 0);
	signal s_curr_sel  : std_logic;

	-- AXI LITE register values
	signal reg_right_digit_meta0 : std_logic_vector(6 downto 0);
	signal reg_left_digit_meta0 : std_logic_vector(6 downto 0);
	signal reg_right_digit_meta1 : std_logic_vector(6 downto 0);
	signal reg_left_digit_meta1 : std_logic_vector(6 downto 0);
    signal reg_right_digit : std_logic_vector(6 downto 0);
    signal reg_left_digit : std_logic_vector(6 downto 0);
begin

-- Instantiation of Axi Bus Interface S00_AXI
MuxSSD_v1_0_S00_AXI_inst : MuxSSD_v1_0_S00_AXI
	generic map (
		C_S_AXI_DATA_WIDTH	=> C_S00_AXI_DATA_WIDTH,
		C_S_AXI_ADDR_WIDTH	=> C_S00_AXI_ADDR_WIDTH
	)
	port map (
		reg_right_digit_o => reg_right_digit_meta0,
		reg_left_digit_o => reg_left_digit_meta0,
		S_AXI_ACLK	=> s00_axi_aclk,
		S_AXI_ARESETN	=> s00_axi_aresetn,
		S_AXI_AWADDR	=> s00_axi_awaddr,
		S_AXI_AWPROT	=> s00_axi_awprot,
		S_AXI_AWVALID	=> s00_axi_awvalid,
		S_AXI_AWREADY	=> s00_axi_awready,
		S_AXI_WDATA	=> s00_axi_wdata,
		S_AXI_WSTRB	=> s00_axi_wstrb,
		S_AXI_WVALID	=> s00_axi_wvalid,
		S_AXI_WREADY	=> s00_axi_wready,
		S_AXI_BRESP	=> s00_axi_bresp,
		S_AXI_BVALID	=> s00_axi_bvalid,
		S_AXI_BREADY	=> s00_axi_bready,
		S_AXI_ARADDR	=> s00_axi_araddr,
		S_AXI_ARPROT	=> s00_axi_arprot,
		S_AXI_ARVALID	=> s00_axi_arvalid,
		S_AXI_ARREADY	=> s00_axi_arready,
		S_AXI_RDATA	=> s00_axi_rdata,
		S_AXI_RRESP	=> s00_axi_rresp,
		S_AXI_RVALID	=> s00_axi_rvalid,
		S_AXI_RREADY	=> s00_axi_rready
	);

	-- Add user logic here
	
	-- The AXI registers are in a different clock domain than the ext_mux_clk; so
	-- synchronize the values into the ext_mux_clk domain.
	p_sync_reg_values : process(ext_mux_clk)
	begin
	   if rising_edge(ext_mux_clk) then
	       reg_right_digit <= reg_right_digit_meta1;
	       reg_left_digit <= reg_left_digit_meta1;
	       reg_right_digit_meta1 <= reg_right_digit_meta0;
	       reg_left_digit_meta1 <= reg_left_digit_meta0;
	   end if;
	end process p_sync_reg_values;
	
	-- The clock frequency division is operated by a clock enable signal to
	-- indicate the upstream clock cycle for changing the values of the outputs.
	p_clk_div_cnt: process(ext_mux_clk)
	begin
		if rising_edge(ext_mux_clk) then
			if (ext_mux_rst = '1') then
				s_clk_div_cnt <= 0;
				s_clk_div_ce <= '1';
			else
				if (s_clk_div_cnt = c_clk_max) then
					s_clk_div_cnt <= 0;
					s_clk_div_ce <= '1';
				else
					s_clk_div_cnt <= s_clk_div_cnt + 1;
					s_clk_div_ce <= '0';
				end if;
			end if;
		end if;
	end process p_clk_div_cnt;

	-- Muxed output to the two digit SSD with 8 bits of GPIO
	p_mux_disp_out : process(ext_mux_clk)
	begin
		if rising_edge(ext_mux_clk) then
			if (ext_mux_rst = '1') then
				s_curr_sel  <= '0';
				s_curr_disp <= (others => '0');
			else
			    if (s_clk_div_ce = '1') then
                    if (s_curr_sel = '1') then
                        s_curr_sel  <= '0';
                        s_curr_disp <= reg_right_digit;
                    else
                        s_curr_sel  <= '1';
                        s_curr_disp <= reg_left_digit;
                    end if;
				end if;
			end if;
		end if;
	end process p_mux_disp_out;

	ssd_seg_o <= s_curr_disp;
	ssd_mux_o  <= s_curr_sel;

	-- User logic ends

end arch_imp;
