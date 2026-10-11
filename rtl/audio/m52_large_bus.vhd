-- External Large decode with MC6803 internal-register/RAM precedence.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity m52_large_bus is
  port(clk,reset,ce,vma,rw,command_write : in std_logic;
       addr : in std_logic_vector(15 downto 0);
       command_data : in std_logic_vector(7 downto 0);
       io_select,ram_select,rom_select,io_write,ram_write,irq : out std_logic;
       adpcm_write : out std_logic_vector(1 downto 0);
       sound_latch : out std_logic_vector(7 downto 0));
end;
architecture rtl of m52_large_bus is
  signal latch_data : std_logic_vector(7 downto 0) := x"00";
  signal internal_io,internal_ram,write_cycle,ack_write : std_logic;
begin
  internal_io<='1' when unsigned(addr)<=20 else '0';
  internal_ram<='1' when addr(15 downto 7)="000000001" else '0';
  write_cycle<=ce and vma and not rw and not reset;
  io_select<=internal_io; ram_select<=internal_ram;
  rom_select<=addr(15); -- populated half of the six-socket ROM decode
  io_write<=write_cycle and internal_io;
  ram_write<=write_cycle and internal_ram;
  adpcm_write<=addr(1 downto 0) when write_cycle='1' and
    addr(15 downto 13)="000" and internal_io='0' and internal_ram='0' else "00";
  ack_write<='1' when write_cycle='1' and addr(15 downto 13)="001" else '0';
  sound_latch<=latch_data;
  process(clk)
  begin
    if rising_edge(clk) then
      if reset='1' then latch_data<=x"00"; irq<='1';
      else
        if ack_write='1' and latch_data(7)='1' then irq<='0'; end if;
        if command_write='1' then
          latch_data<=command_data;
          if command_data(7)='0' then irq<='1'; end if;
        end if;
      end if;
    end if;
  end process;
end;
