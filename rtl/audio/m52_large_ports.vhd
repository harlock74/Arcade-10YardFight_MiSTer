-- MC6803 P1/P2 overlay and M52 AY bus adapter.
-- Detailed comparison retained in development; see NOTICE.md for attribution.
-- A cpu68 instruction engine alone does not implement these peripherals.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity m52_large_ports is
  generic(P2_INPUT : std_logic_vector(7 downto 0) := x"02");
  port(clk, reset, ce_psg, bus_write : in std_logic;
       addr : in std_logic_vector(4 downto 0);
       data_in, sound_command : in std_logic_vector(7 downto 0);
       data_out : out std_logic_vector(7 downto 0);
       ay1_audio, ay2_audio : out std_logic_vector(9 downto 0);
       adpcm_control, percussion : out std_logic_vector(7 downto 0);
       debug_ay_write : out std_logic_vector(1 downto 0);
       debug_p1_ddr, debug_p2_ddr : out std_logic_vector(7 downto 0));
end;

architecture rtl of m52_large_ports is
  signal ddr1, ddr2, latch1, latch2 : std_logic_vector(7 downto 0) := (others=>'0');
  signal p1_pins, p2_pins, p1_external : std_logic_vector(7 downto 0);
  signal p2_written : std_logic := '0';
  signal ay_data : std_logic_vector(7 downto 0) := (others=>'0');
  signal pulse1, pulse2, address_cycle : std_logic := '0';
  signal ay1_di, ay2_di, ay1_pb, ay2_pa : std_logic_vector(7 downto 0);
  signal ay1_pb_oe_n, ay2_pa_oe_n : std_logic;
  signal bc1_1, bc1_2 : std_logic;
  function output2(latch_value, direction : std_logic_vector(7 downto 0))
    return std_logic_vector is
    variable d : std_logic_vector(7 downto 0);
  begin
    d := direction and x"1f";
    -- MAME write_port2 behavior, including its all-input callback convention.
    if d=x"00" or d=x"1f" then return latch_value and x"1f";
    else return ((latch_value and d) or not d) and x"1f"; end if;
  end;
begin
  debug_p1_ddr<=ddr1; debug_p2_ddr<=ddr2;
  p1_pins <= (latch1 and ddr1) or not ddr1;
  p2_pins <= output2(latch2,ddr2) when p2_written='1' else x"00";
  p1_external <= ay1_di when p2_pins(3)='1' else
                 ay2_di when p2_pins(4)='1' else x"ff";
  data_out <= (p1_external and not ddr1) or (latch1 and ddr1) when addr="00010" else
              (P2_INPUT and not ddr2) or (latch2 and ddr2) when addr="00011" else
              x"20" when addr="10001" else -- reset SCI status; no SCI use in target trace
              x"c0" when addr="10100" else
              x"ff";
  adpcm_control <= ay1_pb when ay1_pb_oe_n='0' else x"ff";
  percussion <= ay2_pa when ay2_pa_oe_n='0' else x"ff";
  debug_ay_write <= pulse2 & pulse1 when address_cycle='0' else "00";
  -- Idle bus is read mode, exposing the selected register without writes.
  bc1_1 <= address_cycle when pulse1='1' else '1';
  bc1_2 <= address_cycle when pulse2='1' else '1';
  process(clk)
    variable new_p2 : std_logic_vector(7 downto 0);
    variable update_p2 : boolean;
  begin
    if rising_edge(clk) then
      pulse1<='0'; pulse2<='0';
      if reset='1' then
        ddr1<=x"00"; ddr2<=x"00"; latch1<=x"00"; latch2<=x"00";
        p2_written<='0'; ay_data<=x"00"; address_cycle<='0';
      elsif bus_write='1' then
        new_p2:=p2_pins; update_p2:=false;
        case addr is
          when "00000" => ddr1<=data_in;
          when "00001" =>
            ddr2<=data_in;
            if p2_written='1' then new_p2:=output2(latch2,data_in); update_p2:=true; end if;
          when "00010" => latch1<=data_in;
          when "00011" =>
            latch2<=data_in; p2_written<='1';
            new_p2:=output2(data_in,ddr2); update_p2:=true;
          when others => null;
        end case;
        if update_p2 and p2_pins(0)='1' and new_p2(0)='0' then
          pulse1<=p2_pins(3); pulse2<=p2_pins(4);
          address_cycle<=p2_pins(2); ay_data<=p1_pins;
        end if;
      end if;
    end if;
  end process;
  ay_command : entity work.YM2149
    port map(I_DA=>ay_data, O_DA=>ay1_di, O_DA_OE_L=>open,
      I_A9_L=>'0', I_A8=>'1', I_BDIR=>pulse1, I_BC2=>'1', I_BC1=>bc1_1,
      I_SEL_L=>'1', I_STEREO=>'0', O_AUDIO=>open, O_CHAN=>open,
      O_AUDIO_L=>ay1_audio, O_AUDIO_R=>open,
      I_IOA=>sound_command, O_IOA=>open, O_IOA_OE_L=>open,
      I_IOB=>ay1_pb, O_IOB=>ay1_pb, O_IOB_OE_L=>ay1_pb_oe_n,
      ENA=>ce_psg, RESET_L=>not reset, CLK=>clk);
  ay_second : entity work.YM2149
    port map(I_DA=>ay_data, O_DA=>ay2_di, O_DA_OE_L=>open,
      I_A9_L=>'0', I_A8=>'1', I_BDIR=>pulse2, I_BC2=>'1', I_BC1=>bc1_2,
      I_SEL_L=>'1', I_STEREO=>'0', O_AUDIO=>open, O_CHAN=>open,
      O_AUDIO_L=>ay2_audio, O_AUDIO_R=>open,
      I_IOA=>ay2_pa, O_IOA=>ay2_pa, O_IOA_OE_L=>ay2_pa_oe_n,
      I_IOB=>x"ff", O_IOB=>open, O_IOB_OE_L=>open,
      ENA=>ce_psg, RESET_L=>not reset, CLK=>clk);
end;
