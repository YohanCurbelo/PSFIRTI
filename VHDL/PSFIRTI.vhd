----------------------------------------------------------------------------------
-- Engineer: Yohan Curbelo Angles
-- 
-- Module Name: PSFIRTI (Pipelined Sequential FIR Filter Type I)
--
-- Description: 
-- 1. Customazible and optimized Sequential FIR Filter.
-- 2. The order of the filter has to be even (odd number of coefficients) 
-- and its coefficients symmetric.
-- 3. Customizable: The widths of input, output, and internal signals are 
-- configurable, making natual growth and truncation of data possible. 
-- 4. Optimized: As filter coefficients are symmetric, only half of them are 
-- loaded into the ROM and a sum of values that are symmetric to the middle 
-- address of the shift register is made.
-- 5. The design is pipelined.
--
-- Descripcion:
-- 1. Filtro FIR secuencial personalizable.
-- 2. El orden del filtro tiene que ser par (cantidad impar de coeficientes)
-- y sus coeficientes simetricos.
-- 3. Personalizable: El ancho de la senyal de entrada, salida, e internas son 
-- configurables, haciendo posible el truncado y el crecimiento natural de los 
-- datos internos.
-- 4. Optimizado: Como el filtro es simetrico solo se cargan en la ROM la mitad
-- de los coeficientes y se realiza una suma de los valores que son simetricos 
-- respecto a la direccion central del registro de desplazamiento.
-- 5. El disenyo esta segmentado.
--
----------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.math_real.all;
use		ieee.std_logic_textio.all;

library std;
use 	std.textio.all;

entity PSFIRTI is
    generic (
        INPUT_WIDTH     :   positive    :=  12;
        COEFF_WIDTH     :   positive    :=  10;
        SUM_WIDTH       :   positive    :=  12;
        MULT_WIDTH      :   positive    :=  12;
        OUTPUT_WIDTH    :   positive    :=  12;
        FILTER_ORDER    :   positive    :=  50;
        COEFF_FILE      :   string      :=  "coefficients_python.txt"
    );
    port (
        clk         :   in  std_logic;
        rst         :   in  std_logic;
        i_enable    :   in  std_logic;
        i_data      :   in  std_logic_vector(INPUT_WIDTH-1 downto 0);  
        o_enable    :   out std_logic;      
        o_data      :   out std_logic_vector(OUTPUT_WIDTH-1 downto 0)
    );
end PSFIRTI;

architecture Behavioral of PSFIRTI is

    -- FSM signals
    type states is (idle, S1);
    signal state    :   states;

    -- Coefficientes signals and function to load coefficients from txt
    constant ROM_ADDR   :   positive    :=  positive(ceil(log2(real(FILTER_ORDER/2))));
    type rom is array (0 to 2**ROM_ADDR-1) of std_logic_vector(COEFF_WIDTH-1 downto 0);
    
    impure function read_file (file_name : in string) return rom is
        file		rom_file		:	text is in file_name;
        variable	rom_file_line	:   line;
        variable	rom_data		:   rom;
    begin
        for i in 0 to FILTER_ORDER/2 loop   
            readline(rom_file, rom_file_line);
            read(rom_file_line, rom_data(i));                      
        end loop;
        return rom_data;
    end function;    
    
    signal coeff_ptr    :   integer range 0 to 2**ROM_ADDR-1;
    signal coefficients :   rom     :=  read_file(COEFF_FILE);

    -- Latency of the filter
    constant lat_sr     :   positive    :=  1;
    constant lat_add    :   positive    :=  1;
    constant lat_mult   :   positive    :=  1;    
    constant lat_acc    :   positive    :=  FILTER_ORDER/2+1; 
    constant lat_out    :   positive    :=  1;
    constant LATENCY    :   positive    :=  lat_sr + lat_add + lat_mult + lat_acc + lat_out;
    signal delay_en     :   std_logic_vector(0 to LATENCY-1);    
    
    -- Shift Register signals
    type shift_reg is array (0 to FILTER_ORDER) of std_logic_vector(INPUT_WIDTH-1 downto 0);
    signal sr           :   shift_reg;
    signal sr_ptr       :   integer range 0 to FILTER_ORDER/2;
    
    -- Internal signals
    constant ACC_GROWTH :   positive    :=  positive(ceil(log2(real(FILTER_ORDER)/real(2))));
    signal sum          :   signed(INPUT_WIDTH downto 0);
    signal mult_en      :   std_logic;
    signal mult         :   signed(COEFF_WIDTH+SUM_WIDTH-1 downto 0);    
    signal acc_en       :   std_logic;
    signal acc          :   signed(MULT_WIDTH+ACC_GROWTH-1 downto 0);
    signal sum_reg      :   std_logic_vector(INPUT_WIDTH downto INPUT_WIDTH-SUM_WIDTH+1);
    signal mult_reg     :   std_logic_vector(COEFF_WIDTH+SUM_WIDTH-1 downto COEFF_WIDTH+SUM_WIDTH-MULT_WIDTH);
    signal acc_reg      :   std_logic_vector(MULT_WIDTH+ACC_GROWTH-1 downto 0);

begin

    fsm_p   :   process(clk)
    begin
        if rising_edge(clk) then
            if rst = '0' then
                state   <=  idle;                
            else
                case state is
                    when idle   =>  if i_enable = '1' then
                                        state   <=  S1;
                                    end if;

                    when S1     =>  if sr_ptr = FILTER_ORDER/2 then
                                        state   <=  idle;                                        
                                    end if;
                end case;
            end if;
        end if;
    end process;

    sr_p    :   process(clk)
    begin
        if rising_edge(clk) then
            if rst = '0' then
                sr      <=  (others => (others => '0'));
            elsif i_enable = '1' and state = idle then
                sr      <=  i_data & sr(0 to FILTER_ORDER-1);
            end if;
        end if;
    end process;
    
    sum_p   :   process(clk)
    begin
        if rising_edge(clk) then
            if rst = '0' then
                mult_en     <=  '0';
                sr_ptr      <=  0;
                sum_reg     <=  (others => '0');
            elsif state = S1 then
                mult_en     <=  '1';
                sum_reg     <=  std_logic_vector(sum(INPUT_WIDTH downto INPUT_WIDTH-SUM_WIDTH+1));
                if sr_ptr = FILTER_ORDER/2 then
                    sr_ptr  <=  0;  
                else
                    sr_ptr  <=  sr_ptr + 1;    
                end if;
            else
                mult_en     <=  '0';
            end if;
        end if;
    end process;

    sum     <=  resize(signed(sr(sr_ptr)), INPUT_WIDTH + 1) + resize(signed(sr(FILTER_ORDER-sr_ptr)), INPUT_WIDTH + 1) when sr_ptr < FILTER_ORDER/2 else 
                resize(signed(sr(sr_ptr)), INPUT_WIDTH + 1); 
    
    mult_p  :   process(clk)
    begin
        if rising_edge(clk) then
            if rst = '0' then
                acc_en      <=  '0';
                coeff_ptr   <=  0;
                mult_reg    <=  (others => '0');
            else
                acc_en      <=  mult_en;
                coeff_ptr   <=  sr_ptr;
                if mult_en = '1' then                    
                    mult_reg    <=  std_logic_vector(mult(COEFF_WIDTH+SUM_WIDTH-1 downto COEFF_WIDTH+SUM_WIDTH-MULT_WIDTH));
                end if;
            end if;
        end if;
    end process;

    mult    <=  signed(coefficients(coeff_ptr)) * signed(sum_reg);
    
    acc_p   :   process(clk)
    begin
        if rising_edge(clk) then
            if rst = '0' then            
                acc_reg     <=  (others => '0');
                o_data      <=  (others => '0');
            elsif acc_en = '1' then                                  
                acc_reg     <=  std_logic_vector(acc);
            else
                acc_reg     <=  (others => '0');
                o_data      <=  acc_reg(MULT_WIDTH+ACC_GROWTH-1 downto MULT_WIDTH+ACC_GROWTH-OUTPUT_WIDTH);             
            end if;
        end if;
    end process;
        
    acc     <=  signed(acc_reg) + resize(signed(mult_reg), MULT_WIDTH + ACC_GROWTH);
    
    out_en_p   :   process(clk)
    begin
        if rising_edge(clk) then
            if rst = '0' then            
                delay_en    <=  (others => '0');
            else   
                delay_en    <=  i_enable & delay_en(0 to LATENCY-2);                
            end if;
        end if;
    end process;   
    
    o_enable    <=  delay_en(LATENCY-1);   

end Behavioral;