--------------------------------------------------
--	Author:      Ismael Seidel (entity)
--	Created:     May 1, 2025
--
--	Project:     Exercício 6 de INE5406
--	Description: Este pacote contém definições de tipos e funções auxiliares que
--               podem ser utilizadas no circuito para cálculo da soma das diferenças
--               absolutas (SAD - Sum of Absolute Differences). 
--               Atenção: Você pode incluir novos tipos e funções neste arquivo.
--                        Porém, não altere os tipos e funções já existentes, pois
--                        alguns testes podem ser utilizados na avaliação (tesbenches).
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package sad_pack is
    -- Declaração do tipo parallel_samples_vector. 
    -- Note que é um array que não tem tamanho especificado de unsigned, que por sua vez também
    -- é um array sem tamanho especificado. Assim, na declaração de um parallel_samples_vector é
    -- necessário especificar duas dimensões, uma para o número de elementos unsigned em paralelo 
    -- e outra para o número de elementos em unsigned. Por exemplo:
    -- signal oito_de_dez_bits_em_paralelo : parallel_samples_vector(0 to 7)(9 downto 0);
    type parallel_samples_vector_t is array (natural range <>) of unsigned;

    -- Função para conversão de std_logic_vector para parallel_samples_vector.
    -- Essa função auxiliar divide um std_logic_vector de comprimento PxN em P amostras de N 
    -- bits. Cada amostra é representada como um unsigned (veja a definição do tipo 
    -- parallel_samples_vector).
    function to_parallel_samples_vector(param : std_logic_vector; N : positive; P : positive) return parallel_samples_vector_t;

    -- Função para conversão de parallel_samples_vector para std_logic_vector.
    -- Essa função realiza a operação inversa da função anterior. A partir de um vetor de P
    -- amostras (cada uma com N bits), obtém um vetor de 1 dimensão concatenado contendo todas
    -- as amostras de forma sequencial.
    function to_std_logic_vector(param : parallel_samples_vector_t; N : positive; P : positive)
    return std_logic_vector;

    -- Tipo que armazena parâmetros de configuração do datapath.
    -- bits_per_sample: número de bits por amostra.
    -- samples_per_block: total de amostras por bloco a serem processadas.
    -- parallel_samples: grau de paralelismo (quantas amostras são processadas simultaneamente).
    type datapath_configuration_t is record
        bits_per_sample   : positive;
        samples_per_block : positive;
        parallel_samples  : positive;
    end record;

    -- Calcula o número de bits necessários para representar a soma de um número arbitrário
    -- de valores (number_of_values), cada um com um determinado número de bits (bits_per_value).
    -- O resultado é: bits_per_value + ceil(log2(number_of_values))
    function sum_of_values_length(bits_per_value : positive; number_of_values : positive)
    return positive;

    -- Calcula a largura total (número de bits) necessária para armazenar o resultado da SAD
    -- completa, ou seja, a soma de todas as diferenças absolutas das amostras de um par de blocos.
    function sad_length(bits_per_sample : positive; samples_per_block : positive)
    return positive;

    -- Calcula a largura necessária para armazenar uma SAD parcial, considerando apenas as
    -- diferenças de um subconjunto de amostras processadas em paralelo.
    function partial_sad_length(bits_per_sample : positive; parallel_samples : positive)
    return positive;

    -- Calcula o número de bits necessários para indexar todos os grupos parciais de amostras
    -- dentro de um bloco completo. O número de grupos é (samples_per_block / parallel_samples),
    -- e o resultado é o menor inteiro maior ou igual a log2 desse valor.
    function address_length(samples_per_block : positive; parallel_samples : positive)
    return positive;

	-- Comandos do bloco de controle para o bloco operativo.
	-- zi/ci controlam o registrador de endereço; zs/cs controlam o registrador da SAD.
	type sad_command_t is record
		zi       : std_logic; -- 1: carrega 0 no endereço
		ci       : std_logic; -- 1: habilita a carga do endereço
		zs       : std_logic; -- 1: carrega 0 na SAD
		cs       : std_logic; -- 1: habilita a carga da SAD
		read_mem : std_logic; -- ler
	end record;

	-- Status do bloco operativo para o bloco de controle.
	type sad_status_t is record
		menor : std_logic; -- 1 enquanto o endereço ainda não é o último do bloco
	end record;

end package sad_pack;

package body sad_pack is

    -- Implementação da função que converte um std_logic_vector para um vetor de amostras sem sinal.
    -- Entrada:
    --   param : vetor de P*N bits.
    --   N     : número de bits por amostra.
    --   P     : número de amostras.
    -- Saída:
    --   Vetor com P elementos do tipo unsigned(N-1 downto 0), extraídos sequencialmente.
    function to_parallel_samples_vector(param : std_logic_vector; N : positive; P : positive)
    return parallel_samples_vector_t is
        variable return_vector : parallel_samples_vector_t(0 to P - 1)(N - 1 downto 0);
    begin
        for i in return_vector'range loop
            -- Cada amostra é extraída como uma fatia de N bits do std_logic_vector de entrada (param).
            return_vector(i) := unsigned(param(N * (i + 1) - 1 downto N * i));
        end loop;
        return return_vector;
    end function to_parallel_samples_vector;

    -- Implementação da função que concatena um vetor de amostras em um único std_logic_vector.
    -- Entrada:
    --   param : vetor de P amostras, cada uma com N bits.
    --   N     : número de bits por amostra.
    --   P     : número de amostras.
    -- Saída:
    --   std_logic_vector de P*N bits, resultado da concatenação de todas as amostras.
    function to_std_logic_vector(param : parallel_samples_vector_t; N : positive; P : positive)
    return std_logic_vector is
        variable return_vector : std_logic_vector(N * P - 1 downto 0);
    begin
        for i in 0 to P - 1 loop
            return_vector(N * (i + 1) - 1 downto N * i) := std_logic_vector(param(i));
        end loop;
        return return_vector;
    end function to_std_logic_vector;

    -- Função que calcula o número de bits necessários para representar a soma de N (number_of_values) valores
    -- de 'bits_per_value' bits sem sinal. 
    function sum_of_values_length(bits_per_value : positive; number_of_values : positive)
    return positive is
    begin
        return integer(ceil(log2(real(number_of_values)))) + bits_per_value;
    end function sum_of_values_length;

    -- Função que retorna a largura total da saída da SAD completa.
    -- Internamente usa a função sum_of_values_length passando o número total de amostras.
    function sad_length(bits_per_sample : positive; samples_per_block : positive)
    return positive is
    begin
        return sum_of_values_length(bits_per_value => bits_per_sample, number_of_values => samples_per_block);
    end function sad_length;

    -- Função semelhante à anterior, mas para SAD parciais (paralelismo).
    function partial_sad_length(bits_per_sample : positive; parallel_samples : positive)
    return positive is
    begin
        return sum_of_values_length(bits_per_value => bits_per_sample, number_of_values => parallel_samples);
    end function partial_sad_length;

    -- Função que determina a largura do endereço (em bits) necessário para indexar os
    -- vetores parciais de P amostras. Calcula log2(samples_per_block / parallel_samples), com arredondamento.
    function address_length(samples_per_block : positive; parallel_samples : positive)
    return positive is
    begin
        return integer(ceil(log2(real(samples_per_block) / real(parallel_samples))));
    end function address_length;

end package body sad_pack;
