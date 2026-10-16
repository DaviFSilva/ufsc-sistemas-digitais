--------------------------------------------------
--	Author:      Ismael Seidel (entidade)
--	Created:     May 1, 2025
--
--	Project:     Exercício 6 de INE5406
--	Description: Contém a descrição da entidade `sad_bo`, que representa o
--               bloco operativo (BO) do circuito para cálculo da soma das
--               diferenças absolutas (SAD - Sum of Absolute Differences).
--               Este bloco implementa o *datapath* principal do circuito e
--               realiza operações como subtração, valor absoluto e acumulação
--               dos valores calculados. Além disso, também será feito aqui o
--               calculo de endereçamento e do sinal de controle do laço de
--               execução (menor), que deve ser enviado ao bloco de controle (i.e.,
--               menor será um sinal de status gerado no BO).
--               A parametrização é feita por meio do tipo
--               `datapath_configuration_t` definido no pacote `sad_pack`.
--               Os parâmetros incluem:
--               - `bits_per_sample`: número de bits por amostra; (uso obrigatório)
--               - `samples_per_block`: número total de amostras por bloco; (uso 
--                  opcional, útil para definição do número de bits da sad e 
--                  endereço, conforme feito no top-level, i.e., no arquivo sad.vhdl)
--               - `parallel_samples`: número de amostras processadas em paralelo.
--                  (uso opcional)
--               A arquitetura estrutural instanciará os componentes necessários
--               à implementação completa do bloco operativo.
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.sad_pack.all;

-- Bloco Operativo (BO) do circuito SAD.
-- Responsável pelo processamento aritmético dos dados de entrada, incluindo
-- subtração, cálculo de valor absoluto e soma acumulada.
-- Totalmente parametrizável por meio do tipo `datapath_configuration_t`.
entity sad_bo is
	generic(
		CFG : datapath_configuration_t := (
			bits_per_sample   => 8,  -- número de bits por amostra
			samples_per_block => 64, -- número total de amostras por bloco
			parallel_samples  => 1   -- paralelismo no processamento
		)
	);
	port(
		clk        : in  std_logic;
		sample_ori : in  std_logic_vector(CFG.bits_per_sample * CFG.parallel_samples - 1 downto 0);
		sample_can : in  std_logic_vector(CFG.bits_per_sample * CFG.parallel_samples - 1 downto 0);
		command    : in  sad_command_t;
		status     : out sad_status_t;
		address    : out std_logic_vector(address_length(
			samples_per_block => CFG.samples_per_block,
			parallel_samples  => CFG.parallel_samples
		) - 1 downto 0);
		sad_value  : out std_logic_vector(sad_length(
			bits_per_sample   => CFG.bits_per_sample,
			samples_per_block => CFG.samples_per_block
		) - 1 downto 0)
	);
end entity;
-- Não altere o nome da entidade! Como você quem irá instanciar, neste caso podes
-- mudar o nome da arquitetura, embora isso não seja necessário. 
-- A arquitetura será estrutural, composta por instâncias de componentes auxiliares.

architecture structure OF sad_bo is
	constant ADDR_W : positive := address_length(
			samples_per_block => CFG.samples_per_block,
			parallel_samples  => CFG.parallel_samples
		);
	constant SAD_W : positive := sad_length(
			bits_per_sample   => CFG.bits_per_sample,
			samples_per_block => CFG.samples_per_block
		);
	-- Último endereço válido: há (samples/parallel) posições, numeradas de 0 até LAST.
	constant LAST : natural := CFG.samples_per_block / CFG.parallel_samples - 1;
begin
	address_path : entity work.sad_address
		generic map(
			ADDR_W => ADDR_W,
			LAST   => LAST
		)
		port map(
			clk     => clk,
			zi      => command.zi,
			ci      => command.ci,
			address => address,
			menor   => status.menor
		);

	value_path : entity work.sad_calculator
		generic map(
			SAMPLE_W => CFG.bits_per_sample,
			SAD_W    => SAD_W,
			PARALLEL => CFG.parallel_samples
		)
		port map(
			clk        => clk,
			zs         => command.zs,
			cs         => command.cs,
			sample_ori => sample_ori,
			sample_can => sample_can,
			sad_value  => sad_value
		);
end architecture structure;
