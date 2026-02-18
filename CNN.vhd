library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.kernel_pkg.all;

ENTITY conv IS 
generic(
    NUM_MULT : integer := 9; 
    NUM_ADD : integer := 8;  
	 NUM_COMPARATOR : integer := 2;
	 INP_MATRIX_S : integer := 28; --bunlar ilk conv için sabit olcak 
	 OUT_MATRIX_S : integer := 26;
	 FM1_MATRIX_S : integer := 26;
	 FM2_MATRIX_S : integer := 24;
	 POOL1_MATRIX_S:integer := 12;
	 FM3_MATRIX_S : integer := 10;
	 FM4_MATRIX_S : integer := 8;
	 POOL2_MATRIX_S:integer := 4;

	 cnt_end_div:integer:=7;--6
	 cnt_end_expo:integer:=18;--17
	 cnt_end_add:integer:=8; --7(+1'ler safe olsun diye)
	 cnt_end_mul:integer:=6; --5
	 cnt_end_compare:integer:=2 --1
);
PORT(
    clock_50 : in std_logic;
	 rst : in std_logic;
	 LEDR : out std_logic_vector(9 downto 0);
	 LEDG : out  std_logic_vector(7 downto 0);
	 KEY : in std_logic_vector(3 downto 0);
	 SW :in std_logic_vector(17 downto 0);
	 HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7 : out std_logic_vector(6 downto 0)

);
END conv;


architecture d of conv is
component hex_display_driver is
    port (
        data_in : in  std_logic_vector(31 downto 0);
        hex0, hex1, hex2, hex3, hex4, hex5, hex6, hex7 : out std_logic_vector(6 downto 0)
    );
end component;
	 component img_rom
	PORT
	(
		aclr		: IN STD_LOGIC  := '0';
		address		: IN STD_LOGIC_VECTOR (9 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		rden		: IN STD_LOGIC  := '1';
		q		: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
	);
	
	end component;
	
	component fmap_ram
		PORT
		(
			clock		: IN STD_LOGIC  := '1';
			data		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
			rdaddress		: IN STD_LOGIC_VECTOR (9 DOWNTO 0);
			rden		: IN STD_LOGIC  := '1';
			wraddress		: IN STD_LOGIC_VECTOR (9 DOWNTO 0);
			wren		: IN STD_LOGIC  := '0';
			q		: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
		);
	end component;
	 component altfp_mula
		 PORT
		 (
			 aclr		: IN STD_LOGIC ;
			 clk_en	: IN STD_LOGIC ;
			 clock		: IN STD_LOGIC ;
			 dataa		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
			 datab		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
			 result	: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
		 );
	 end component;
	component altfp_add
		PORT
		(
			aclr		: IN STD_LOGIC ;
			clk_en		: IN STD_LOGIC ;
			clock		: IN STD_LOGIC ;
			dataa		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
			datab		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
			result		: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
		);
	end component;
	
	component compare
		PORT
		(
			aclr		: IN STD_LOGIC ;
			clk_en		: IN STD_LOGIC ;
			clock		: IN STD_LOGIC ;
			dataa		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
			datab		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
			agb		: OUT STD_LOGIC 
		);
	end component;
	 
	component div
		PORT
		(
			aclr		: IN STD_LOGIC ;
			clk_en		: IN STD_LOGIC ;
			clock		: IN STD_LOGIC ;
			dataa		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
			datab		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
			result		: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
		);
	end component;
	
	component expo
		 PORT
		 (
			 aclr		: IN STD_LOGIC ;
			 clk_en		: IN STD_LOGIC ;
			 clock		: IN STD_LOGIC ;
			 data		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
			 result		: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
		 );
	end component;

	 type mult_array is array (0 to NUM_MULT-1) of std_logic_vector(31 downto 0);
	 type adder_array is array (0 to NUM_ADD-1) of std_logic_vector(31 downto 0);
	 
	 type state_type is (
			s_idle, s_control, s_mult, 
			s_reduction, s_reduction2, s_reduction3, s_reduction4,
			s_writeResult, s_slide, s_finish,
			s_assignFor1, s_assignFor2, s_assignFor3,
			s_combineFmapRed1, s_combineFmapRed2,
			s_pipeFlow1, s_pipeFlow2, s_writeResult1, s_writeResult2,
			s_read_ram, s_wait_data, s_save_data, s_write_wait, s_write_wait1, s_write_wait2, 
			s_setup_F1, s_setup_F2, s_setup_F3, 
			s_mult_F1, s_mult_F2, s_mult_F3, 
			s_red1_F1, s_red2_F1, s_red3_F1, s_red4_F1, s_red5_F1, s_red6_F1,
			s_red1_F2, s_red2_F2, s_red3_F2, s_red4_F2, s_red5_F2, s_red6_F2, 
			s_red1_F3, s_red2_F3, s_red3_F3, s_red4_F3, s_red5_F3, s_red6_F3, 
			s_write_F1, s_write_F2, s_write_F3, s_wait_write_F1, s_wait_write_F2, s_wait_write_F3 
  );
	 
	 type layer_state_type is (INIT,CONV1,LRELU1,CONV2,LRELU2,MAXPOOL1,CONV3,LRELU3,CONV4,LRELU4,MAXPOOL2,FLATTING, CONVEND,FF_MM1,FF_LRELU,FF_MM2,SOFTMAX,PREDICT);
	 type lrelu_state_type is (s_idle,s_increaseIndex,s_finishRelu,s_set_addr, s_wait_ram,s_mult_wait, s_check_sign, s_write_back, s_write_finish);
	 type maxpool_state_type is (s_idle,s_compare1,s_writeTemps,s_compare2,s_writeGreater,s_slide,s_finishMaxpool, s_set_addr, s_wait_ram,s_waitCompare, s_write_wait);
	 type flatting_state_type is (s_idle,s_read_addr,s_wait_data,s_write_data,s_wait_write,s_increaseFlatIndex,s_finishFlat);
	 


	 signal rden_sig		: std_logic  := '1';
	 
	 signal data_counter : integer range 0 to 9 := 0;

	 signal rom_addr : std_logic_vector(9 downto 0);
	 signal rom_q_out    : std_logic_vector(31 downto 0);
	 
	 signal ram_fmap1_1_data_in  : std_logic_vector(31 downto 0);
	 signal ram_fmap1_1_rd_addr  : std_logic_vector(9 downto 0);--2^10 adres tutcak yani en büyük fmapimize yetcek kadar(hepsi bu kadar olsun kolaylık açısından)
	 signal ram_fmap1_1_wr_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap1_1_we       : std_logic := '0';
	 signal ram_fmap1_1_q_out    : std_logic_vector(31 downto 0);

	 signal ram_fmap1_2_data_in  : std_logic_vector(31 downto 0);
	 signal ram_fmap1_2_rd_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap1_2_wr_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap1_2_we       : std_logic := '0';
	 signal ram_fmap1_2_q_out    : std_logic_vector(31 downto 0);
	 
	 signal ram_fmap1_3_data_in  : std_logic_vector(31 downto 0);
	 signal ram_fmap1_3_rd_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap1_3_wr_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap1_3_we       : std_logic := '0';
	 signal ram_fmap1_3_q_out    : std_logic_vector(31 downto 0);
	 
	 signal ram_fmap2_1_data_in  : std_logic_vector(31 downto 0);
	 signal ram_fmap2_1_rd_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap2_1_wr_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap2_1_we       : std_logic := '0';
	 signal ram_fmap2_1_q_out    : std_logic_vector(31 downto 0);

	 signal ram_fmap2_2_data_in  : std_logic_vector(31 downto 0);
	 signal ram_fmap2_2_rd_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap2_2_wr_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap2_2_we       : std_logic := '0';
	 signal ram_fmap2_2_q_out    : std_logic_vector(31 downto 0);
	 
	 signal ram_fmap2_3_data_in  : std_logic_vector(31 downto 0);
	 signal ram_fmap2_3_rd_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap2_3_wr_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap2_3_we       : std_logic := '0';
	 signal ram_fmap2_3_q_out    : std_logic_vector(31 downto 0);
	 
	 signal ram_maxpool1_1_data_in  : std_logic_vector(31 downto 0);
	 signal ram_maxpool1_1_rd_addr  : std_logic_vector(9 downto 0);
	 signal ram_maxpool1_1_wr_addr  : std_logic_vector(9 downto 0);
	 signal ram_maxpool1_1_we       : std_logic := '0';
	 signal ram_maxpool1_1_q_out    : std_logic_vector(31 downto 0);

	 signal ram_maxpool2_1_data_in  : std_logic_vector(31 downto 0);
	 signal ram_maxpool2_1_rd_addr  : std_logic_vector(9 downto 0);
	 signal ram_maxpool2_1_wr_addr  : std_logic_vector(9 downto 0);
	 signal ram_maxpool2_1_we       : std_logic := '0';
	 signal ram_maxpool2_1_q_out    : std_logic_vector(31 downto 0);
	 
	 signal ram_maxpool3_1_data_in  : std_logic_vector(31 downto 0);
	 signal ram_maxpool3_1_rd_addr  : std_logic_vector(9 downto 0);
	 signal ram_maxpool3_1_wr_addr  : std_logic_vector(9 downto 0);
	 signal ram_maxpool3_1_we       : std_logic := '0';
	 signal ram_maxpool3_1_q_out    : std_logic_vector(31 downto 0);
	 
	 signal ram_fmap3_1_data_in  : std_logic_vector(31 downto 0);
	 signal ram_fmap3_1_rd_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap3_1_wr_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap3_1_we       : std_logic := '0';
	 signal ram_fmap3_1_q_out    : std_logic_vector(31 downto 0);

	 signal ram_fmap3_2_data_in  : std_logic_vector(31 downto 0);
	 signal ram_fmap3_2_rd_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap3_2_wr_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap3_2_we       : std_logic := '0';
	 signal ram_fmap3_2_q_out    : std_logic_vector(31 downto 0);
	 
	 signal ram_fmap3_3_data_in  : std_logic_vector(31 downto 0);
	 signal ram_fmap3_3_rd_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap3_3_wr_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap3_3_we       : std_logic := '0';
	 signal ram_fmap3_3_q_out    : std_logic_vector(31 downto 0);
	 
	 signal ram_fmap4_1_data_in  : std_logic_vector(31 downto 0);
	 signal ram_fmap4_1_rd_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap4_1_wr_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap4_1_we       : std_logic := '0';
	 signal ram_fmap4_1_q_out    : std_logic_vector(31 downto 0);

	 signal ram_fmap4_2_data_in  : std_logic_vector(31 downto 0);
	 signal ram_fmap4_2_rd_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap4_2_wr_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap4_2_we       : std_logic := '0';
	 signal ram_fmap4_2_q_out    : std_logic_vector(31 downto 0);
	 
	 signal ram_fmap4_3_data_in  : std_logic_vector(31 downto 0);
	 signal ram_fmap4_3_rd_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap4_3_wr_addr  : std_logic_vector(9 downto 0);
	 signal ram_fmap4_3_we       : std_logic := '0';
	 signal ram_fmap4_3_q_out    : std_logic_vector(31 downto 0);
	 
	 signal ram_maxpool1_2_data_in  : std_logic_vector(31 downto 0);
	 signal ram_maxpool1_2_rd_addr  : std_logic_vector(9 downto 0);
	 signal ram_maxpool1_2_wr_addr  : std_logic_vector(9 downto 0);
	 signal ram_maxpool1_2_we       : std_logic := '0';
	 signal ram_maxpool1_2_q_out    : std_logic_vector(31 downto 0);

	 signal ram_maxpool2_2_data_in  : std_logic_vector(31 downto 0);
	 signal ram_maxpool2_2_rd_addr  : std_logic_vector(9 downto 0);
	 signal ram_maxpool2_2_wr_addr  : std_logic_vector(9 downto 0);
	 signal ram_maxpool2_2_we       : std_logic := '0';
	 signal ram_maxpool2_2_q_out    : std_logic_vector(31 downto 0);
	 
	 signal ram_maxpool3_2_data_in  : std_logic_vector(31 downto 0);
	 signal ram_maxpool3_2_rd_addr  : std_logic_vector(9 downto 0);
	 signal ram_maxpool3_2_wr_addr  : std_logic_vector(9 downto 0);
	 signal ram_maxpool3_2_we       : std_logic := '0';
	 signal ram_maxpool3_2_q_out    : std_logic_vector(31 downto 0);
	 
	 signal clk : std_logic;
	 signal clk_en_mul: STD_LOGIC;
	 signal clk_en_add: STD_LOGIC;
	 signal clk_en_compare: STD_LOGIC;
	 signal aclr : STD_LOGIC;
	 
	 signal dataa_compare1  : mult_array;
    signal datab_compare1  : mult_array;
	 signal agb_compare1 : std_logic_vector(NUM_COMPARATOR-1 downto 0);

	 signal dataa_compare2  : mult_array;
    signal datab_compare2  : mult_array;
	 signal agb_compare2 : std_logic_vector(NUM_COMPARATOR-1 downto 0);

	 signal dataa_compare3  : mult_array;
    signal datab_compare3  : mult_array;
	 signal agb_compare3 : std_logic_vector(NUM_COMPARATOR-1 downto 0);
	 
	 signal dataa_mult1  : mult_array;
    signal datab_mult1  : mult_array;
    signal result_mult1 : mult_array;
	 signal dataa_add1  : adder_array;
    signal datab_add1  : adder_array;
    signal result_add1 : adder_array;
	 
	 signal dataa_mult2  : mult_array;
    signal datab_mult2  : mult_array;
    signal result_mult2 : mult_array;
	 signal dataa_add2  : adder_array;
    signal datab_add2  : adder_array;
    signal result_add2 : adder_array;
	 
	 signal dataa_mult3  : mult_array;
    signal datab_mult3  : mult_array;
    signal result_mult3 : mult_array;
	 signal dataa_add3 : adder_array;
    signal datab_add3  : adder_array;
    signal result_add3 : adder_array;
     --eleman tutmak için temp registerlar------------------------------------------------------------------------------------

	 signal flat_debug_reg1 : std_logic_vector(31 downto 0);
	 signal flat_debug_reg2 : std_logic_vector(31 downto 0);
	 signal flat_debug_reg3 : std_logic_vector(31 downto 0);
	 

	 signal reg_m1_8_out1 : std_logic_vector(31 downto 0); --1. fmap için (pipelinesız conv1'de ise tüm fmapler için)
	 signal reg_m2_8_out1 : std_logic_vector(31 downto 0);
	 signal reg_m3_8_out1 : std_logic_vector(31 downto 0);
	 
	 
	 signal reg_tempMax1_1 : std_logic_vector(31 downto 0);     -- !!!!!!!!!! eğer register kullanımı donanımı aşarsa aynı registerları tekrar kullanabiliriz (array olanlarda değil ama)
	 signal reg_tempMax1_2 : std_logic_vector(31 downto 0);

	 signal reg_tempMax2_1 : std_logic_vector(31 downto 0);     --pipeline uğruna giden registerlar :-
	 signal reg_tempMax2_2 : std_logic_vector(31 downto 0);  
	 
	 signal reg_tempMax3_1 : std_logic_vector(31 downto 0);  
	 signal reg_tempMax3_2 : std_logic_vector(31 downto 0);  	
	 signal sum_ch1 : std_logic_vector(31 downto 0);
	 signal sum_ch2 : std_logic_vector(31 downto 0);
	 signal sum_ch3 : std_logic_vector(31 downto 0);
	 signal sum_ch1_ch2 : std_logic_vector(31 downto 0); 
	 ---------------------------------------------------------------------------------------------------------------------------------------
	 signal row_idx : integer range 0 to OUT_MATRIX_S-1; --feature mapin index değerleri(çıkan sonuç kadar kaydırma yapcaz, formül aynı)
    signal col_idx : integer range 0 to OUT_MATRIX_S-1;
	 signal row_idx_lrelu1 : integer range 0 to OUT_MATRIX_S; --bunlarda da -1 olması lazım sanırım 1 fazla eleman olmuş oluyor ama algoritmadaki kontrolden dolayı sorun çıkmıyor böyle kalsın
	 signal col_idx_lrelu1 : integer range 0 to OUT_MATRIX_S;
	 signal row_idx_conv2 : integer range 0 to FM2_MATRIX_S-1;
	 signal col_idx_conv2 : integer range 0 to FM2_MATRIX_S-1;
	 signal row_idx_lrelu2 : integer range 0 to FM2_MATRIX_S;
	 signal col_idx_lrelu2 : integer range 0 to FM2_MATRIX_S;
	 signal row_idx_maxpool1 : integer range 0 to POOL1_MATRIX_S;
	 signal col_idx_maxpool1 : integer range 0 to POOL1_MATRIX_S;
	 
	 signal row_idx_conv3 : integer range 0 to FM3_MATRIX_S-1;	 
	 signal col_idx_conv3 : integer range 0 to FM3_MATRIX_S-1;	 
	 signal row_idx_lrelu3 : integer range 0 to FM3_MATRIX_S; 
	 signal col_idx_lrelu3 : integer range 0 to FM3_MATRIX_S;	 
	 signal row_idx_conv4 : integer range 0 to FM4_MATRIX_S-1;	 
	 signal col_idx_conv4 : integer range 0 to FM4_MATRIX_S-1;	 
	 signal row_idx_lrelu4 : integer range 0 to FM4_MATRIX_S;	 
	 signal col_idx_lrelu4 : integer range 0 to FM4_MATRIX_S;	 
	 signal row_idx_maxpool2 : integer range 0 to POOL2_MATRIX_S;	 
	 signal col_idx_maxpool2 : integer range 0 to POOL2_MATRIX_S;	 
	
	 signal flat_idx : integer;
	 
	 signal relu_control1 : boolean;
	 signal relu_control2 : boolean;
	 signal relu_control3 : boolean;
	 
	 signal state : state_type;
	 signal layer_state : layer_state_type := INIT;
	 signal lrelu_state : lrelu_state_type;
	 signal maxpool_state : maxpool_state_type;
	 signal flatting_state : flatting_state_type;
	 signal cnt : integer;
	 signal cnt_end : integer;
	 
	 signal flattenMatrix : hiddenInputMatrix;
----------------------------------------------FULLY CONNECT LAYER SIGNALS-----------------------------------------------------------
	 type MM_mult_array is array (0 to 7) of std_logic_vector(31 downto 0);
	 type MM_adder_array is array (0 to 7) of std_logic_vector(31 downto 0);
	 

	 type MM_state_type is (s_idle,s_load_mult,s_wait_mult,s_reduce,s_next_block,s_wait_add,s_write_out,s_finish);
	 type MM_Softmax_state_type is (s_idle,s_calc_ej,s_waitExpo,s_writeForAdder,s_reduct1,s_reduct2,s_reduct3,s_reduct4,s_div,s_finish);

	 type MM_lrelu_state_type is (s_idle,s_compare,s_write,s_increaseIndex,s_finishRelu);
	 type MM_precit_state_type is (s_idle,s_compare,s_writeTemp,s_increaseIdx,s_finishPredict, s_showResult);
	 

	 signal MM_state : MM_state_type;
	 signal MM_Softmax_state : MM_Softmax_state_type;
	 signal MM_lrelu_state : MM_lrelu_state_type;
	 signal MM_predict_state : MM_precit_state_type;
	 
	 signal MM_dataa_mult1  : MM_mult_array;
    signal MM_datab_mult1  : MM_mult_array;
    signal MM_result_mult1 : MM_mult_array;
	 signal MM_dataa_add1  : MM_adder_array;
    signal MM_datab_add1  : MM_adder_array;
    signal MM_result_add1 : MM_adder_array;
	 signal MM_dataa_div  : std_logic_vector(31 downto 0);
    signal MM_datab_div  : std_logic_vector(31 downto 0);
    signal MM_result_div : std_logic_vector(31 downto 0);
	 signal MM_dataExpo : std_logic_vector(31 downto 0);
	 signal MM_resultExpo : std_logic_vector(31 downto 0);
	 signal MM_dataa_compare : std_logic_vector(31 downto 0);
	 signal MM_datab_compare : std_logic_vector(31 downto 0);
	 signal MM_agb_compare : std_logic;
	 
	 signal hidLayerMatrix : hiddenLayerMatrix;
	 signal softmaxIn :  fullyOutLayerMatrix;
	 signal fullyOut : fullyOutLayerMatrix;
	 signal MM_row_idx_lrelu : integer; 
	 signal MM_relu_control1 : boolean;

	 signal MM_reg_accum : std_logic_vector(31 downto 0);
	 signal MM_reg_exp_sum : std_logic_vector(31 downto 0);
	 signal MM_reg_tempCompare : std_logic_vector(31 downto 0);
	 signal MM_temp_sum_8_9 : std_logic_vector(31 downto 0);
	 
	 signal MM_block_idx : integer range 0 to 5 := 0;
	 signal MM_row_idx : integer range 0 to 15 := 0;
	 signal MM_red_idx    : integer range 0 to 7  := 0;
	 signal MM_softmax_idx : integer range 0 to 9 := 0;
	 signal MM_compareIdx : integer;
	 signal MM_predictedNumberTemp : integer; 

	 signal clk_en_exp: std_logic;
	 signal clk_en_div: std_logic;

	 signal predictOut : integer;
	 signal predictOutSizeReference : std_logic_vector(9 downto 0);
	 signal exeTime : integer;
	 signal exeTimeFloat : std_logic_vector(31 downto 0);
---------------------------------------------debounce---------------------------------------
	 constant DEBOUNCE_TIME : integer := 500000;
    signal counter : integer range 0 to DEBOUNCE_TIME := 0;
    signal key_stable : std_logic := '1';
    signal key_prev : std_logic := '1';
    signal key_pressed : std_logic := '0';
------------------------------------------------------------------------------------------------------------------------------------
begin
u_debug_display : hex_display_driver
    port map (
        data_in => exeTimeFloat,
        hex0    => hex0, 
        hex1    => hex1,
        hex2    => hex2,
        hex3    => hex3,
        hex4    => hex4,
        hex5    => hex5,
        hex6    => hex6,
        hex7    => hex7
    );
---------------------------------RAM Inst'leri------------------------------------
	img_rom_inst : img_rom PORT MAP (
			aclr	 => aclr,
			address	 => rom_addr,
			clock	 => clock_50,
			rden	 => rden_sig,
			q	 => rom_q_out
		);

	inst_fmap1_1 : fmap_ram PORT MAP (
    clock     => clock_50,
    data      => ram_fmap1_1_data_in,
	 rden	 	  => rden_sig,
    rdaddress => ram_fmap1_1_rd_addr,
    wraddress => ram_fmap1_1_wr_addr,
    wren      => ram_fmap1_1_we,
    q         => ram_fmap1_1_q_out
	);
	inst_fmap1_2 : fmap_ram PORT MAP (
		clock     => clock_50,
		data      => ram_fmap1_2_data_in,
		rden	    => rden_sig,
		rdaddress => ram_fmap1_2_rd_addr,
		wraddress => ram_fmap1_2_wr_addr,
		wren      => ram_fmap1_2_we,
		q         => ram_fmap1_2_q_out
	);
	inst_fmap1_3 : fmap_ram PORT MAP (
		clock     => clock_50,
		data      => ram_fmap1_3_data_in,
		rden	    => rden_sig,
		rdaddress => ram_fmap1_3_rd_addr,
		wraddress => ram_fmap1_3_wr_addr,
		wren      => ram_fmap1_3_we,
		q         => ram_fmap1_3_q_out
	);
	
	inst_fmap2_1 : fmap_ram PORT MAP (
    clock     => clock_50,
    data      => ram_fmap2_1_data_in,
	 rden	 	  => rden_sig,
    rdaddress => ram_fmap2_1_rd_addr,
    wraddress => ram_fmap2_1_wr_addr,
    wren      => ram_fmap2_1_we,
    q         => ram_fmap2_1_q_out
	);
	inst_fmap2_2 : fmap_ram PORT MAP (
		clock     => clock_50,
		data      => ram_fmap2_2_data_in,
		rden	    => rden_sig,
		rdaddress => ram_fmap2_2_rd_addr,
		wraddress => ram_fmap2_2_wr_addr,
		wren      => ram_fmap2_2_we,
		q         => ram_fmap2_2_q_out
	);
	inst_fmap2_3 : fmap_ram PORT MAP (
		clock     => clock_50,
		data      => ram_fmap2_3_data_in,
		rden	    => rden_sig,
		rdaddress => ram_fmap2_3_rd_addr,
		wraddress => ram_fmap2_3_wr_addr,
		wren      => ram_fmap2_3_we,
		q         => ram_fmap2_3_q_out
	);

	inst_pool1_1 : fmap_ram PORT MAP (
    clock     => clock_50,
    data      => ram_maxpool1_1_data_in,
	 rden	 	  => rden_sig,
    rdaddress => ram_maxpool1_1_rd_addr,
    wraddress => ram_maxpool1_1_wr_addr,
    wren      => ram_maxpool1_1_we,
    q         => ram_maxpool1_1_q_out
	);
	inst_pool1_2 : fmap_ram PORT MAP ( 
		clock     => clock_50,
		data      => ram_maxpool2_1_data_in, --1_2 diye isimlendirceğime 2_1 demişim değiştirmekle uğraşmak istemiyorum pool layer'ında 2. indis katmanı göstersin(tersten)
		rden	    => rden_sig,
		rdaddress => ram_maxpool2_1_rd_addr,
		wraddress => ram_maxpool2_1_wr_addr,
		wren      => ram_maxpool2_1_we,
		q         => ram_maxpool2_1_q_out
	);
	inst_pool1_3 : fmap_ram PORT MAP (
		clock     => clock_50,
		data      => ram_maxpool3_1_data_in,
		rden	    => rden_sig,
		rdaddress => ram_maxpool3_1_rd_addr,
		wraddress => ram_maxpool3_1_wr_addr,
		wren      => ram_maxpool3_1_we,
		q         => ram_maxpool3_1_q_out
	);	

	inst_fmap3_1 : fmap_ram PORT MAP (
    clock     => clock_50,
    data      => ram_fmap3_1_data_in,
	 rden	 	  => rden_sig,
    rdaddress => ram_fmap3_1_rd_addr,
    wraddress => ram_fmap3_1_wr_addr,
    wren      => ram_fmap3_1_we,
    q         => ram_fmap3_1_q_out
	);
	inst_fmap3_2 : fmap_ram PORT MAP (
		clock     => clock_50,
		data      => ram_fmap3_2_data_in,
		rden	    => rden_sig,
		rdaddress => ram_fmap3_2_rd_addr,
		wraddress => ram_fmap3_2_wr_addr,
		wren      => ram_fmap3_2_we,
		q         => ram_fmap3_2_q_out
	);
	inst_fmap3_3 : fmap_ram PORT MAP (
		clock     => clock_50,
		data      => ram_fmap3_3_data_in,
		rden	    => rden_sig,
		rdaddress => ram_fmap3_3_rd_addr,
		wraddress => ram_fmap3_3_wr_addr,
		wren      => ram_fmap3_3_we,
		q         => ram_fmap3_3_q_out
	);
	inst_fmap4_1 : fmap_ram PORT MAP (
    clock     => clock_50,
    data      => ram_fmap4_1_data_in,
	 rden	 	  => rden_sig,
    rdaddress => ram_fmap4_1_rd_addr,
    wraddress => ram_fmap4_1_wr_addr,
    wren      => ram_fmap4_1_we,
    q         => ram_fmap4_1_q_out
	);
	inst_fmap4_2 : fmap_ram PORT MAP (
		clock     => clock_50,
		data      => ram_fmap4_2_data_in,
		rden	    => rden_sig,
		rdaddress => ram_fmap4_2_rd_addr,
		wraddress => ram_fmap4_2_wr_addr,
		wren      => ram_fmap4_2_we,
		q         => ram_fmap4_2_q_out
	);
	inst_fmap4_3 : fmap_ram PORT MAP (
		clock     => clock_50,
		data      => ram_fmap4_3_data_in,
		rden	    => rden_sig,
		rdaddress => ram_fmap4_3_rd_addr,
		wraddress => ram_fmap4_3_wr_addr,
		wren      => ram_fmap4_3_we,
		q         => ram_fmap4_3_q_out
	);
	inst_pool2_1 : fmap_ram PORT MAP (
        clock     => clock_50,
        data      => ram_maxpool1_2_data_in,
        rden      => rden_sig,
        rdaddress => ram_maxpool1_2_rd_addr,
        wraddress => ram_maxpool1_2_wr_addr,
        wren      => ram_maxpool1_2_we,
        q         => ram_maxpool1_2_q_out
    );

    inst_pool2_2 : fmap_ram PORT MAP (
        clock     => clock_50,
        data      => ram_maxpool2_2_data_in,
        rden      => rden_sig,
        rdaddress => ram_maxpool2_2_rd_addr,
        wraddress => ram_maxpool2_2_wr_addr,
        wren      => ram_maxpool2_2_we,
        q         => ram_maxpool2_2_q_out
    );

    inst_pool2_3 : fmap_ram PORT MAP (
        clock     => clock_50,
        data      => ram_maxpool3_2_data_in,
        rden      => rden_sig,
        rdaddress => ram_maxpool3_2_rd_addr,
        wraddress => ram_maxpool3_2_wr_addr,
        wren      => ram_maxpool3_2_we,
        q         => ram_maxpool3_2_q_out
    );
------------------------------------------Aritmatik inst'ler--------------------------------------------------------


	comparators1: for c1 in 0 to NUM_COMPARATOR-1 generate
		compare_inst : compare PORT MAP (
		aclr	 => aclr,
		clk_en => clk_en_compare,
		clock	 => clk,
		dataa	 => dataa_compare1(c1),
		datab	 => datab_compare1(c1),
		agb	 => agb_compare1(c1)
	);
	end generate;
	
	comparators2: for c2 in 0 to NUM_COMPARATOR-1 generate
		compare_inst : compare PORT MAP (
		aclr	 => aclr,
		clk_en => clk_en_compare,
		clock	 => clk,
		dataa	 => dataa_compare2(c2),
		datab	 => datab_compare2(c2),
		agb	 => agb_compare2(c2)
	);
	end generate;
	
	comparators3: for c3 in 0 to NUM_COMPARATOR-1 generate
		compare_inst : compare PORT MAP (
		aclr	 => aclr,
		clk_en => clk_en_compare,
		clock	 => clk,
		dataa	 => dataa_compare3(c3),
		datab	 => datab_compare3(c3),
		agb	 => agb_compare3(c3)
	);
	end generate;
	
	multipliers1: for m1 in 0 to NUM_MULT-1 generate
		mult_inst : altfp_mula PORT MAP (
			aclr   => aclr,
			clk_en => clk_en_mul,
			clock  => clk,
			dataa  => dataa_mult1(m1),
			datab  => datab_mult1(m1),
			result => result_mult1(m1)
		);
	 end generate;
	 
	 adders1: for a1 in 0 to NUM_ADD-1 generate
		add_inst : altfp_add PORT MAP (
			aclr   => aclr,
			clk_en => clk_en_add,
			clock  => clk,
			dataa  => dataa_add1(a1),
			datab  => datab_add1(a1),
			result => result_add1(a1)
		);
	 end generate;
	multipliers2: for m2 in 0 to NUM_MULT-1 generate
		mult_inst : altfp_mula PORT MAP (
			aclr   => aclr,
			clk_en => clk_en_mul,
			clock  => clk,
			dataa  => dataa_mult2(m2),
			datab  => datab_mult2(m2),
			result => result_mult2(m2)
		);
	 end generate;
	 
	 adders2: for a2 in 0 to NUM_ADD-1 generate
		add_inst : altfp_add PORT MAP (
			aclr   => aclr,
			clk_en => clk_en_add,
			clock  => clk,
			dataa  => dataa_add2(a2),
			datab  => datab_add2(a2),
			result => result_add2(a2)
		);
	 end generate;
	multipliers3: for m3 in 0 to NUM_MULT-1 generate
		mult_inst : altfp_mula PORT MAP (
			aclr   => aclr,
			clk_en => clk_en_mul,
			clock  => clk,
			dataa  => dataa_mult3(m3),
			datab  => datab_mult3(m3),
			result => result_mult3(m3)
		);
	 end generate;
	 
	 adders3: for a3 in 0 to NUM_ADD-1 generate
		add_inst : altfp_add PORT MAP (
			aclr   => aclr,
			clk_en => clk_en_add,
			clock  => clk,
			dataa  => dataa_add3(a3),
			datab  => datab_add3(a3),
			result => result_add3(a3)
		);
	 end generate;
---------------------------------------------FULLY CONNECT INSTLERI--------------------------------------------------------	
			compare_inst : compare PORT MAP (
		aclr	 => aclr,
		clk_en => clk_en_compare,
		clock	 => clk,
		dataa	 => MM_dataa_compare,
		datab	 => MM_datab_compare,
		agb	 => MM_agb_compare
	);
	
	div_inst : div PORT MAP (
		aclr	 => aclr,
		clk_en	 => clk_en_div,
		clock	 => clk,
		dataa	 => MM_dataa_div,
		datab	 => MM_datab_div,
		result	 => MM_result_div
	);
	
	expo_inst : expo PORT MAP (
		aclr	 => aclr,
		clk_en	 => clk_en_exp,
		clock	 => clk,
		data	 => MM_dataExpo,
		result	 => MM_resultExpo
	);


	multipliersMM: for mMM in 0 to 7 generate --1x48 . 48x16 için 6 epochta tamamlancak kadar
		mult_inst : altfp_mula PORT MAP (      --1x16 . 16x10 için 2 epoch
			aclr   => aclr,
			clk_en => clk_en_mul,
			clock  => clk,
			dataa  => MM_dataa_mult1(mMM),
			datab  => MM_datab_mult1(mMM),
			result => MM_result_mult1(mMM)
		);
	 end generate;
	 
	 addersMM: for aMM in 0 to 7 generate
		add_inst : altfp_add PORT MAP (
			aclr   => aclr,
			clk_en => clk_en_add,
			clock  => clk,
			dataa  => MM_dataa_add1(aMM),
			datab  => MM_datab_add1(aMM),
			result => MM_result_add1(aMM)
		);
	 end generate;
---------------------------------------------------------------------------------------------------------
	
	clk <= clock_50;
	aclr <= not SW(0);


debounce_proc: process(clock_50)
    begin
        if rising_edge(clock_50) then  
            if KEY(0) /= key_stable then  
                counter <= counter + 1;
                if counter >= DEBOUNCE_TIME then  
                    key_stable <= KEY(0);         
                    counter <= 0;                 
                end if;
            else 
                counter <= 0; 
            end if;
          
            if key_prev = '1' and key_stable = '0' then 
                key_pressed <= '1';
            else
                key_pressed <= '0';
            end if;
         
            key_prev <= key_stable;  
        end if;
    end process;


	process(clock_50)
	begin
		if rising_edge(clock_50) then
			if SW(0) = '0' then
				clk_en_mul <= '0';
				clk_en_add <= '0'; 
				cnt <= 0;
				cnt_end <= 1;
				state <= s_idle;
				lrelu_state <= s_idle;
				flatting_state <= s_idle;
				maxpool_state <= s_idle;
				reg_m1_8_out1 <= (others => '0');
				reg_m2_8_out1 <= (others => '0');
				reg_m3_8_out1 <= (others => '0');
				reg_tempMax1_1 <= (others => '0');
				reg_tempMax1_2 <= (others => '0');
				reg_tempMax2_1 <= (others => '0');
				reg_tempMax2_2 <= (others => '0');
				reg_tempMax3_1 <= (others => '0');
				reg_tempMax3_2 <= (others => '0');

				row_idx <= 0;
				col_idx <= 0;
				row_idx_conv2 <= 0;
				col_idx_conv2 <= 0;
				row_idx_conv3 <= 0;
				col_idx_conv3 <= 0;
				row_idx_conv4 <= 0;
				col_idx_conv4 <= 0;
				row_idx_lrelu1 <= 0;
				col_idx_lrelu1 <= 0;
				row_idx_lrelu2 <= 0;
				col_idx_lrelu2 <= 0;
				row_idx_lrelu3 <= 0;
				col_idx_lrelu3 <= 0;
				row_idx_lrelu4 <= 0;
				col_idx_lrelu4 <= 0;
				row_idx_maxpool1 <= 0;
				col_idx_maxpool1 <= 0;
				row_idx_maxpool2 <= 0;
				col_idx_maxpool2 <= 0;
				
				MM_row_idx   <= 0;
            MM_block_idx <= 0;
            MM_red_idx   <= 0;
				MM_reg_accum <= (others => '0');
				MM_state <= s_idle;
				MM_softmax_state <= s_idle;
				MM_lrelu_state <= s_idle;
				MM_predict_state <= s_idle;
				layer_state <= INIT;
				LEDR <= (others => '0');
				LEDG <= (others => '0');
				exeTime <= 0;
				else
					exeTime <= exeTime + 1;
					case (layer_state) is
						when INIT =>-- belli değerlerde bir şeyler başlatırsak diye(bir de 1 clock daha hazırlansın)
							layer_state <= CONV1;
------------------------------------------------------------CONV1-------------------------------------------------------------------------------
						when CONV1 =>
						
						case (state) is
							when s_idle=>
								clk_en_mul<='0';
								clk_en_add <= '0'; 
								state <= s_control;
							when s_control =>
								
								state <= s_read_ram;--aslında rom
								data_counter <= 0;
								cnt    <= 0;
								
							when s_read_ram =>
								case data_counter is
									when 0 => rom_addr <= std_logic_vector(to_unsigned((row_idx + 0) * 28 + (col_idx + 0),10)); --to_unsigned(<integer_value>, <bit_width>);
									when 1 => rom_addr <= std_logic_vector(to_unsigned((row_idx + 0) * 28 + (col_idx + 1),10)); --10 çünkü 2^10, 28x28 veriyi tutar, yukarda da adresi 0-9 yaptık 
									when 2 => rom_addr <= std_logic_vector(to_unsigned((row_idx + 0) * 28 + (col_idx + 2),10)); --yani 2^10, 1024 adreslik bellek
									when 3 => rom_addr <= std_logic_vector(to_unsigned((row_idx + 1) * 28 + (col_idx + 0),10));
									when 4 => rom_addr <= std_logic_vector(to_unsigned((row_idx + 1) * 28 + (col_idx + 1),10));
									when 5 => rom_addr <= std_logic_vector(to_unsigned((row_idx + 1) * 28 + (col_idx + 2),10));
									when 6 => rom_addr <= std_logic_vector(to_unsigned((row_idx + 2) * 28 + (col_idx + 0),10));
									when 7 => rom_addr <= std_logic_vector(to_unsigned((row_idx + 2) * 28 + (col_idx + 1),10));
									when 8 => rom_addr <= std_logic_vector(to_unsigned((row_idx + 2) * 28 + (col_idx + 2),10)); --son adres 783 (28x28-1)
									when others => null;
								end case;
								state <= s_wait_data;
								
							when s_wait_data =>
								if cnt = 2 then 
									cnt <= 0;
									state <= s_save_data;
								else
									cnt <= cnt + 1;
								end if;
		
							when s_save_data =>
								dataa_mult1(data_counter) <= rom_q_out; 
								dataa_mult2(data_counter) <= rom_q_out;
								dataa_mult3(data_counter) <= rom_q_out;
								for i in 0 to 2 loop
										for j in 0 to 2 loop
											datab_mult1(i*3+j) <= pkgKernel1_1_1(i,j);
											datab_mult2(i*3+j) <= pkgKernel1_2_1(i,j);
											datab_mult3(i*3+j) <= pkgKernel1_3_1(i,j);
									end loop;
								end loop;
								if data_counter = 8 then
									state <= s_mult;
								else
									data_counter <= data_counter + 1;
									state <= s_read_ram;
								end if;
								
							when s_mult =>
								clk_en_mul <= '1';
								cnt <= 0;  
								if cnt = cnt_end_mul then
									reg_m1_8_out1 <= result_mult1(8);
									reg_m2_8_out1 <= result_mult2(8);
									reg_m3_8_out1 <= result_mult3(8);
									cnt <= 0;
									clk_en_mul <= '0';
									state <= s_reduction;
								else
									cnt <= cnt + 1;
								end if;
						
							when s_reduction =>
								clk_en_add <= '1';
								cnt <= 0;  
								for i in 0 to 3 loop
									dataa_add1(i) <= result_mult1(2*i);
									datab_add1(i) <= result_mult1(2*i+1);
		
									dataa_add2(i) <= result_mult2(2*i);
									datab_add2(i) <= result_mult2(2*i+1);
		
									dataa_add3(i) <= result_mult3(2*i);
									datab_add3(i) <= result_mult3(2*i+1);
								end loop;
								if cnt = cnt_end_add then
									cnt <= 0;
									state <= s_reduction2;
								else
									cnt <= cnt + 1;
								end if;
			
							when s_reduction2 =>
								clk_en_add <= '1';
								cnt <= 0;  
								for i in 4 to 5 loop
									dataa_add1(i) <= result_add1(2*(i-4));
									datab_add1(i) <= result_add1(2*(i-4)+1);
		
									dataa_add2(i) <= result_add2(2*(i-4));
									datab_add2(i) <= result_add2(2*(i-4)+1);
		
									dataa_add3(i) <= result_add3(2*(i-4));
									datab_add3(i) <= result_add3(2*(i-4)+1);
								end loop;
									if cnt = cnt_end_add then
										cnt <= 0;
										state <= s_reduction3;
									else
										cnt <= cnt + 1;
									end if;
        
							when s_reduction3 =>
								clk_en_add <= '1';
									cnt <= 0;  
								dataa_add1(6) <= result_add1(4);
								datab_add1(6) <= result_add1(5);
		
								dataa_add2(6) <= result_add2(4);
								datab_add2(6) <= result_add2(5);
		
								dataa_add3(6) <= result_add3(4);
								datab_add3(6) <= result_add3(5);
		
								if cnt = cnt_end_add then
									cnt <= 0;
									state <= s_reduction4;
								else
									cnt <= cnt + 1;
								end if;
			
							when s_reduction4 =>
								clk_en_add <= '1';
								cnt <= 0;  
								dataa_add1(7) <= reg_m1_8_out1;
								datab_add1(7) <= result_add1(6);
		
								dataa_add2(7) <= reg_m2_8_out1;
								datab_add2(7) <= result_add2(6);
		
								dataa_add3(7) <= reg_m3_8_out1;
								datab_add3(7) <= result_add3(6);
								
								if cnt = cnt_end_add then
									clk_en_add <= '0';
									cnt <= 0;
									state <= s_writeResult;
								else
									cnt <= cnt + 1;
								end if;
								
							when s_writeResult =>
								cnt <= 0;
								ram_fmap1_1_we      <= '1';
								ram_fmap1_1_wr_addr <= std_logic_vector(to_unsigned(row_idx * 26 + col_idx, 10)); --to_unsigned(<integer_value>, <bit_width>);
								ram_fmap1_2_wr_addr <= std_logic_vector(to_unsigned(row_idx * 26 + col_idx, 10));
								ram_fmap1_3_wr_addr <= std_logic_vector(to_unsigned(row_idx * 26 + col_idx, 10));
								ram_fmap1_1_data_in <= result_add1(7);
								ram_fmap1_2_we <= '1';
								ram_fmap1_2_data_in <= result_add2(7); 
								ram_fmap1_3_we <= '1';
								ram_fmap1_3_data_in <= result_add3(7);
								state <= s_write_wait; 
								
							when s_write_wait =>
								if cnt = 0 then
									cnt <= 1;
								elsif cnt = 1 then
									cnt <= 0;
									ram_fmap1_1_we <= '0';
									if col_idx = (OUT_MATRIX_S - 1) and row_idx = (OUT_MATRIX_S - 1) then
										state <= s_finish;
									else
										state <= s_slide;
									end if;
								end if;
							when s_slide =>
								cnt <= 0;
								if col_idx < (OUT_MATRIX_S - 1) then
									col_idx <= col_idx + 1;
									state  <= s_control;
								else
									col_idx <= 0;
									row_idx <= row_idx + 1;
									state  <= s_control;
								end if;
								
							when s_finish =>
								data_counter <= 0;
								cnt <= 0;
								layer_state <= LRELU1;
								state <= s_idle;
								lrelu_state <= s_idle;
							
							when others =>
								state <= s_idle;
						end case;
-------------------------------------------------------------LRELU-----------------------------------------------------------------------------	
					when LRELU1 =>
					
						case (lrelu_state) is
								
								when s_idle =>
									clk_en_mul <= '0';
									row_idx_lrelu1 <= 0;
									col_idx_lrelu1 <= 0;
									cnt <= 0;
									relu_control1 <= false;
									relu_control2 <= false;
									relu_control3 <= false;
									data_counter <= 0;
									ram_fmap1_1_we <= '0';
									ram_fmap1_2_we <= '0';
									ram_fmap1_3_we <= '0';
									
									lrelu_state <= s_set_addr;
					
								when s_set_addr =>
									ram_fmap1_1_rd_addr <= std_logic_vector(to_unsigned(row_idx_lrelu1 * 26 + col_idx_lrelu1, 10));
									ram_fmap1_2_rd_addr <= std_logic_vector(to_unsigned(row_idx_lrelu1 * 26 + col_idx_lrelu1, 10));
									ram_fmap1_3_rd_addr <= std_logic_vector(to_unsigned(row_idx_lrelu1 * 26 + col_idx_lrelu1, 10));
									
									lrelu_state <= s_wait_ram;
						
								when s_wait_ram =>
									if cnt = 2 then
										cnt <= 0;
										lrelu_state <= s_check_sign;
									else
										cnt <= cnt + 1;
									end if;
							
				
								when s_check_sign =>
									clk_en_mul <= '1';
									cnt <= 0;
									
									if ram_fmap1_1_q_out(31) = '1' then 
										dataa_mult1(0) <= ram_fmap1_1_q_out; 
										datab_mult1(0) <= x"3c23d70a"; 
										relu_control1 <= true; 
									else 
										relu_control1 <= false; 
									end if;
						
								
									if ram_fmap1_2_q_out(31) = '1' then
										dataa_mult2(0) <= ram_fmap1_2_q_out;
										datab_mult2(0) <= x"3c23d70a";
										relu_control2 <= true;
									else 
										relu_control2 <= false;
									end if;
						
								
									if ram_fmap1_3_q_out(31) = '1' then
										dataa_mult3(0) <= ram_fmap1_3_q_out;
										datab_mult3(0) <= x"3c23d70a";
										relu_control3 <= true;
									else 
										relu_control3 <= false;
									end if;
									lrelu_state <= s_mult_wait; 
						
								when s_mult_wait =>
					
									if (relu_control1 = false and relu_control2 = false and relu_control3 = false) then
										clk_en_mul <= '0';
										lrelu_state <= s_write_finish; 
									else
									
										if cnt = cnt_end_mul then
												clk_en_mul <= '0';
												cnt <= 0;
												lrelu_state <= s_write_back;
										else
												cnt <= cnt + 1;
										end if;
									end if;
						
								when s_write_back =>
								
									ram_fmap1_1_wr_addr <= std_logic_vector(to_unsigned(row_idx_lrelu1 * 26 + col_idx_lrelu1, 10));
									ram_fmap1_2_wr_addr <= std_logic_vector(to_unsigned(row_idx_lrelu1 * 26 + col_idx_lrelu1, 10));
									ram_fmap1_3_wr_addr <= std_logic_vector(to_unsigned(row_idx_lrelu1 * 26 + col_idx_lrelu1, 10));
						
									
									if relu_control1 then
										
										ram_fmap1_1_data_in <= result_mult1(0); 
										ram_fmap1_1_we <= '1';                 
									end if;
						
									if relu_control2 then
										ram_fmap1_2_data_in <= result_mult2(0);
										ram_fmap1_2_we <= '1';
									end if;
						
									if relu_control3 then
										ram_fmap1_3_data_in <= result_mult3(0);
										ram_fmap1_3_we <= '1';
									end if;
						
									lrelu_state <= s_write_finish;
						
					
								when s_write_finish =>
									ram_fmap1_1_we <= '0';
									ram_fmap1_2_we <= '0';
									ram_fmap1_3_we <= '0';
									
									
									if col_idx_lrelu1 = (OUT_MATRIX_S-1) and row_idx_lrelu1 = (OUT_MATRIX_S-1) then
										lrelu_state <= s_finishRelu;
									else
										lrelu_state <= s_increaseIndex;
									end if;
						
						
								when s_increaseIndex =>
									if col_idx_lrelu1 < (OUT_MATRIX_S-1) then
										col_idx_lrelu1 <= col_idx_lrelu1 + 1;
									else
										col_idx_lrelu1 <= 0;
										row_idx_lrelu1 <= row_idx_lrelu1 + 1;
									end if;
									lrelu_state <= s_set_addr; 
									
							
								when s_finishRelu =>
									cnt <= 0;
									layer_state <= CONV2;
									state <= s_idle;
									lrelu_state <= s_idle;
								when others =>
									null;
						end case;
------------------------------------------------------------CONV2-------------------------------------------------------------------------------
						when CONV2 =>
							
							case (state) is
				
								when s_idle =>
										clk_en_mul <= '0';
										clk_en_add <= '0'; 
										data_counter <= 0;
										row_idx_conv2 <= 0; 
										col_idx_conv2 <= 0;
										cnt <= 0;
										state <= s_read_ram;
										
								when s_read_ram =>
									
										case data_counter is
											when 0 => 
												ram_fmap1_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 0) * 26 + (col_idx_conv2 + 0), 10));
												ram_fmap1_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 0) * 26 + (col_idx_conv2 + 0), 10));
												ram_fmap1_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 0) * 26 + (col_idx_conv2 + 0), 10));
											when 1 => 
												ram_fmap1_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 0) * 26 + (col_idx_conv2 + 1), 10));
												ram_fmap1_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 0) * 26 + (col_idx_conv2 + 1), 10));
												ram_fmap1_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 0) * 26 + (col_idx_conv2 + 1), 10));
											when 2 => 
												ram_fmap1_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 0) * 26 + (col_idx_conv2 + 2), 10));
												ram_fmap1_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 0) * 26 + (col_idx_conv2 + 2), 10));
												ram_fmap1_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 0) * 26 + (col_idx_conv2 + 2), 10));
											when 3 => 
												ram_fmap1_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 1) * 26 + (col_idx_conv2 + 0), 10));
												ram_fmap1_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 1) * 26 + (col_idx_conv2 + 0), 10));
												ram_fmap1_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 1) * 26 + (col_idx_conv2 + 0), 10));
											when 4 => 
												ram_fmap1_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 1) * 26 + (col_idx_conv2 + 1), 10));
												ram_fmap1_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 1) * 26 + (col_idx_conv2 + 1), 10));
												ram_fmap1_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 1) * 26 + (col_idx_conv2 + 1), 10));
											when 5 => 
												ram_fmap1_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 1) * 26 + (col_idx_conv2 + 2), 10));
												ram_fmap1_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 1) * 26 + (col_idx_conv2 + 2), 10));
												ram_fmap1_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 1) * 26 + (col_idx_conv2 + 2), 10));
											when 6 => 
												ram_fmap1_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 2) * 26 + (col_idx_conv2 + 0), 10));
												ram_fmap1_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 2) * 26 + (col_idx_conv2 + 0), 10));
												ram_fmap1_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 2) * 26 + (col_idx_conv2 + 0), 10));
											when 7 => 
												ram_fmap1_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 2) * 26 + (col_idx_conv2 + 1), 10));
												ram_fmap1_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 2) * 26 + (col_idx_conv2 + 1), 10));
												ram_fmap1_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 2) * 26 + (col_idx_conv2 + 1), 10));
											when 8 => 
												ram_fmap1_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 2) * 26 + (col_idx_conv2 + 2), 10));
												ram_fmap1_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 2) * 26 + (col_idx_conv2 + 2), 10));
												ram_fmap1_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv2 + 2) * 26 + (col_idx_conv2 + 2), 10));
											when others => null;
										end case;		
										state <= s_wait_data;
						
								when s_wait_data =>
									if cnt = 2 then 
										cnt <= 0;
										state <= s_save_data;
									else
										cnt <= cnt + 1;
									end if;
						
								when s_save_data =>
										
										dataa_mult1(data_counter) <= ram_fmap1_1_q_out;
										dataa_mult2(data_counter) <= ram_fmap1_2_q_out;
										dataa_mult3(data_counter) <= ram_fmap1_3_q_out;
						
										if data_counter = 8 then
											state <= s_setup_F1; 
										else
											data_counter <= data_counter + 1;
											state <= s_read_ram;
										end if;
						
			
								when s_setup_F1 =>
										for i in 0 to 2 loop
											for j in 0 to 2 loop
												datab_mult1(i*3 + j) <= pkgKernel2_1_1(i, j); 
												datab_mult2(i*3 + j) <= pkgKernel2_1_2(i, j); 
												datab_mult3(i*3 + j) <= pkgKernel2_1_3(i, j); 
											end loop;
										end loop;
										clk_en_mul <= '1';
										cnt <= 0;
										state <= s_mult_F1;
									
								when s_mult_F1 =>
										if cnt = cnt_end_mul then
											clk_en_mul <= '0';
											cnt <= 0;
											reg_m1_8_out1 <= result_mult1(8);
											reg_m2_8_out1 <= result_mult2(8);
											reg_m3_8_out1 <= result_mult3(8);
											state <= s_red1_F1; 
										else
											cnt <= cnt + 1;
										end if;
						
				
								when s_red1_F1 =>
										clk_en_add <= '1';
										for i in 0 to 3 loop 
											dataa_add1(i) <= result_mult1(2*i);
											datab_add1(i) <= result_mult1(2*i+1);
											dataa_add2(i) <= result_mult2(2*i); 
											datab_add2(i) <= result_mult2(2*i+1);
											dataa_add3(i) <= result_mult3(2*i); 
											datab_add3(i) <= result_mult3(2*i+1);
										end loop;
										if cnt = cnt_end_add then 
											cnt <= 0;
											state <= s_red2_F1; 
										else
											cnt <= cnt + 1; 
										end if;
						
								when s_red2_F1 => 
										if cnt = 0 then 
											for i in 4 to 5 loop
												dataa_add1(i) <= result_add1(2*(i-4));
												datab_add1(i) <= result_add1(2*(i-4)+1);
					
												dataa_add2(i) <= result_add2(2*(i-4));
												datab_add2(i) <= result_add2(2*(i-4)+1);
					
												dataa_add3(i) <= result_add3(2*(i-4));
												datab_add3(i) <= result_add3(2*(i-4)+1);
											end loop;
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											state <= s_red3_F1; 
										else 
											cnt <= cnt + 1; 
										end if;
						
								when s_red3_F1 => 
										if cnt = 0 then 
											dataa_add1(6) <= result_add1(4);--1. için 3. reduct
											datab_add1(6) <= result_add1(5);
						
											dataa_add2(6) <= result_add2(4);
											datab_add2(6) <= result_add2(5);
						
											dataa_add3(6) <= result_add3(4);
											datab_add3(6) <= result_add3(5);
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0; state <= s_red4_F1; 
										else 
											cnt <= cnt + 1; 
										end if;
						
								when s_red4_F1 => 
										if cnt = 0 then 
											dataa_add1(7) <= reg_m1_8_out1;--1. için 4.reduct
											datab_add1(7) <= result_add1(6);
					
											dataa_add2(7) <= reg_m2_8_out1;
											datab_add2(7) <= result_add2(6);
					
											dataa_add3(7) <= reg_m3_8_out1;
											datab_add3(7) <= result_add3(6);
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											sum_ch1 <= result_add1(7); 
											sum_ch2 <= result_add2(7); 
											sum_ch3 <= result_add3(7);
											state <= s_red5_F1; 
										else 
											cnt <= cnt + 1; 
										end if;
						
								when s_red5_F1 => 
										if cnt = 0 then 
											dataa_add1(0) <= sum_ch1; 
											datab_add1(0) <= sum_ch2;
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											sum_ch1_ch2 <= result_add1(0);
											state <= s_red6_F1; 
										else 
											cnt <= cnt + 1; 
										end if;
						
								when s_red6_F1 => 
										if cnt = 0 then 
											dataa_add1(0) <= sum_ch1_ch2; 
											datab_add1(0) <= sum_ch3;
										end if;
										if cnt = cnt_end_add then 
											clk_en_add <= '0';
											cnt <= 0; 
											state <= s_write_F1; 
										else 
											cnt <= cnt + 1;
										end if;
						
						
								when s_write_F1 =>
										ram_fmap2_1_we <= '1';
										ram_fmap2_1_wr_addr <= std_logic_vector(to_unsigned(row_idx_conv2 * 24 + col_idx_conv2, 10));
										ram_fmap2_1_data_in <= result_add1(0);
										state <= s_wait_write_F1;
						
								when s_wait_write_F1 =>
										if cnt = 0 then 
											cnt <= 1;
										else 
											cnt <= 0;
											ram_fmap2_1_we <= '0'; 
											state <= s_setup_F2;
										end if;
						
				
								when s_setup_F2 =>
										for i in 0 to 2 loop
											for j in 0 to 2 loop
												datab_mult1(i*3 + j) <= pkgKernel2_2_1(i, j); 
												datab_mult2(i*3 + j) <= pkgKernel2_2_2(i, j); 
												datab_mult3(i*3 + j) <= pkgKernel2_2_3(i, j); 
											end loop;
										end loop;
										clk_en_mul <= '1';
										cnt <= 0;
										state <= s_mult_F2;
						
								when s_mult_F2 => 
										if cnt = cnt_end_mul then 
											clk_en_mul <= '0'; 
											cnt <= 0; 
											state <= s_red1_F2; 
										else 
											cnt <= cnt + 1; 
										end if;
						
								
								when s_red1_F2 => 
										clk_en_add <= '1';
										for i in 0 to 3 loop
											dataa_add1(i) <= result_mult1(2*i); 
											datab_add1(i) <= result_mult1(2*i+1);
											dataa_add2(i) <= result_mult2(2*i);
											datab_add2(i) <= result_mult2(2*i+1);
											dataa_add3(i) <= result_mult3(2*i); 
											datab_add3(i) <= result_mult3(2*i+1);
										end loop;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											reg_m1_8_out1 <= result_mult1(8);
											reg_m2_8_out1 <= result_mult2(8);
											reg_m3_8_out1 <= result_mult3(8);
											state <= s_red2_F2; 
										else
											cnt <= cnt + 1;
										end if;
						
								when s_red2_F2 => 
										for i in 0 to 1 loop
											dataa_add1(i) <= result_add1(2*i); 
											datab_add1(i) <= result_add1(2*i+1);
											dataa_add2(i) <= result_add2(2*i);
											datab_add2(i) <= result_add2(2*i+1);
											dataa_add3(i) <= result_add3(2*i);
											datab_add3(i) <= result_add3(2*i+1);
										end loop;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											state <= s_red3_F2; 
										else 
											cnt <= cnt + 1; 
										end if;
						
								when s_red3_F2 => 
										dataa_add1(0) <= result_add1(0);
										datab_add1(0) <= result_add1(1);
										dataa_add2(0) <= result_add2(0); 
										datab_add2(0) <= result_add2(1);
										dataa_add3(0) <= result_add3(0);
										datab_add3(0) <= result_add3(1);
										if cnt = cnt_end_add then 
											cnt <= 0; 
											state <= s_red4_F2; 
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red4_F2 => 
										dataa_add1(0) <= result_add1(0); 
										datab_add1(0) <= reg_m1_8_out1;
										dataa_add2(0) <= result_add2(0);
										datab_add2(0) <= reg_m2_8_out1;
										dataa_add3(0) <= result_add3(0); 
										datab_add3(0) <= reg_m3_8_out1;
										if cnt = cnt_end_add then 
											cnt <= 0;
											sum_ch1 <= result_add1(0);
											sum_ch2 <= result_add2(0);
											sum_ch3 <= result_add3(0);
											state <= s_red5_F2; 
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red5_F2 => 
										dataa_add1(0) <= sum_ch1;
										datab_add1(0) <= sum_ch2;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											sum_ch1_ch2 <= result_add1(0); 
											state <= s_red6_F2; 
										else 
											cnt <= cnt + 1; 
										end if;
						
								when s_red6_F2 => 
											dataa_add1(0) <= sum_ch1_ch2;
											datab_add1(0) <= sum_ch3;
										if cnt = cnt_end_add then 
											clk_en_add <= '0';
											cnt <= 0; 
											state <= s_write_F2;
										else 
											cnt <= cnt + 1;
										end if;
		
								when s_write_F2 =>
										ram_fmap2_2_we <= '1';
										ram_fmap2_2_wr_addr <= std_logic_vector(to_unsigned(row_idx_conv2 * 24 + col_idx_conv2, 10));
										ram_fmap2_2_data_in <= result_add1(0);
										state <= s_wait_write_F2;
						
								when s_wait_write_F2 =>
										if cnt = 0 then 
											cnt <= 1;
										else 
											cnt <= 0; 
											ram_fmap2_2_we <= '0';
											state <= s_setup_F3;
										end if;
							

								when s_setup_F3 =>
										for i in 0 to 2 loop
											for j in 0 to 2 loop
												datab_mult1(i*3 + j) <= pkgKernel2_3_1(i, j); 
												datab_mult2(i*3 + j) <= pkgKernel2_3_2(i, j); 
												datab_mult3(i*3 + j) <= pkgKernel2_3_3(i, j); 
											end loop;
										end loop;
										clk_en_mul <= '1';
										cnt <= 0;
										state <= s_mult_F3;
						
								when s_mult_F3 => 
										if cnt = cnt_end_mul then 
											clk_en_mul <= '0'; 
											cnt <= 0; 
											state <= s_red1_F3; 
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red1_F3 => 
										clk_en_add <= '1';
										for i in 0 to 3 loop
											dataa_add1(i) <= result_mult1(2*i);
											datab_add1(i) <= result_mult1(2*i+1);
											dataa_add2(i) <= result_mult2(2*i);
											datab_add2(i) <= result_mult2(2*i+1);
											dataa_add3(i) <= result_mult3(2*i);
											datab_add3(i) <= result_mult3(2*i+1);
										end loop;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											state <= s_red2_F3;
											reg_m1_8_out1 <= result_mult1(8);
											reg_m2_8_out1 <= result_mult2(8);
											reg_m3_8_out1 <= result_mult3(8);
										else 
											cnt <= cnt + 1; 
										end if;
						
								when s_red2_F3 => 
										for i in 0 to 1 loop
											dataa_add1(i) <= result_add1(2*i);
											datab_add1(i) <= result_add1(2*i+1);
											dataa_add2(i) <= result_add2(2*i);
											datab_add2(i) <= result_add2(2*i+1);
											dataa_add3(i) <= result_add3(2*i);
											datab_add3(i) <= result_add3(2*i+1);
										end loop;
										if cnt = cnt_end_add then
											cnt <= 0; 
											state <= s_red3_F3;
										else 
											cnt <= cnt + 1; 
										end if;
						
								when s_red3_F3 => 
										dataa_add1(0) <= result_add1(0);
										datab_add1(0) <= result_add1(1);
										dataa_add2(0) <= result_add2(0); 
										datab_add2(0) <= result_add2(1);
										dataa_add3(0) <= result_add3(0); 
										datab_add3(0) <= result_add3(1);
										if cnt = cnt_end_add then 
											cnt <= 0;
											state <= s_red4_F3; 
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red4_F3 => 
										dataa_add1(0) <= result_add1(0); 
										datab_add1(0) <= reg_m1_8_out1;
										dataa_add2(0) <= result_add2(0); 
										datab_add2(0) <= reg_m2_8_out1;
										dataa_add3(0) <= result_add3(0); 
										datab_add3(0) <= reg_m3_8_out1;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											sum_ch1 <= result_add1(0); 
											sum_ch2 <= result_add2(0); 
											sum_ch3 <= result_add3(0);
											state <= s_red5_F3; 
										else
											cnt <= cnt + 1; 
										end if;
						
								when s_red5_F3 => 
											dataa_add1(0) <= sum_ch1; 
											datab_add1(0) <= sum_ch2;
										if cnt = cnt_end_add then 
											cnt <= 0;
											sum_ch1_ch2 <= result_add1(0); 
											state <= s_red6_F3; 
										else 
											cnt <= cnt + 1; 
										end if;
						
								when s_red6_F3 => 
										dataa_add1(0) <= sum_ch1_ch2;
										datab_add1(0) <= sum_ch3;
										if cnt = cnt_end_add then 
											clk_en_add <= '0';
											cnt <= 0; 
											state <= s_write_F3;
										else 
											cnt <= cnt + 1;
										end if;
						
							
								when s_write_F3 =>
										ram_fmap2_3_we <= '1';
										ram_fmap2_3_wr_addr <= std_logic_vector(to_unsigned(row_idx_conv2 * 24 + col_idx_conv2, 10));
										ram_fmap2_3_data_in <= result_add1(0);
										state <= s_wait_write_F3;
						
								when s_wait_write_F3 =>
										if cnt = 0 then 
											cnt <= 1;
										else 
											cnt <= 0; ram_fmap2_3_we <= '0'; 
											state <= s_slide;
										end if;
						
						

								when s_slide =>
									data_counter <= 0;
										if col_idx_conv2 < (FM2_MATRIX_S - 1) then
											col_idx_conv2 <= col_idx_conv2 + 1;
											state <= s_read_ram;
										else
											col_idx_conv2 <= 0;
											if row_idx_conv2 < (FM2_MATRIX_S - 1) then
												row_idx_conv2 <= row_idx_conv2 + 1;
												state <= s_read_ram;
											else
												state <= s_finish;
											end if;
										end if;
						
								when s_finish =>
										layer_state <= LRELU2;
										state <= s_idle;
						
								when others =>
										null;
							end case;
---------------------------------------------------LRELU2----------------------------------------------------------------------
					when LRELU2 =>
					
						case (lrelu_state) is
								
								when s_idle =>
									clk_en_mul <= '0';
									row_idx_lrelu2 <= 0;
									col_idx_lrelu2 <= 0;
									cnt <= 0;
									relu_control1 <= false;
									relu_control2 <= false;
									relu_control3 <= false;
									data_counter <= 0;
									ram_fmap2_1_we <= '0';
									ram_fmap2_2_we <= '0';
									ram_fmap2_3_we <= '0';
									
									lrelu_state <= s_set_addr;
					
								when s_set_addr =>
							
									ram_fmap2_1_rd_addr <= std_logic_vector(to_unsigned(row_idx_lrelu2 * 24 + col_idx_lrelu2, 10));
									ram_fmap2_2_rd_addr <= std_logic_vector(to_unsigned(row_idx_lrelu2 * 24 + col_idx_lrelu2, 10));
									ram_fmap2_3_rd_addr <= std_logic_vector(to_unsigned(row_idx_lrelu2 * 24 + col_idx_lrelu2, 10));
									
									lrelu_state <= s_wait_ram;
						
								when s_wait_ram =>
									
									if cnt = 2 then
										cnt <= 0;
										lrelu_state <= s_check_sign;
									else
										cnt <= cnt + 1;
									end if;
				
								when s_check_sign =>
									clk_en_mul <= '1';
									cnt <= 0;
									
					
									if ram_fmap2_1_q_out(31) = '1' then 
										dataa_mult1(0) <= ram_fmap2_1_q_out; 
										datab_mult1(0) <= x"3c23d70a"; 
										relu_control1 <= true; 
									else 
										relu_control1 <= false; 
									end if;
						
								
									if ram_fmap2_2_q_out(31) = '1' then
										dataa_mult2(0) <= ram_fmap2_2_q_out;
										datab_mult2(0) <= x"3c23d70a";
										relu_control2 <= true;
									else 
										relu_control2 <= false;
									end if;
						
								
									if ram_fmap2_3_q_out(31) = '1' then
										dataa_mult3(0) <= ram_fmap2_3_q_out;
										datab_mult3(0) <= x"3c23d70a";
										relu_control3 <= true;
									else 
										relu_control3 <= false;
									end if;
									lrelu_state <= s_mult_wait; 
						
								when s_mult_wait =>
					
									if (relu_control1 = false and relu_control2 = false and relu_control3 = false) then
										clk_en_mul <= '0';
										lrelu_state <= s_write_finish; 
									else
									
										if cnt = cnt_end_mul then
												clk_en_mul <= '0';
												cnt <= 0;
												lrelu_state <= s_write_back;
										else
												cnt <= cnt + 1;
										end if;
									end if;
						
								when s_write_back =>
								
									ram_fmap2_1_wr_addr <= std_logic_vector(to_unsigned(row_idx_lrelu2 * 24 + col_idx_lrelu2, 10));
									ram_fmap2_2_wr_addr <= std_logic_vector(to_unsigned(row_idx_lrelu2 * 24 + col_idx_lrelu2, 10));
									ram_fmap2_3_wr_addr <= std_logic_vector(to_unsigned(row_idx_lrelu2 * 24 + col_idx_lrelu2, 10));
						
									
									if relu_control1 then
										ram_fmap2_1_data_in <= result_mult1(0); 
										ram_fmap2_1_we <= '1';                 
									end if;
						
									if relu_control2 then
										ram_fmap2_2_data_in <= result_mult2(0);
										ram_fmap2_2_we <= '1';
									end if;
						
									if relu_control3 then
										ram_fmap2_3_data_in <= result_mult3(0);
										ram_fmap2_3_we <= '1';
									end if;
						
									lrelu_state <= s_write_finish;
						
					
								when s_write_finish =>
									ram_fmap2_1_we <= '0';
									ram_fmap2_2_we <= '0';
									ram_fmap2_3_we <= '0';
									
									
									if col_idx_lrelu2 = (FM2_MATRIX_S-1) and row_idx_lrelu2 = (FM2_MATRIX_S-1) then
										lrelu_state <= s_finishRelu;
									else
										lrelu_state <= s_increaseIndex;
									end if;
						
						
								when s_increaseIndex =>
									if col_idx_lrelu2 < (FM2_MATRIX_S-1) then
										col_idx_lrelu2 <= col_idx_lrelu2 + 1;
									else
										col_idx_lrelu2 <= 0;
										row_idx_lrelu2 <= row_idx_lrelu2 + 1;
									end if;
									lrelu_state <= s_set_addr; 
						
							
								when s_finishRelu =>
									
									layer_state <= MAXPOOL1;
									state <= s_idle;
									lrelu_state <= s_idle;
								when others =>
									state <= s_idle;
						end case;
------------------------------------------------------MAXPOOL1-----------------------------------------------------------------
					when MAXPOOL1 =>
					
						case (maxpool_state) is
							when s_idle =>
								row_idx_maxpool1 <= 0;
								col_idx_maxpool1 <= 0;
					
								clk_en_compare <= '0';
								cnt <= 0;
								data_counter <= 0;
								ram_maxpool1_1_we <= '0';
								ram_maxpool2_1_we <= '0';
								ram_maxpool3_1_we <= '0';
								maxpool_state <= s_set_addr;
							when s_set_addr =>
									case data_counter is
									
									when 0 => 
										ram_fmap2_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool1 *2 + 0) * 24 + (col_idx_maxpool1 *2 + 0), 10)); --fmap1_1in ilk penceresinin 1. pixeli
										ram_fmap2_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool1 *2 + 0) * 24 + (col_idx_maxpool1 *2 + 0), 10));
										ram_fmap2_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool1 *2 + 0) * 24 + (col_idx_maxpool1 *2 + 0), 10));
									when 1 =>                                                                                                   
										ram_fmap2_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool1 *2 + 0) * 24 + (col_idx_maxpool1 *2 + 1), 10)); --2. pixeli...
										ram_fmap2_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool1 *2 + 0) * 24 + (col_idx_maxpool1 *2 + 1), 10));
										ram_fmap2_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool1 *2 + 0) * 24 + (col_idx_maxpool1 *2 + 1), 10));
									when 2 =>                                                                                                   
										ram_fmap2_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool1 *2 + 1) * 24 + (col_idx_maxpool1 *2 + 0), 10)); --3.
										ram_fmap2_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool1 *2 + 1) * 24 + (col_idx_maxpool1 *2 + 0), 10));
										ram_fmap2_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool1 *2 + 1) * 24 + (col_idx_maxpool1 *2 + 0), 10));
									when 3 =>                                                                                                   
										ram_fmap2_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool1 *2 + 1) * 24 + (col_idx_maxpool1 *2 + 1), 10)); --4.
										ram_fmap2_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool1 *2 + 1) * 24 + (col_idx_maxpool1 *2 + 1), 10));
										ram_fmap2_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool1 *2 + 1) * 24 + (col_idx_maxpool1 *2 + 1), 10));
									when others => null;
									end case;
										maxpool_state <= s_wait_ram;
									
							
							when s_wait_ram =>
									if cnt = 2 then
										cnt <= 0;
										maxpool_state <= s_compare1;
									else
										cnt <= cnt + 1;
									end if;
							
									
							when s_compare1 =>                --featureMap[row*poolKernelWidth+i , col*poolKernelWidth+j] 
																					        --       2     + i ve jler manuel
								clk_en_compare <= '0';
								
									case data_counter is
										when 0 =>
											dataa_compare1(0) <= ram_fmap2_1_q_out;
											dataa_compare2(0) <= ram_fmap2_2_q_out;
											dataa_compare3(0) <= ram_fmap2_3_q_out;
										when 1 =>
											datab_compare1(0) <= ram_fmap2_1_q_out;
											datab_compare2(0) <= ram_fmap2_2_q_out;
											datab_compare3(0) <= ram_fmap2_3_q_out;
										when 2 =>
											dataa_compare1(1) <= ram_fmap2_1_q_out;
											dataa_compare2(1) <= ram_fmap2_2_q_out;
											dataa_compare3(1) <= ram_fmap2_3_q_out;
										when 3 =>
											datab_compare1(1) <= ram_fmap2_1_q_out;
											datab_compare2(1) <= ram_fmap2_2_q_out;
											datab_compare3(1) <= ram_fmap2_3_q_out;
										when others => null;
									end case;
									if data_counter = 3 then
										cnt <= 0;
										clk_en_compare <= '1';
										maxpool_state <= s_waitCompare;
									else 
										data_counter <= data_counter + 1;
										maxpool_state <= s_set_addr;
									end if;
									
							when s_waitCompare =>
								if cnt = cnt_end_compare then
									clk_en_compare <= '0';
									cnt <= 0;
									maxpool_state <= s_writeTemps;
								else
									cnt <= cnt + 1;
								end if;
								
							when s_writeTemps =>
								cnt <= 0;

								if agb_compare1(0) = '1' then --a>b durumu
									reg_tempMax1_1 <= dataa_compare1(0);
								else
									reg_tempMax1_1 <= datab_compare1(0);
								end if;
								
								if agb_compare1(1) = '1' then --a>b durumu
									reg_tempMax1_2 <= dataa_compare1(1);
								else 
									reg_tempMax1_2 <= datab_compare1(1);
								end if;
								
								if agb_compare2(0) = '1' then --a>b durumu
									reg_tempMax2_1 <= dataa_compare2(0);
								else                 
									reg_tempMax2_1 <= datab_compare2(0);
								end if;
								
								if agb_compare2(1) = '1' then --a>b durumu
									reg_tempMax2_2 <= dataa_compare2(1);
								else                 
									reg_tempMax2_2 <= datab_compare2(1);
								end if;
								
								if agb_compare3(0) = '1' then --a>b durumu
									reg_tempMax3_1 <= dataa_compare3(0);
								else                 
									reg_tempMax3_1 <= datab_compare3(0);
								end if;
								
								if agb_compare3(1) = '1' then --a>b durumu
									reg_tempMax3_2 <= dataa_compare3(1);
								else                 
									reg_tempMax3_2 <= datab_compare3(1);
								end if;

								maxpool_state <= s_compare2;
								
							when s_compare2 =>
								clk_en_compare <= '1';
								if cnt = 0 then
									dataa_compare1(0) <= reg_tempMax1_1;  
									datab_compare1(0) <= reg_tempMax1_2;

									dataa_compare2(0) <= reg_tempMax2_1;
									datab_compare2(0) <= reg_tempMax2_2;

									dataa_compare3(0) <= reg_tempMax3_1;
									datab_compare3(0) <= reg_tempMax3_2;
								end if;
								
								if cnt = cnt_end_compare then
									clk_en_compare <= '0';
									cnt <= 0;
									maxpool_state <= s_writeGreater;
								else
									cnt <= cnt + 1;
								end if;
					
								
							
								
							when s_writeGreater =>
								ram_maxpool1_1_we <= '1';
								ram_maxpool2_1_we <= '1';
								ram_maxpool3_1_we <= '1';
								cnt <= 0;
								ram_maxpool1_1_wr_addr <= std_logic_vector(to_unsigned(row_idx_maxpool1 * 12 + col_idx_maxpool1, 10));
								ram_maxpool2_1_wr_addr <= std_logic_vector(to_unsigned(row_idx_maxpool1 * 12 + col_idx_maxpool1, 10));
								ram_maxpool3_1_wr_addr <= std_logic_vector(to_unsigned(row_idx_maxpool1 * 12 + col_idx_maxpool1, 10));
								if agb_compare1(0) = '1' then -- a>b durumu
									ram_maxpool1_1_data_in <= reg_tempMax1_1;
								else
									ram_maxpool1_1_data_in <= reg_tempMax1_2;
								end if;
								
								if agb_compare2(0) = '1' then -- a>b durumu
									ram_maxpool2_1_data_in <= reg_tempMax2_1;
								else
									ram_maxpool2_1_data_in <= reg_tempMax2_2;
								end if;
								
								if agb_compare3(0) = '1' then -- a>b durumu
									ram_maxpool3_1_data_in <= reg_tempMax3_1;
								else
									ram_maxpool3_1_data_in <= reg_tempMax3_2;
								end if;
								maxpool_state <= s_write_wait;
								
								
							when s_write_wait =>
								if cnt = 0 then
									cnt <= 1;
								elsif cnt = 1 then
									ram_maxpool1_1_we <= '0';
									ram_maxpool2_1_we <= '0';
									ram_maxpool3_1_we <= '0';
									cnt <= 0; 
									if col_idx_maxpool1 = (POOL1_MATRIX_S -1) and row_idx_maxpool1 = (POOL1_MATRIX_S-1) then --son elemanda yazmadan burası yüzünden finishe gitme durumu olabilir ona simde bak
										maxpool_state <= s_finishMaxpool;
									else
										maxpool_state <= s_slide;
									end if;
								end if;
							when s_slide =>
								cnt <= 0;
								data_counter <= 0;
								if col_idx_maxpool1 < (POOL1_MATRIX_S-1) then --11 olcak
									col_idx_maxpool1 <= (col_idx_maxpool1 + 1); --12 olcak daha da koşula girmicek
								
								else
									col_idx_maxpool1 <= 0;
									row_idx_maxpool1 <= (row_idx_maxpool1 + 1);
								
								end if;
								maxpool_state <= s_set_addr;
								
							when s_finishMaxpool =>
								if cnt = 0 then
									cnt <= 1;
								elsif cnt = 1 then
									clk_en_compare <= '0';
									cnt <= 0;
									layer_state <= CONV3;
									state <= s_idle;
									lrelu_state <= s_idle;
									maxpool_state <= s_idle;
								end if;
							when others => null;
						end case;
---------------------------------------------------------1. aşama sonu--------------------------------------------------------------------------
------------------------------------------------------------CONV3-------------------------------------------------------------------------------
						when CONV3 =>
							
							case (state) is
						
								when s_idle =>
									
										clk_en_mul <= '0';
										clk_en_add <= '0'; 
										data_counter <= 0;
										cnt <= 0;	
										state <= s_read_ram;
						
								when s_read_ram =>
									
										case data_counter is
											when 0 => 
												ram_maxpool1_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 0) * 12 + (col_idx_conv3 + 0), 10));
												ram_maxpool2_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 0) * 12 + (col_idx_conv3 + 0), 10));
												ram_maxpool3_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 0) * 12 + (col_idx_conv3 + 0), 10));
											when 1 => 
												ram_maxpool1_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 0) * 12 + (col_idx_conv3 + 1), 10));
												ram_maxpool2_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 0) * 12 + (col_idx_conv3 + 1), 10));
												ram_maxpool3_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 0) * 12 + (col_idx_conv3 + 1), 10));
											when 2 => 
												ram_maxpool1_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 0) * 12 + (col_idx_conv3 + 2), 10));
												ram_maxpool2_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 0) * 12 + (col_idx_conv3 + 2), 10));
												ram_maxpool3_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 0) * 12 + (col_idx_conv3 + 2), 10));
											when 3 => 
												ram_maxpool1_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 1) * 12 + (col_idx_conv3 + 0), 10));
												ram_maxpool2_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 1) * 12 + (col_idx_conv3 + 0), 10));
												ram_maxpool3_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 1) * 12 + (col_idx_conv3 + 0), 10));
											when 4 => 
												ram_maxpool1_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 1) * 12 + (col_idx_conv3 + 1), 10));
												ram_maxpool2_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 1) * 12 + (col_idx_conv3 + 1), 10));
												ram_maxpool3_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 1) * 12 + (col_idx_conv3 + 1), 10));
											when 5 => 
												ram_maxpool1_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 1) * 12 + (col_idx_conv3 + 2), 10));
												ram_maxpool2_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 1) * 12 + (col_idx_conv3 + 2), 10));
												ram_maxpool3_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 1) * 12 + (col_idx_conv3 + 2), 10));
											when 6 => 
												ram_maxpool1_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 2) * 12 + (col_idx_conv3 + 0), 10));
												ram_maxpool2_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 2) * 12 + (col_idx_conv3 + 0), 10));
												ram_maxpool3_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 2) * 12 + (col_idx_conv3 + 0), 10));
											when 7 => 
												ram_maxpool1_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 2) * 12 + (col_idx_conv3 + 1), 10));
												ram_maxpool2_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 2) * 12 + (col_idx_conv3 + 1), 10));
												ram_maxpool3_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 2) * 12 + (col_idx_conv3 + 1), 10));
											when 8 => 
												ram_maxpool1_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 2) * 12 + (col_idx_conv3 + 2), 10));
												ram_maxpool2_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 2) * 12 + (col_idx_conv3 + 2), 10));
												ram_maxpool3_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv3 + 2) * 12 + (col_idx_conv3 + 2), 10));
											when others => null;
										end case;
								
										state <= s_wait_data;
						
								when s_wait_data =>
										
										if cnt = 2 then 
											cnt <= 0;
											state <= s_save_data;
										else
											cnt <= cnt + 1;
										end if;
						
								when s_save_data =>
									
										dataa_mult1(data_counter) <= ram_maxpool1_1_q_out; 
										dataa_mult2(data_counter) <= ram_maxpool2_1_q_out; 
										dataa_mult3(data_counter) <= ram_maxpool3_1_q_out; 
						
										if data_counter = 8 then
											state <= s_setup_F1; 
										else
											data_counter <= data_counter + 1;
											state <= s_read_ram;
										end if;
						

								when s_setup_F1 =>
										for i in 0 to 2 loop
											for j in 0 to 2 loop
												datab_mult1(i*3 + j) <= pkgKernel3_1_1(i, j); 
												datab_mult2(i*3 + j) <= pkgKernel3_1_2(i, j); 
												datab_mult3(i*3 + j) <= pkgKernel3_1_3(i, j); 
											end loop;
										end loop;
										clk_en_mul <= '1';
										cnt <= 0;
										state <= s_mult_F1; 
						
								when s_mult_F1 => 
										if cnt = cnt_end_mul then 
											clk_en_mul <= '0'; 
											cnt <= 0; 
										
											reg_m1_8_out1 <= result_mult1(8);
											reg_m2_8_out1 <= result_mult2(8);
											reg_m3_8_out1 <= result_mult3(8);
											state <= s_red1_F1; 
										else
											cnt <= cnt + 1;
										end if;
						
								when s_red1_F1 => 
										clk_en_add <= '1';
										if cnt = 0 then
											for i in 0 to 3 loop
												dataa_add1(i) <= result_mult1(2*i);
												datab_add1(i) <= result_mult1(2*i+1);
												dataa_add2(i) <= result_mult2(2*i);
												datab_add2(i) <= result_mult2(2*i+1);
												dataa_add3(i) <= result_mult3(2*i);
												datab_add3(i) <= result_mult3(2*i+1);
											end loop;
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											state <= s_red2_F1;
										else 
											cnt <= cnt + 1; 
										end if;
						
								when s_red2_F1 => 
										if cnt = 0 then
											for i in 4 to 5 loop
												dataa_add1(i) <= result_add1(2*(i-4));
												datab_add1(i) <= result_add1(2*(i-4)+1);
												dataa_add2(i) <= result_add2(2*(i-4));
												datab_add2(i) <= result_add2(2*(i-4)+1);
												dataa_add3(i) <= result_add3(2*(i-4));
												datab_add3(i) <= result_add3(2*(i-4)+1);
											end loop;
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											state <= s_red3_F1; 
										else
											cnt <= cnt + 1;
										end if;
						
								when s_red3_F1 => 
										if cnt = 0 then
											dataa_add1(6) <= result_add1(4);
											datab_add1(6) <= result_add1(5);
											dataa_add2(6) <= result_add2(4);
											datab_add2(6) <= result_add2(5);
											dataa_add3(6) <= result_add3(4);
											datab_add3(6) <= result_add3(5);
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											state <= s_red4_F1;
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red4_F1 => 
										if cnt = 0 then
											dataa_add1(7) <= reg_m1_8_out1;
											datab_add1(7) <= result_add1(6);
											dataa_add2(7) <= reg_m2_8_out1;
											datab_add2(7) <= result_add2(6);
											dataa_add3(7) <= reg_m3_8_out1;
											datab_add3(7) <= result_add3(6);
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											sum_ch1 <= result_add1(7); 
											sum_ch2 <= result_add2(7); 
											sum_ch3 <= result_add3(7);
											state <= s_red5_F1; 
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red5_F1 => 
										if cnt = 0 then
											dataa_add1(0) <= sum_ch1; 
											datab_add1(0) <= sum_ch2;
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											sum_ch1_ch2 <= result_add1(0);
											state <= s_red6_F1; 
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red6_F1 => 
										if cnt = 0 then
											dataa_add1(0) <= sum_ch1_ch2; 
											datab_add1(0) <= sum_ch3;
										end if;
										if cnt = cnt_end_add then
											clk_en_add <= '0';
											cnt <= 0;
											state <= s_write_F1;
										else
											cnt <= cnt + 1; 
										end if;
						
								
								when s_write_F1 =>
										ram_fmap3_1_we <= '1';
										ram_fmap3_1_wr_addr <= std_logic_vector(to_unsigned(row_idx_conv3 * 10 + col_idx_conv3, 10));
										ram_fmap3_1_data_in <= result_add1(0);
										state <= s_wait_write_F1;
						
								when s_wait_write_F1 =>
										if cnt = 0 then
											cnt <= 1;
										else 
											cnt <= 0;
											ram_fmap3_1_we <= '0';
											state <= s_setup_F2;
										end if;
						
				
				
								when s_setup_F2 =>
										for i in 0 to 2 loop
											for j in 0 to 2 loop
												datab_mult1(i*3 + j) <= pkgKernel3_2_1(i, j); 
												datab_mult2(i*3 + j) <= pkgKernel3_2_2(i, j); 
												datab_mult3(i*3 + j) <= pkgKernel3_2_3(i, j); 
											end loop;
										end loop;
										clk_en_mul <= '1';
										cnt <= 0;
										state <= s_mult_F2;
						
								when s_mult_F2 => 
										if cnt = cnt_end_mul then 
											clk_en_mul <= '0'; 
											cnt <= 0; 
											state <= s_red1_F2;
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red1_F2 => 
										clk_en_add <= '1';
										if cnt = 0 then
											for i in 0 to 3 loop
												dataa_add1(i) <= result_mult1(2*i); datab_add1(i) <= result_mult1(2*i+1);
												dataa_add2(i) <= result_mult2(2*i); datab_add2(i) <= result_mult2(2*i+1);
												dataa_add3(i) <= result_mult3(2*i); datab_add3(i) <= result_mult3(2*i+1);
											end loop;
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											reg_m1_8_out1 <= result_mult1(8); 
											reg_m2_8_out1 <= result_mult2(8); 
											reg_m3_8_out1 <= result_mult3(8);
											state <= s_red2_F2; 
										else
											cnt <= cnt + 1;
										end if;
						
								when s_red2_F2 => 
										if cnt = 0 then
											for i in 0 to 1 loop
												dataa_add1(i) <= result_add1(2*i);
												datab_add1(i) <= result_add1(2*i+1);
												dataa_add2(i) <= result_add2(2*i);
												datab_add2(i) <= result_add2(2*i+1);
												dataa_add3(i) <= result_add3(2*i);
												datab_add3(i) <= result_add3(2*i+1);
											end loop;
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											state <= s_red3_F2; 
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red3_F2 => 
										if cnt = 0 then
											dataa_add1(0) <= result_add1(0);
											datab_add1(0) <= result_add1(1);
											dataa_add2(0) <= result_add2(0);
											datab_add2(0) <= result_add2(1);
											dataa_add3(0) <= result_add3(0);
											datab_add3(0) <= result_add3(1);
										end if;
										if cnt = cnt_end_add then
											cnt <= 0;
											state <= s_red4_F2; 
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red4_F2 => 
										if cnt = 0 then
											dataa_add1(0) <= result_add1(0);
											datab_add1(0) <= reg_m1_8_out1;
											dataa_add2(0) <= result_add2(0);
											datab_add2(0) <= reg_m2_8_out1;
											dataa_add3(0) <= result_add3(0);
											datab_add3(0) <= reg_m3_8_out1;
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0;
											sum_ch1 <= result_add1(0);
											sum_ch2 <= result_add2(0); 
											sum_ch3 <= result_add3(0);
											state <= s_red5_F2; 
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red5_F2 => 
										if cnt = 0 then
											dataa_add1(0) <= sum_ch1;
											datab_add1(0) <= sum_ch2;
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0;
											sum_ch1_ch2 <= result_add1(0);
											state <= s_red6_F2; 
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red6_F2 => 
										if cnt = 0 then
											dataa_add1(0) <= sum_ch1_ch2;
											datab_add1(0) <= sum_ch3;
										end if;
										if cnt = cnt_end_add then
											clk_en_add <= '0'; 
											cnt <= 0;
											state <= s_write_F2;
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_write_F2 =>
										ram_fmap3_2_we <= '1';
										ram_fmap3_2_wr_addr <= std_logic_vector(to_unsigned(row_idx_conv3 * 10 + col_idx_conv3, 10));
										ram_fmap3_2_data_in <= result_add1(0);
										state <= s_wait_write_F2;
						
								when s_wait_write_F2 =>
										if cnt = 0 then
											cnt <= 1;
										else 
											cnt <= 0; 
											ram_fmap3_2_we <= '0';
											state <= s_setup_F3;
										end if;
						
	
								when s_setup_F3 =>
										for i in 0 to 2 loop
											for j in 0 to 2 loop
												datab_mult1(i*3 + j) <= pkgKernel3_3_1(i, j); 
												datab_mult2(i*3 + j) <= pkgKernel3_3_2(i, j); 
												datab_mult3(i*3 + j) <= pkgKernel3_3_3(i, j); 
											end loop;
										end loop;
										clk_en_mul <= '1';
										cnt <= 0;
										state <= s_mult_F3;
						
								when s_mult_F3 => 
										if cnt = cnt_end_mul then
											clk_en_mul <= '0';
											cnt <= 0;
											state <= s_red1_F3; 
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red1_F3 => 
										clk_en_add <= '1';
										if cnt = 0 then
											for i in 0 to 3 loop
												dataa_add1(i) <= result_mult1(2*i);
												datab_add1(i) <= result_mult1(2*i+1);
												dataa_add2(i) <= result_mult2(2*i);
												datab_add2(i) <= result_mult2(2*i+1);
												dataa_add3(i) <= result_mult3(2*i);
												datab_add3(i) <= result_mult3(2*i+1);
											end loop;
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											state <= s_red2_F3;
											reg_m1_8_out1 <= result_mult1(8); 
											reg_m2_8_out1 <= result_mult2(8); 
											reg_m3_8_out1 <= result_mult3(8);
										else 
											cnt <= cnt + 1; 
										end if;
						
								when s_red2_F3 => 
										if cnt = 0 then
											for i in 0 to 1 loop
												dataa_add1(i) <= result_add1(2*i);
												datab_add1(i) <= result_add1(2*i+1);
												dataa_add2(i) <= result_add2(2*i);
												datab_add2(i) <= result_add2(2*i+1);
												dataa_add3(i) <= result_add3(2*i);
												datab_add3(i) <= result_add3(2*i+1);
											end loop;
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0;
											state <= s_red3_F3;
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red3_F3 => 
										if cnt = 0 then
											dataa_add1(0) <= result_add1(0);
											datab_add1(0) <= result_add1(1);
											dataa_add2(0) <= result_add2(0); 
											datab_add2(0) <= result_add2(1);
											dataa_add3(0) <= result_add3(0);
											datab_add3(0) <= result_add3(1);
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											state <= s_red4_F3;
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red4_F3 => 
										if cnt = 0 then
											dataa_add1(0) <= result_add1(0);
											datab_add1(0) <= reg_m1_8_out1;
											dataa_add2(0) <= result_add2(0);
											datab_add2(0) <= reg_m2_8_out1;
											dataa_add3(0) <= result_add3(0);
											datab_add3(0) <= reg_m3_8_out1;
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0;
											sum_ch1 <= result_add1(0);
											sum_ch2 <= result_add2(0);
											sum_ch3 <= result_add3(0);
											state <= s_red5_F3; 
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red5_F3 => 
										if cnt = 0 then
											dataa_add1(0) <= sum_ch1;
											datab_add1(0) <= sum_ch2;
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0;
											sum_ch1_ch2 <= result_add1(0); 
											state <= s_red6_F3;
										else
											cnt <= cnt + 1;
										end if;
						
								when s_red6_F3 => 
										if cnt = 0 then
											dataa_add1(0) <= sum_ch1_ch2; 
											datab_add1(0) <= sum_ch3;
										end if;
										if cnt = cnt_end_add then 
											clk_en_add <= '0';
											cnt <= 0;
											state <= s_write_F3;
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_write_F3 =>
										ram_fmap3_3_we <= '1';
										ram_fmap3_3_wr_addr <= std_logic_vector(to_unsigned(row_idx_conv3 * 10 + col_idx_conv3, 10));
										ram_fmap3_3_data_in <= result_add1(0);
										state <= s_wait_write_F3;
						
								when s_wait_write_F3 =>
										if cnt = 0 then 
											cnt <= 1; 
										else 
											cnt <= 0;
											ram_fmap3_3_we <= '0'; 
											state <= s_slide;
										end if;
						
								when s_slide =>
										data_counter <= 0;
										if col_idx_conv3 < (FM3_MATRIX_S - 1) then
											col_idx_conv3 <= col_idx_conv3 + 1;
											state <= s_read_ram;
										else
											col_idx_conv3 <= 0;
											if row_idx_conv3 < (FM3_MATRIX_S - 1) then
												row_idx_conv3 <= row_idx_conv3 + 1;
												state <= s_read_ram;
											else
												state <= s_finish;
											end if;
										end if;
						
								when s_finish =>
										layer_state <= LRELU3;
										state <= s_idle;
						
								when others => null;
							end case;
---------------------------------------------------LRELU3----------------------------------------------------------------------
					when LRELU3 =>
				
						case (lrelu_state) is
								
								when s_idle =>
									clk_en_mul <= '0';
									row_idx_lrelu3 <= 0;
									col_idx_lrelu3 <= 0;
									cnt <= 0;
									relu_control1 <= false;
									relu_control2 <= false;
									relu_control3 <= false;
									data_counter <= 0;
									ram_fmap3_1_we <= '0';
									ram_fmap3_2_we <= '0';
									ram_fmap3_3_we <= '0';
									
									lrelu_state <= s_set_addr;
					
								when s_set_addr =>
				
									ram_fmap3_1_rd_addr <= std_logic_vector(to_unsigned(row_idx_lrelu3 * 10 + col_idx_lrelu3, 10));
									ram_fmap3_2_rd_addr <= std_logic_vector(to_unsigned(row_idx_lrelu3 * 10 + col_idx_lrelu3, 10));
									ram_fmap3_3_rd_addr <= std_logic_vector(to_unsigned(row_idx_lrelu3 * 10 + col_idx_lrelu3, 10));
									
									lrelu_state <= s_wait_ram;
						
							
								when s_wait_ram =>
									if cnt = 2 then
										cnt <= 0;
										lrelu_state <= s_check_sign;
									else
										cnt <= cnt + 1;
									end if;
								
				
								when s_check_sign =>
									clk_en_mul <= '1';
									cnt <= 0;
									
					
									if ram_fmap3_1_q_out(31) = '1' then 
										dataa_mult1(0) <= ram_fmap3_1_q_out; 
										datab_mult1(0) <= x"3c23d70a"; 
										relu_control1 <= true; 
									else 
										relu_control1 <= false; 
									end if;
						
								
									if ram_fmap3_2_q_out(31) = '1' then
										dataa_mult2(0) <= ram_fmap3_2_q_out;
										datab_mult2(0) <= x"3c23d70a";
										relu_control2 <= true;
									else 
										relu_control2 <= false;
									end if;
						
								
									if ram_fmap3_3_q_out(31) = '1' then
										dataa_mult3(0) <= ram_fmap3_3_q_out;
										datab_mult3(0) <= x"3c23d70a";
										relu_control3 <= true;
									else 
										relu_control3 <= false;
									end if;
									lrelu_state <= s_mult_wait; 
						
								when s_mult_wait =>
					
									if (relu_control1 = false and relu_control2 = false and relu_control3 = false) then
										clk_en_mul <= '0';
										lrelu_state <= s_write_finish; 
									else
									
										if cnt = cnt_end_mul then
												clk_en_mul <= '0';
												cnt <= 0;
												lrelu_state <= s_write_back;
										else
												cnt <= cnt + 1;
										end if;
									end if;
						
								when s_write_back =>
								
									ram_fmap3_1_wr_addr <= std_logic_vector(to_unsigned(row_idx_lrelu3 * 10 + col_idx_lrelu3, 10));
									ram_fmap3_2_wr_addr <= std_logic_vector(to_unsigned(row_idx_lrelu3 * 10 + col_idx_lrelu3, 10));
									ram_fmap3_3_wr_addr <= std_logic_vector(to_unsigned(row_idx_lrelu3 * 10 + col_idx_lrelu3, 10));
						
									
									if relu_control1 then
										ram_fmap3_1_data_in <= result_mult1(0); 
										ram_fmap3_1_we <= '1';                 
									end if;
						
									if relu_control2 then
										ram_fmap3_2_data_in <= result_mult2(0);
										ram_fmap3_2_we <= '1';
									end if;
						
									if relu_control3 then
										ram_fmap3_3_data_in <= result_mult3(0);
										ram_fmap3_3_we <= '1';
									end if;
						
									lrelu_state <= s_write_finish;
						
					
								when s_write_finish =>
									ram_fmap3_1_we <= '0';
									ram_fmap3_2_we <= '0';
									ram_fmap3_3_we <= '0';
									
									
									if col_idx_lrelu3 = (FM3_MATRIX_S-1) and row_idx_lrelu3 = (FM3_MATRIX_S-1) then
										lrelu_state <= s_finishRelu;
									else
										lrelu_state <= s_increaseIndex;
									end if;
						
						
								when s_increaseIndex =>
									if col_idx_lrelu3 < (FM3_MATRIX_S-1) then
										col_idx_lrelu3 <= col_idx_lrelu3 + 1;
									else
										col_idx_lrelu3 <= 0;
										row_idx_lrelu3 <= row_idx_lrelu3 + 1;
									end if;
									lrelu_state <= s_set_addr; 
						
							
								when s_finishRelu =>
									
									layer_state <= CONV4;
									state <= s_idle;
									lrelu_state <= s_idle;
								when others =>
									state <= s_idle;
						end case;
------------------------------------------------------------CONV4-------------------------------------------------------------------------------
						when CONV4 =>
						
							case (state) is
						
								when s_idle =>
										clk_en_mul <= '0';
										clk_en_add <= '0'; 
										data_counter <= 0;
										cnt <= 0;
										state <= s_read_ram;
						
								when s_read_ram =>
									
										case data_counter is
											when 0 => 
												ram_fmap3_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 0) * 10 + (col_idx_conv4 + 0), 10));
												ram_fmap3_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 0) * 10 + (col_idx_conv4 + 0), 10));
												ram_fmap3_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 0) * 10 + (col_idx_conv4 + 0), 10));
											when 1 => 
												ram_fmap3_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 0) * 10 + (col_idx_conv4 + 1), 10));
												ram_fmap3_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 0) * 10 + (col_idx_conv4 + 1), 10));
												ram_fmap3_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 0) * 10 + (col_idx_conv4 + 1), 10));
											when 2 => 
												ram_fmap3_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 0) * 10 + (col_idx_conv4 + 2), 10));
												ram_fmap3_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 0) * 10 + (col_idx_conv4 + 2), 10));
												ram_fmap3_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 0) * 10 + (col_idx_conv4 + 2), 10));
											when 3 => 
												ram_fmap3_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 1) * 10 + (col_idx_conv4 + 0), 10));
												ram_fmap3_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 1) * 10 + (col_idx_conv4 + 0), 10));
												ram_fmap3_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 1) * 10 + (col_idx_conv4 + 0), 10));
											when 4 => 
												ram_fmap3_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 1) * 10 + (col_idx_conv4 + 1), 10));
												ram_fmap3_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 1) * 10 + (col_idx_conv4 + 1), 10));
												ram_fmap3_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 1) * 10 + (col_idx_conv4 + 1), 10));
											when 5 => 
												ram_fmap3_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 1) * 10 + (col_idx_conv4 + 2), 10));
												ram_fmap3_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 1) * 10 + (col_idx_conv4 + 2), 10));
												ram_fmap3_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 1) * 10 + (col_idx_conv4 + 2), 10));
											when 6 => 
												ram_fmap3_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 2) * 10 + (col_idx_conv4 + 0), 10));
												ram_fmap3_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 2) * 10 + (col_idx_conv4 + 0), 10));
												ram_fmap3_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 2) * 10 + (col_idx_conv4 + 0), 10));
											when 7 => 
												ram_fmap3_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 2) * 10 + (col_idx_conv4 + 1), 10));
												ram_fmap3_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 2) * 10 + (col_idx_conv4 + 1), 10));
												ram_fmap3_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 2) * 10 + (col_idx_conv4 + 1), 10));
											when 8 => 
												ram_fmap3_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 2) * 10 + (col_idx_conv4 + 2), 10));
												ram_fmap3_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 2) * 10 + (col_idx_conv4 + 2), 10));
												ram_fmap3_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_conv4 + 2) * 10 + (col_idx_conv4 + 2), 10));
											when others => null;
										end case;
										state <= s_wait_data;
						
								when s_wait_data =>
										if cnt = 2 then 
											cnt <= 0;
											state <= s_save_data;
										else
											cnt <= cnt + 1;
										end if;
						
								when s_save_data =>
										dataa_mult1(data_counter) <= ram_fmap3_1_q_out; 
										dataa_mult2(data_counter) <= ram_fmap3_2_q_out; 
										dataa_mult3(data_counter) <= ram_fmap3_3_q_out; 
						
										if data_counter = 8 then
											state <= s_setup_F1; 
										else
											data_counter <= data_counter + 1;
											state <= s_read_ram;
										end if;
						
								when s_setup_F1 =>
										for i in 0 to 2 loop
											for j in 0 to 2 loop
												datab_mult1(i*3 + j) <= pkgKernel4_1_1(i, j); 
												datab_mult2(i*3 + j) <= pkgKernel4_1_2(i, j); 
												datab_mult3(i*3 + j) <= pkgKernel4_1_3(i, j); 
											end loop;
										end loop;
										clk_en_mul <= '1';
										cnt <= 0;
										state <= s_mult_F1; 
						
								when s_mult_F1 => 
										if cnt = cnt_end_mul then 
											clk_en_mul <= '0'; 
											cnt <= 0; 
											reg_m1_8_out1 <= result_mult1(8);
											reg_m2_8_out1 <= result_mult2(8);
											reg_m3_8_out1 <= result_mult3(8);
											state <= s_red1_F1; 
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red1_F1 => 
										clk_en_add <= '1';
										if cnt = 0 then
											for i in 0 to 3 loop
												dataa_add1(i) <= result_mult1(2*i); 
												datab_add1(i) <= result_mult1(2*i+1);
												dataa_add2(i) <= result_mult2(2*i); 
												datab_add2(i) <= result_mult2(2*i+1);
												dataa_add3(i) <= result_mult3(2*i);
												datab_add3(i) <= result_mult3(2*i+1);
											end loop;
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											state <= s_red2_F1; 
										else 
											cnt <= cnt + 1; 
										end if;
						
								when s_red2_F1 => 
										if cnt = 0 then
											for i in 4 to 5 loop
												dataa_add1(i) <= result_add1(2*(i-4));
												datab_add1(i) <= result_add1(2*(i-4)+1);
												dataa_add2(i) <= result_add2(2*(i-4));
												datab_add2(i) <= result_add2(2*(i-4)+1);
												dataa_add3(i) <= result_add3(2*(i-4));
												datab_add3(i) <= result_add3(2*(i-4)+1);
											end loop;
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0;
											state <= s_red3_F1; 
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red3_F1 => 
										if cnt = 0 then
											dataa_add1(6) <= result_add1(4);
											datab_add1(6) <= result_add1(5);
											dataa_add2(6) <= result_add2(4); 
											datab_add2(6) <= result_add2(5);
											dataa_add3(6) <= result_add3(4);
											datab_add3(6) <= result_add3(5);
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											state <= s_red4_F1;
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red4_F1 => 
										if cnt = 0 then
											dataa_add1(7) <= reg_m1_8_out1;
											datab_add1(7) <= result_add1(6);
											dataa_add2(7) <= reg_m2_8_out1;
											datab_add2(7) <= result_add2(6);
											dataa_add3(7) <= reg_m3_8_out1;
											datab_add3(7) <= result_add3(6);
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											sum_ch1 <= result_add1(7); 
											sum_ch2 <= result_add2(7); 
											sum_ch3 <= result_add3(7);
											state <= s_red5_F1; 
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red5_F1 => 
										if cnt = 0 then
											dataa_add1(0) <= sum_ch1;
											datab_add1(0) <= sum_ch2;
										end if;
										if cnt = cnt_end_add then
											cnt <= 0;
											sum_ch1_ch2 <= result_add1(0); 
											state <= s_red6_F1; 
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red6_F1 => 
										if cnt = 0 then
											dataa_add1(0) <= sum_ch1_ch2; 
											datab_add1(0) <= sum_ch3;
										end if;
										if cnt = cnt_end_add then
											clk_en_add <= '0'; 
											cnt <= 0; 
											state <= s_write_F1;
										else 
											cnt <= cnt + 1; 
										end if;
						
								when s_write_F1 =>
										ram_fmap4_1_we <= '1';
										ram_fmap4_1_wr_addr <= std_logic_vector(to_unsigned(row_idx_conv4 * 8 + col_idx_conv4, 10));
										ram_fmap4_1_data_in <= result_add1(0);
										state <= s_wait_write_F1;
						
								when s_wait_write_F1 =>
										if cnt = 0 then
											cnt <= 1;
										else 
											cnt <= 0;
											ram_fmap4_1_we <= '0';
											state <= s_setup_F2;
										end if;
						
								when s_setup_F2 =>
										for i in 0 to 2 loop
											for j in 0 to 2 loop
												datab_mult1(i*3 + j) <= pkgKernel4_2_1(i, j); 
												datab_mult2(i*3 + j) <= pkgKernel4_2_2(i, j); 
												datab_mult3(i*3 + j) <= pkgKernel4_2_3(i, j); 
											end loop;
										end loop;
										clk_en_mul <= '1';
										cnt <= 0;
										state <= s_mult_F2;
						
								when s_mult_F2 => 
										if cnt = cnt_end_mul then 
											clk_en_mul <= '0'; 
											cnt <= 0; 
											state <= s_red1_F2;
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red1_F2 => 
										clk_en_add <= '1';
										if cnt = 0 then
											for i in 0 to 3 loop
												dataa_add1(i) <= result_mult1(2*i);
												datab_add1(i) <= result_mult1(2*i+1);
												dataa_add2(i) <= result_mult2(2*i); 
												datab_add2(i) <= result_mult2(2*i+1);
												dataa_add3(i) <= result_mult3(2*i);
												datab_add3(i) <= result_mult3(2*i+1);
											end loop;
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											reg_m1_8_out1 <= result_mult1(8); 
											reg_m2_8_out1 <= result_mult2(8); 
											reg_m3_8_out1 <= result_mult3(8);
											state <= s_red2_F2; 
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red2_F2 => 
										if cnt = 0 then
											for i in 0 to 1 loop
												dataa_add1(i) <= result_add1(2*i); 
												datab_add1(i) <= result_add1(2*i+1);
												dataa_add2(i) <= result_add2(2*i);
												datab_add2(i) <= result_add2(2*i+1);
												dataa_add3(i) <= result_add3(2*i);
												datab_add3(i) <= result_add3(2*i+1);
											end loop;
										end if;
										if cnt = cnt_end_add then
											cnt <= 0;
											state <= s_red3_F2;
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red3_F2 => 
										if cnt = 0 then
											dataa_add1(0) <= result_add1(0);
											datab_add1(0) <= result_add1(1);
											dataa_add2(0) <= result_add2(0);
											datab_add2(0) <= result_add2(1);
											dataa_add3(0) <= result_add3(0);
											datab_add3(0) <= result_add3(1);
										end if;
										if cnt = cnt_end_add then
											cnt <= 0;
											state <= s_red4_F2;
										else
											cnt <= cnt + 1;
										end if;
						
								when s_red4_F2 => 
										if cnt = 0 then
											dataa_add1(0) <= result_add1(0);
											datab_add1(0) <= reg_m1_8_out1;
											dataa_add2(0) <= result_add2(0);
											datab_add2(0) <= reg_m2_8_out1;
											dataa_add3(0) <= result_add3(0);
											datab_add3(0) <= reg_m3_8_out1;
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0;
											sum_ch1 <= result_add1(0);
											sum_ch2 <= result_add2(0); 
											sum_ch3 <= result_add3(0);
											state <= s_red5_F2; 
										else
											cnt <= cnt + 1;
										end if;
						
								when s_red5_F2 => 
										if cnt = 0 then
											dataa_add1(0) <= sum_ch1;
											datab_add1(0) <= sum_ch2;
										end if;
										if cnt = cnt_end_add then
											cnt <= 0;
											sum_ch1_ch2 <= result_add1(0);
											state <= s_red6_F2;
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red6_F2 => 
										if cnt = 0 then
											dataa_add1(0) <= sum_ch1_ch2; 
											datab_add1(0) <= sum_ch3;
										end if;
										if cnt = cnt_end_add then
											clk_en_add <= '0';
											cnt <= 0;
											state <= s_write_F2;
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_write_F2 =>
										ram_fmap4_2_we <= '1';
										ram_fmap4_2_wr_addr <= std_logic_vector(to_unsigned(row_idx_conv4 * 8 + col_idx_conv4, 10));
										ram_fmap4_2_data_in <= result_add1(0);
										state <= s_wait_write_F2;
						
								when s_wait_write_F2 =>
										if cnt = 0 then
											cnt <= 1;
										else
											cnt <= 0;
											ram_fmap4_2_we <= '0';
											state <= s_setup_F3;
										end if;
						
						
								when s_setup_F3 =>
										for i in 0 to 2 loop
											for j in 0 to 2 loop
												datab_mult1(i*3 + j) <= pkgKernel4_3_1(i, j); 
												datab_mult2(i*3 + j) <= pkgKernel4_3_2(i, j); 
												datab_mult3(i*3 + j) <= pkgKernel4_3_3(i, j); 
											end loop;
										end loop;
										clk_en_mul <= '1';
										cnt <= 0;
										state <= s_mult_F3;
						
								when s_mult_F3 => 
										if cnt = cnt_end_mul then
												clk_en_mul <= '0';
												cnt <= 0;
												state <= s_red1_F3;
											else
												cnt <= cnt + 1;
											end if;
						
								when s_red1_F3 => 
										clk_en_add <= '1';
										if cnt = 0 then
											for i in 0 to 3 loop
												dataa_add1(i) <= result_mult1(2*i); 
												datab_add1(i) <= result_mult1(2*i+1);
												dataa_add2(i) <= result_mult2(2*i); 
												datab_add2(i) <= result_mult2(2*i+1);
												dataa_add3(i) <= result_mult3(2*i);
												datab_add3(i) <= result_mult3(2*i+1);
											end loop;
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											state <= s_red2_F3;
											reg_m1_8_out1 <= result_mult1(8); 
											reg_m2_8_out1 <= result_mult2(8); 
											reg_m3_8_out1 <= result_mult3(8);
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red2_F3 => 
										if cnt = 0 then
											for i in 0 to 1 loop
												dataa_add1(i) <= result_add1(2*i);
												datab_add1(i) <= result_add1(2*i+1);
												dataa_add2(i) <= result_add2(2*i);
												datab_add2(i) <= result_add2(2*i+1);
												dataa_add3(i) <= result_add3(2*i);
												datab_add3(i) <= result_add3(2*i+1);
											end loop;
										end if;
										if cnt = cnt_end_add then
											cnt <= 0; 
											state <= s_red3_F3;
										else
											cnt <= cnt + 1; 
										end if;
						
								when s_red3_F3 => 
										if cnt = 0 then
											dataa_add1(0) <= result_add1(0); 
											datab_add1(0) <= result_add1(1);
											dataa_add2(0) <= result_add2(0);
											datab_add2(0) <= result_add2(1);
											dataa_add3(0) <= result_add3(0); 
											datab_add3(0) <= result_add3(1);
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0; 
											state <= s_red4_F3;
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_red4_F3 => 
										if cnt = 0 then
											dataa_add1(0) <= result_add1(0);
											datab_add1(0) <= reg_m1_8_out1;
											dataa_add2(0) <= result_add2(0);
											datab_add2(0) <= reg_m2_8_out1;
											dataa_add3(0) <= result_add3(0);
											datab_add3(0) <= reg_m3_8_out1;
										end if;
										if cnt = cnt_end_add then 
											cnt <= 0;
											sum_ch1 <= result_add1(0);
											sum_ch2 <= result_add2(0); 
											sum_ch3 <= result_add3(0);
											state <= s_red5_F3; 
										else
											cnt <= cnt + 1;
										end if;
						
								when s_red5_F3 => 
										if cnt = 0 then
											dataa_add1(0) <= sum_ch1;
											datab_add1(0) <= sum_ch2;
										end if;
										if cnt = cnt_end_add then
											cnt <= 0;
											sum_ch1_ch2 <= result_add1(0); 
											state <= s_red6_F3;
										else
											cnt <= cnt + 1; 
										end if;
						
								when s_red6_F3 => 
										if cnt = 0 then
											dataa_add1(0) <= sum_ch1_ch2;
											datab_add1(0) <= sum_ch3;
										end if;
										if cnt = cnt_end_add then 
											clk_en_add <= '0';
											cnt <= 0;
											state <= s_write_F3; 
										else 
											cnt <= cnt + 1;
										end if;
						
								when s_write_F3 =>
										ram_fmap4_3_we <= '1';
										ram_fmap4_3_wr_addr <= std_logic_vector(to_unsigned(row_idx_conv4 * 8 + col_idx_conv4, 10));
										ram_fmap4_3_data_in <= result_add1(0);
										state <= s_wait_write_F3;
						
								when s_wait_write_F3 =>
										if cnt = 0 then 
											cnt <= 1; 
										else 
											cnt <= 0;
											ram_fmap4_3_we <= '0';
											state <= s_slide;
										end if;
						
								when s_slide =>
										data_counter <= 0;
										if col_idx_conv4 < (FM4_MATRIX_S - 1) then
											col_idx_conv4 <= col_idx_conv4 + 1;
											state <= s_read_ram;
										else
											col_idx_conv4 <= 0;
											if row_idx_conv4 < (FM4_MATRIX_S - 1) then
												row_idx_conv4 <= row_idx_conv4 + 1;
												state <= s_read_ram;
											else
												state <= s_finish;
											end if;
										end if;
						
								when s_finish =>
										layer_state <= LRELU4;
										state <= s_idle;
						
								when others => null;
							end case;
---------------------------------------------------LRELU4----------------------------------------------------------------------(conv4 doğru)
					when LRELU4 =>
				
						case (lrelu_state) is
								
								when s_idle =>
									clk_en_mul <= '0';
									row_idx_lrelu4 <= 0;
									col_idx_lrelu4 <= 0;
									cnt <= 0;
									relu_control1 <= false;
									relu_control2 <= false;
									relu_control3 <= false;
									data_counter <= 0;
									ram_fmap4_1_we <= '0';
									ram_fmap4_2_we <= '0';
									ram_fmap4_3_we <= '0';
									
									lrelu_state <= s_set_addr;
					
								when s_set_addr =>
				
									ram_fmap4_1_rd_addr <= std_logic_vector(to_unsigned(row_idx_lrelu4 * 8 + col_idx_lrelu4, 10));
									ram_fmap4_2_rd_addr <= std_logic_vector(to_unsigned(row_idx_lrelu4 * 8 + col_idx_lrelu4, 10));
									ram_fmap4_3_rd_addr <= std_logic_vector(to_unsigned(row_idx_lrelu4 * 8 + col_idx_lrelu4, 10));
									
									lrelu_state <= s_wait_ram;
						
								when s_wait_ram =>
									if cnt = 2 then
										cnt <= 0;
										lrelu_state <= s_check_sign;
									
									else
										cnt <= cnt + 1;
									end if;
								
				
								when s_check_sign =>
									clk_en_mul <= '1';
									cnt <= 0;
									
					
									if ram_fmap4_1_q_out(31) = '1' then 
										dataa_mult1(0) <= ram_fmap4_1_q_out; 
										datab_mult1(0) <= x"3c23d70a"; 
										relu_control1 <= true; 
									else 
										relu_control1 <= false; 
									end if;
						
								
									if ram_fmap4_2_q_out(31) = '1' then
										dataa_mult2(0) <= ram_fmap4_2_q_out;
										datab_mult2(0) <= x"3c23d70a";
										relu_control2 <= true;
									else 
										relu_control2 <= false;
									end if;
						
								
									if ram_fmap4_3_q_out(31) = '1' then
										dataa_mult3(0) <= ram_fmap4_3_q_out;
										datab_mult3(0) <= x"3c23d70a";
										relu_control3 <= true;
									else 
										relu_control3 <= false;
									end if;
									lrelu_state <= s_mult_wait; 
						
								when s_mult_wait =>
					
									if (relu_control1 = false and relu_control2 = false and relu_control3 = false) then
										clk_en_mul <= '0';
										lrelu_state <= s_write_finish; 
									else
									
										if cnt = cnt_end_mul then
												clk_en_mul <= '0';
												cnt <= 0;
												lrelu_state <= s_write_back;
										else
												cnt <= cnt + 1;
										end if;
									end if;
						
								when s_write_back =>
								
									ram_fmap4_1_wr_addr <= std_logic_vector(to_unsigned(row_idx_lrelu4 * 8 + col_idx_lrelu4, 10));
									ram_fmap4_2_wr_addr <= std_logic_vector(to_unsigned(row_idx_lrelu4 * 8 + col_idx_lrelu4, 10));
									ram_fmap4_3_wr_addr <= std_logic_vector(to_unsigned(row_idx_lrelu4 * 8 + col_idx_lrelu4, 10));
						
									
									if relu_control1 then
										ram_fmap4_1_data_in <= result_mult1(0); 
										ram_fmap4_1_we <= '1';                 
									end if;
						
									if relu_control2 then
										ram_fmap4_2_data_in <= result_mult2(0);
										ram_fmap4_2_we <= '1';
									end if;
						
									if relu_control3 then
										ram_fmap4_3_data_in <= result_mult3(0);
										ram_fmap4_3_we <= '1';
									end if;
						
									lrelu_state <= s_write_finish;
						
					
								when s_write_finish =>
									ram_fmap4_1_we <= '0';
									ram_fmap4_2_we <= '0';
									ram_fmap4_3_we <= '0';
									
									
									if col_idx_lrelu4 = (FM4_MATRIX_S-1) and row_idx_lrelu4 = (FM4_MATRIX_S-1) then
										lrelu_state <= s_finishRelu;
									else
										lrelu_state <= s_increaseIndex;
									end if;
						
						
								when s_increaseIndex =>
									if col_idx_lrelu4 < (FM4_MATRIX_S-1) then
										col_idx_lrelu4 <= col_idx_lrelu4 + 1;
									else
										col_idx_lrelu4 <= 0;
										row_idx_lrelu4 <= row_idx_lrelu4 + 1;
									end if;
									lrelu_state <= s_set_addr; 
						
							
								when s_finishRelu =>
									
									layer_state <= MAXPOOL2;
									state <= s_idle;
									lrelu_state <= s_idle;
								when others =>
									null;
						end case;
------------------------------------------------------MAXPOOL2-----------------------------------------------------------------
					when MAXPOOL2 =>
				
						case (maxpool_state) is
							when s_idle =>
								row_idx_maxpool2 <= 0;
								col_idx_maxpool2 <= 0;
					
								clk_en_compare <= '0';
								cnt <= 0;
								data_counter <= 0;
								ram_maxpool1_2_we <= '0';
								ram_maxpool2_2_we <= '0';
								ram_maxpool3_2_we <= '0';
								maxpool_state <= s_set_addr;
							when s_set_addr =>
									case data_counter is
									
									when 0 => 
										ram_fmap4_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool2 *2 + 0) * 8 + (col_idx_maxpool2 *2 + 0), 10)); --fmap1_1in ilk penceresinin 1. pixeli
										ram_fmap4_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool2 *2 + 0) * 8 + (col_idx_maxpool2 *2 + 0), 10));
										ram_fmap4_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool2 *2 + 0) * 8 + (col_idx_maxpool2 *2 + 0), 10));
									when 1 =>                                                                                            
										ram_fmap4_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool2 *2 + 0) * 8 + (col_idx_maxpool2 *2 + 1), 10)); --2. pixeli...
										ram_fmap4_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool2 *2 + 0) * 8 + (col_idx_maxpool2 *2 + 1), 10));
										ram_fmap4_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool2 *2 + 0) * 8 + (col_idx_maxpool2 *2 + 1), 10));
									when 2 =>                                                                                             
										ram_fmap4_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool2 *2 + 1) * 8 + (col_idx_maxpool2 *2 + 0), 10)); --3.
										ram_fmap4_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool2 *2 + 1) * 8 + (col_idx_maxpool2 *2 + 0), 10));
										ram_fmap4_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool2 *2 + 1) * 8 + (col_idx_maxpool2 *2 + 0), 10));
									when 3 =>                                                                                           
										ram_fmap4_1_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool2 *2 + 1) * 8 + (col_idx_maxpool2 *2 + 1), 10)); --4.
										ram_fmap4_2_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool2 *2 + 1) * 8 + (col_idx_maxpool2 *2 + 1), 10));
										ram_fmap4_3_rd_addr <= std_logic_vector(to_unsigned((row_idx_maxpool2 *2 + 1) * 8 + (col_idx_maxpool2 *2 + 1), 10));
									when others => null;
									end case;
										maxpool_state <= s_wait_ram;
									
					
							when s_wait_ram =>
									if cnt = 2 then
										cnt <= 0;
										maxpool_state <= s_compare1;
									else
										cnt <= cnt + 1;
									end if;
								
						
									
							when s_compare1 =>                --featureMap[row*poolKernelWidth+i , col*poolKernelWidth+j] 
																					        --       2     + i ve jler manuel
								clk_en_compare <= '0';
								
									case data_counter is
										when 0 =>
											dataa_compare1(0) <= ram_fmap4_1_q_out;
											dataa_compare2(0) <= ram_fmap4_2_q_out;
											dataa_compare3(0) <= ram_fmap4_3_q_out;
										when 1 =>
											datab_compare1(0) <= ram_fmap4_1_q_out;
											datab_compare2(0) <= ram_fmap4_2_q_out;
											datab_compare3(0) <= ram_fmap4_3_q_out;
										when 2 =>
											dataa_compare1(1) <= ram_fmap4_1_q_out;
											dataa_compare2(1) <= ram_fmap4_2_q_out;
											dataa_compare3(1) <= ram_fmap4_3_q_out;
										when 3 =>
											datab_compare1(1) <= ram_fmap4_1_q_out;
											datab_compare2(1) <= ram_fmap4_2_q_out;
											datab_compare3(1) <= ram_fmap4_3_q_out;
										when others => null;
									end case;
									if data_counter = 3 then
										cnt <= 0;
										clk_en_compare <= '1';
										maxpool_state <= s_waitCompare;
									else 
										data_counter <= data_counter + 1;
										maxpool_state <= s_set_addr;
									end if;
									
							when s_waitCompare =>
								if cnt = cnt_end_compare then
									clk_en_compare <= '0';
									cnt <= 0;
									maxpool_state <= s_writeTemps;
								else
									cnt <= cnt + 1;
								end if;
								
							when s_writeTemps =>
								cnt <= 0;

								if agb_compare1(0) = '1' then --a>b durumu
									reg_tempMax1_1 <= dataa_compare1(0);
								else
									reg_tempMax1_1 <= datab_compare1(0);
								end if;
								
								if agb_compare1(1) = '1' then --a>b durumu
									reg_tempMax1_2 <= dataa_compare1(1);
								else 
									reg_tempMax1_2 <= datab_compare1(1);
								end if;
								
								if agb_compare2(0) = '1' then --a>b durumu
									reg_tempMax2_1 <= dataa_compare2(0);
								else                 
									reg_tempMax2_1 <= datab_compare2(0);
								end if;
								
								if agb_compare2(1) = '1' then --a>b durumu
									reg_tempMax2_2 <= dataa_compare2(1);
								else                 
									reg_tempMax2_2 <= datab_compare2(1);
								end if;
								
								if agb_compare3(0) = '1' then --a>b durumu
									reg_tempMax3_1 <= dataa_compare3(0);
								else                 
									reg_tempMax3_1 <= datab_compare3(0);
								end if;
								
								if agb_compare3(1) = '1' then --a>b durumu
									reg_tempMax3_2 <= dataa_compare3(1);
								else                 
									reg_tempMax3_2 <= datab_compare3(1);
								end if;

								maxpool_state <= s_compare2;
								
							when s_compare2 =>
								clk_en_compare <= '1';
								if cnt = 0 then
									dataa_compare1(0) <= reg_tempMax1_1;  
									datab_compare1(0) <= reg_tempMax1_2;

									dataa_compare2(0) <= reg_tempMax2_1;
									datab_compare2(0) <= reg_tempMax2_2;

									dataa_compare3(0) <= reg_tempMax3_1;
									datab_compare3(0) <= reg_tempMax3_2;
								end if;
								
								if cnt = cnt_end_compare then
									clk_en_compare <= '0';
									cnt <= 0;
									maxpool_state <= s_writeGreater;
								else
									cnt <= cnt + 1;
								end if;
					
	
							when s_writeGreater =>
								ram_maxpool1_2_we <= '1';
								ram_maxpool2_2_we <= '1';
								ram_maxpool3_2_we <= '1';
								cnt <= 0;
								ram_maxpool1_2_wr_addr <= std_logic_vector(to_unsigned(row_idx_maxpool2 * 4 + col_idx_maxpool2, 10));
								ram_maxpool2_2_wr_addr <= std_logic_vector(to_unsigned(row_idx_maxpool2 * 4 + col_idx_maxpool2, 10));
								ram_maxpool3_2_wr_addr <= std_logic_vector(to_unsigned(row_idx_maxpool2 * 4 + col_idx_maxpool2, 10));
								if agb_compare1(0) = '1' then -- a>b durumu
									ram_maxpool1_2_data_in <= reg_tempMax1_1;
								else
									ram_maxpool1_2_data_in <= reg_tempMax1_2;
								end if;
								
								if agb_compare2(0) = '1' then -- a>b durumu
									ram_maxpool2_2_data_in <= reg_tempMax2_1;
								else
									ram_maxpool2_2_data_in <= reg_tempMax2_2;
								end if;
								
								if agb_compare3(0) = '1' then -- a>b durumu
									ram_maxpool3_2_data_in <= reg_tempMax3_1;
								else
									ram_maxpool3_2_data_in <= reg_tempMax3_2;
								end if;
								maxpool_state <= s_write_wait;
								
								
							when s_write_wait =>
								if cnt = 0 then
									cnt <= 1;
								elsif cnt = 1 then
									cnt <= 0;
									ram_maxpool1_2_we <= '0';
									ram_maxpool2_2_we <= '0';
									ram_maxpool3_2_we <= '0';
									if col_idx_maxpool2 = (POOL2_MATRIX_S -1) and row_idx_maxpool2 = (POOL2_MATRIX_S-1) then --son elemanda yazmadan burası yüzünden finishe gitme durumu olabilir ona simde bak
										maxpool_state <= s_finishMaxpool;
									else
										maxpool_state <= s_slide;
									end if;
								end if;
							when s_slide =>
								cnt <= 0;
								data_counter <= 0;
								if col_idx_maxpool2 < (POOL2_MATRIX_S-1) then 
									col_idx_maxpool2 <= (col_idx_maxpool2 + 1); 
								
								else
									col_idx_maxpool2 <= 0;
									row_idx_maxpool2 <= (row_idx_maxpool2 + 1);
								
								end if;
								maxpool_state <= s_set_addr;
								
							when s_finishMaxpool =>
								if cnt = 0 then
									cnt <= 1;
								elsif cnt = 1 then
									clk_en_compare <= '0';
									cnt <= 0;
									layer_state <= FLATTING;
									state <= s_idle;
									lrelu_state <= s_idle;
									maxpool_state <= s_idle;
								end if;
							when others => null;
						end case;
------------------------------------------------------FLATTING-------------------------------------				
					when FLATTING =>
						case (flatting_state) is
							when s_idle =>
								flat_idx <= 0;
								flatting_state <= s_read_addr;
								
							when s_read_addr =>
								
								ram_maxpool1_2_rd_addr <= std_logic_vector(to_unsigned((flat_idx),10));
								ram_maxpool2_2_rd_addr <= std_logic_vector(to_unsigned((flat_idx),10));
								ram_maxpool3_2_rd_addr <= std_logic_vector(to_unsigned((flat_idx),10));
								flatting_state <= s_wait_data;
								
							when s_wait_data =>
								
									if cnt = 2 then 
										cnt <= 0;
										flatting_state <= s_write_data;
									else
										cnt <= cnt + 1;
									
									end if;
								
							when s_write_data =>
							
								if flat_idx = 0 then --debug için
									flat_debug_reg1 <= ram_maxpool1_2_q_out;
									flat_debug_reg2 <= ram_maxpool2_2_q_out;
									flat_debug_reg3 <= ram_maxpool3_2_q_out;
								end if;
								
								flattenMatrix(flat_idx) <= ram_maxpool1_2_q_out;
								flattenMatrix(flat_idx+16) <= ram_maxpool2_2_q_out;
								flattenMatrix(flat_idx+32) <= ram_maxpool3_2_q_out;
								flatting_state <= s_wait_write; 
								
							when s_wait_write =>
								flatting_state <= s_increaseFlatIndex;
								
							when s_increaseFlatIndex =>
								if flat_idx = 15 then
									flatting_state <= s_finishFlat;
									flat_idx <= 0;
								else 
									flat_idx <= flat_idx + 1;
									flatting_state <= s_read_addr;
								end if;
								
							when s_finishFlat =>
								layer_state <= CONVEND;
								
							end case;
							
					when CONVEND =>
						layer_state <= FF_MM1;
						
			-----------------------------------burdan sonrası fully connect-------------------------------------- 
					when FF_MM1 =>
				
						case (MM_state) is
							when s_idle =>
								cnt <= 0;
								MM_row_idx   <= 0;
                        MM_block_idx <= 0;
                        MM_reg_accum <= (others => '0');
                        MM_state     <= s_load_mult;
								
                     when s_load_mult =>
                         for i in 0 to 7 loop
                             MM_dataa_mult1(i) <= flattenMatrix(MM_block_idx*8 + i);
                             MM_datab_mult1(i) <= pkgHidWeight1(MM_row_idx, MM_block_idx*8 + i);
                         end loop;
  
                         clk_en_mul <= '1';
                         cnt <= 0;
                         MM_state  <= s_wait_mult;
								
                     when s_wait_mult =>
                         if cnt = cnt_end_mul then
                             clk_en_mul  <= '0';
                             MM_red_idx <= 0;
                             MM_state   <= s_reduce;
                         else
                             cnt <= cnt + 1;
                         end if;
								 
                    when s_reduce =>
                        MM_dataa_add1(0) <= MM_reg_accum;
                        MM_datab_add1(0) <= MM_result_mult1(MM_red_idx);
                        clk_en_add <= '1';
                        cnt <= 0;
                        MM_state <= s_wait_add;
								
                    when s_wait_add =>
                        if cnt = cnt_end_add then
                            MM_reg_accum <= MM_result_add1(0);
                            clk_en_add <= '0';

                            if MM_red_idx = 7 then
                                MM_state <= s_next_block;
                            else
                                MM_red_idx <= MM_red_idx + 1;
                                MM_state <= s_reduce;
                            end if;
                        else
                            cnt <= cnt + 1;
                        end if;
								
                    when s_next_block =>
                        if MM_block_idx = 5 then
                            MM_state <= s_write_out;
									 cnt <= 0;
                        else
									 cnt <= 0;
                            MM_block_idx <= MM_block_idx + 1;
									 MM_red_idx <= 0;
                            MM_state <= s_load_mult;
                        end if;
								
                    when s_write_out =>
                        hidLayerMatrix(0, MM_row_idx) <= MM_reg_accum;
								
                        MM_reg_accum <= (others => '0');

                        if MM_row_idx = 15 then
                            MM_state <= s_finish;
                        else
                            MM_row_idx   <= MM_row_idx + 1;
                            MM_block_idx <= 0;
                            MM_state <= s_load_mult;
                        end if;
							
							when s_finish =>
								
								MM_row_idx <= 0;
								MM_block_idx <= 0;
								MM_red_idx <= 0;
								layer_state <= FF_LRELU;
						end case;
----------------------------------------------------LRELU--------------------------------------------------------				
					when FF_LRELU =>
								
						case (MM_lrelu_state) is
							when s_idle =>
								MM_state <= s_idle;
								clk_en_mul <= '0';
								clk_en_add <= '0'; 
								MM_row_idx_lrelu <= 0;
								cnt <= 0;
								MM_relu_control1 <= false;
								MM_lrelu_state <= s_compare;
								
							when s_compare =>
								clk_en_mul <= '1';
								
								if cnt = 0 then
									if hidLayerMatrix(0,MM_row_idx_lrelu)(31) = '1' then
										MM_dataa_mult1(0) <= hidLayerMatrix(0,MM_row_idx_lrelu);
										MM_datab_mult1(0) <= x"3c23d70a"; --0.01
										MM_relu_control1 <= true;
									else 
										hidLayerMatrix(0,MM_row_idx_lrelu) <= hidLayerMatrix(0,MM_row_idx_lrelu);
										MM_relu_control1 <= false;
									end if;

								end if;
								
								if cnt = (cnt_end_mul+1) then
									clk_en_mul <= '0';
									cnt <= 0;
									MM_lrelu_state <= s_write;
								else
									cnt <= cnt + 1;
								end if;
							
							when s_write =>
								cnt <= 0;
								if MM_relu_control1 = true then
									MM_relu_control1 <= false;
									hidLayerMatrix(0,MM_row_idx_lrelu) <= MM_result_mult1(0);

								end if;
								
								MM_lrelu_state <= s_increaseIndex;
								
							when s_increaseIndex =>
								if MM_row_idx_lrelu = 15 then 
									MM_lrelu_state <= s_finishRelu;
								else
									MM_row_idx_lrelu <= MM_row_idx_lrelu + 1;
									MM_lrelu_state <= s_compare;
								end if;
			
							
							when s_finishRelu =>
							
								clk_en_mul <= '0';
								cnt <= 0;
								layer_state <= FF_MM2;
								MM_state <= s_idle;
								MM_lrelu_state <= s_idle;
								
						end case;
-----------------------------------------------------MM2---------------------------------------------------------
					when FF_MM2 =>
					
						case (MM_state) is
							when s_idle =>
								cnt <= 0;
								MM_row_idx   <= 0;
                        MM_block_idx <= 0;
                        MM_reg_accum <= (others => '0');
                        MM_state     <= s_load_mult;
								
                     when s_load_mult =>
                         for i in 0 to 7 loop
                             MM_dataa_mult1(i) <= hidLayerMatrix(0,MM_block_idx*8 + i);
                             MM_datab_mult1(i) <= pkgHidWeight2(MM_row_idx, MM_block_idx*8 + i);
                         end loop;
  
                         clk_en_mul <= '1';
                         cnt    <= 0;
                         MM_state  <= s_wait_mult;
								
                     when s_wait_mult =>
                         if cnt = cnt_end_mul then
                             clk_en_mul  <= '0';
                             MM_red_idx <= 0;
                             MM_state   <= s_reduce;
                         else
                             cnt <= cnt + 1;
                         end if;
								 
                    when s_reduce =>
                        MM_dataa_add1(0) <= MM_reg_accum;
                        MM_datab_add1(0) <= MM_result_mult1(MM_red_idx);
                        clk_en_add <= '1';
                        cnt <= 0;
                        MM_state <= s_wait_add;
								
                    when s_wait_add =>
                        if cnt = cnt_end_add then
                            MM_reg_accum <= MM_result_add1(0);
                            clk_en_add <= '0';

                            if MM_red_idx = 7 then
                                MM_state <= s_next_block;
                            else
                                MM_red_idx <= MM_red_idx + 1;
                                MM_state <= s_reduce;
                            end if;
                        else
                            cnt <= cnt + 1;
                        end if;
								
                    when s_next_block =>
                        if MM_block_idx = 1 then
									 cnt <= 0;
                            MM_state <= s_write_out;
                        else
									 cnt <= 0;
                            MM_block_idx <= MM_block_idx + 1;
									 MM_red_idx <= 0;
                            MM_state <= s_load_mult;
                        end if;
								
                    when s_write_out =>
                        softmaxIn(0, MM_row_idx) <= MM_reg_accum;
                        MM_reg_accum <= (others => '0');

                        if MM_row_idx = 9 then
                            MM_state <= s_finish;
                        else
                            MM_row_idx   <= MM_row_idx + 1;
                            MM_block_idx <= 0;
                            MM_state <= s_load_mult;
                        end if;
							

							when s_finish =>
							
								MM_row_idx <= 0;
								MM_block_idx <= 0;
								MM_red_idx <= 0;
								layer_state <= SOFTMAX;
						end case;
-----------------------------------------------------SOFTMAX----------------------------------------------						
						when SOFTMAX =>
					
							case (MM_softmax_state) is  
								when s_idle =>
									MM_reg_accum <= (others => '0');
									cnt <= 0;
									clk_en_exp <= '0';
									clk_en_add <= '0';
									MM_softmax_idx <= 0;
									MM_softmax_state <= s_calc_ej;
									
								when s_calc_ej =>
									clk_en_exp <= '1'; 
									MM_dataExpo <= softmaxIn(0,MM_softmax_idx);
									MM_softmax_state <= s_waitExpo;
									
								when s_waitExpo =>
									if cnt = cnt_end_expo then
										MM_softmax_state <= s_writeForAdder;
										cnt <= 0;
										clk_en_exp <= '0'; 
									else 
										cnt <= cnt + 1; 
									end if;
									
								when s_writeForAdder =>
									
									softmaxIn(0,MM_softmax_idx) <= MM_resultExpo;
									if MM_softmax_idx = 9 then
										MM_softmax_idx <= 0;
										MM_softmax_state <= s_reduct1;
									else
										MM_softmax_idx <= MM_softmax_idx + 1;
										MM_softmax_state <= s_calc_ej;
									end if;
								
								when s_reduct1 =>
									clk_en_add <= '1';
									if cnt = 0 then
										MM_dataa_add1(0) <= softmaxIn(0,0);
										MM_datab_add1(0) <= softmaxIn(0,1);
										MM_dataa_add1(1) <= softmaxIn(0,2);
										MM_datab_add1(1) <= softmaxIn(0,3);
										MM_dataa_add1(2) <= softmaxIn(0,4);
										MM_datab_add1(2) <= softmaxIn(0,5);
										MM_dataa_add1(3) <= softmaxIn(0,6);
										MM_datab_add1(3) <= softmaxIn(0,7);
										MM_dataa_add1(4) <= softmaxIn(0,8);
										MM_datab_add1(4) <= softmaxIn(0,9);
									end if;
									if cnt = cnt_end_add then
										cnt <= 0;
										MM_softmax_state <= s_reduct2;
										MM_temp_sum_8_9 <= MM_result_add1(4);
									else 
										cnt <= cnt + 1;
									end if;
								when s_reduct2 =>
									if cnt = 0 then
										MM_dataa_add1(0) <= MM_result_add1(0);
										MM_datab_add1(0) <= MM_result_add1(1);
										MM_dataa_add1(1) <= MM_result_add1(2);
										MM_datab_add1(1) <= MM_result_add1(3);
									end if;
									if cnt = cnt_end_add then
										cnt <= 0;
										MM_softmax_state <= s_reduct3;
									else 
										cnt <= cnt + 1;
									end if;
								when s_reduct3 =>
									if cnt = 0 then 
										MM_dataa_add1(0) <= MM_result_add1(0);
										MM_datab_add1(0) <= MM_result_add1(1);
									end if;
									if cnt = cnt_end_add then
										cnt <= 0;
										MM_softmax_state <= s_reduct4;
									else 
										cnt <= cnt + 1;
									end if;
								when s_reduct4 =>
									if cnt = 0 then 
										MM_dataa_add1(0) <= MM_result_add1(0);
										MM_datab_add1(0) <= MM_temp_sum_8_9;
									end if;
									if cnt = cnt_end_add then
										cnt <= 0;
										clk_en_add <= '0'; 
										MM_reg_exp_sum <= MM_result_add1(0);
										MM_softmax_state <= s_div;
									else 
										cnt <= cnt + 1;
									end if;
									
								when s_div =>
									clk_en_div <= '1'; 
									if cnt = 0 then
										MM_dataa_div <= softmaxIn(0,MM_softmax_idx);
										MM_datab_div <= MM_reg_exp_sum;
									end if;
									if cnt = cnt_end_div then
										clk_en_div <= '0';
										fullyOut(0,MM_softmax_idx) <= MM_result_div;
										cnt <= 0;
										if MM_softmax_idx = 9 then
											MM_softmax_idx <= 0;
											MM_softmax_state <= s_finish;
										else
											MM_softmax_idx <= MM_softmax_idx + 1;
										end if;
									else
										cnt <= cnt + 1;
									end if;
									
								
								when s_finish =>
									layer_state <= PREDICT;
							end case;
-----------------------------------------------------PREDICT-------------------------------------------------------
					when PREDICT =>
					
						case (MM_predict_state) is
							when s_idle =>
								MM_predictedNumberTemp <= 0;
								clk_en_compare <= '0';
								cnt <= 0;
								MM_compareIdx <= 0;
								MM_reg_tempCompare <= (others => '0'); --ilk karşılaştırma için sıfırladım
								MM_predict_state <= s_compare;
							
							when s_compare =>
								
								clk_en_compare <= '1';
								if cnt = 0 then
									MM_dataa_compare <= fullyOut(0,MM_compareIdx);
									MM_datab_compare <= MM_reg_tempCompare;
								end if;
								if cnt = cnt_end_compare then
									cnt <= 0;
									MM_predict_state <= s_writeTemp;
								else
									cnt <= cnt + 1;
								end if;
								
							when s_writeTemp =>
								
									if MM_agb_compare = '1' then
										MM_reg_tempCompare <= fullyOut(0,MM_compareIdx);
										MM_predictedNumberTemp <= MM_compareIdx;
										MM_predict_state <= s_increaseIdx;
									else
										MM_predict_state <= s_increaseIdx;
									end if;
								
							
							when s_increaseIdx =>
								if MM_compareIdx = 9 then
									MM_predict_state <= s_finishPredict;
								else
									MM_compareIdx <= MM_compareIdx + 1;
									MM_predict_state <= s_compare;
								end if;
							
							when s_finishPredict =>
								clk_en_compare <= '0';
								predictOut <= MM_predictedNumberTemp;
								MM_predict_state <= s_showResult;
								exeTimeFloat <= std_logic_vector(to_unsigned(exeTime, exeTimeFloat'length));
							when s_showResult =>
								
								LEDR <= std_logic_vector(to_unsigned(predictOut, predictOutSizeReference'length));
								--if SW(1) = '1' then --buraya resetlemek için bişi yaparız fln(hatta sw2 ile yeni resim girişini tetikleriz)
									
								MM_predict_state <= s_showResult;
						end case;
						
					end case;

			end if;
		end if;
	end process;
	


end d;
