-- Independent rational E clock and 384 kHz oscillator in one 36.864 MHz domain.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity m52_sound_clock is
  port(clk,reset : in std_logic;
       mode : in std_logic_vector(1 downto 0);
       ce_cpu,vclk,capture : out std_logic);
end;
architecture rtl of m52_sound_clock is
  signal phase : unsigned(27 downto 0) := (others=>'0');
  constant denominator : unsigned(27 downto 0) := to_unsigned(147456000,28);
  constant numerator : unsigned(27 downto 0) := to_unsigned(3579545,28);
  signal ce : std_logic;
  signal xtal_div : integer range 0 to 95 := 0;
  signal vclk_count : integer range 0 to 47 := 0;
  signal capture_delay : integer range 0 to 6 := 0;
  signal vck : std_logic := '0';
  signal previous_mode : std_logic_vector(1 downto 0) := "11";
begin
  ce<='1' when phase>=denominator-numerator and reset='0' else '0';
  ce_cpu<=ce; vclk<=vck;
  process(clk)
    variable half_period : integer range 24 to 48;
  begin
    if rising_edge(clk) then
      capture<='0';
      if reset='1' then
        phase<=(others=>'0'); xtal_div<=0; vclk_count<=0;
        capture_delay<=0; vck<='0'; previous_mode<=mode;
      else
        if ce='1' then phase<=phase+numerator-denominator;
        else phase<=phase+numerator; end if;
        if mode/=previous_mode then previous_mode<=mode; vclk_count<=0; end if;
        if xtal_div=95 then
          xtal_div<=0;
          if capture_delay/=0 then
            capture_delay<=capture_delay-1;
            if capture_delay=1 then capture<='1'; end if;
          end if;
          case mode is
            when "00" => half_period:=48;
            when "01" => half_period:=24;
            when others => half_period:=32;
          end case;
          if mode/="11" and mode=previous_mode then
            if vclk_count>=half_period-1 then
              vclk_count<=0; vck<=not vck;
              if vck='1' then capture_delay<=6; end if;
            else vclk_count<=vclk_count+1; end if;
          end if;
        else xtal_div<=xtal_div+1; end if;
      end if;
    end if;
  end process;
end;
