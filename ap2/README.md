# AP2 — SAD v1 (Cyclone IV E)

Síntese da arquitetura SAD v1 descrita na AP1 (bloco de controle + bloco operativo). O top-level é a entidade `sad`, com os generics padrão da especificação: 8 bits por amostra, 64 amostras por bloco e 1 amostra por ciclo.

## Projeto

- Quartus Prime 25.1
- Família: Cyclone IV E
- Dispositivo: EP4CE40F29C7
- Simulador: Questa Altera FPGA
- Testbench: `sad_tb` (instância `DUV`), vetores `testing_sads_8.dat` e `testing_sads_10.dat` na mesma pasta do projeto
- Clock restringido em `sad.sdc` com período de 20 ns, o mesmo período do testbench

Os arquivos VHDL da síntese estão listados em `sad.qpf` / `sad.qsf` só pelo nome, sem diretório. A descrição usa VHDL-2008.

## Como compilar

1. Abrir `rtl/sad.qpf` no Quartus Prime 25.1.
2. Processing → Start Compilation.
3. A simulação no QuestaSim parte sozinha depois da compilação.

## Onde ler `resultados.json`

No Compilation Report:

- Flow Summary: `total combinational functions`, `dedicated logic registers`, `total pins`
- TimeQuest Timing Analyzer → Slow 1200mV 85C Model → Fmax Summary: `Fmax` do clock `clk`, em MHz

Esses campos estão preenchidos em `resultados.json` com a compilação de 16/10/2026: 51 funções combinacionais, 27 registradores, 41 pinos e Fmax de 348,19 MHz no modelo Slow 1200mV 85C. O resumo do fluxo também mostra 55 logic elements; esse total junta as funções combinacionais com os registradores e não entra no JSON.

## Organização

`sad_bc` é a FSM (registrador de estado, próximo estado e saídas). `sad_bo` instancia `sad_address` (endereço e `menor`) e `sad_calculator` (`|A-B|` e acumulador). Os dois se falam pelos records `sad_command_t` e `sad_status_t` de `sad_pack`.
