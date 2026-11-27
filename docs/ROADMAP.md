# Roadmap de Implementação — Projeto Filtro FIR Passa-Baixa (PDS / Prática 3)

**Disciplina:** Processamento Digital de Sinais (SENAI CIMATEC)  
**Professor:** Elio Pithon Sarno Filho  
**Data de Entrega:** 02 de dezembro de 2026  
**Referência:** [Roteiro_prática3-1.pdf](./Roteiro_prática3-1.pdf)

---

## 1. Visão Geral e Decisões de Arquitetura

Este roadmap cobre todo o ciclo de desenvolvimento do projeto: configuração do repositório, implementação modular em MATLAB (com suporte ao *Filter Designer*), geração automatizada de gráficos e tabelas, validação numérica, redação em LaTeX e empacotamento final da entrega.

### Decisões Definidas
- **Ambiente principal:** MATLAB completo local (com *Signal Processing Toolbox*).
- **Estrutura de código:** Modular por etapa com orquestrador central (`src/main.m`), executável sem intervenção manual relevante e exportando figuras/tabelas automaticamente.
- **Busca de ordem (Etapa A):** Fórmula de estimativa inicial de referência $N \approx \frac{3{,}3}{\Delta f / F_s}$ ($\Delta\omega \approx \frac{6{,}6\pi}{M}$ — verificar nos slides de aula se o docente utilizou $3{,}3$ ou $4$) seguida de varredura incluindo comprimentos **pares e ímpares** para encontrar o menor $N$ absoluto que atende à máscara.
- **Integração do Filter Designer (Etapa A2):** Uso interativo da GUI para conferência do filtro de janelamento e geração/exportação dos coeficientes *Equiripple* em `.mat` (`data/coeficientes_equiripple.mat`), carregado automaticamente pelos scripts (com *fallback* opcional via `firpmord`/`firpm` caso o `.mat` ainda não exista).
- **Relatório:** LaTeX técnico conciso em arquivo único autocontido (`report/main.tex`) pensado para edição e exportação no **Overleaf** (cabeçalho SENAI CIMATEC, figuras em PDF/PNG de alta resolução, diagrama do buffer circular em TikZ embutido e tabelas preenchidas com precisão consistente aos scripts).

---

## 2. Estrutura de Diretórios Planejada

```text
Filtro-FIR/
├── README.md
├── LICENSE
├── docs/
│   ├── Roteiro_prática3-1.pdf
│   └── ROADMAP.md
├── src/
│   ├── main.m                  # Orquestrador: executa Etapas A → E sem intervenção manual
│   ├── config_specs.m          # Constantes e especificações do filtro (Fs, Fpass, Fstop, etc.)
│   ├── fir_circular.m          # Função da Etapa B (buffer circular amostra a amostra)
│   ├── etapa_A_janelamento.m   # Projeto por série de Fourier + janela de Hamming
│   ├── etapa_A2_equiripple.m   # Comparação Janelamento vs Equiripple (Filter Designer)
│   ├── etapa_B_validacao.m     # Testes da fir_circular vs filter() e ganhos via freqz
│   ├── etapa_C_quant_coef.m    # Quantização de coeficientes (Q1.7 e Q1.15)
│   ├── etapa_D_quant_amostras.m# Quantização de amostras de entrada (Q1.7) e análise de SNR
│   ├── etapa_E_ponto_fixo.m    # Exemplo numérico Q1.7 (produto, arredondamento, truncamento)
│   └── utils/
│       ├── avaliar_mascara.m   # Helper: calcula desvio na passante, atenuação na rejeição e status
│       └── salvar_figura.m     # Helper: padroniza fontes, grid, margens e exportação PDF/PNG
├── data/
│   ├── coeficientes_FIR.mat        # Vetor h final (e metadados: N, ordem, atraso de grupo)
│   └── coeficientes_equiripple.mat # Exportado do Filter Designer (Etapa A2)
├── figures/                    # Figuras exportadas automaticamente (300 dpi PNG / vetorial PDF)
├── results/                    # Tabelas exportadas (.csv / .tex / resumo_metricas.txt)
├── report/
│   └── main.tex                # Documento LaTeX único autocontido (pronto para Overleaf)
└── entrega/                    # Pasta limpa montada ao final com PDF + .m + .mat para envio
```

> **Atenção sobre a pasta `entrega/`:** O roteiro exige o arquivo `coeficientes_FIR.mat` e os arquivos `.m` necessários à reprodução dos resultados. Ao montar a entrega final, garantir que `main.m` funcione tanto na estrutura completa do repositório quanto se os `.m` e `.mat` forem colocados juntos no mesmo diretório de avaliação pelo professor (usar resolução de caminhos relativa inteligente no `main.m`).

---

## 3. Especificações de Referência (Base Única)

| Parâmetro | Símbolo | Valor | Unidade |
| :--- | :---: | :---: | :---: |
| Frequência de amostragem | $F_s$ | $8.000$ | Hz |
| Banda passante | $[0, F_{\text{pass}}]$ | $0$ a $1.000$ | Hz |
| Desvio máximo na banda passante | $\delta_p$ (dB) | $\pm 0{,}1$ (em torno de $0\text{ dB}$) | dB |
| Banda de rejeição | $[F_{\text{stop}}, F_s/2]$ | $2.200$ a $4.000$ | Hz |
| Atenuação mínima na rejeição | $A_s$ | $45$ | dB |
| Banda de transição | $\Delta f$ | $1.000$ a $2.200$ ($1.200\text{ Hz}$) | Hz |
| Frequência de corte ideal inicial | $f_c$ | $1.600$ | Hz |

---

## 4. Roadmap Técnico Detalhado por Fase

### Fase 0 — Setup do Repositório e Infraestrutura Base
**Objetivo:** Preparar ambiente MATLAB, estrutura de diretórios e funções utilitárias compartilhadas antes de implementar as etapas de PDS.

- [x] Criar a árvore de diretórios (`src/`, `src/utils/`, `data/`, `figures/`, `results/`, `report/`, `entrega/`).
- [x] Criar `src/config_specs.m` centralizando todas as constantes com comentários e unidades claras (`Fs = 8000; % [Hz]`, `Fpass = 1000; % [Hz]`, `Fstop = 2200; % [Hz]`, `fc = 1600; % [Hz]`, `tol_pass_dB = 0.1; % [dB]`, `aten_stop_dB = 45; % [dB]`).
- [x] Criar `src/utils/avaliar_mascara.m`:
  - Entrada: vetor de coeficientes `h`, parâmetros da máscara, grade densa de frequência (ex.: `Nfft = 16384` ou `32768` pontos em `[0, Fs/2]`).
  - Saída: `desvio_pass_max_dB` ($\max |20\log_{10}|H(f)||$ na faixa $[0, 1000]\text{ Hz}$), `aten_stop_min_dB` ($\min (-20\log_{10}|H(f)|)$ na faixa $[2200, 4000]\text{ Hz}$), `ganho_dc_dB` e booleano `atende_mascara`.
  - **Cuidado crítico:** Usar grade de frequência suficientemente densa (`>= 16384` pontos) para não perder picos estreitos de ripple próximos às bordas de $1.000\text{ Hz}$ e $2.200\text{ Hz}$.
- [x] Criar `src/utils/salvar_figura.m` para padronizar tamanho, fonte legível, legendas, grid e exportação automática em `.png` (300 dpi) e `.pdf` (vetorial para LaTeX).

---

### Fase 1 — Etapa A: Projeto por Janelamento (Série de Fourier + Hamming) [CONCLUÍDA]
**Script:** `src/etapa_A_janelamento.m`

- [x] Calcular $\Delta f = 1.200\text{ Hz}$, $\Delta\omega = 0{,}3\pi\text{ rad/amostra}$ e estimativa inicial ($N_{\text{est}} = 22$ para fator $3{,}3$; $N_{\text{est,alt}} = 27$ para fator $4{,}0$).
- [x] Varredura de comprimentos pares e ímpares ($N = 15$ a $45$) com tratamento explícito de $n = (N-1)/2$, janela de Hamming e normalização `h = h / sum(h)`.
- [x] Seleção do menor comprimento válido ($N = 23$, ordem $M = 22$) e exportação de `results/tab_A1_varredura_N.csv`, `results/tab_A2_metricas_finais.csv` e `data/coeficientes_FIR.mat`.
- [x] Geração das figuras `figures/fig_A1_impulso_janela` e `figures/fig_A2_magnitude_mascara` (`.pdf` e `.png`).

> **Resumo dos Valores Numéricos Obtidos (Fase 1 / Etapa A):**
> - $\Delta f = 1.200\text{ Hz}$, $\Delta\omega = 0{,}3\pi\text{ rad/amostra} \approx 0{,}942478\text{ rad/amostra}$
> - Estimativa inicial: $N_{\text{est}} = \lceil 3{,}3 / 0{,}15 \rceil = 22$ (fator $3{,}3$) | $N_{\text{est,alt}} = \lceil 4{,}0 / 0{,}15 \rceil = 27$ (fator $4{,}0$)
> - **Menor comprimento aprovado:** $N = 23$ coeficientes (ímpar, **Ordem $M = 22$**)
>   - *(Nota: $N = 21$ e $N = 22$ atendem à banda passante com $0{,}0637\text{ dB}$ e $0{,}0440\text{ dB}$, mas reprovam na rejeição com $40{,}6091\text{ dB}$ e $44{,}0615\text{ dB} < 45\text{ dB}$ na borda de $2.200\text{ Hz}$.)*
> - **Desvio máximo na banda passante ($N=23$):** $0{,}042323\text{ dB}$ ($\le 0{,}10\text{ dB}$)
> - **Atenuação mínima na banda de rejeição ($N=23$):** $47{,}0065\text{ dB}$ ($\ge 45{,}00\text{ dB}$)
> - **Soma dos coeficientes $\sum h[k]$:** $1{,}0000000000000000$ (Ganho DC $= 0{,}0000\text{ dB}$)
> - **Erro máximo de simetria $\max |h[k] - h[N-1-k]|$:** $0$ (`0.0000e+00`)
> - **Atraso de grupo constante:** $\tau_g = 11{,}0\text{ amostras} = 1{,}3750\text{ ms}$

#### Procedimentos de Código
1. Calcular $\Delta f = F_{\text{stop}} - F_{\text{pass}} = 1.200\text{ Hz}$ e $\Delta\omega = \frac{2\pi\Delta f}{F_s} = 0{,}3\pi\text{ rad/amostra}$.
2. Calcular a estimativa inicial $N_{\text{est}}$ (ex.: $N_{\text{est}} = \lceil 3{,}3 / (\Delta f / F_s) \rceil = 22$; conferir nos slides da disciplina se o fator usado em aula foi $3{,}3$ ou $4$ e registrar a fórmula exata no script/relatório).
3. Implementar função local de síntese do filtro:
   - Vetor de índices $n = 0, 1, \dots, N-1$, centro de simetria $\alpha = \frac{N-1}{2}$.
   - Resposta impulsiva ideal passa-baixa:
     $$h_{\text{ideal}}[n] = \frac{\sin\big(\omega_c (n - \alpha)\big)}{\pi (n - \alpha)}, \quad \text{com } h_{\text{ideal}}[\alpha] = \frac{\omega_c}{\pi} = \frac{2 f_c}{F_s}$$
     onde $\omega_c = 2\pi f_c / F_s$ (tratar explicitamente o caso $n = \alpha$ quando $N$ for ímpar para evitar `0/0 = NaN`).
   - Aplicar janela de Hamming `w = hamming(N)` (funciona tanto para $N$ par quanto $N$ ímpar).
   - Normalizar: `h = h_win / sum(h_win)`.
4. **Varredura de comprimentos $N$ (pares e ímpares):**
   - Testar uma faixa ampla ao redor de $N_{\text{est}}$ (por exemplo, de $N = 15$ até $N = 45$, passo $1$).
   - Para cada $N$, chamar `avaliar_mascara` e registrar em tabela: `N`, `Ordem (N-1)`, `Desvio_Pass_dB`, `Aten_Stop_dB`, `Atende_Pass`, `Atende_Stop`, `Atende_Geral`.
   - Selecionar automaticamente o **menor $N$** que satisfaz simultaneamente ambas as exigências (incluindo comprimentos que falharam na tabela de registro).
5. Para o $N$ selecionado, calcular e registrar:
   - Soma dos coeficientes: `sum(h)` (deve ser $1$ dentro da precisão numérica).
   - Erro máximo de simetria: `max(abs(h - fliplr(h)))`.
   - Atraso de grupo: $\tau_g = \frac{N-1}{2}$ em amostras, e $\tau_{g,\text{ms}} = \frac{(N-1)}{2 F_s} \times 1000$ em milissegundos.
6. Salvar `h`, `N`, `ordem`, `Fs`, `fc`, `tau_amostras`, `tau_ms` em `data/coeficientes_FIR.mat`.

#### Gráficos e Tabelas Gerados
- `fig_A1_impulso_janela`: subplots ou sobreposição com $h_{\text{ideal}}[k]$, janela de Hamming $w[k]$ e coeficientes finais $h[k]$ (usar `stem`).
- `fig_A2_magnitude_mascara`: resposta em magnitude $|H(f)|_{\text{dB}}$ de $0$ a $4.000\text{ Hz}$ com linhas tracejadas da máscara ($\pm 0{,}1\text{ dB}$ em $[0, 1000]\text{ Hz}$; $-45\text{ dB}$ em $[2200, 4000]\text{ Hz}$) + subplots com **ampliação (zoom)** da banda passante e da banda de rejeição.
- `tab_A1_varredura_N.csv`: tabela completa dos comprimentos testados (aprovados e reprovados).
- `tab_A2_metricas_finais.csv`: $N$, ordem, soma dos coeficientes, erro de simetria, atraso de grupo (amostras e ms).

#### Pontos de Análise Obrigatórios para o Relatório
- Por que a estimativa inicial da largura da transição não garante automaticamente o cumprimento da máscara (ela estima a largura do lóbulo principal/transição aproximada, mas não controla isoladamente o *ripple* exato na borda de $1.000\text{ Hz}$ nem a atenuação combinada com a escolha de $f_c$).
- Justificativa do comprimento $N$ selecionado (menor $N$ testado que cumpre simultaneamente $\pm 0{,}1\text{ dB}$ e $\ge 45\text{ dB}$).
- Função da normalização `h = h/sum(h)` (garantir ganho unitário em DC, $H(0) = 1 \equiv 0\text{ dB}$, centralizando a banda passante na máscara).
- Relação entre simetria par ($h[n] = h[N-1-n]$) e fase linear generalizada (atraso de grupo constante igual a $(N-1)/2$ amostras, sem distorção de fase).
- Distinção conceitual entre *estimativa de ordem* e *verificação efetiva da máscara*.

---

### Fase 2 — Etapa A2: Filter Designer como Ferramenta Auxiliar [CONCLUÍDA]
**Execução híbrida (GUI MATLAB + Script `src/etapa_A2_equiripple.m`)**

- [x] Conferência do filtro de janelamento ($N=23$) e projeto do filtro *Equiripple* de ordem mínima ($N=15$, ordem $M=14$) para a mesma máscara (`data/coeficientes_equiripple.mat`).
- [x] Implementação de `src/etapa_A2_equiripple.m` avaliando `h` e `h_equiripple` com `avaliar_mascara.m` sem substituir `h` nas etapas seguintes.
- [x] Exportação da tabela comparativa `results/tab_A2_comparacao_equiripple.csv` e da figura `figures/fig_A2_comp_janelamento_equiripple` (`.pdf` e `.png`).

> **Resumo dos Valores Numéricos Obtidos (Fase 2 / Etapa A2):**
> - **Janelamento (Hamming):** $N = 23$ coeficientes (Ordem $M = 22$), desvio máx. passante $= 0{,}042323\text{ dB}$, atenuação mín. rejeição $= 47{,}0065\text{ dB}$, ganho DC $= 0{,}000000\text{ dB}$ ($\sum h[k] = 1{,}000000$), atraso de grupo $= 11{,}0\text{ amostras}$ ($1{,}3750\text{ ms}$), **Atende à máscara: Sim**.
> - **Equiripple (Parks-McClellan / Ordem Mínima):** $N = 15$ coeficientes (Ordem $M = 14$), desvio máx. passante $= 0{,}083846\text{ dB}$ ($\le 0{,}10\text{ dB}$), atenuação mín. rejeição $= 46{,}5690\text{ dB}$ ($\ge 45{,}00\text{ dB}$), ganho DC $= 0{,}082627\text{ dB}$ ($\sum h_{\text{eq}}[k] = 1{,}009558$), atraso de grupo $= 7{,}0\text{ amostras}$ ($0{,}8750\text{ ms}$), **Atende à máscara: Sim**.
> - **Redução de custo computacional:** $15$ vs $23$ operações MAC por amostra ($-34{,}8\%$, ou $120.000$ vs $184.000\text{ MACs/s}$ a $F_s = 8.000\text{ Hz}$).

#### Procedimento Manual no Filter Designer (1ª execução)
1. Abrir `filterDesigner` no MATLAB após rodar a Etapa A.
2. **Conferência do filtro de janelamento:**
   - Importar `h` do Workspace (*File → Import Filter from Workspace*, `Numerator = h`, `Denominator = 1`, `Fs = 8000`).
   - Conferir visualmente: *Magnitude Response*, *Phase Response*, *Group Delay* e *Pole/Zero Plot*.
   - Capturar/validar que os valores coincidem com os gráficos e cálculos da Etapa A.
3. **Projeto do filtro Equiripple de referência:**
   - Selecionar *Response Type*: `Lowpass`.
   - *Design Method*: `FIR → Equiripple`.
   - *Filter Order*: `Minimum order`.
   - *Frequency Specifications*: `Units = Hz`, `Fs = 8000`, `Fpass = 1000`, `Fstop = 2200`.
   - *Magnitude Specifications*: `Units = dB`, `Apass = 0.2` (atenção: $\pm 0{,}1\text{ dB}$ de oscilação total pico-a-pico ao redor de $0\text{ dB}$ corresponde a `Apass = 0.2 dB` no Filter Designer, ou conferir como o Filter Designer centraliza a banda passante — verificar se `Apass = 0.1` vs `0.2` atende $\pm 0{,}1\text{ dB}$ em relação a $0\text{ dB}$ após normalização/offset; se o Filter Designer assume banda passante em $[0, -A_{\text{pass}}]$, ajustar ganho ou usar `Apass = 0.1` e validar com `avaliar_mascara`!).
   - `Astop = 45`.
   - Clicar em *Design Filter*, conferir se atende à máscara exata ($\pm 0{,}1\text{ dB}$ em torno de $0\text{ dB}$ e $\ge 45\text{ dB}$).
   - Exportar para o Workspace (*File → Export → Workspace*, variável `h_equiripple`) e salvar como `save('data/coeficientes_equiripple.mat', 'h_equiripple')`.

#### Procedimentos no Script `src/etapa_A2_equiripple.m`
1. Carregar `data/coeficientes_FIR.mat` e `data/coeficientes_equiripple.mat`.
   - Se `coeficientes_equiripple.mat` ainda não existir, emitir aviso claro no console e calcular referência via `firpmord` + `firpm` apenas como *fallback* temporário.
2. Aplicar exatamente a mesma função `avaliar_mascara` em ambos os filtros (`h` e `h_equiripple`).
3. **Importante:** Não substituir `h` por `h_equiripple` nas etapas B–E!

#### Gráficos, Tabelas e Análise
- `tab_A2_comparacao_equiripple.csv`: tabela idêntica à do roteiro (Número de coeficientes, Desvio máximo na passante em dB, Atenuação mínima na rejeição em dB, Atende à máscara?).
- `fig_A2_comp_janelamento_equiripple`: curvas de magnitude em dB sobrepostas (0 a 4.000 Hz + zoom nas bandas) com os limites da máscara.
- **Análise no relatório:** Comparar ordem/número de coeficientes, distribuição do erro de aproximação (ripple concentrado próximo à transição no janelamento vs ripple uniforme distribuído — *equiripple*/Parks-McClellan — otimizado pelo critério minimax) e impacto direto no **custo computacional** (número de multiplicações e somas MAC por amostra de saída = $N$).

---

### Fase 3 — Etapa B: Implementação com Buffer Circular [CONCLUÍDA]
**Arquivos:** `src/fir_circular.m` e `src/etapa_B_validacao.m`

- [x] Implementação de `src/fir_circular.m` seguindo estritamente a convenção do roteiro (buffer numerado em sentido horário `1..N`, escrita em sentido anti-horário sobrescrevendo a amostra mais antiga e leitura em sentido horário a partir de `idx_recente` com índice auxiliar separado `idx_leitura`, sem chamar `filter`, `conv` ou `fftfilt`).
- [x] Validação em `src/etapa_B_validacao.m` com impulso unitário ($L = 43$ amostras) e sinal composto de duas senoides ($500\text{ Hz} + 3.000\text{ Hz}$, $L = 400$ amostras), confrontando com `filter(h, 1, x)` e `freqz`.
- [x] Exportação de `results/tab_B1_erros_e_ganhos.csv`, `results/tikz_buffer_circular.tex`, `figures/fig_B1_impulso_comparacao` e `figures/fig_B2_senoides_temporal` (`.pdf` e `.png`).

> **Resumo dos Valores Numéricos Obtidos (Fase 3 / Etapa B):**
> - **Teste 1 — Impulso unitário ($L_{\text{imp}} = 43$ amostras):**
>   - Erro absoluto máximo $\max_n |y_{\text{circ}}[n] - y_{\text{filter}}[n]| = 0$ (`0.000000e+00`).
>   - Erro absoluto máximo nos primeiros $N=23$ pontos $\max_{1\le k\le N} |y_{\text{circ}}[k] - h[k]| = 0$.
>   - Amplitude residual máxima na cauda nula ($n \ge N$): $0$.
> - **Teste 2 — Duas senoides ($500\text{ Hz} + 3.000\text{ Hz}$, $L_{\text{sen}} = 400$ amostras):**
>   - Erro absoluto máximo $\max_n |y_{\text{circ}}[n] - y_{\text{filter}}[n]| = 3{,}330669\times 10^{-16}$ (precisão de máquina `double`).
> - **Ganhos exatos via `freqz(h, 1, [500, 3000], Fs)`:**
>   - Em $f_1 = 500\text{ Hz}$ (banda passante): $|H(500\text{ Hz})| = 0{,}99783632$ ($-0{,}018814\text{ dB}$, desvio $= 0{,}018814\text{ dB} \le 0{,}10\text{ dB} \implies$ **Atende**).
>   - Em $f_2 = 3.000\text{ Hz}$ (banda de rejeição): $|H(3000\text{ Hz})| = 0{,}00235009$ ($-52{,}5783\text{ dB}$, atenuação $= 52{,}5783\text{ dB} \ge 45{,}00\text{ dB} \implies$ **Atende**).

#### Especificação Exata de `fir_circular(x, h)`
- **Assinatura:** `function y = fir_circular(x, h)`
- **Proibição:** Não chamar `filter`, `conv` ou `fftfilt` dentro de `fir_circular`.
- **Convenção obrigatória do roteiro:**
  - Buffer `buf = zeros(1, N)` com posições indexadas de `1` a `N` no **sentido horário**.
  - `ptr_write` (ou `idx_recente`): ponteiro da amostra mais recente.
  - A cada nova amostra `x(n)`:
    1. **Próxima posição de escrita em direção anti-horária** (sobrescrevendo a amostra mais antiga):
       ```matlab
       idx_recente = idx_recente - 1;
       if idx_recente < 1
           idx_recente = N;
       end
       buf(idx_recente) = x(n);
       ```
    2. **Leitura a partir da amostra mais recente em direção horária**, acumulando `h(k) * buf(idx_leitura)`:
       ```matlab
       idx_leitura = idx_recente; % índice auxiliar separado
       acc = 0;
       for k = 1:N
           acc = acc + h(k) * buf(idx_leitura);
           idx_leitura = idx_leitura + 1;
           if idx_leitura > N
               idx_leitura = 1;
           end
       end
       y(n) = acc;
       ```
    *(Nota: verificar que para um impulso unitário $x[0]=1, x[n>0]=0$, quando $n=1$ (1ª amostra) `h(1)*buf(idx_recente)` resulta em `h(1)`, e a cada passo subsequente a amostra `1` "caminha" na posição relativa horária `k = 2, 3, ..., N` porque novas escritas recuam no sentido anti-horário! Assim, a saída reproduz exatamente $y[n] = h[n]$).*

#### Procedimentos de Validação (`src/etapa_B_validacao.m`)
1. **Teste 1 — Impulso unitário:** `delta = [1, zeros(1, N + 20)]`.
   - Comparar `y_circ_imp = fir_circular(delta, h)` vs `y_filt_imp = filter(h, 1, delta)` vs `h`.
   - Registrar erro máximo absoluto: `max(abs(y_circ_imp - y_filt_imp))`.
2. **Teste 2 — Sinal de duas senoides:**
   - $x[n] = \sin\left(\frac{2\pi \cdot 500 \cdot n}{F_s}\right) + \sin\left(\frac{2\pi \cdot 3000 \cdot n}{F_s}\right)$ (ex.: $n = 0, \dots, 399$ ou $799$).
   - Comparar `y_circ_sen = fir_circular(x, h)` vs `y_filt_sen = filter(h, 1, x)`.
   - Registrar erro máximo absoluto: `max(abs(y_circ_sen - y_filt_sen))`.
3. **Verificação em frequência (`freqz`):**
   - Calcular resposta em $f = 500\text{ Hz}$ e $f = 3.000\text{ Hz}$ via `freqz(h, 1, [500, 3000], Fs)`.
   - Montar tabela com ganho linear, ganho em dB e comparação com as exigências da máscara ($\pm 0{,}1\text{ dB}$ em $500\text{ Hz}$ e $\le -45\text{ dB}$ em $3.000\text{ Hz}$).

#### Artefatos e Análise (Etapa B)
- `fig_B1_impulso_comparacao`: resposta ao impulso de `fir_circular` comparada com `h[k]` e `filter`.
- `fig_B2_senoides_temporal`: sinal temporal de entrada $x[n]$ e saída filtrada $y[n]$ (destacando atenuação da componente de $3.000\text{ Hz}$ e preservação da de $500\text{ Hz}$ após o transitório).
- `tab_B1_erros_e_ganhos.csv`: erros máximos nos dois testes e ganhos via `freqz` em 500 Hz e 3.000 Hz.
- Diagrama TikZ (para incluir no `report/main.tex` na Fase 8): anel circular de $N$ posições numeradas no sentido horário, seta horária para leitura (`idx_leitura`) e seta anti-horária para escrita (`idx_recente`).
- **Questões de análise:** Por que não há deslocamento físico de dados em memória ($O(1)$ de escrita vs $O(N)$ de cópia/shift); como o alinhamento de ponteiros associa `h(k)` à amostra `x[n-k+1]`; e por que `filter(h,1,x)` valida a equivalência algorítmica da convolução causal, mas não valida a especificação espectral da máscara.

---

### Fase 4 — Etapa C: Quantização dos Coeficientes [CONCLUÍDA]
**Script:** `src/etapa_C_quant_coef.m`

- [x] Quantização dos coeficientes originais normalizados `h` em **Q1.7** ($F=7$, $\Delta = 2^{-7} = 0{,}0078125$) e **Q1.15** ($F=15$, $\Delta = 2^{-15} \approx 3{,}051758\times 10^{-5}$) por arredondamento `hQ = round(h * 2^F) / 2^F`, **sem renormalizar** após a quantização.
- [x] Cálculo de erros individuais, erro absoluto máximo, EQM, coeficientes anulados, preservação de simetria, soma/ganho DC e verificação da máscara via `avaliar_mascara.m`.
- [x] Exportação de `results/tab_C1_coeficientes_erros.csv`, `results/tab_C2_metricas_quant_coef.csv` e `figures/fig_C1_respostas_quant_coef` (`.pdf` e `.png`).

> **Resumo dos Valores Numéricos Obtidos (Fase 4 / Etapa C):**
> - **Original (`double`, $N=23$):** $\sum h[k] = 1{,}0000000$ (Ganho DC $= 0{,}000000\text{ dB}$), erro simetria $= 0$, desvio máx. passante $= 0{,}042323\text{ dB}$, atenuação mín. rejeição $= 47{,}0065\text{ dB}$, **Atende à máscara: Sim**.
> - **Q1.15 ($F = 15$, $\Delta/2 = 2^{-16} \approx 1{,}525879\times 10^{-5}$):**
>   - Erro absoluto máximo: $1{,}397490\times 10^{-5}$ (no coeficiente central $k = 11$, $\le \Delta/2$) | $\text{EQM} = 9{,}057312\times 10^{-11}$.
>   - Coeficientes iguais a zero: $4$ ($k \in \{1, 6, 16, 21\}$, apenas os cruzamentos analíticos da função $\text{sinc}$ ideal).
>   - Erro máx. de simetria: $0$ (fase linear Tipo I preservada) | Soma $\sum h_{Q1.15}[k] = 0{,}99993896$ ($32766/32768$, Ganho DC $= -0{,}000530\text{ dB}$).
>   - Desvio máx. passante: $0{,}042440\text{ dB}$ ($\le 0{,}10\text{ dB}$) | Atenuação mín. rejeição: $46{,}9752\text{ dB}$ ($\ge 45{,}00\text{ dB}$) | **Atende à máscara: Sim**.
> - **Q1.7 ($F = 7$, $\Delta/2 = 2^{-8} = 0{,}00390625$):**
>   - Erro absoluto máximo: $2{,}673012\times 10^{-3}$ (no par simétrico $k = 2$ e $k = 20$, $\le \Delta/2$) | $\text{EQM} = 2{,}260906\times 10^{-6}$.
>   - Coeficientes iguais a zero: $6$ ($k \in \{0, 1, 6, 16, 21, 22\}$, anulando os dois coeficientes periféricos não nulos $k = 0$ e $k = 22$ pois $|h[0]| = 0{,}00219838 < \Delta/2 = 0{,}00390625$).
>   - Erro máx. de simetria: $0$ (fase linear preservada) | Soma $\sum h_{Q1.7}[k] = 0{,}97656250$ ($125/128$, Ganho DC $= -0{,}205999\text{ dB}$).
>   - Desvio máx. passante: $0{,}205999\text{ dB}$ ($> 0{,}10\text{ dB}$, reprova) | Atenuação mín. rejeição: $39{,}8632\text{ dB}$ ($< 45{,}00\text{ dB}$, reprova) | **Atende à máscara: Não**.

#### Procedimentos de Código
1. Partir do vetor `h` original em ponto flutuante (`double`) sem alterar sua normalização.
2. Quantizar separadamente em **Q1.7** ($F=7$) e **Q1.15** ($F=15$):
   $$h_Q = \frac{\text{round}(h \cdot 2^F)}{2^F}$$
   - **Regra do roteiro:** Manter entradas e aritmética em ponto flutuante e **NÃO renormalizar** `hQ7` nem `hQ15`.
3. Calcular para Q1.7 e Q1.15 em relação a `h`:
   - Erro individual: `e_coef = hQ - h`.
   - Erro absoluto máximo: `max(abs(e_coef))` (e comparar com $\Delta/2 = 2^{-(F+1)}$).
   - Erro quadrático médio (EQM): `mean(e_coef.^2)`.
   - Soma dos coeficientes `sum(hQ)` e ganho DC em dB ($20\log_{10}|\sum h_Q|$).
   - Erro máximo de simetria `max(abs(hQ - fliplr(hQ)))`.
4. Avaliar a resposta em frequência (`avaliar_mascara`) para as três versões: Original (`double`), Q1.15 e Q1.7.

#### Gráficos, Tabelas e Questões de Análise
- `tab_C1_coeficientes_erros.csv`: índice `k`, `h[k]`, `hQ1.7[k]`, `e_Q1.7[k]`, `hQ1.15[k]`, `e_Q1.15[k]`.
- `tab_C2_metricas_quant_coef.csv`: Erro abs máx, EQM, Desvio máx passante (dB), Atenuação mín rejeição (dB), Soma / Ganho DC (linear e dB), Atende à máscara? (para Original, Q1.15 e Q1.7).
- `fig_C1_respostas_quant_coef`: sobreposição das três magnitudes de $0$ a $4.000\text{ Hz}$ + zoom na passante ($0\text{–}1.000\text{ Hz}$) e na rejeição ($2.200\text{–}4.000\text{ Hz}$) com os limites da máscara.
- **Responder às 7 questões no relatório:**
  1. Quais coeficientes foram mais alterados (erro absoluto vs erro relativo nas caudas de baixa amplitude)?
  2. Algum coeficiente foi quantizado para zero? Explicar pelo passo de quantização $\Delta = 2^{-F}$ (limiar $|h[k]| < 2^{-(F+1)}$).
  3. A simetria foi preservada? (Arredondamento é função ímpar simétrica ao redor de zero, logo pares iguais geram valores quantizados iguais).
  4. Qual a consequência para a fase? (Como a simetria é mantida, a fase continua linear!).
  5. Em que banda os efeitos foram mais relevantes? (Tipicamente na banda de rejeição, pois pequenos erros absolutos de coeficientes causam desvios proporcionais grandes onde $|H(f)| \ll 1$, degradando o piso de atenuação; além de eventual deslocamento global na passante por perda da soma unitária).
  6. Quais versões atendem à máscara?
  7. Qual a relação entre soma dos coeficientes e ganho DC? ($H(e^{j0}) = \sum_{k=0}^{N-1} h[k]$).

---

### Fase 5 — Etapa D: Quantização das Amostras de Entrada [CONCLUÍDA]
**Script:** `src/etapa_D_quant_amostras.m`

- [x] Quantização das amostras de entrada $x[n]$ em **Q1.7** ($\Delta = 2^{-7} = 0{,}0078125$) por arredondamento e saturação estrita em $[-1,\; 1 - 2^{-7}]$, mantendo os coeficientes `h` originais em ponto flutuante (`double`).
- [x] Avaliação dos Casos 1 e 2 ($L = 800$ amostras, $F_s = 8.000\text{ Hz}$) com exclusão documentada do transitório inicial para $n \ge 32$ (`idx = 33:800`, descartando as primeiras $32$ amostras $\ge N-1 = 22$ e mantendo $768$ amostras $= 48$ períodos inteiros de $N_0 = 16$ amostras).
- [x] Exportação de `results/tab_D1_snr_comparacao.csv`, `figures/fig_D1_caso1_amostras_e_erros` e `figures/fig_D2_caso2_amostras_e_erros` (`.pdf` e `.png`, com marcadores explícitos).

> **Resumo dos Valores Numéricos Obtidos (Fase 5 / Etapa D):**
> - **Corte de transitório adotado:** descartadas as primeiras $32$ amostras ($n = 0 \dots 31$), avaliando o regime permanente em $n = 32 \dots 799$ ($L_{\text{regime}} = 768$ amostras $= 48$ ciclos exatos de $N_0 = 16$ amostras).
> - **Caso 1 — $x_1[n] = 0{,}8\sin(2\pi\cdot 500n/F_s)$:**
>   - Erro máx. entrada: $\max|e[n]| = 3{,}185425\times 10^{-3} \le \Delta/2 = 3{,}906250\times 10^{-3}$ ($81{,}55\%$ de $\Delta/2$).
>   - Erro máx. saída (regime $n \ge 32$): $\max|e_y[n]| = 1{,}276482\times 10^{-3}$.
>   - Potências: $P_x = 0{,}320000 \to P_{y,\text{ss}} = 0{,}318617$ ($-0{,}0188\text{ dB}$); $P_e = 6{,}667355\times 10^{-6} \to P_{e_y,\text{ss}} = 8{,}304642\times 10^{-7}$ ($-9{,}0463\text{ dB}$).
>   - **SNR:** $\text{SNR}_{\text{in}} = 46{,}8120\text{ dB} \to \text{SNR}_{\text{out}} = 55{,}8395\text{ dB}$ ($\Delta\text{SNR} = +9{,}0275\text{ dB}$).
> - **Caso 2 — $x_2[n] = 0{,}5\sin(2\pi\cdot 500n/F_s) + 0{,}3\sin(2\pi\cdot 3000n/F_s)$:**
>   - Erro máx. entrada: $\max|e[n]| = 2{,}776249\times 10^{-3} \le \Delta/2 = 3{,}906250\times 10^{-3}$ ($71{,}07\%$ de $\Delta/2$).
>   - Erro máx. saída (regime $n \ge 32$): $\max|e_y[n]| = 8{,}393524\times 10^{-4}$.
>   - Potências: $P_x = 0{,}170000 \to P_{y,\text{ss}} = 0{,}124460$ ($-1{,}3542\text{ dB}$ pela rejeição da componente de $3.000\text{ Hz}$); $P_e = 3{,}516992\times 10^{-6} \to P_{e_y,\text{ss}} = 2{,}110931\times 10^{-7}$ ($-12{,}2170\text{ dB}$).
>   - **SNR:** $\text{SNR}_{\text{in}} = 46{,}8428\text{ dB} \to \text{SNR}_{\text{out}} = 57{,}7056\text{ dB}$ ($\Delta\text{SNR} = +10{,}8628\text{ dB} = -1{,}3542\text{ dB} - (-12{,}2170\text{ dB})$).

#### Procedimentos de Código
1. Manter coeficientes `h` originais em ponto flutuante (`double`).
2. Implementar função auxiliar de quantização Q1.7 com arredondamento e saturação estrita ao intervalo $[-1,\; 1 - 2^{-7}]$:
   $$x_q[n] = \min\!\left(\max\!\left(\frac{\text{round}(x[n] \cdot 2^7)}{2^7},\; -1\right),\; 1 - 2^{-7}\right)$$
3. Definir os dois sinais de teste com $F_s = 8.000\text{ Hz}$ e $L = 800$ amostras ($n = 0, \dots, 799$):
   - **Caso 1:** $x_1[n] = 0{,}8 \sin\left(\frac{2\pi \cdot 500 \cdot n}{F_s}\right)$
   - **Caso 2:** $x_2[n] = 0{,}5 \sin\left(\frac{2\pi \cdot 500 \cdot n}{F_s}\right) + 0{,}3 \sin\left(\frac{2\pi \cdot 3000 \cdot n}{F_s}\right)$
4. Para cada caso:
   - Calcular erro de entrada $e[n] = x_q[n] - x[n]$ e verificar seus extremos frente a $\pm \Delta/2 = \pm 2^{-8} \approx \pm 0{,}00390625$ ($\Delta = 2^{-7} = 0{,}0078125$).
   - Filtrar $x$ e $x_q$ com `h` (via `filter` ou `fir_circular`, que são equivalentes): $y = \text{filter}(h, 1, x)$, $y_q = \text{filter}(h, 1, x_q)$.
   - Calcular erro de saída $e_y[n] = y_q[n] - y[n]$.
   - **Exclusão do transitório inicial na saída:** Descartar as primeiras $N-1$ amostras (ou múltiplo conveniente de $16$ amostras $\ge N-1$, uma vez que $500\text{ Hz}$ tem período de $16$ amostras e $3.000\text{ Hz}$ de $8/3$ amostras — um múltiplo de $16$ garante número inteiro de ciclos em ambas as frequências para medição exata de potência média em regime permanente!). Documentar explicitamente no código e no relatório o índice de corte adotado.
   - Calcular potências médias e SNRs (em dB):
     $$\text{SNR}_{\text{in}} = 10\log_{10}\!\left(\frac{\overline{x^2}}{\overline{e^2}}\right), \qquad \text{SNR}_{\text{out}} = 10\log_{10}\!\left(\frac{\overline{y_{\text{ss}}^2}}{\overline{e_{y,\text{ss}}^2}}\right), \qquad \Delta\text{SNR} = \text{SNR}_{\text{out}} - \text{SNR}_{\text{in}}$$
     *(Medir também $P_x$, $P_e$, $P_{y,\text{ss}}$ e $P_{e_y,\text{ss}}$ separadamente para embasar a última questão de análise!)*

#### Gráficos, Tabelas e Questões de Análise
- `fig_D1_caso1_amostras_e_erros` e `fig_D2_caso2_amostras_e_erros`:
  - Subplots com **marcadores** (`stem` ou `plot(..., '-o')` em janela curta de amostras, ex. 32 ou 48 amostras) mostrando $x[n]$ vs $x_q[n]$ para explicitar quantização em amplitude discreta das amostras; erro na entrada $e[n]$ com linhas $\pm \Delta/2$; erro na saída $e_y[n]$ (destacando a região transitória vs regime permanente).
- `tab_D1_snr_comparacao.csv`: $\text{SNR}_{\text{in}}$, $\text{SNR}_{\text{out}}$, $\Delta\text{SNR}$, além de $P_{\text{sinal}}$ e $P_{\text{erro}}$ na entrada e na saída, e $\max |e[n]|$ vs $\Delta/2$.
- **Responder às 4 questões no relatório:**
  1. O erro de quantização apresenta periodicidade? Por quê? (Sim! $F_s = 8000\text{ Hz}$ e frequências de $500\text{ Hz}$ e $3000\text{ Hz}$ têm razão racional $\implies$ sinal discreto periódico com período de 16 amostras; como a quantização é um mapeamento determinístico sem memória, $e[n]$ herda a periodicidade, concentrando energia em harmônicos em vez de ruído perfeitamente branco).
  2. Como o filtro modifica esse erro? (O filtro passa-baixa atenua os harmônicos e componentes de alta frequência do erro acima da banda de transição, reduzindo a potência do erro na saída $\overline{e_y^2} < \overline{e^2}$).
  3. A SNR melhora em ambos os casos? (Analisar os valores numéricos observados: no Caso 1 o sinal útil de 500 Hz passa integralmente enquanto o erro acima de ~1,6 kHz é atenuado $\implies$ SNR melhora; no Caso 2 a componente de 3000 Hz do próprio sinal é fortemente atenuada pelo filtro, reduzindo drasticamente a potência do sinal útil na saída!).
  4. Por que não é correto atribuir toda variação de SNR exclusivamente à redução do ruído quando a própria potência do sinal útil também se altera? (Porque $\text{SNR} = P_{\text{sinal}} / P_{\text{ruído}}$: no Caso 2, $P_y$ cai em relação a $P_x$ pela eliminação da senoide de 3000 Hz; logo, $\Delta\text{SNR}$ reflete a razão conjunta entre atenuação do sinal e atenuação do ruído).

---

### Fase 6 — Etapa E: Precisão Aritmética e Overflow (Conceitual e Breve) [CONCLUÍDA]
**Script auxiliar:** `src/etapa_E_ponto_fixo.m`

- [x] Implementação do exemplo numérico de multiplicação de dois operandos exatos em Q1.7 ($a = 79/128$ e $b = 45/128$) com produto completo em Q2.14 ($3555/16384$), comparando arredondamento (`round`) e truncamento (`floor`) para Q1.7.
- [x] Cálculo da norma $\ell_1$ dos coeficientes ($\sum_{k=0}^{22} |h[k]|$) como limite superior BIBO de saída e dimensionamento de bits de guarda no acumulador MAC, além do exemplo numérico de *overflow* em adição Q1.7 comparando saturação e *wrap-around*.
- [x] Exportação de `results/tab_E1_produto_Q17.csv`.

> **Resumo dos Valores Numéricos Obtidos (Fase 6 / Etapa E):**
> - **Operandos em Q1.7:** $a = 79/128 = 0{,}6171875$ (`01001111_2`) e $b = 45/128 = 0{,}3515625$ (`00101101_2`).
> - **Produto completo exato em Q2.14 (16 bits):** $a \cdot b = 3555/16384 = 27{,}7734375/128 = 0{,}21697998046875$ (`0000110111100011_2`, parte fracionária descartada $= 99/128\text{ LSB}_{Q1.7} = 0{,}7734375\text{ LSB}_{Q1.7} \ge 0{,}5\text{ LSB}$).
> - **Arredondado para Q1.7 (`round`):** $28/128 = 0{,}2187500$ (`00011100_2`), erro $= +0{,}00177001953125$ ($+0{,}2265625\text{ LSB}_{Q1.7}$, magnitude $\le \Delta/2 = 0{,}00390625$).
> - **Truncado para Q1.7 (`floor`):** $27/128 = 0{,}2109375$ (`00011011_2`), erro $= -0{,}00604248046875$ ($-0{,}7734375\text{ LSB}_{Q1.7}$, magnitude $< \Delta = 0{,}0078125$).
> - **Norma $\ell_1$ dos coeficientes ($N = 23$):** $\sum_{k=0}^{22} |h[k]| = 1{,}47339547500902$ ($3{,}3664\text{ dB}$), exigindo $\lceil\log_2(1{,}4734)\rceil = 1\text{ bit}$ de guarda pela restrição física do filtro ($\lceil\log_2(23)\rceil = 5\text{ bits}$ no pior caso genérico de $23$ parcelas).
> - **Exemplo de *overflow* em adição Q1.7:** $0{,}75\;(96/128) + 0{,}50\;(64/128) = +1{,}25\;(160/128) > +0{,}9921875\;(127/128)$:
>   - **Com Saturação:** $+127/128 = +0{,}9921875$ (`01111111_2`, erro absoluto $= 0{,}2578125$).
>   - **Com Retorno Circular (*Wrap-Around*):** $-96/128 = -0{,}7500000$ (`10100000_2`, erro absoluto $= 2{,}0000000$, inversão de sinal).

#### Procedimentos de Código e Conteúdo
1. Escolher um par simples e didático de operandos em Q1.7 (ex.: $a = 0{,}5 = 64/128$ e $b = 0{,}375 = 48/128$, ou valores não exatos em 7 bits após multiplicação como $a = 75/128 = 0{,}5859375$ e $b = 43/128 = 0{,}3359375$ para que arredondamento e truncamento produzam resultados distintos e claros!).
2. Calcular em `etapa_E_ponto_fixo.m`:
   - Produto completo exato em Q2.14 (16 bits com sinal / 14 bits fracionários).
   - Produto arredondado para Q1.7 (`round(prod * 2^7) / 2^7`) e erro absoluto.
   - Produto truncado em direção a $-\infty$ (complemento de 2: `floor(prod * 2^7) / 2^7`) e erro absoluto.
   - Exportar `tab_E1_produto_Q17.csv`.
3. Calcular também $\sum_{k=0}^{N-1} |h[k]|$ para o filtro projetado na Etapa A (como ilustração concreta do limitante BIBO de saída quando $|x[n]| \le 1$).

#### Conteúdo Breve no Relatório
- Pequena tabela com operandos, produto completo, resultado arredondado, resultado truncado e respectivos erros.
- Texto curto e direto respondendo:
  1. Por que multiplicar duas palavras com sinal de 8 bits exige até 16 bits para preservar o produto completo (Q1.7 $\times$ Q1.7 $\to$ Q2.14, e casos extremos como $(-1) \times (-1) = +1$).
  2. Por que a soma de $N$ produtos no acumulador exige maior faixa numérica (*word growth*: até $\lceil \log_2 N \rceil$ bits inteiros extras ou guard bits no acumulador MAC).
  3. Significado de $\sum |h[k]|$ como limite superior da amplitude de saída: $|y[n]| \le \|x\|_\infty \sum |h[k]|$ (estabilidade BIBO e dimensionamento de margem dinâmica contra *overflow*).
  4. Definição de *overflow* e distinção entre **saturação** (limita no máximo/mínimo representável) e **retorno circular (*wrap-around*)** em complemento de 2, com exemplo numérico simples (ex.: em Q1.7, `0.75 + 0.50 = 1.25` $\to$ satura em `1 - 2^-7 = 0.9921875`, enquanto em *wrap-around* dá a volta para `-0.75`).

---

### Fase 7 — Orquestração e Validação Ponta a Ponta em MATLAB [CONCLUÍDA]
**Script orquestrador:** `src/main.m`

- [x] Escrever `src/main.m` chamando `config_specs`, `etapa_A_janelamento`, `etapa_A2_equiripple`, `etapa_B_validacao`, `etapa_C_quant_coef`, `etapa_D_quant_amostras` e `etapa_E_ponto_fixo` em sequência.
- [x] Rodar `main.m` a partir de uma sessão limpa do MATLAB (`clear; clc; close all;`) e confirmar que **nenhuma intervenção manual** ocorre durante a execução.
- [x] Inspecionar todas as figuras em `figures/` (verificar sobreposição de rótulos, unidades nos eixos em Hz, dB, amostras, ms, legendas claras e linhas de máscara visíveis).
- [x] Conferir todos os números exportados em `results/` para consistência cruzada entre etapas, gerando `results/resumo_metricas.txt` e `results/metricas_relatorio.tex` como fonte única da verdade para o relatório LaTeX.

> **Resumo da Validação Ponta a Ponta (Fase 7):**
> - **Comando validado:** `matlab -batch "run('src/main.m')"` (tempo total $\approx 29{,}3\text{ s}$, código de saída `0`, zero intervenção manual).
> - **Auditoria automática de 29 artefatos (`todos_integros = true`):**
>   - **Dados (`.mat`):** `data/coeficientes_FIR.mat`, `data/coeficientes_equiripple.mat`.
>   - **Tabelas e Resumos (`results/`):** `tab_A1_varredura_N.csv`, `tab_A2_metricas_finais.csv`, `tab_A2_comparacao_equiripple.csv`, `tab_B1_erros_e_ganhos.csv`, `tikz_buffer_circular.tex`, `tab_C1_coeficientes_erros.csv`, `tab_C2_metricas_quant_coef.csv`, `tab_D1_snr_comparacao.csv`, `tab_E1_produto_Q17.csv`, `resumo_metricas.txt`, `metricas_relatorio.tex`.
>   - **Figuras (`figures/`, pares `.pdf` vetorial + `.png` 300 dpi):** `fig_A1_impulso_janela`, `fig_A2_magnitude_mascara`, `fig_A2_comp_janelamento_equiripple`, `fig_B1_impulso_comparacao`, `fig_B2_senoides_temporal`, `fig_C1_respostas_quant_coef`, `fig_D1_caso1_amostras_e_erros`, `fig_D2_caso2_amostras_e_erros`.

---

### Fase 8 — Escrita e Formatação do Relatório em LaTeX [CONCLUÍDA]
**Diretório:** `report/` (`report/main.tex`)

- [x] Redação integral de `report/main.tex` em arquivo único autocontido em português (`babel` `brazil`, `booktabs`, `siunitx`, `listings` UTF-8, `graphicx` com `\graphicspath{{./figures/}{../figures/}{./}}`, `placeins` e `tikz` embutido) com cabeçalho institucional do SENAI CIMATEC.
- [x] Alinhamento teórico e terminológico integral com as notas de aula da disciplina (`docs/Aula_12.pdf` a `docs/Aula_17.pdf`) e referências bibliográficas externas verificadas (Diniz/da Silva/Netto, Oppenheim/Schafer, Lyons, Manolakis/Ingle e MathWorks), incluindo seção final `\begin{thebibliography}` (`Referências`) com 12 entradas citadas no corpo do texto.
- [x] Incorporação exata de todas as métricas oficiais de `results/metricas_relatorio.tex` e das 9 tabelas geradas a partir dos CSVs de `results/`, sem qualquer arredondamento arbitrário.
- [x] Inclusão das 8 figuras vetoriais PDF de `figures/` + diagrama TikZ embutido do buffer circular (`fig:tikz_buffer`) + listagem do núcleo essencial de `src/fir_circular.m` (`lst:fir_circular`).
- [x] Redação completa das respostas interpretativas de todas as etapas (Etapa A, Etapa A2, Etapa B, 7 questões da Etapa C, 4 questões da Etapa D, questões conceituais da Etapa E) e da Conclusão Técnica diferenciando explicitamente os 5 eixos obrigatórios (`(i)` a `(v)`), com layout dimensionado para a faixa alvo de 15–20 páginas.

> **Resumo da Validação do Relatório LaTeX (Fase 8 — Conciso e Compilado via BasicTeX `pdflatex`):**
> - **Arquivos gerados:** `report/main.tex` (autocontido, zero dependências de `\input` externo) e `report/main.pdf` (**16 páginas**, com a seção de **Referências isolada na página 16** via `\clearpage`, compilado em 2 passadas com `/Library/TeX/texbin/pdflatex`, TeX Live 2026 BasicTeX).
> - **Auditoria sintática, visual, numérica e teórica automatizada:**
>   - Zero erros, zero `Overfull`/`Underfull \hbox` e zero referências indefinidas na compilação `pdflatex`.
>   - Alinhamento auditado slide a slide contra os 6 PDFs de aula do Prof. Elio Pithon Sarno Filho (`docs/Aula_12.pdf` a `docs/Aula_17.pdf`), incorporando terminologia, exemplos (como $h[5] = 0{,}02390682 \to 3/128$ da Aula 17) e referências padronizadas.
>   - 51 macros `\Metrica...` sincronizadas 1-para-1 com `results/metricas_relatorio.tex` e varredura completa $N = 15 \dots 45$ validada contra `results/tab_A1_varredura_N.csv`.
>   - Todas as referências cruzadas (`\label` / `\ref` / `\eqref` de 9 tabelas, 9 figuras incluindo TikZ, 1 listagem e equações) e as 12 entradas bibliográficas (`\bibitem` / `\cite`) verificadas 1-para-1.
> - **Instruções de compilação no Overleaf:**
>   1. Criar um novo projeto em branco no Overleaf (compilador `pdfLaTeX`).
>   2. Enviar `report/main.tex` para a raiz do projeto no Overleaf.
>   3. Criar uma pasta `figures/` no Overleaf e fazer upload dos 8 arquivos `.pdf` (ou `.png`) contidos em `figures/`.

#### Estrutura Espelhando o Roteiro (Seção 9)
1. **Cabeçalho / Identificação:** Disciplina, Professor, Equipe, Data (estilo limpo alinhado ao documento do SENAI CIMATEC).
2. **Objetivo e Especificações:** Texto conciso + tabela resumo das especificações do filtro.
3. **Metodologia Sucinta:** Visão resumida do fluxo (série de Fourier + Hamming, validação, buffer circular, análise de quantização em ponto fixo).
4. **Resultados e Análises (na ordem exata das etapas):**
   - **Etapa A:** Figuras $h_{\text{ideal}} / w / h$ e magnitude com zoom + tabelas (varredura de $N$ e métricas finais) + análise completa.
   - **Etapa A2:** Tabela comparativa Janelamento vs Equiripple + figura de comparação das magnitudes + discussão sobre custo computacional.
   - **Etapa B:** Trecho essencial de `fir_circular.m` (apenas o núcleo de ponteiros/loop, **não** scripts longos inteiros), diagrama TikZ do buffer circular, gráficos (impulso e senoides), tabela de erros máximos e ganhos `freqz` + análise.
   - **Etapa C:** Tabela de coeficientes/erros (compacta ou formatada em colunas múltiplas para não poluir o relatório), tabela de métricas Q1.7/Q1.15/double, figura comparativa com zoom + respostas às 7 questões.
   - **Etapa D:** Gráficos com marcadores (Caso 1 e Caso 2), tabela de SNR e erro vs $\pm \Delta/2$ + respostas às 4 questões.
   - **Etapa E:** Tabela do exemplo numérico Q1.7 + respostas curtas sobre crescimento de palavra, $\sum |h[k]|$ e *overflow*.
5. **Conclusão Técnica:** Estruturada obrigatoriamente nos **5 eixos exigidos pelo roteiro**:
   - (i) Projeto e máscara;
   - (ii) Correção funcional do buffer circular;
   - (iii) Efeitos da quantização de coeficientes;
   - (iv) Efeitos da quantização de amostras;
   - (v) Limites da aritmética finita.

#### Checklist de Formatação LaTeX
- [x] Figuras em PDF vetorial (ou PNG 300 dpi) com `width=\linewidth` ou `0.9\linewidth` e legendas autoexplicativas (`\caption{...}`).
- [x] Todas as figuras e tabelas explicitamente citadas no texto (`Figura~\ref{...}`, `Tabela~\ref{...}`).
- [x] Uso de `siunitx` / `booktabs` para tabelas limpas e unidades padronizadas (`\SI{8000}{Hz}`, `\SI{0.1}{dB}`).
- [x] Conferir número final de páginas e clareza visual (sem *overfull hbox*, tabelas quebradas ou figuras órfãs).

---

### Fase 9 — Revisão Final e Empacotamento da Entrega
- [x] Criar apresentação de slides 100% editável diretamente no Google Apresentações via `gslides` CLI (13 slides enxutos focados nos resultados e com os 8 gráficos científicos de `figures/*.png` em destaque, além de tabelas e notas do apresentador nativos) e exportar cópia `.pptx` para `slides/Apresentacao_Pratica3_Filtro_FIR.pptx`.
- [ ] Auditar o relatório (`report/main.tex` / PDF) e a apresentação de slides editável (`slides/Apresentacao_Pratica3_Filtro_FIR.pptx`) quanto à fidelidade numérica contra `results/`, linguagem alinhada às aulas (`docs/Aula_12.pdf`–`Aula_17.pdf`), referências técnicas e clareza visual.
- [ ] Montar pasta `entrega/` contendo:
  - Relatório final em PDF (`Relatorio_Pratica3_Filtro_FIR.pdf`).
  - Apresentação de slides totalmente editável (`Apresentacao_Pratica3_Filtro_FIR.pptx`).
  - Todos os scripts `.m` necessários (`main.m`, `config_specs.m`, `fir_circular.m`, `etapa_*.m`, `utils/*.m`), devidamente comentados com variáveis e unidades explícitas.
  - Arquivos `.mat` (`coeficientes_FIR.mat`, `coeficientes_equiripple.mat`).
- [ ] Testar a reprodução limpa dentro da própria pasta `entrega/` (abrir MATLAB nela e rodar `main.m` do zero) garantindo que tudo execute sem erros ou caminhos quebrados.

> **Registro da Apresentação de Slides (Fase 9 — Parcial, Revisada para Foco em Resultados):**
> - **`PRESENTATION_ID`:** `1jgJ13fx_Wa6nsiORit5Th3BtASF6rdM6Ue8NGcIgLfY` *(cópia de segurança v1: `1nBLqtcAPUeI9TcxevG3WM8nur2TtpLl2y2hw2VHm0VI`)*
> - **Link direto (Google Apresentações):** `https://docs.google.com/presentation/d/1jgJ13fx_Wa6nsiORit5Th3BtASF6rdM6Ue8NGcIgLfY/edit`
> - **Cópia local `.pptx`:** `slides/Apresentacao_Pratica3_Filtro_FIR.pptx` (`3.401.266 bytes`, exportada via `gslides readonly export`)
> - **Escopo validado:** 13 slides enxutos inspecionados visualmente via `gslides readonly export-thumbnail` (zero cortes, zero sobreposições, 8 gráficos MATLAB em tamanho protagonista e 100% editável nativamente).

> **Revisão com a Aula 18 (27/11/2026) — PENDENTE DE EXECUÇÃO NO MATLAB:**
> - [x] Scripts estendidos: `etapa_A_janelamento.m` (conferência com `fir1` + `grpdelay`), `etapa_C_quant_coef.m` (`sum(abs(hQ))` em Q1.15/Q1.7), `etapa_E_ponto_fixo.m` (amplitude máxima de entrada K/128, escalonamento por `1/sum(abs(h))` verificado nos coeficientes armazenados, momento do arredondamento; nova tabela `results/tab_E2_limite_amplitude.csv`) e `main.m` (novas macros e auditoria).
> - [x] `report/main.tex` e `report/main_v02.tex` atualizados (ainda **não** unificados): conferência `fir1`/`grpdelay`, parâmetros do Filter Designer (Apass = 0,2 dB), teste de retorno do ponteiro, `sum(abs(hQ))`, escolha de Q1.15, amplitude máxima, escalonamento, momento do arredondamento, peso −1 do bit de sinal, referência à Aula 18.
> - [x] `src/main.m` executado no MATLAB Online (27/11/2026, pasta `MATLAB Drive/PDS/Filtro_FIR_A18`) e macros preenchidas nos dois relatórios. Valores-chave: `fir1` difere de h em 5,55e-17; `grpdelay` = 11,000000 amostras (desvio 0); sum|hQ| = 1,47332764 (Q1.15) / 1,47656250 (Q1.7); K_max = 86 → |x| ≤ 86/128 = 0,671875 (pico 126,712 / 128,185 passos); h/sum|h| → ganho DC 0,678704 (−3,3664 dB); escalonado em Q1.7: sum|hq| = 129/128, sum(hq) = 89/128 (−3,1564 dB), pico 0,9999390 > 127/128 (ainda há overflow); exemplo da aula 10/128 (Q por ramo) vs 9/128 (Q após soma); limites 0,08984375 vs 0,00390625.
> - [x] Fusão concluída em `report/main.tex` (27/11/2026): texto do `main_v02.tex` como base, com a varredura completa N = 15 a 45, o detalhe dos zeros no Filter Designer, a bibliografia formal com `\cite` (13 itens, incluindo a Aula 18) e a Etapa E enxugada (~1 página). Compila sem erros (20 páginas). `report/main_v02.tex` mantido sem alterações, como referência.
> - [ ] Sincronizar a pasta `results/` local com a execução do MATLAB Online (hoje só os relatórios têm os valores novos; `results/tab_E2_limite_amplitude.csv` não existe localmente).
> - [ ] Observação: no MATLAB Online, o erro máximo das senoides da Etapa B saiu 4,440892e-16 (local: 3,330669e-16; diferença de 1 ulp entre versões). Os relatórios mantêm o valor local.
> - [x] Corrigido (27/11/2026): `main.m` exigia `results/tikz_buffer_circular.tex`, que nenhum script gera (o diagrama TikZ fica embutido em `report/main.tex`). O arquivo saiu da lista de verificação do `main.m` e da Etapa B; validado no MATLAB Online a partir de `results/` e `figures/` vazios (29 arquivos OK, 117 s).

---

## 5. Cronograma Sugerido (23/11/2026 → 02/12/2026)

| Período | Marco | Entregáveis do Marco |
| :--- | :--- | :--- |
| **23/11 – 24/11** | Fases 0 e 1 | Estrutura de pastas, `config_specs.m`, helpers e **Etapa A** (`coeficientes_FIR.mat` validado). |
| **25/11** | Fases 2 e 3 | **Etapa A2** no Filter Designer (`coeficientes_equiripple.mat`) e **Etapa B** (`fir_circular.m` validada). |
| **26/11 – 27/11** | Fases 4, 5 e 6 | Scripts das **Etapas C, D e E** implementados e métricas/tabelas exportadas. |
| **28/11** | Fase 7 | Execução completa via `main.m`, ajuste fino de figuras e validação cruzada de resultados. |
| **29/11 – 30/11** | Fase 8 | Redação completa do relatório em LaTeX (diagrama TikZ, tabelas, respostas e conclusão nos 5 pontos). |
| **01/12** | Fase 9 | Revisão ortográfica/técnica do PDF, montagem e teste isolado da pasta `entrega/`. |
| **02/12/2026** | **Entrega** | Submissão final do relatório PDF + arquivos `.m` e `.mat`. |
