-- Irem 10-Yard Fight M52 Large. 36.864 MHz FPGA domain, independent E/ADPCM CEs.
-- Physical/MAME distinctions and intentional approximations are documented in
-- Detailed comparison retained in development; see NOTICE.md for attribution.
-- Sound ROM data is downloaded, never embedded.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity m52_large_audio is
  generic(P2_INPUT : std_logic_vector(7 downto 0) := x"02");
  port(clk, reset, command_write : in std_logic;
       command_data : in std_logic_vector(7 downto 0);
       download_clk, download_write : in std_logic;
       download_addr : in std_logic_vector(26 downto 0);
       download_data : in std_logic_vector(7 downto 0);
       audio : out std_logic_vector(15 downto 0);
       debug_addr : out std_logic_vector(15 downto 0);
       debug_di, debug_do : out std_logic_vector(7 downto 0);
       debug_ce, debug_vma, debug_rw, debug_irq, debug_vclk, debug_capture : out std_logic;
       debug_adpcm_write, debug_ay_write : out std_logic_vector(1 downto 0);
       debug_control : out std_logic_vector(7 downto 0);
       debug_pcm1, debug_pcm2 : out std_logic_vector(11 downto 0));
end;

architecture rtl of m52_large_audio is
  type rom_t is array(0 to 32767) of std_logic_vector(7 downto 0);
  type ram_t is array(0 to 127) of std_logic_vector(7 downto 0);
  signal sound_rom : rom_t;
  signal internal_ram : ram_t;
  attribute ramstyle : string;
  attribute ramstyle of sound_rom : signal is "M10K";
  attribute ramstyle of internal_ram : signal is "M10K";
  signal rom_q, ram_q, io_q, cpu_di, cpu_do : std_logic_vector(7 downto 0);
  signal cpu_addr : std_logic_vector(15 downto 0);
  signal rw, vma, ce_cpu, cpu_irq : std_logic := '0';
  signal sound_latch : std_logic_vector(7 downto 0) := x"00";
  signal internal_io, ram_select, rom_select, io_write, ram_write : std_logic;
  signal adpcm_write : std_logic_vector(1 downto 0);
  signal control, percussion : std_logic_vector(7 downto 0);
  signal ay1, ay2 : std_logic_vector(9 downto 0);
  signal pcm1, pcm2 : std_logic_vector(11 downto 0);
  signal vclk, capture : std_logic;
begin
  debug_addr<=cpu_addr; debug_di<=cpu_di; debug_do<=cpu_do;
  debug_ce<=ce_cpu; debug_vma<=vma; debug_rw<=rw; debug_irq<=cpu_irq;
  debug_vclk<=vclk; debug_capture<=capture;
  debug_adpcm_write<=adpcm_write; debug_control<=control;
  debug_pcm1<=pcm1; debug_pcm2<=pcm2;

  bus_decoder : entity work.m52_large_bus
    port map(clk=>clk,reset=>reset,ce=>ce_cpu,vma=>vma,rw=>rw,
      command_write=>command_write,addr=>cpu_addr,command_data=>command_data,
      io_select=>internal_io,ram_select=>ram_select,rom_select=>rom_select,
      io_write=>io_write,ram_write=>ram_write,irq=>cpu_irq,
      adpcm_write=>adpcm_write,sound_latch=>sound_latch);
  clocks : entity work.m52_sound_clock
    port map(clk=>clk,reset=>reset,mode=>control(3 downto 2),
      ce_cpu=>ce_cpu,vclk=>vclk,capture=>capture);
  cpu_di <= io_q when internal_io='1' else ram_q when ram_select='1' else
            rom_q when rom_select='1' else x"ff";

  process(download_clk)
  begin
    if rising_edge(download_clk) then
      if download_write='1' and unsigned(download_addr)>=16#06000# and
         unsigned(download_addr)<16#0e000# then
        sound_rom(to_integer(unsigned(download_addr)-16#06000#)) <= download_data;
      end if;
    end if;
  end process;
  process(clk)
  begin
    if rising_edge(clk) then
      rom_q <= sound_rom(to_integer(unsigned(cpu_addr(14 downto 0))));
      ram_q <= internal_ram(to_integer(unsigned(cpu_addr(6 downto 0))));
      if ram_write='1' then
        internal_ram(to_integer(unsigned(cpu_addr(6 downto 0))))<=cpu_do;
      end if;
    end if;
  end process;

  cpu : entity work.cpu68
    port map(clk=>clk, rst=>reset, rw=>rw, vma=>vma, address=>cpu_addr,
      data_in=>cpu_di, data_out=>cpu_do, hold=>not ce_cpu, halt=>'0',
      irq=>cpu_irq, nmi=>vclk, test_alu=>open, test_cc=>open);
  ports : entity work.m52_large_ports generic map(P2_INPUT=>P2_INPUT)
    port map(clk=>clk, reset=>reset, ce_psg=>ce_cpu,
      bus_write=>io_write, addr=>cpu_addr(4 downto 0),
      data_in=>cpu_do, sound_command=>sound_latch, data_out=>io_q,
      ay1_audio=>ay1, ay2_audio=>ay2, adpcm_control=>control,
      percussion=>percussion, debug_ay_write=>debug_ay_write,
      debug_p1_ddr=>open, debug_p2_ddr=>open);
  msm_master : entity work.m52_msm5205
    port map(clk=>clk, reset=>reset, capture=>capture, chip_reset=>control(0),
      data_write=>adpcm_write(0), four_bit=>control(4), data_in=>cpu_do(3 downto 0),
      pcm=>pcm1, debug_step=>open);
  -- One shared event: slave has no independent sampling-clock generator.
  msm_slave : entity work.m52_msm5205
    port map(clk=>clk, reset=>reset, capture=>capture, chip_reset=>control(1),
      data_write=>adpcm_write(1), four_bit=>control(4), data_in=>cpu_do(3 downto 0),
      pcm=>pcm2, debug_step=>open);

  process(clk)
    variable mix : integer range -32768 to 32767;
  begin
    if rising_edge(clk) then
      -- 10-bit DAC quantization of each internal 12-bit MSM accumulator.
      -- Bound: PSG <= 16368; ADPCM sum -8192..8176. No arithmetic wrap.
      mix := (to_integer(unsigned(ay1))+to_integer(unsigned(ay2)))*8 +
             (to_integer(signed(pcm1(11 downto 2)))+
              to_integer(signed(pcm2(11 downto 2))))*8;
      if reset='1' then audio<=(others=>'0');
      else audio<=std_logic_vector(to_signed(mix,16)); end if;
    end if;
  end process;
end;
