LIBRARY ieee;                                               
USE ieee.std_logic_1164.all;                                

ENTITY i2c_master_vhd_tst IS
END i2c_master_vhd_tst;
ARCHITECTURE i2c_master_arch OF i2c_master_vhd_tst IS
-- constants  
constant clk_period : time := 20 ns;  
signal  sda_tb : std_logic := 'H';  
signal  data_out_tb : std_logic_vector(7 downto 0);
SIGNAL ack_error_tb : STD_LOGIC ; 
SIGNAL busy_tb : STD_LOGIC;   
SIGNAL done_tb : STD_LOGIC;                                         
-- signals                                                   
SIGNAL ack_error : STD_LOGIC ; 
SIGNAL busy : STD_LOGIC;
SIGNAL clk : STD_LOGIC;
SIGNAL data_in : STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL data_out : STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL done : STD_LOGIC;
SIGNAL enable : STD_LOGIC;
SIGNAL read_write : STD_LOGIC;
SIGNAL reset : STD_LOGIC;
SIGNAL scl : STD_LOGIC;
SIGNAL sda : STD_LOGIC;
SIGNAL slave_address : STD_LOGIC_VECTOR(6 DOWNTO 0);
signal stop_signal   : std_logic;
COMPONENT i2c_master
	PORT (
		ack_error : OUT STD_LOGIC;
		busy : OUT STD_LOGIC;
		clk : IN STD_LOGIC;
		data_in : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		data_out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		done : OUT STD_LOGIC;
		enable : IN STD_LOGIC;
		read_write : IN STD_LOGIC;
		reset : IN STD_LOGIC;
		scl : INOUT STD_LOGIC;
		sda : INOUT STD_LOGIC;
		slave_address : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
		stop_signal   : in std_logic
	);
END COMPONENT;
BEGIN
	i1 : i2c_master
	PORT MAP (
	ack_error => ack_error_tb,
	busy => busy_tb,
	clk => clk,
	data_in => data_in,
	data_out => data_out_tb,
	done => done_tb,
	enable => enable,
	read_write => read_write,
	reset => reset,
	scl => scl,
	sda => sda_tb,
	slave_address => slave_address,
	stop_signal   => stop_signal
	);
	init : PROCESS
	BEGIN
	    reset <= '1';
		enable <= '0';
		stop_signal <= '0';
		slave_address <= "1010000";
		read_write <= '1';

		wait for 60 ns;
		reset <= '0';
		wait for 100 ns;

		enable <= '1';
		wait for 60 ns;
		enable <= '0';

		wait;
	END PROCESS init;

	slave_dummy : process
    variable data_byte : std_logic_vector(7 downto 0) := "10101010";
    variable bit_idx   : integer := 7;
    begin
        wait until reset = '0';           
        wait until enable = '1';                     

		wait for 105121 ns;
		sda_tb <= '0';
		wait for 6000 ns;
		

		for bit_idx in 7 downto 0 loop
			sda_tb <= data_byte(bit_idx);
			wait until scl = '1';  
			wait until scl = '0';
		end loop;
	 
    end process;

											   
	always : PROCESS
	BEGIN
		while true loop
			clk <= '0';
			wait for clk_period / 2;
			clk <= '1';
			wait for clk_period / 2;
		end loop;
	END PROCESS always;
											 
END i2c_master_arch;
