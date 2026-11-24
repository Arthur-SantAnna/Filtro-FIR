# Projeto Filtro FIR Passa-Baixa — Processamento Digital de Sinais (Prática 3)

Projeto de implementação, validação numérica e documentação técnica de um **Filtro FIR Passa-Baixa** para a disciplina de **Processamento Digital de Sinais (PDS)** do **SENAI CIMATEC**.

- **Professor:** Elio Pithon Sarno Filho
- **Entrega:** 02 de dezembro de 2026
- **Plataforma principal:** MATLAB (com *Signal Processing Toolbox*) e LaTeX (Overleaf)
- **Idioma padrão:** Português (PT-BR) em todo o código, comentários, figuras, tabelas e relatório
- **Status atual:** **Fases 0 a 8 concluídas** (código MATLAB validado ponta a ponta via `src/main.m` e relatório completo em `report/main.tex`); pendente apenas a **Fase 9** (compilação final do PDF no Overleaf, auditoria e empacotamento em `entrega/`).

---

## Documentação de Referência

- **[Roteiro Oficial da Prática 3](docs/Roteiro_pra%CC%81tica3-1.pdf):** Enunciado original, especificações, requisitos das etapas e critérios de entrega.
- **[Roadmap de Implementação](docs/ROADMAP.md):** Plano detalhado por fases (Fases 0 a 9), checklists concluídos e histórico dos valores numéricos obtidos.
- **[Guia de Padrões para Agentes (AGENTS.md)](AGENTS.md):** Regras técnicas, convenções de código e restrições obrigatórias por etapa.

---

## Especificações do Filtro

| Parâmetro | Valor |
| :--- | :--- |
| Frequência de amostragem ($F_s$) | $8.000\text{ Hz}$ |
| Banda passante | $0$ a $1.000\text{ Hz}$ |
| Desvio máximo na banda passante | $\pm 0{,}1\text{ dB}$ em relação a $0\text{ dB}$ |
| Banda de rejeição | $2.200$ a $4.000\text{ Hz}$ |
| Atenuação mínima na rejeição | $45\text{ dB}$ |
| Banda de transição | $1.000$ a $2.200\text{ Hz}$ ($\Delta f = 1.200\text{ Hz}$) |
| Frequência de corte ideal inicial ($f_c$) | $1.600\text{ Hz}$ (centro da transição) |
| Método principal | Série de Fourier + janela de Hamming |

---

## Implementação e Principais Resultados

Todas as etapas estão implementadas de forma modular em `src/` e consolidadas no orquestrador [main.m](src/main.m), com base única de parâmetros em [config_specs.m](src/config_specs.m) e avaliação espectral compartilhada em [avaliar_mascara.m](src/utils/avaliar_mascara.m) (`Nfft = 32.768` pontos):

1. **Etapa A — Projeto por Janelamento ([etapa_A_janelamento.m](src/etapa_A_janelamento.m)):**
   - Varredura de comprimentos pares e ímpares ($N = 15$ a $45$) após estimativa inicial ($N_{\text{est}} = 22$ pelo fator $3{,}3$; alternativa $27$ pelo fator $4{,}0$).
   - **Filtro selecionado:** $N = 23$ coeficientes (ordem $M = 22$), desvio máximo na passante $= 0{,}042323\text{ dB}$, atenuação mínima na rejeição $= 47{,}0065\text{ dB}$, soma unitária ($\sum h[k] = 1$, ganho DC $= 0\text{ dB}$), erro de simetria $= 0$ e atraso de grupo $= 11{,}0\text{ amostras}$ ($1{,}3750\text{ ms}$).
   - Coeficientes salvos em `data/coeficientes_FIR.mat`.

2. **Etapa A2 — *Filter Designer* e Comparação *Equiripple* ([etapa_A2_equiripple.m](src/etapa_A2_equiripple.m)):**
   - Carrega `data/coeficientes_equiripple.mat` exportado do *Filter Designer* (com *fallback* automático via `firpmord`/`firpm` caso ausente) sem substituir `h` nas etapas seguintes.
   - **Equiripple (ordem mínima):** $N_{\text{eq}} = 15$ coeficientes (ordem $M_{\text{eq}} = 14$), desvio $= 0{,}083846\text{ dB}$, atenuação $= 46{,}5690\text{ dB}$, atraso de grupo $= 7{,}0\text{ amostras}$ ($0{,}8750\text{ ms}$) — redução de **34,78%** no custo computacional por amostra ($15$ vs $23$ MACs/amostra).

3. **Etapa B — Buffer Circular ([fir_circular.m](src/fir_circular.m) e [etapa_B_validacao.m](src/etapa_B_validacao.m)):**
   - Implementação amostra a amostra sem chamadas a `filter`, `conv` ou `fftfilt`, com buffer numerado em sentido horário (`1..N`), avanço de escrita em sentido anti-horário e leitura em sentido horário a partir de `idx_recente` com índice auxiliar separado.
   - Validação frente a `filter(h, 1, x)`: erro absoluto máximo de `0` no impulso unitário e `3,330669e-16` no sinal de duas senoides ($500\text{ Hz} + 3.000\text{ Hz}$). Ganhos via `freqz`: $-0{,}018814\text{ dB}$ em $500\text{ Hz}$ e $-52{,}5783\text{ dB}$ em $3.000\text{ Hz}$.

4. **Etapa C — Quantização dos Coeficientes ([etapa_C_quant_coef.m](src/etapa_C_quant_coef.m)):**
   - Quantização isolada por arredondamento em **Q1.15** e **Q1.7** sem renormalização.
   - **Q1.15:** preserva a máscara ($0{,}042440\text{ dB}$ / $46{,}9752\text{ dB}$, $\text{EQM} = 9{,}057312\times 10^{-11}$, $4$ zeros analíticos).
   - **Q1.7:** reprova em ambas as bandas ($0{,}205999\text{ dB}$ / $39{,}8632\text{ dB}$, $\text{EQM} = 2{,}260906\times 10^{-6}$, $6$ zeros incluindo os coeficientes periféricos $k=0$ e $k=22$). Ambas as versões preservam simetria exata (erro $= 0$) e fase linear.

5. **Etapa D — Quantização das Amostras de Entrada ([etapa_D_quant_amostras.m](src/etapa_D_quant_amostras.m)):**
   - Quantização Q1.7 com arredondamento e saturação em $[-1,\; 1 - 2^{-7}]$ aplicada a dois sinais de $800$ amostras ($F_s = 8.000\text{ Hz}$), com exclusão das primeiras $32$ amostras de transitório ($n = 32\dots 799$, $48$ ciclos exatos de $16$ amostras).
   - **Caso 1 ($500\text{ Hz}$):** $\text{SNR}_{\text{in}} = 46{,}8120\text{ dB} \to \text{SNR}_{\text{out}} = 55{,}8395\text{ dB}$ ($\Delta\text{SNR} = +9{,}0275\text{ dB}$).
   - **Caso 2 ($500\text{ Hz} + 3.000\text{ Hz}$):** $\text{SNR}_{\text{in}} = 46{,}8428\text{ dB} \to \text{SNR}_{\text{out}} = 57{,}7056\text{ dB}$ ($\Delta\text{SNR} = +10{,}8628\text{ dB}$, com queda simultânea da potência do sinal útil pela rejeição de $3.000\text{ Hz}$).

6. **Etapa E — Precisão Aritmética e *Overflow* ([etapa_E_ponto_fixo.m](src/etapa_E_ponto_fixo.m)):**
   - Comparação numérica em Q1.7 ($79/128 \times 45/128$) entre produto completo em Q2.14, arredondamento (`round`) e truncamento (`floor`), cálculo da norma $\ell_1$ ($\sum |h[k]| = 1{,}473395$, $1$ bit de guarda pela norma ou $5$ bits no pior caso genérico) e exemplo de saturação vs *wrap-around*.

7. **Relatório Técnico LaTeX ([main.tex](report/main.tex)):**
   - Arquivo único autocontido pronto para o **Overleaf**, com diagrama TikZ do buffer circular embutido, 8 figuras vetoriais PDF, 9 tabelas, respostas às questões interpretativas e conclusão técnica estruturada nos 5 eixos solicitados pelo roteiro.

---

## Estrutura do Repositório

```text
Filtro-FIR/
├── AGENTS.md                           # Convenções e regras técnicas do projeto
├── README.md                           # Documentação geral do repositório
├── LICENSE
├── docs/
│   ├── Roteiro_prática3-1.pdf          # Especificação oficial da Prática 3
│   └── ROADMAP.md                      # Plano, checklists e métricas registradas
├── src/
│   ├── main.m                          # Orquestrador ponta a ponta (Etapas A → E)
│   ├── config_specs.m                  # Especificações do filtro e caminhos portáveis
│   ├── fir_circular.m                  # Filtragem FIR com buffer circular
│   ├── etapa_A_janelamento.m           # Etapa A: Série de Fourier + Hamming
│   ├── etapa_A2_equiripple.m           # Etapa A2: Comparação com Equiripple
│   ├── etapa_B_validacao.m             # Etapa B: Validação do buffer circular
│   ├── etapa_C_quant_coef.m            # Etapa C: Quantização de coeficientes (Q1.7/Q1.15)
│   ├── etapa_D_quant_amostras.m        # Etapa D: Quantização de amostras Q1.7 e SNR
│   ├── etapa_E_ponto_fixo.m            # Etapa E: Precisão aritmética e overflow
│   └── utils/
│       ├── avaliar_mascara.m           # Avaliação espectral frente à máscara
│       └── salvar_figura.m             # Padronização e exportação (.pdf e .png)
├── data/
│   ├── coeficientes_FIR.mat            # Coeficientes e metadados do filtro Hamming (N=23)
│   └── coeficientes_equiripple.mat     # Coeficientes Equiripple exportados (N=15)
├── figures/                            # 8 figuras em .pdf (vetorial) e .png (300 dpi)
├── results/                            # Tabelas .csv, resumo_metricas.txt e metricas_relatorio.tex
├── report/
│   └── main.tex                        # Relatório LaTeX autocontido (Overleaf)
└── entrega/                            # Pacote final (a montar na Fase 9)
```

---

## Como Executar

### 1. Pipeline completo em MATLAB (sem intervenção manual)
A partir da raiz do repositório:

```matlab
run('src/main.m')
```

Ou via terminal (modo *headless*):

```bash
matlab -batch "run('src/main.m')"
```

A execução regenera automaticamente os arquivos `.mat` (preservando `coeficientes_equiripple.mat`), todas as tabelas em `results/`, os resumos `resumo_metricas.txt` e `metricas_relatorio.tex`, e todas as figuras `.pdf` e `.png` em `figures/`.

### 2. Compilação do Relatório no Overleaf
1. Crie um projeto no Overleaf com compilador **`pdfLaTeX`**.
2. Faça upload de [report/main.tex](report/main.tex) para a raiz do projeto.
3. Crie uma pasta `figures/` no Overleaf e envie os 8 arquivos `.pdf` contidos em `figures/` (ou compile localmente com `pdflatex` dentro de `report/`).
