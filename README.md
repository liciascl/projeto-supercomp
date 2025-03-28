# Projeto - Minerador de Hashes

Este projeto é um minerador de hashes em **C++** que simula um processo de **proof-of-work** similar ao usado na mineração de criptomoedas. O código permite a **busca de um hash válida** a partir de transações lidas de arquivos e a tentativa de encontrar um **nonce correto** para gerar um hash que atenda a um critério de dificuldade.

No repositório tem três implementações prontas:

- Um minerador **sequencial** de transações **síncronas**
- Um gerador de **transações síncronas**, com 30 transações fixas.
- Um gerador de **transações assíncronas**, com quantidade e intervalo de transações aleatórios.

### Para executar o gerador de transações síncronas:

Se você estiver em um ambiente HPC, carregue os módulos

```cpp
# Se estiver no SDumont
module load gcc/12.4.0_sequana
```

Compile o código e gere o binário:

```cpp
 g++ sync_generator.cpp -o sync_generator -lssl -lcrypto
```

Execute o binário:

```cpp
./sync_generator
```

Você deve ter uma saída parecida com essa:

![image.png](imgs/image.png)

O conteúdo de cada bloco é:

```cpp
ID: tx_1
Timestamp: 2025-03-28 11:24:55
Conteúdo: txcVfYs819MPNETO9zPS
Hash: 435a03ab073f14a6f80591affbfde6b98d1945de0749e633f1e2c9ff34f8b06d
...
...
...
ID: tx_30
Timestamp: 2025-03-28 11:24:55
Conteúdo: w5sNqOPnBNm4iwnQeXS3
Hash: c96958b686b92597528f3666e56963b62194a4bdaa2ecee3329f4f6c47fb577c

```

### Para o gerador de transações assíncronas, siga o mesmo processo com o código async_generator.cpp

### Para realizar a mineração sequêncial

Garanta que os módulos estão carregados:

```cpp
# Se estiver no SDumont
module load gcc/12.4.0_sequana
```

Compile o código e gere o binário:

```cpp
g++ miner_sync_seq.cpp -o miner_sync_seq -lssl -lcrypto
```

Execute o binário via srun, o comando abaixo solicita ao slurm:

- 1 CPU,
- 1 tarefa por CPU,
- por 20 minutos (tempo máximo disponível na fila sequana_cpu_dev),
- salva o output em miner_seq_4_código_do_job
- Executa o miner_seq com 4 zeros a esquerda

```cpp
time srun   --partition=sequana_cpu_dev   --nodes=1   --ntasks-per-node=1   --time=00:20:00  --output=miner_seq_5_%j   .
/miner_seq 4
```

Você deve ver algo parecido com:

![image.png](imgs/image1.png)

E dentro do arquivo de output:

![image.png](imgs/image2.png)

Se você der o comando no terminal do SDumont:

```cpp
sacctmgr list user $USER -s format=partition%20,MaxJobs,MaxSubmit,MaxNodes,MaxCPUs,MaxWall
```

Terá acesso aos recursos habilitados para uso com o seu login:

![image.png](imgs/image3.png)

## **Critérios de Avaliação**

### **Rubrica D**

- Executa o código minerador síncrono, no cluster **Franky**
- Com dificuldade **5 zeros**
- Gera relatório com explicação, tempo de execução e recursos SLURM utilizados

### **Rubrica D+**

- Cumpre todos os requisitos da Rubrica D
- Executa no cluster **SDumont**
- Explica diferenças de execução, desempenho e configurações entre os ambientes

### Rúbrica C

- Executa o código minerador **assíncrono**, no cluster **Franky**
- Com dificuldade **5 zeros, com pelo menos 5 gerações diferentes de async_gen**
- Gera relatório com explicação, tempos de execução e recursos SLURM utilizados

### **Rubrica C+**

- Cumpre todos os requisitos da Rubrica C
- Executa no cluster  **SDumont**
- Explica diferenças de execução, desempenho e configurações entre os ambientes

### **Rubrica B**

- Executa o código minerador **assíncrono**, no cluster **SDumont**
- Com dificuldade **6 zeros, com pelo menos 5 gerações diferentes de async_gen**
- Usa pelo pelo menos uma estratégia de otimização **em CPU** (MPI e OpenMP) no código.
- Gera relatório com explicação, tempos de execução e recursos SLURM utilizados
- Explica diferenças de execução, desempenho e configurações entre os ambientes

### **Rubrica B+**

- Cumpre todos os requisitos da Rubrica B
- Usa as duas estratégias de otimização, MPI e OpenMP

### **Rubrica A**

- Executa o código minerador **assíncrono**, no cluster **SDumont**
- Com dificuldade **7 zeros, com pelo menos 5 gerações diferentes de async_gen**
- Usa pelo pelo menos uma estratégia de otimização em **GPU** no código.
- Gera relatório com explicação, tempos de execução e recursos SLURM utilizados
- Explica diferenças de execução, desempenho e configurações entre os ambientes

### **Rubrica A+**

- Cumpre todos os requisitos da Rubrica A
- Usa uma estratégia de otimização híbrida, partes do código paralelizado em CPU, partes do código em GPU.
- Apresenta **análise comparativa** completa entre as estratégias de otimização, ambientes e arquiteturas.

## **📌 Entregáveis**

GitHub-Classroom contendo:

- Implementações
- Scripts SLURM utilizados
- Evidências (prints, logs, etc..)
- Relatório técnico contendo:
    
    - Explicação do funcionamento do código
    
    - Tempo de execução
    
    - Estratégias computacionais utilizadas (CPU/GPU, etc.)
    
    - Discussão sobre os recursos solicitados via SLURM
    
    - Comparação entre ambientes
