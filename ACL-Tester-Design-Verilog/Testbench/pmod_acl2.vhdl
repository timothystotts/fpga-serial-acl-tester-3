--------------------------------------------------------------------------------
-- MIT License
--
-- Copyright (c) 2021 Timothy Stotts
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--------------------------------------------------------------------------------
-- \file pmod_acl2.vhdl
--
-- \brief OSVVM testbench component: incomplete Simulation Model of Digilent Inc.
-- Pmod ACL2 external peripheral, using datasheet for Analog Devices ADXL362.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library osvvm;
context osvvm.OsvvmContext;

library work;
--------------------------------------------------------------------------------
package tbc_pmod_acl2_types_pkg is
	-- Byte address of the ADXL362 status register. See ADI datasheet.
	constant c_reg_idx_status_reg : natural := 16#0B#;
	-- Byte address of the signed XDATA value, lower byte. See ADI datasheet.
	constant c_reg_idx_xdata_l    : natural := 16#0E#;
	-- Byte address of the signed XDATA value, upper byte. See ADI datasheet.
	constant c_reg_idx_xdata_h    : natural := 16#0F#;
	-- Byte address of the signed YDATA value, lower byte. See ADI datasheet.
	constant c_reg_idx_ydata_l    : natural := 16#10#;
	-- Byte address of the signed YDATA value, upper byte. See ADI datasheet.
	constant c_reg_idx_ydata_h    : natural := 16#11#;
	-- Byte address of the signed ZDATA value, lower byte. See ADI datasheet.
	constant c_reg_idx_zdata_l    : natural := 16#12#;
	-- Byte address of the signed ZDATA value, upper byte. See ADI datasheet.
	constant c_reg_idx_zdata_h    : natural := 16#13#;
	-- Byte address of the signed TEMP value, lower byte. See ADI datasheet.
	constant c_reg_idx_temp_l     : natural := 16#14#;
	-- Byte address of the signed TEMP value, upper byte. See ADI datasheet.
	constant c_reg_idx_temp_h     : natural := 16#15#;
	-- Byte address of the ADXL362 INT1 Mapping register. See ADI datasheet.
	constant c_reg_idx_int1_map   : natural := 16#2A#;
	-- Byte address of the ADXL362 INT2 Mapping register. See ADI datasheet.
	constant c_reg_idx_int2_map   : natural := 16#2B#;
	-- Byte address of the ADXL362 Filter Control register. See ADI datasheet.
	constant c_reg_idx_filter_ctl : natural := 16#2C#;

	-- Register description type: permissions: Read-Only, Write-Only,
	-- Read-Write, Reserved.
	type t_reg_perm is (REG_R, REG_W, REG_RW, REG_RESV);

	-- Register value array type: integer byte for an integer address range.
	-- Integers can be specified in base-16 with 16#value# .
	type t_reg_array is array (natural range <>) of natural range 0 to 255;

	-- Register permission array type: array of \ref t_reg_perm .
	type t_reg_perms is array(natural range <>) of t_reg_perm;

	-- Register address number type: a constrained integer. The ADI datasheet
	-- specifies 0 to 46. This type ranges 0 to 47 for less complex
	-- SPI address auto-increment.
	subtype t_op_addr is natural range 0 to 47;

	-- A protected complex type to implement a 8-bit logic vector register
	-- with access to shared between multiple architecture processes. 
	type t_share_reg is protected
		impure function Get return std_logic_vector;
		procedure Set(constant c_reg    : in std_logic_vector(7 downto 0));
		procedure Update(constant c_bit :    std_logic; constant c_pos : natural range 0 to 7);
	end protected t_share_reg;

	-- A protected complex type to implement a signed 16-bit logic vector
	-- register with access to shared between multiple architecture processes.
	-- This type also implements MAX and MIN boundaries, with increment and
	-- decrement methods for the purpose of quickly modifying the register
	-- value, presuming that the register contains a data reading and not
	-- controls.
	type t_share_s16bit_reg is protected
		procedure SetMax(constant c_max : in std_logic_Vector(15 downto 0));
		procedure SetMin(constant c_min : in std_logic_vector(15 downto 0));
		impure function Get return std_logic_vector;
		procedure Set(constant c_reg          : in std_logic_vector(15 downto 0));
		procedure Update(constant c_bit       : in std_logic; constant c_pos : in natural range 0 to 15);
		procedure Increment_By(constant c_val : in natural range 0 to 2**16-1;
				variable capped : out boolean);
		procedure Decrement_By(constant c_val : in natural range 0 to 2**16-1;
				variable capped : out boolean);
	end protected t_share_s16bit_reg;
end package tbc_pmod_acl2_types_pkg;
--------------------------------------------------------------------------------
package body tbc_pmod_acl2_types_pkg is
	type t_share_reg is protected body
		variable v_reg : std_logic_vector(7 downto 0) := (others => '0');

		impure function Get return std_logic_vector is
		begin
			return v_reg;
		end function Get;

		procedure Set(constant c_reg : in std_logic_vector(7 downto 0)) is
		begin
			v_reg := c_reg;
		end procedure Set;

		procedure Update(constant c_bit : std_logic; constant c_pos : natural range 0 to 7) is
	begin
		v_reg(c_pos) := c_bit;
		end procedure Update;
	end protected body t_share_reg;

	type t_share_s16bit_reg is protected body
		variable v_max : std_logic_vector(15 downto 0) := (others => '0');
		variable v_min : std_logic_vector(15 downto 0) := (others => '0');
		variable v_reg : std_logic_vector(15 downto 0) := (others => '0');

		procedure SetMax(constant c_max : in std_logic_Vector(15 downto 0)) is
		begin
			v_max := c_max;
		end procedure SetMax;

		procedure SetMin(constant c_min : in std_logic_Vector(15 downto 0)) is
		begin
			v_min := c_min;
		end procedure SetMin;

		impure function Get return std_logic_vector is
		begin
			return v_reg;
		end function Get;

		procedure Set(constant c_reg : in std_logic_vector(15 downto 0)) is
		begin
			v_reg := c_reg;
		end procedure Set;

		procedure Update(constant c_bit : in std_logic; constant c_pos : in natural range 0 to 15) is
		begin
			v_reg(c_pos) := c_bit;
		end procedure Update;

		procedure Increment_By(constant c_val : in natural range 0 to 2**16-1;
				variable capped : out boolean) is
			variable v_reg_tmp : signed(19 downto 0) := signed(v_reg(15) & v_reg(15) & v_reg(15) & v_reg(15) & v_reg);
			variable v_reg_max : signed(19 downto 0) := signed(v_max(15) & v_max(15) & v_max(15) & v_max(15) & v_max);
		begin
			v_reg_tmp := v_reg_tmp + c_val;
			if (v_reg_tmp > v_reg_max) then
				v_reg  := v_max;
				capped := true;
			else
				v_reg  := std_logic_vector(v_reg_tmp(15 downto 0));
				capped := false;
			end if;
		end procedure Increment_By;

		procedure Decrement_By(constant c_val : in natural range 0 to 2**16-1;
				variable capped : out boolean) is
			variable v_reg_tmp : signed(19 downto 0) := signed(v_reg(15) & v_reg(15) & v_reg(15) & v_reg(15) & v_reg);
			variable v_reg_min : signed(19 downto 0) := signed(v_min(15) & v_min(15) & v_min(15) & v_min(15) & v_min);
		begin
			v_reg_tmp := v_reg_tmp - c_val;
			if (v_reg_tmp < v_reg_min) then
				v_reg  := v_min;
				capped := true;
			else
				v_reg  := std_logic_vector(v_reg_tmp(15 downto 0));
				capped := false;
			end if;
		end procedure Decrement_By;
	end protected body t_share_s16bit_reg;
end package body tbc_pmod_acl2_types_pkg;
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library osvvm;
context osvvm.OsvvmContext;

library work;
use work.tbc_pmod_acl2_types_pkg.all;
--------------------------------------------------------------------------------
package tbc_pmod_acl2_pkg is
	-- A constant defining the default byte values of the full register map of
	-- the ADXL362. See ADI datasheet.
	constant c_acl2_reg_mem : t_reg_array(t_op_addr'low to t_op_addr'high) := (
			16#AD#, 16#1D#, 16#F2#, 16#01#, 16#00#, 16#00#, 16#00#, 16#00#,
			16#00#, 16#00#, 16#00#, 16#40#, 16#00#, 16#00#, 16#00#, 16#00#,
			16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#,
			16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#,
			16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#,
			16#00#, 16#80#, 16#00#, 16#00#, 16#13#, 16#00#, 16#00#, 16#00#
		);

	-- A constant defining the register access types/permissions of the full
	-- register map of the ADXL362. See datasheet.
	constant c_acl2_reg_perms : t_reg_perms(t_op_addr'low to t_op_addr'high) := (
			REG_R, REG_R, REG_R, REG_R, REG_RESV, REG_RESV, REG_RESV, REG_RESV,
			REG_R, REG_R, REG_R, REG_R, REG_R, REG_R, REG_R, REG_R,
			REG_R, REG_R, REG_R, REG_R, REG_R, REG_R, REG_R, REG_R,
			REG_RESV, REG_RESV, REG_RESV, REG_RESV, REG_RESV, REG_RESV, REG_RESV, REG_W,
			REG_RW, REG_RW, REG_RW, REG_RW, REG_RW, REG_RW, REG_RW, REG_RW,
			REG_RW, REG_RW, REG_RW, REG_RW, REG_RW, REG_RW, REG_RW, REG_RESV
		);

	-- A procedure to perform Mode 0 SPI register reading or writing, with
	-- the Pmod ACL2 (containing ADXL362) as FPGA peripheral.
	procedure pr_spi_reg_access_mode_zero(
			constant ModelID       : in    AlertLogIDType;
			signal sck             : in    std_logic;
			signal csn             : in    std_logic;
			signal copi            : in    std_logic;
			signal cipo            : out   std_logic;
			variable input_buffer  : inout std_logic_vector;
			variable output_buffer : inout std_logic_vector;
			variable buffer_len    : inout natural;
			variable buffer_ovr    : inout natural;
			variable reg_mem       : inout t_reg_array;
			variable reg_access    : inout t_reg_array;
			variable reg_pending   : inout t_reg_array;
			constant reg_perms     : in    t_reg_perms
		);
end package tbc_pmod_acl2_pkg;
--------------------------------------------------------------------------------
package body tbc_pmod_acl2_pkg is
	procedure pr_spi_reg_access_mode_zero(
			constant ModelID       : in    AlertLogIDType;
			signal sck             : in    std_logic;
			signal csn             : in    std_logic;
			signal copi            : in    std_logic;
			signal cipo            : out   std_logic;
			variable input_buffer  : inout std_logic_vector;
			variable output_buffer : inout std_logic_vector;
			variable buffer_len    : inout natural;
			variable buffer_ovr    : inout natural;
			variable reg_mem       : inout t_reg_array;
			variable reg_access    : inout t_reg_array;
			variable reg_pending   : inout t_reg_array;
			constant reg_perms     : in    t_reg_perms
		) is
		alias in_buf  : std_logic_vector(input_buffer'length downto 1) is input_buffer;
		alias out_buf : std_logic_vector(output_buffer'length downto 1) is output_buffer;

		variable op_read        : boolean                := false;
		variable op_write       : boolean                := false;
		variable op_addr_in     : natural range 0 to 255 := 0;
		variable op_addr        : t_op_addr              := 0;
		variable op_addr_slv    : std_logic_vector(7 downto 0);
		variable op_byte_slv    : std_logic_vector(7 downto 0);
		variable val_out_as_slv : std_logic_vector(7 downto 0);
		variable val_in_as_int  : natural range 0 to 255;
	begin
		-- Set initial count and output values.
		buffer_len := 0;
		buffer_ovr := 0;
		cipo       <= 'Z';

		-- Upon entering this loop, it is presumed that outside the procedure
		-- the process had already detected: wait until csn = '0'.
		l_spi_recv : loop
			-- Wait for a clock edge or deassertion of chip select
			wait on sck, csn;

			-- Upon falling edge of SPI clock
			if (sck'event and sck = '0') then
				if (op_read and (buffer_len <= 15)) then
					-- High Z for first 16 bits, first bit without falling edge
					-- and preceding the first rising edge of clock.
					cipo <= 'Z';
				elsif (op_write) then
					-- For a write operation, continue to hold High Z.
					cipo <= 'Z';
				elsif (not(op_read or op_write)) then
					-- For an unknown operation, continue to hold High Z.
					cipo <= 'Z';
				else
					-- For a read operation, output the MSBit.
					cipo <= out_buf(out_buf'left);
				end if;

				-- Shift the output buffer left by one bit, to discard the
				-- MSBit of the buffer.
				out_buf := out_buf(out_buf'left - 1 downto 1) & '0';
			end if;

			-- Upon rising edge of SPI clock
			if (sck'event and sck = '1') then
				-- Shift the input buffer left by one bit, to enqueue the
				-- MSBbit of the buffer.
				in_buf := in_buf(in_buf'left - 1 downto 1) & copi;

				-- If input buffer not exceeded, count the bits received.
				-- If maxed-out, then count the number of overrun bits.
				if (buffer_len < in_buf'length) then
					buffer_len := buffer_len + 1;
				else
					buffer_ovr := buffer_ovr + 1;
				end if;

				-- Test the first byte once received, to determine if the
				-- operation mode is WRITE or READ or unknown.
				if (buffer_len = 8) then
					op_write := (in_buf(8 downto 1) = x"0A");
					op_read  := (in_buf(8 downto 1) = x"0B");
				end if;

				-- Attempt to receive the Operation Address, an integer byte.
				if (buffer_len = 16) then
					if (op_write or op_read) then
						op_addr_in := to_integer(unsigned(in_buf(8 downto 1)));
						if ((op_addr_in < t_op_addr'high) and (op_addr_in >= 0)) then
							op_addr := op_addr_in;
						else
							op_addr := t_op_addr'high;
						end if;
					end if;
				end if;

				-- Convert the address integer to a logic byte.
				op_addr_slv    := std_logic_vector(to_unsigned(op_addr, 8));
				-- Read the register memory at the address location, and place
				-- in this variable.
				val_out_as_slv := std_logic_vector(
					to_unsigned(reg_mem(op_addr), 8));
				-- Convert the input byte (lowest 8 bits at any time) to an
				-- integer representation.
				val_in_as_int  := to_integer(unsigned(in_buf(8 downto 1)));

				-- On the clock count immediately before the FPGA bus Controller
				-- reads a byte's first bit from this ACL2 peripheral, set the
				-- MSByte of the output buffer. This only occurs immediately
				-- before the output of the 3rd, 4th, 5th, etc byte, honoring
				-- address auto-increment.
				if (buffer_len mod 8 = 0) then
					if (op_addr < t_op_addr'high) then
						if ((op_read) and (buffer_len >= 16)) then
							if ((reg_perms(op_addr) = REG_R) or (reg_perms(op_addr) = REG_RW)) then
								out_buf(out_buf'left downto out_buf'left - 7) := val_out_as_slv;
							end if;
						end if;
					end if;
				end if;

				-- On the clock count immediately after the FPGA bus Controller
				-- reads a byte's first bit from the ACL2 peripheral, Log the
				-- the address and value being read, check register permissions,
				-- and if permissions exist for reading, auto-increment the read
				-- address.
				if (buffer_len mod 8 = 1) then
					if (op_addr < t_op_addr'high) then
						if ((op_read) and (buffer_len > 16)) then
							if ((reg_perms(op_addr) = REG_R) or (reg_perms(op_addr) = REG_RW)) then
								op_byte_slv := std_logic_vector(to_unsigned(reg_mem(op_addr), 8));
								reg_access(op_addr) := 1;

								Log(ModelID, "PMOD ACL2 read addr x" & to_hstring(op_addr_slv) &
									" value x" & to_hstring(op_byte_slv), INFO);

								if (op_addr < t_op_addr'high) then
									op_addr := op_addr + 1;
								end if;
							else
								Alert(ModelID, "PMOD ACL2 attempted read of non-read address x" &
									to_string(op_addr_slv), WARNING);
							end if;
						end if;
					end if;
				end if;

				-- On the clock count immediately after a full byte has been
				-- written via SPI, check the register permissions, if
				-- permitted commit that byte to register memory, and flag
				-- the byte as Pending so that the outer process can take to
				-- synchronize memory bytes instead of overwritten.
				if (buffer_len mod 8 = 0) then
					if (op_addr < t_op_addr'high) then
						if ((op_write) and (buffer_len >= 24)) then
							if ((reg_perms(op_addr) = REG_W) or (reg_perms(op_addr) = REG_RW)) then
								reg_mem(op_addr)     := val_in_as_int;
								reg_pending(op_addr) := 1;
								op_byte_slv          := std_logic_vector(to_unsigned(reg_mem(op_addr), 8));

								Log(ModelID, "PMOD ACL2 write addr x" & to_hstring(op_addr_slv) &
									" value x" & to_hstring(op_byte_slv), INFO);

								if (op_addr < t_op_addr'high) then
									op_addr := op_addr + 1;
								end if;
							else
								Alert(ModelID, "PMOD ACL2 attempted write to non-write address x" &
									to_string(op_addr_slv) & " with value x" &
									to_string(op_byte_slv), WARNING);
							end if;
						end if;
					end if;
				end if;
			end if;

			-- If the chip select rises, then exit this procedure.
			if (csn = '1') then
				exit;
			end if;
		end loop l_spi_recv;
	end procedure pr_spi_reg_access_mode_zero;
end package body tbc_pmod_acl2_pkg;
---------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library osvvm;
context osvvm.OsvvmContext;

library work;
use work.acl_testbench_types_pkg.all;
use work.acl_testbench_pkg.all;
use work.tbc_pmod_acl2_types_pkg.all;
use work.tbc_pmod_acl2_pkg.all;
--------------------------------------------------------------------------------
entity tbc_pmod_acl2 is
	port(
		TBID             : in    AlertLogIDType;
		BarrierTestStart : inout std_logic;
		BarrierLogStart  : inout std_logic;
		ci_sck           : in    std_logic;
		ci_csn           : in    std_logic;
		ci_copi          : in    std_logic;
		co_cipo          : out   std_logic;
		co_int1          : out   std_logic;
		co_int2          : out   std_logic
	);
end entity tbc_pmod_acl2;
--------------------------------------------------------------------------------
architecture simulation_default of tbc_pmod_acl2 is
	-- Shared status register byte.
	shared variable sv_status_reg : t_share_reg;
	-- Shared 16-bit signed XDATA register.
	shared variable sv_xdata_reg  : t_share_s16bit_reg;
	-- Shared 16-bit signed YDATA register.
	shared variable sv_ydata_reg  : t_share_s16bit_reg;
	-- Shared 16-bit signed ZDATA register.
	shared variable sv_zdata_reg  : t_share_s16bit_reg;
	-- Shared 16-bit signed TEMP register.	
	shared variable sv_temp_reg   : t_share_s16bit_reg;

	signal ModelID : AlertLogIDType;

	signal s_clk            : std_logic;
	signal so_int1          : std_logic;
	signal so_int2          : std_logic;
	signal s_filter_ctl_reg : std_logic_vector(7 downto 0);
	signal s_int1_map_reg   : std_logic_vector(7 downto 0);
	signal s_int2_map_reg   : std_logic_vector(7 downto 0);
begin
	-- Simulation initialization
	p_sim_init : process
		variable ID : AlertLogIDType;
	begin
		wait for 0 ns;
		WaitForBarrier(BarrierTestStart);
		ID      := GetAlertLogID(PathTail(tbc_pmod_acl2'path_name), TBID);
		ModelID <= ID;

		wait on ModelID;
		Log(ModelID, "Starting Pmod ACL2 emulation with SPI mode 0 bus, two interrupt lines, internal clock of 8.0 MHz.", ALWAYS);

		CreateClock(
			Clk       => s_clk,
			Period    => 125 ns, -- 8 MHz
			DutyCycle => 0.5);
		wait;
	end process p_sim_init;

	-- interrupt signal outputs
	co_int1 <= so_int1;
	co_int2 <= so_int2;

	-- This process implements an emulation of the SPI mode 0 operation of the PmodACL2 as an
	-- SPI mode 0 peripheral with the FPGA as controller. Both COPI and CIPO are used; and the
	-- PmodACL2 is alone on its own SPI bus.
	--
	-- The internal 8 MHz clock of this architecture is used to frequently update the X, Y, Z, Temp
	-- 12-bit register data as stored sign-extended in 16-bit registers. Shared variables of Protected
	-- Type are implemented for this purpose.
	--
	p_spi_reg_access_mode_zero : process
		variable sb_push_item      : t_reg_sb;
		variable v_processed_spi   : boolean := false;
		variable v_temp_s16bit_reg : std_logic_vector(15 downto 0);
		variable input_buffer      : std_logic_vector(127 downto 0);
		variable output_buffer     : std_logic_vector(127 downto 0);
		variable buffer_len        : natural;
		variable buffer_ovr        : natural;
		variable reg_mem           : t_reg_array(c_acl2_reg_mem'range)   := c_acl2_reg_mem;
		variable reg_access        : t_reg_array(c_acl2_reg_mem'range)   := (others => 0);
		variable reg_pending       : t_reg_array(c_acl2_reg_mem'range)   := (others => 0);
		constant reg_perms         : t_reg_perms(c_acl2_reg_perms'range) := c_acl2_reg_perms;
	begin
		wait for 0 ns;
		WaitForBarrier(BarrierLogStart);
		Log(ModelID, "Entering Pmod ACL2 emulation with SPI mode 0 bus.", ALWAYS);

		l_spi_recv : loop
			input_buffer  := (others => '0');
			output_buffer := (others => '0');

			v_processed_spi := false;
			l_spi_process : while (not v_processed_spi) loop
				wait on ci_csn, s_clk;

				if (ci_csn'event and ci_csn = '0') then

					pr_spi_reg_access_mode_zero(
						ModelID,
						ci_sck,
						ci_csn,
						ci_copi,
						co_cipo,
						input_buffer,
						output_buffer,
						buffer_len,
						buffer_ovr,
						reg_mem,
						reg_access,
						reg_pending,
						reg_perms);

					v_processed_spi := true;

					--constant c_reg_idx_xdata_l    : natural := 16#0E#;
					--constant c_reg_idx_xdata_h    : natural := 16#0F#;
					--constant c_reg_idx_ydata_l    : natural := 16#10#;
					--constant c_reg_idx_ydata_h    : natural := 16#11#;
					--constant c_reg_idx_zdata_l    : natural := 16#12#;
					--constant c_reg_idx_zdata_h    : natural := 16#13#;
					--constant c_reg_idx_temp_l     : natural := 16#14#;
					--constant c_reg_idx_temp_h     : natural := 16#15#;

					if ((reg_access(c_reg_idx_xdata_l) = 1) and (reg_access(c_reg_idx_xdata_h) = 1) and
						(reg_access(c_reg_idx_ydata_l) = 1) and (reg_access(c_reg_idx_ydata_h) = 1) and
						(reg_access(c_reg_idx_zdata_l) = 1) and (reg_access(c_reg_idx_zdata_h) = 1) and
						(reg_access(c_reg_idx_temp_l) = 1) and (reg_access(c_reg_idx_temp_h) = 1)) then


						sb_push_item(8*8-1 downto 7*8) := std_logic_vector(to_unsigned(reg_mem(c_reg_idx_xdata_h), 8));
						sb_push_item(7*8-1 downto 6*8) := std_logic_vector(to_unsigned(reg_mem(c_reg_idx_xdata_l), 8));
						sb_push_item(6*8-1 downto 5*8) := std_logic_vector(to_unsigned(reg_mem(c_reg_idx_ydata_h), 8));
						sb_push_item(5*8-1 downto 4*8) := std_logic_vector(to_unsigned(reg_mem(c_reg_idx_ydata_l), 8));
						sb_push_item(4*8-1 downto 3*8) := std_logic_vector(to_unsigned(reg_mem(c_reg_idx_zdata_h), 8));
						sb_push_item(3*8-1 downto 2*8) := std_logic_vector(to_unsigned(reg_mem(c_reg_idx_zdata_l), 8));
						sb_push_item(2*8-1 downto 1*8) := std_logic_vector(to_unsigned(reg_mem(c_reg_idx_temp_h), 8));
						sb_push_item(1*8-1 downto 0*8) := std_logic_vector(to_unsigned(reg_mem(c_reg_idx_temp_l), 8));

						Log(ModelID, "PMOD ACL2 SPI mode 0 access iteration, pushing Pmod ACL2 data to PmodCLS and BoardUART ScoreBoards: x" & to_hstring(sb_push_item), INFO);
						SB_CLS.Push(sb_push_item);
						SB_UART.Push(sb_push_item);
					else
						Log(ModelID, "PMOD ACL2 SPI mode 0 access iteration, completed without pushing to ScoreBoards.", INFO);
					end if;

					reg_access(c_reg_idx_xdata_l) := 0;
					reg_access(c_reg_idx_xdata_h) := 0;
					reg_access(c_reg_idx_ydata_l) := 0;
					reg_access(c_reg_idx_ydata_h) := 0;
					reg_access(c_reg_idx_zdata_l) := 0;
					reg_access(c_reg_idx_zdata_h) := 0;
					reg_access(c_reg_idx_temp_l) := 0;
					reg_access(c_reg_idx_temp_h) := 0;
					sb_push_item := (others => 'U');

				elsif (s_clk'event and s_clk = '1') then
					v_temp_s16bit_reg          := sv_xdata_reg.Get;
					reg_mem(c_reg_idx_xdata_l) := to_integer(unsigned(v_temp_s16bit_reg(7 downto 0)));
					reg_mem(c_reg_idx_xdata_h) := to_integer(unsigned(v_temp_s16bit_reg(15 downto 8)));

					v_temp_s16bit_reg          := sv_ydata_reg.Get;
					reg_mem(c_reg_idx_ydata_l) := to_integer(unsigned(v_temp_s16bit_reg(7 downto 0)));
					reg_mem(c_reg_idx_ydata_h) := to_integer(unsigned(v_temp_s16bit_reg(15 downto 8)));

					v_temp_s16bit_reg          := sv_zdata_reg.Get;
					reg_mem(c_reg_idx_zdata_l) := to_integer(unsigned(v_temp_s16bit_reg(7 downto 0)));
					reg_mem(c_reg_idx_zdata_h) := to_integer(unsigned(v_temp_s16bit_reg(15 downto 8)));

					v_temp_s16bit_reg         := sv_temp_reg.Get;
					reg_mem(c_reg_idx_temp_l) := to_integer(unsigned(v_temp_s16bit_reg(7 downto 0)));
					reg_mem(c_reg_idx_temp_h) := to_integer(unsigned(v_temp_s16bit_reg(15 downto 8)));
				end if;
			end loop;

			s_int1_map_reg   <= std_logic_vector(to_unsigned(reg_mem(c_reg_idx_int1_map), 8));
			s_int2_map_reg   <= std_logic_vector(to_unsigned(reg_mem(c_reg_idx_int2_map), 8));
			s_filter_ctl_reg <= std_logic_vector(to_unsigned(reg_mem(c_reg_idx_filter_ctl), 8));

			-- Synchronize the Status Register
			-- Step 1 - react to register write
			if (reg_pending(c_reg_idx_status_reg) = 1) then
				sv_status_reg.Set(std_logic_vector(to_unsigned(reg_mem(c_reg_idx_status_reg), 8)));
				reg_pending(c_reg_idx_status_reg) := 0;
			end if;
			-- Step 2 - react to register read
			if (reg_access(c_reg_idx_status_reg) = 1) then
				sv_status_reg.Update('0', 0);
				reg_access(c_reg_idx_status_reg) := 0;
			end if;
			-- Step 3 - final sync
			reg_mem(c_reg_idx_status_reg) := to_integer(unsigned(sv_status_reg.Get));
		end loop l_spi_recv;
	end process p_spi_reg_access_mode_zero;

	-- This process implements an emulation of the internal Data Ready status
	-- indication, controlled in frequency by the FILTER_CTL. When the indication
	-- happens, the X, Y, Z, Temp data registers are updated with a rotating
	-- change, starting at zero, between Min and Max, according to an arbitrary
	-- increment and decrement. As OSVVM Coverage and Scoreboard could be implemented
	-- according to this data, this section may require editing.
	--
	-- Refer to datasheet Register Details of FILTER_CTL as to the logical behavior
	-- that this process attempts to emulate.
	p_filter_ctl : process
		variable v_delay      : time    := 2.5 ms;
		variable v_delay_prev : time    := 0 ms;
		variable v_capped     : boolean := false;
		variable x_increment  : boolean := true;
		variable y_increment  : boolean := false;
		variable z_increment  : boolean := true;
		variable t_increment  : boolean := false;
	begin
		wait for 0 ns;
		-- 8 bit register init
		sv_status_reg.Set(x"00");

		-- 16 bit register init
		sv_xdata_reg.Set(x"0000");
		sv_xdata_reg.SetMax(x"0FFF");
		sv_xdata_reg.SetMin(x"F000");

		sv_ydata_reg.Set(x"0000");
		sv_ydata_reg.SetMax(x"0FFF");
		sv_ydata_reg.SetMin(x"F000");

		sv_zdata_reg.Set(x"0000");
		sv_zdata_reg.SetMax(x"0FFF");
		sv_zdata_reg.SetMin(x"F000");

		sv_temp_reg.Set(x"0000");
		sv_temp_reg.SetMax(x"00FF");
		sv_temp_reg.SetMin(x"FF00");

		WaitForBarrier(BarrierLogStart);
		Log(ModelID, "Entering Pmod ACL2 emulation of Data Ready filter control.", ALWAYS);

		sv_status_reg.Update('0', 0);

		l_drive_data_ready : loop
			case s_filter_ctl_reg(2 downto 0) is
				when "000"  => v_delay := 80 ms;
				when "001"  => v_delay := 40 ms;
				when "010"  => v_delay := 20 ms;
				when "011"  => v_delay := 10 ms;
				when "100"  => v_delay := 5 ms;
				when others => v_delay := 2.5 ms;
			end case;

			if (v_delay /= v_delay_prev) then
				Log(ModelID, "Updating Pmod ACL2 emulation of Data Ready filter " &
					"control executing with period " & to_string(v_delay) & " .", ALWAYS);
			end if;

			wait for v_delay;

			if (x_increment) then
				sv_xdata_reg.Increment_By(16#81#, v_capped);
				x_increment := not v_capped;
			else
				sv_xdata_reg.Decrement_By(16#82#, v_capped);
				x_increment := v_capped;
			end if;

			if (y_increment) then
				sv_ydata_reg.Increment_By(16#F3#, v_capped);
				y_increment := not v_capped;
			else
				sv_ydata_reg.Decrement_By(16#F4#, v_capped);
				y_increment := v_capped;
			end if;

			if (z_increment) then
				sv_zdata_reg.Increment_By(16#C5#, v_capped);
				z_increment := not v_capped;
			else
				sv_zdata_reg.Decrement_By(16#C6#, v_capped);
				z_increment := v_capped;
			end if;

			if (t_increment) then
				sv_temp_reg.Increment_By(16#05#, v_capped);
				t_increment := not v_capped;
			else
				sv_temp_reg.Decrement_By(16#06#, v_capped);
				t_increment := v_capped;
			end if;

			sv_status_reg.Update('1', 0);

			v_delay_prev := v_delay;
		end loop l_drive_data_ready;
		wait;
	end process p_filter_ctl;

	-- This process implements an emulation of the INT1 and INT2 physical interrupt
	-- lines of the Pmod ACL2 board, as driven by the ADXL362 chip. Three registers
	-- determine the state of the interrupt lines. For INT1: INTMAP1(6 downto 0)
	-- ANDed with the STATUS(6 downto 0), then XORed with the INTMAP1(7) for polarity
	-- of the physical line. For INT2, the same calculation, with INTMAP2 and the
	-- STATUS register.
	--
	-- Refer to datasheet Register Map and Register Details as to the logical
	-- behavior that this process attempts to emulate.
	p_update_int12 : process
		variable v_status_reg : std_logic_vector(7 downto 0);
		variable v_prev_int1  : std_logic;
		variable v_prev_int2  : std_logic;
	begin
		wait for 0 ns;
		WaitForBarrier(BarrierLogStart);
		Log(ModelID, "Entering Pmod ACL2 emulation of interrupt lines.", ALWAYS);

		l_drive_int : loop
			wait for 100 ns;
			v_prev_int1 := so_int1;
			v_prev_int2 := so_int2;

			v_status_reg := sv_status_reg.Get;

			so_int1 <= s_int1_map_reg(7) xor (
				or(s_int1_map_reg(6 downto 0) and v_status_reg(6 downto 0)));

			so_int2 <= s_int2_map_reg(7) xor (
				or(s_int2_map_reg(6 downto 0) and v_status_reg(6 downto 0)));

			wait for 1 ns;

			if (so_int1 /= v_prev_int1) then
				Log(ModelID, "PMOD ACL2 INT1 is " & to_string(so_int1), DEBUG);
			end if;

			if (so_int2 /= v_prev_int2) then
				Log(ModelID, "PMOD ACL2 INT2 is " & to_string(so_int2), DEBUG);
			end if;
		end loop l_drive_int;
	end process p_update_int12;

end architecture simulation_default;
--------------------------------------------------------------------------------
