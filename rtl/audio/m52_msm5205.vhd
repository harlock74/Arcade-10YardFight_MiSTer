-- M52 Large MSM5205 decoder. Arithmetic cross-check: MAME msm5205.cpp,
-- Aaron Giles, BSD-3-Clause; step table also used by Dar's Moon Patrol core.
-- Board timing (including the slave's capture event) is supplied separately.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity m52_msm5205 is
  port(clk, reset, capture, chip_reset, data_write, four_bit : in std_logic;
       data_in : in std_logic_vector(3 downto 0);
       pcm : out std_logic_vector(11 downto 0);
       debug_step : out integer range 0 to 48);
end;

architecture rtl of m52_msm5205 is
  type step_table_t is array(0 to 48) of integer range 16 to 1552;
  constant steps : step_table_t := (
    16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,
    73,80,88,97,107,118,130,143,157,173,190,209,230,253,
    279,307,337,371,408,449,494,544,598,658,724,796,876,
    963,1060,1166,1282,1411,1552);
  type shifts_t is array(0 to 7) of integer range -1 to 8;
  constant shifts : shifts_t := (-1,-1,-1,-1,2,4,6,8);
  signal nibble : std_logic_vector(3 downto 0) := (others=>'0');
  signal level : integer range -2048 to 2047 := 0;
  signal step_index : integer range 0 to 48 := 0;
begin
  pcm <= std_logic_vector(to_signed(level,12));
  debug_step <= step_index;
  process(clk)
    variable delta, next_level, next_step : integer;
  begin
    if rising_edge(clk) then
      if reset='1' then
        nibble <= (others=>'0'); level <= 0; step_index <= 0;
      else
        if data_write='1' then
          if four_bit='1' then nibble <= data_in;
          else nibble <= data_in(2 downto 0) & '0'; end if;
        end if;
        if capture='1' then
          if chip_reset='1' then level <= 0; step_index <= 0;
          else
            delta := steps(step_index)/8;
            if nibble(0)='1' then delta := delta + steps(step_index)/4; end if;
            if nibble(1)='1' then delta := delta + steps(step_index)/2; end if;
            if nibble(2)='1' then delta := delta + steps(step_index); end if;
            if nibble(3)='1' then delta := -delta; end if;
            next_level := level + delta;
            next_step := step_index + shifts(to_integer(unsigned(nibble(2 downto 0))));
            if next_level>2047 then level<=2047;
            elsif next_level < -2048 then level<=-2048;
            else level<=next_level; end if;
            if next_step>48 then step_index<=48;
            elsif next_step<0 then step_index<=0;
            else step_index<=next_step; end if;
          end if;
        end if;
      end if;
    end if;
  end process;
end;
