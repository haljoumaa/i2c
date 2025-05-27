library std;
use     std.textio.all;

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;
use     uvvm_util.sbi_bfm_pkg.all;

entity i2c_tb_uvvm is
end entity;

architecture behav of i2c_tb_uvvm is
  component i2c_top
    port (
      clk       : in  std_logic;
      reset     : in  std_logic;
      sbi_cs    : in  std_logic;
      sbi_we    : in  std_logic;
      sbi_re    : in  std_logic;
      sbi_addr  : in  std_logic_vector(1 downto 0);
      sbi_wdata : in  std_logic_vector(31 downto 0);
      sbi_rdata : out std_logic_vector(31 downto 0);
      sda       : inout std_logic;
      scl       : out  std_logic);
  end component;

  -- sbi interface record
  signal sbi_if : t_sbi_if(addr(1 downto 0), wdata(31 downto 0), rdata(31 downto 0))
  := init_sbi_if_signals(2, 32);


  -- clock & reset
  constant T : time := 20 ns;
  signal clk    : std_logic := '0';
  signal reset  : std_logic := '0';
  signal term_poll      : std_logic := '0';
  signal clock_ena : boolean := false;

  
  signal sda : std_logic := 'Z';
  signal scl : std_logic;
begin

  i2c_top0 : i2c_top
    port map (
      clk        => clk,
      reset      => reset,
      sbi_cs     => sbi_if.cs,
      sbi_we     => sbi_if.wena,
      sbi_re     => sbi_if.rena,
      sbi_addr   => std_logic_vector(sbi_if.addr),
      sbi_wdata  => sbi_if.wdata,
      sbi_rdata  => sbi_if.rdata,
      sda        => sda,
      scl        => scl);

  sbi_if.ready <= '1';
  clock_generator(clk, clock_ena, T, "clk");

  
  main : process
   
   constant C_SCOPE     : string  := C_TB_SCOPE_DEFAULT;

    procedure write(
      constant addr_value   : in natural;
      constant data_value   : in std_logic_vector;
      constant msg          : in string) is
      begin
        sbi_write(to_unsigned(addr_value, 2), data_value, msg, CLK, sbi_if, C_SCOPE);
    end;

    procedure check(
      constant addr_value   : in natural;
      constant data_exp     : in std_logic_vector;
      constant alert_level  : in t_alert_level;
      constant msg          : in string) is
      begin
        sbi_check(to_unsigned(addr_value, 2), data_exp, msg, clk, sbi_if, alert_level, C_SCOPE);
    end;
   
    procedure poll(
      constant addr_value   : in natural;
      constant data_exp     : in std_logic_vector;
      constant alert_level  : in t_alert_level;
      constant msg          : in string) is
      begin
        sbi_poll_until(to_unsigned(addr_value, 2),data_exp ,1000,1 ms,msg, clk, sbi_if, term_poll);      
    end;
    

  begin

    set_alert_stop_limit(ERROR,0);
    report_global_ctrl(VOID);
      --report_msg_id_panel(VOID);
    enable_log_msg(ALL_MESSAGES);
      --disable_log_msg(ALL_MESSAGES);
      --enable_log_msg(ID_LOG_HDR);
      
    log(ID_LOG_HDR, "Start Simulation of master", C_SCOPE);
      
    clock_ena <= true; -- to start clock generator
     wait for 10*T;
      
    gen_pulse(reset, T, "reset");
     wait for 10*T;

    log(ID_LOG_HDR, "checking regiters after reset", C_SCOPE);
      
    check(0, x"00000000", ERROR, "checking control register");
    check(1, x"00000000", ERROR, "checking write register");
    check(2, x"00000000", ERROR, "checking status register");
    check(3, x"00000000", ERROR, "checking reading register");
    
    write(0, x"00000001","writing to control register");
    write(1, x"00006800", "writing to write register");
    write(2, x"FFFFFFFF","writing to status register");
    write(3, x"FFFFFFFF","writing to reading register");



    -- Read 
    --write(0, x"00000005", "writing to control register");



  
    wait for 100 *T;
   
    report_alert_counters(FINAL); -- Report final counters and print conclusion for simulation (Success/Fail)
    log(ID_LOG_HDR, "SIMULATION COMPLETED", C_SCOPE);

    wait for 1 sec;
  end process;

  slave_dummy : process
    variable data_byte : std_logic_vector(7 downto 0) := "10101010";
    variable bit_idx   : integer := 7;
    begin

        sda <= 'Z';
        wait until scl = '0';
        
        -- Master : start, idle and writes adress 
		    for bit in 9 downto 0 loop 
          wait until scl = '1';
          wait until scl = '0';
        end loop;

        -- first ack for slave address
        wait until scl = '1';
        sda <= '0';
        wait until scl = '0';
        sda <= 'Z';

        -- dummy driving data 
		    for bit_idx in 7 downto 0 loop
			    sda <= data_byte(bit_idx);
			    wait until scl = '1';  
			    wait until scl = '0';
		    end loop;
		    sda <= 'Z';

		wait;
	end process;
end architecture;
