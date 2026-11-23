# Projeto Filtro FIR Passa-Baixa — Processamento Digital de Sinais (Prática 3)

Projeto completo de projeto, implementação, validação numérica e documentação técnica de um **Filtro FIR Passa-Baixa** para a disciplina de **Processamento Digital de Sinais (PDS)** do **SENAI CIMATEC**.

- **Professor:** Elio Pithon Sarno Filho
- **Entrega:** 02 de dezembro de 2026
- **Plataforma principal:** MATLAB (com *Signal Processing Toolbox*) e LaTeX
- **Idioma padrão do projeto:** Português (PT-BR) — código, comentários, gráficos, tabelas e relatório

---

## Documentação de Apoio

- **[Roteiro Oficial da Prática 3](docs/Roteiro_pra%CC%81tica3-1.pdf):** Enunciado original, especificações, requisitos das etapas e critérios de entrega.
- **[Roadmap de Implementação](docs/ROADMAP.md):** Plano detalhado por fases (Fases 0 a 9), checklists executáveis e cronograma até a entrega.
- **[Guia de Padrões para Agentes (AGENTS.md)](AGENTS.md):** Regras técnicas, convenções de código em português, restrições de cada etapa e protocolo de verificação por sessão.

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

## Escopo da Implementação

O projeto é organizado de forma modular em torno de seis etapas técnicas, um orquestrador automático em MATLAB e um relatório técnico em LaTeX:

1. **Etapa A — Projeto por Janelamento (`src/etapa_A_janelamento.m`):**
   - Estimativa inicial do comprimento para janela de Hamming seguida de varredura de comprimentos **pares e ímpares** para encontrar o menor $N$ que atende simultaneamente às exigências da máscara.
   - Síntese da resposta impulsiva ideal centrada em $(N-1)/2$, janelamento Hamming, normalização unitária em DC (`h = h / sum(h)`), verificação de simetria e atraso de grupo, e salvamento em `data/coeficientes_FIR.mat`.
2. **Etapa A2 — Filter Designer (`src/etapa_A2_equiripple.m`):**
   - Conferência do filtro de janelamento na GUI `filterDesigner` (magnitude, fase, atraso de grupo e zeros) e projeto de um filtro *Equiripple* de ordem mínima apenas para comparação de custo computacional e distribuição de *ripple*.
3. **Etapa B — Buffer Circular (`src/fir_circular.m` e `src/etapa_B_validacao.m`):**
   - Implementação amostra a amostra sem uso de `filter()`, seguindo a convenção de numeração horária do buffer, leitura em direção horária e avanço da posição de escrita em direção anti-horária.
   - Validação com impulso unitário e soma de duas senoides ($500\text{ Hz}$ e $3.000\text{ Hz}$) comparada contra `filter(h, 1, x)` e verificação dos ganhos via `freqz`.
4. **Etapa C — Quantização dos Coeficientes (`src/etapa_C_quant_coef.m`):**
   - Análise isolada da quantização de `h` em **Q1.7** e **Q1.15** por arredondamento (sem renormalização), avaliando erro máximo, EQM, coeficientes zerados, preservação de simetria/fase linear, ganho DC e atendimento à máscara.
5. **Etapa D — Quantização das Amostras de Entrada (`src/etapa_D_quant_amostras.m`):**
   - Quantização de dois sinais senoidais de teste ($800$ amostras a $F_s = 8.000\text{ Hz}$) em Q1.7 com arredondamento e saturação em $[-1,\; 1 - 2^{-7}]$, avaliando erro frente a $\pm \Delta/2$, periodicidade do erro e variação de SNR na entrada e na saída (com exclusão do transitório inicial).
6. **Etapa E — Precisão Aritmética e Overflow (`src/etapa_E_ponto_fixo.m`):**
   - Demonstração numérica do produto de dois operandos Q1.7 (produto completo Q2.14 vs arredondamento vs truncamento), crescimento de palavra no acumulador, limite BIBO via $\sum |h[k]|$ e distinção entre saturação e *wrap-around*.
7. **Relatório Final (`report/main.tex`):**
   - Documento conciso em LaTeX com cabeçalho institucional, metodologia, figuras vetoriais, diagrama TikZ do buffer circular, tabelas preenchidas a partir dos resultados reais do MATLAB e conclusão nos cinco eixos solicitados.

---

## Estrutura Planejada do Repositório

```text
Filtro-FIR/
├── AGENTS.md                   # Convenções obrigatórias para agentes e código
├── README.md                   # Visão geral do projeto
├── docs/                       # Roteiro oficial, ROADMAP.md e PROMPTS_FASES.md
├── src/                        # Scripts MATLAB por etapa + fir_circular.m + utils/
├── data/                       # Arquivos .mat (coeficientes_FIR.mat e equiripple)
├── figures/                    # Gráficos gerados automaticamente (.pdf e .png)
├── results/                    # Tabelas (.csv/.tex) e resumos numéricos
├── report/                     # Código-fonte LaTeX do relatório final
└── entrega/                    # Pacote final reproduzível (PDF + .m + .mat)
```

---

## Como Executar

### 1. Simulação completa em MATLAB
A partir da raiz do repositório ou da pasta `src/`:

```matlab
% Executa todas as etapas (A, A2, B, C, D e E) sem intervenção manual
run('src/main.m')
```

Ou via terminal (modo *headless* no macOS/Linux):

```bash
matlab -batch "run('src/main.m')"
```

### 2. Compilação do Relatório LaTeX (Overleaf ou Local)
O arquivo único `report/main.tex` é compatível diretamente com o **Overleaf** (basta subir `report/main.tex` e a pasta `figures/`). Caso compile localmente após gerar as figuras:

```bash
cd report
pdflatex -interaction=nonstopmode main.tex
pdflatex -interaction=nonstopmode main.tex
```
