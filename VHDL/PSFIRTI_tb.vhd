library	ieee;
use		ieee.std_logic_1164.all;
use		ieee.std_logic_textio.all;
use		ieee.numeric_std.all;

library std;
use 	std.textio.all;

entity PSFIRTI_tb is
	generic (
		INPUT_LENGTH		:	positive	:=	800;
		INPUT_WIDTH			:	positive	:=	12;
		SUM_WIDTH			:	positive	:=	12;
		MULT_WIDTH			:	positive	:=	12;
		OUTPUT_WIDTH		:	positive	:=	12;
		COEFF_WIDTH         :	positive	:=	10;
		FILTER_ORDER		:	positive	:=	50;		
		COEFF_FILE          :	string		:=	"coefficients_python.txt"
	);
end PSFIRTI_tb;

architecture Behavioral of PSFIRTI_tb is

	-- Custom signal types
	type lut is array (0 to FILTER_ORDER) of std_logic_vector(COEFF_WIDTH-1 downto 0);

	-- Clock and reset signals
	constant 	Tclk		:	time		:=	1 us;
	signal 		clk_stop	:	boolean		:=	false;
	signal 		clk			:	std_logic;
	signal 		rst			:	std_logic;
	
	-- Stimuli and reponse signals
	signal stimuli_stop	:	boolean		    :=	false;
	signal i_enable		:	std_logic;
	signal i_signal		:	std_logic_vector(INPUT_WIDTH-1 downto 0);
	signal o_enable		:	std_logic;
	signal o_signal		:	std_logic_vector(INPUT_WIDTH-1 downto 0);	
	
	-- Internal signals
	signal o_matlab			:	std_logic_vector(INPUT_WIDTH-1 downto 0);
	signal cycles_counter   :   natural range 0 to FILTER_ORDER/2 + 5;	
	signal enable_counter	:   natural range 0 to INPUT_LENGTH;	
	
	-- DUT
	component PSFIRTI
		generic (
			INPUT_WIDTH          :	positive;
			SUM_WIDTH            :	positive;
			MULT_WIDTH           :	positive;
			OUTPUT_WIDTH         :	positive;
			COEFF_WIDTH          :	positive;
			FILTER_ORDER         :	positive;		
			COEFF_FILE           :	string
		);
		port (
			clk			:	in		std_logic;
			rst			:	in		std_logic;
			i_enable	:	in		std_logic;
			i_data	    :	in		std_logic_vector(INPUT_WIDTH-1	downto 0);
			o_enable	:	out		std_logic;
			o_data	    :	out		std_logic_vector(INPUT_WIDTH-1	downto 0)
		);		
	end component;
	
begin
	
---------------------------------------------------------------------------------------------------------------------	
--	DUT instance
	DUT : PSFIRTI
		generic map(
			INPUT_WIDTH			=>	INPUT_WIDTH,
			SUM_WIDTH			=>	SUM_WIDTH,
			MULT_WIDTH			=>	MULT_WIDTH,
			OUTPUT_WIDTH		=>	OUTPUT_WIDTH,
			COEFF_WIDTH	        =>	COEFF_WIDTH,
			FILTER_ORDER		=>	FILTER_ORDER,			
			COEFF_FILE	        =>	COEFF_FILE
		)
		port map(
			clk			=> clk,
			rst			=> rst,
			i_enable	=> i_enable,
			i_data	    => i_signal,
			o_enable 	=> o_enable,
			o_data	    => o_signal
		);		

---------------------------------------------------------------------------------------------------------------------	
--	Clock process
	clk_process	:	process
	begin
		while not clk_stop loop
			clk	<=	'1';
			wait for Tclk/2;
			clk	<=	'0';
			wait for Tclk/2;
		end loop;
		wait;
	end process;

---------------------------------------------------------------------------------------------------------------------	
-- 	Reset process
	rst_process	:	process
	begin
		rst	<=	'0';
		wait for 1 ms;
		rst	<=	'1';
		wait;
	end process;

---------------------------------------------------------------------------------------------------------------------	
-- 	Stimuli from txt
	stimuli_txt	:	process
		file		i_file		:	text is in "stimuli_matlab.txt";
		variable	file_line	:	line;
		variable	i_matlab	:	std_logic_vector(INPUT_WIDTH-1 downto 0);
	begin
		while not endfile(i_file) loop
			wait until i_enable = '1';
			readline(i_file,file_line);
			read(file_line,i_matlab);
			i_signal	<=	i_matlab;
		end loop;
		file_close(i_file);
		wait;
	end process;

---------------------------------------------------------------------------------------------------------------------	
-- 	Response from txt
	reponse_txt	:	process
		file		o_file		:	text is in "response_matlab.txt";
		variable 	file_line	:	line;
		variable	out_matlab	:	std_logic_vector(OUTPUT_WIDTH-1 downto 0);
	begin
		while not endfile(o_file) loop
			wait until cycles_counter = FILTER_ORDER/2 + 1;
			readline(o_file,file_line);
			read(file_line,out_matlab);
			o_matlab	<=	out_matlab;
		end loop;
		file_close(o_file);
		wait;
	end process;	

---------------------------------------------------------------------------------------------------------------------	
--	DUT process
	dut_process		:	process
	begin
		while not stimuli_stop loop			
			if rst = '0' then
				i_enable	<=	'0';
				wait until clk = '1';
			else
				if cycles_counter = 0 then
					cycles_counter	<=	cycles_counter + 1;
					i_enable	<=	'1';
				elsif cycles_counter > 0 and cycles_counter < FILTER_ORDER/2 + 1 then
					cycles_counter	<=	cycles_counter + 1;
					i_enable	<=	'0';
				elsif cycles_counter = FILTER_ORDER/2 + 1 then
					cycles_counter	<=	0;
					if enable_counter < INPUT_LENGTH then
						enable_counter	<=	enable_counter + 1;	
					else
						enable_counter	<=	0;
						stimuli_stop	<=	true;
					end if;
				end if;	
				wait until clk = '1';			
			end if;
		end loop;
		wait for 1 ms;
		clk_stop	<=	true;
		wait;
	end process;

end Behavioral;