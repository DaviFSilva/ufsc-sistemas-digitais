--------------------------------------------------
--	Author:      Ismael Seidel (entity)
--	Created:     May 1, 2025
--
--	Project:     Exercício 6 de INE5406
--	Description: Contém a descrição da entidade `sad_bc`, que representa o
--               bloco de controle (BC) do circuito para cálculo da soma das
--               diferenças absolutas (SAD - Sum of Absolute Differences).
--               Este bloco é responsável pela geração dos sinais de controle
--               necessários para coordenar o funcionamento do bloco operativo
--               (BO), como enable de registradores, seletores de multiplexadores,
--               sinais de início e término de processamento, etc.
--               A arquitetura é comportamental e deverá descrever uma máquina
--               de estados finitos (FSM) adequada ao controle do datapath.
--               Os sinais adicionais de controle devem ser definidos conforme
--               a necessidade do projeto. PS: já foram definidos nos slides
--               da aula 6T.
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.sad_pack.all;

-- Bloco de Controle (BC) do circuito SAD.
-- Responsável por gerar os sinais de controle para o bloco operativo (BO),
-- geralmente por meio de uma FSM.
entity sad_bc is
	port(
		clk     : in  std_logic; -- clock (sinal de relógio)
		rst_a   : in  std_logic; -- reset assíncrono ativo em nível alto
		enable  : in  std_logic; -- iniciar
		status  : in  sad_status_t;
		command : out sad_command_t;
		done    : out std_logic  -- pronto
	);
end entity;
-- Não altere o nome da entidade nem da arquitetura!

architecture behavior of sad_bc is
	-- A latência exigida pelo testbench é 3*(K+1)+1 ciclos entre o enable e
	-- o retorno de done=1 (K = amostras/paralelismo). Isso corresponde a:
	--   * 3 ciclos de inicialização (zera endereço e SAD);
	--   * 3 ciclos por amostra (lê, espera o dado, acumula e avança o endereço).
	-- O ciclo seguinte é o estado ocioso, com done = 1.
	-- Enquanto enable permanecer em 1, uma nova SAD começa no ciclo seguinte.
	type state_t is (
			s_idle,
			s_zera,
			s_zera_ok,
			s_prepara,
			s_le,
			s_espera,
			s_acumula
		);
	signal current_state : state_t := s_idle;
	signal next_state    : state_t;
begin
	-- 1) Carga e reset do registrador de estado.
	state_reg : process (clk, rst_a)
	begin
		if rst_a = '1' then
			current_state <= s_idle;
		elsif rising_edge(clk) then
			current_state <= next_state;
		end if;
	end process state_reg;

	-- 2) Lógica de próximo estado.
	next_state_logic : process (current_state, enable, status)
	begin
		next_state <= current_state;
		case current_state is
			when s_idle =>
				if enable = '1' then
					next_state <= s_zera;
				end if;
			when s_zera =>
				next_state <= s_zera_ok;
			when s_zera_ok =>
				next_state <= s_prepara;
			when s_prepara =>
				next_state <= s_le;
			when s_le =>
				next_state <= s_espera;
			when s_espera =>
				next_state <= s_acumula;
			when s_acumula =>
				if status.menor = '1' then
					next_state <= s_le;
				else
					next_state <= s_idle;
				end if;
		end case;
	end process next_state_logic;

	-- 3) Lógica de saída (Moore).
	output_logic : process (current_state)
		variable cmd : sad_command_t;
	begin
		cmd := (
				zi       => '0',
				ci       => '0',
				zs       => '0',
				cs       => '0',
				read_mem => '0'
			);
		done <= '0';

		case current_state is
			when s_idle =>
				done <= '1';
			when s_zera =>
				cmd.zi := '1';
				cmd.ci := '1';
				cmd.zs := '1';
				cmd.cs := '1';
			when s_zera_ok | s_prepara | s_espera =>
				null;
			when s_le =>
				cmd.read_mem := '1';
			when s_acumula =>
				cmd.ci := '1';
				cmd.cs := '1';
		end case;

		command <= cmd;
	end process output_logic;
end architecture;
