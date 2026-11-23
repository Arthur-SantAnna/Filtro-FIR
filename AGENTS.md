# AGENTS.md — Regras e Padronizações do Projeto Filtro FIR Passa-Baixa

Este arquivo define as instruções obrigatórias para qualquer agente atuando neste repositório. Leia-o integralmente antes de planejar, editar código, executar simulações ou redigir o relatório.

---

## 1. Idioma e Comunicação

- **Idioma padrão único (100% Português - PT-BR):**
  - Toda comunicação com o usuário, documentação, comentários de código, mensagens de log/console, títulos e eixos de gráficos, cabeçalhos de tabelas, identificadores de variáveis/funções e todo o relatório LaTeX devem estar em **português brasileiro**.
  - **Exceções técnicas permitidas:**
    - Palavras-chave e funções nativas do MATLAB/LaTeX (`function`, `for`, `hamming`, `freqz`, `filter`, `\begin{figure}`, etc.).
    - Termos consolidados do roteiro quando explicitamente exigidos ou consagrados na disciplina (ex.: `fir_circular`, `Equiripple`, *Filter Designer*, *wrap-around*, `SNR`, `DC`, `Q1.7`, `Q1.15`).
  - **Proibido misturar inglês e português** em nomes de variáveis ou textos (ex.: preferir `desvio_passante_dB` em vez de `passband_ripple_dB`; preferir `atraso_grupo_ms` em vez de `group_delay_ms`).

---

## 2. Documentos de Referência Obrigatórios

Antes de iniciar qualquer fase, consulte:
1. [docs/Roteiro_prática3-1.pdf](docs/Roteiro_pra%CC%81tica3-1.pdf) — Especificação oficial da Prática 3 (Prof. Elio Pithon Sarno Filho, SENAI CIMATEC, entrega em **02/12/2026**).
2. [docs/ROADMAP.md](docs/ROADMAP.md) — Plano de execução fase a fase, arquitetura e checklists de progresso.

---

## 3. Especificações Imutáveis do Filtro

| Parâmetro | Variável em `config_specs.m` | Valor | Unidade |
| :--- | :--- | :--- | :--- |
| Frequência de amostragem | `Fs` | `8000` | Hz |
| Banda passante | `Fpass` | `0` a `1000` | Hz |
| Desvio máximo na banda passante | `tol_pass_dB` | `±0.1` (em torno de `0 dB`) | dB |
| Banda de rejeição | `Fstop` | `2200` a `4000` | Hz |
| Atenuação mínima na rejeição | `aten_stop_dB` | `45` | dB |
| Frequência de corte ideal inicial | `fc` | `1600` | Hz |
| Método principal | — | Série de Fourier + janela de Hamming | — |

---

## 4. Arquitetura e Convenções de Código MATLAB

### 4.1 Estrutura de Diretórios
- `src/` — Scripts e funções `.m` (`main.m`, `config_specs.m`, `fir_circular.m`, `etapa_*.m`).
- `src/utils/` — Funções auxiliares compartilhadas (`avaliar_mascara.m`, `salvar_figura.m`, `exportar_tabela_latex.m`).
- `data/` — Arquivos `.mat` (`coeficientes_FIR.mat`, `coeficientes_equiripple.mat`).
- `figures/` — Figuras geradas automaticamente (`.pdf` vetorial e `.png` 300 dpi).
- `results/` — Tabelas `.csv`, `.tex` e logs de métricas numéricas.
- `report/` — Código-fonte LaTeX do relatório final.
- `entrega/` — Pacote final autocontido (PDF + `.m` + `.mat`).

### 4.2 Padrões de Qualidade MATLAB
1. **Execução sem intervenção manual:** `src/main.m` deve rodar do início ao fim a partir de uma sessão limpa (`clear; clc; close all;`) sem `input()`, pausas bloqueantes ou cliques manuais.
2. **Identificação de variáveis e unidades:** Conforme o roteiro, toda variável física ou métrica deve ter comentário explícito informando significado e unidade (ex.: `Fs = 8000; % Frequência de amostragem [Hz]`).
3. **Resolução de caminhos portável:** Use `fileparts(mfilename('fullpath'))` para localizar diretórios relativos (`data/`, `figures/`, `results/`) de forma independente do diretório atual do usuário. Garanta também compatibilidade caso `.m` e `.mat` estejam todos na mesma pasta (`entrega/`).
4. **Cabeçalho padrão em todo arquivo `.m`:** Incluir título, propósito, entradas/saídas (para funções) e autor/disciplina em português.
5. **Proibição de código duplicado:** A avaliação da máscara de especificações (`desvio_pass_max_dB`, `aten_stop_min_dB`, `ganho_dc_dB`, `atende_mascara`) deve passar sempre pelo mesmo helper `avaliar_mascara.m` usando grade densa (`Nfft >= 16384`).

### 4.3 Regras Técnicas Críticas por Etapa (Não Violar!)
- **Etapa A (Janelamento):**
  - Testar comprimentos **pares e ímpares** ao redor da estimativa inicial e registrar todos na tabela (inclusive os que falharam).
  - Tratar `n == (N-1)/2` explicitamente para evitar `0/0 = NaN` quando `N` for ímpar.
  - Normalizar via `h = h / sum(h)` e salvar em `coeficientes_FIR.mat`.
- **Etapa A2 (Filter Designer / Equiripple):**
  - Carregar `coeficientes_equiripple.mat` exportado da GUI (com fallback via `firpmord`/`firpm` apenas se o `.mat` não existir, emitindo aviso).
  - **NUNCA** substituir `h` pelo filtro *Equiripple* nas etapas B–E.
- **Etapa B (`fir_circular(x, h)`):**
  - **NUNCA** chamar `filter`, `conv` ou `fftfilt` dentro de `fir_circular.m`.
  - Seguir exatamente a convenção do roteiro: buffer de tamanho `N` numerado em sentido horário (`1..N`); **escrita avança em sentido anti-horário** (`idx_recente = mod(idx_recente - 2, N) + 1`, sobrescrevendo a amostra mais antiga); **leitura percorre em sentido horário** a partir de `idx_recente` usando índice auxiliar separado.
- **Etapa C (Quantização de Coeficientes):**
  - Partir de `h` original normalizado (`double`).
  - Quantizar em Q1.7 (`F = 7`) e Q1.15 (`F = 15`) por arredondamento: `hQ = round(h * 2^F) / 2^F`.
  - **NÃO renormalizar** após a quantização. Manter entradas e operações aritméticas em ponto flutuante.
- **Etapa D (Quantização de Amostras):**
  - Manter coeficientes `h` originais em ponto flutuante (`double`).
  - Quantizar `x[n]` em Q1.7 por arredondamento e **saturação estrita** ao intervalo `[-1, 1 - 2^-7]`.
  - Medir `SNR` na saída **excluindo o transitório inicial** (`n >= N`, ajustando para múltiplo de 16 amostras se desejar número inteiro de ciclos de 500 Hz e 3000 Hz; documentar o corte adotado).
- **Etapa E (Precisão Aritmética e Overflow):**
  - Etapa conceitual e breve: não implementar simulador de hardware nem acumulador limitado; gerar apenas tabela de exemplo numérico Q1.7 (produto completo vs arredondamento vs truncamento) e responder às questões conceituais.

---

## 5. Padronizações de Gráficos e Tabelas

- **Figuras:** Exportadas via `salvar_figura.m` em `.pdf` (para o LaTeX) e `.png` (300 dpi, para inspeção rápida).
- **Elementos visuais obrigatórios:**
  - Título descritivo em português, eixos com grandeza e unidade (`Frequência [Hz]`, `Magnitude [dB]`, `Amostra [n]`, `Amplitude`), grade ativada (`grid on`), legendas legíveis sem cobrir curvas.
  - Nas respostas em magnitude, desenhar sempre os limites da máscara (linhas tracejadas em `±0,1 dB` até `1000 Hz` e `-45 dB` a partir de `2200 Hz`) e gerar ampliações (*zoom*) das bandas quando solicitado pelo roteiro.
  - Na Etapa D, usar marcadores explícitos (`stem` ou `-o`) para evidenciar a quantização em amplitude das amostras.

---

## 6. Padrões do Relatório LaTeX (`report/`)

- **Estilo:** Relatório técnico conciso em português em **arquivo único autocontido (`report/main.tex`)** para compatibilidade direta com o **Overleaf** (`article` limpo com cabeçalho institucional SENAI CIMATEC, `babel` em `brazil`, `booktabs`, `siunitx`, `listings` configurado para MATLAB com UTF-8, `tikz` embutido para o diagrama do buffer circular e `\graphicspath{{./figures/}{../figures/}}`).
- **Fidelidade numérica absoluta:**
  - **PROIBIDO** inventar, estimar de memória ou arredondar arbitrariamente números no texto ou nas tabelas do LaTeX. Todos os valores devem vir diretamente das saídas reais geradas pelos scripts MATLAB em `results/`.
- **Estrutura obrigatória:**
  1. Objetivo e Especificações
  2. Metodologia Sucinta
  3. Resultados e Análises na ordem exata: Etapa A, Etapa A2, Etapa B, Etapa C, Etapa D, Etapa E
  4. Conclusão Técnica diferenciando explicitamente os 5 eixos:
     - (i) projeto e máscara;
     - (ii) correção funcional do buffer circular;
     - (iii) efeitos da quantização de coeficientes;
     - (iv) efeitos da quantização de amostras;
     - (v) limites da aritmética finita.
- **Códigos no corpo do relatório:** Não transcrever scripts longos no texto (apenas o trecho essencial de `fir_circular.m` na Etapa B); os arquivos `.m` acompanham a entrega.

---

## 7. Protocolo de Trabalho por Sessão e Verificação

1. **Início da sessão:** Ler `AGENTS.md` e `docs/ROADMAP.md` para identificar o estado atual e os marcos já concluídos.
2. **Execução e teste:** Sempre que possível, executar os scripts via terminal (`matlab -batch ...`) após edições e inspecionar os arquivos gerados em `results/` e `figures/` antes de declarar a fase concluída. Se o MATLAB não estiver acessível pelo terminal da sessão, informar claramente quais comandos o usuário deve rodar e aguardar confirmação/saídas antes de preencher resultados no relatório.
3. **Handoff ao final da sessão:**
   - Atualizar os checkboxes `[x]` correspondentes em `docs/ROADMAP.md`.
   - Registrar os valores-chave obtidos (ex.: comprimento `N` selecionado, erros máximos, SNRs) em `results/` ou na seção de notas do `ROADMAP.md` para que a próxima sessão tenha contexto exato sem precisar recalcular tudo.
