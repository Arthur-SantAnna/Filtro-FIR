function y = fir_circular(x, h)
% FIR_CIRCULAR Filtragem FIR amostra a amostra utilizando buffer circular.
%
%   Proposito:
%       Implementar a equacao a diferencas de um filtro FIR causal de
%       comprimento N (ordem M = N - 1) operando amostra a amostra sobre um
%       buffer circular de tamanho fixo N, sem deslocamento fisico de dados
%       em memoria e sem utilizar funcoes prontas de convolucao ou filtragem.
%
%   Convencao de Ponteiros (conforme roteiro da Pratica 3):
%       1. O buffer possui N posicoes indexadas de 1 ate N no sentido horario.
%       2. A cada nova amostra de entrada x(n), o ponteiro da amostra mais
%          recente (idx_recente) avanca uma posicao no sentido anti-horario:
%              idx_recente = idx_recente - 1;
%              if idx_recente < 1, idx_recente = N; end
%          sobrescrevendo exatamente a amostra mais antiga x(n - N) que
%          deixa a janela de memoria do filtro.
%       3. A leitura parte da amostra mais recente (idx_leitura = idx_recente)
%          e percorre o buffer no sentido horario utilizando um indice
%          auxiliar separado (idx_leitura), acumulando os produtos
%          h(k) * buf(idx_leitura) para k = 1, 2, ..., N com retorno circular:
%              idx_leitura = idx_leitura + 1;
%              if idx_leitura > N, idx_leitura = 1; end
%       4. Alinhamento matematico: como a escrita recua no sentido
%          anti-horario a cada instante n, as amostras anteriores ficam
%          armazenadas nas posicoes horarias consecutivas a partir de
%          idx_recente. Assim, na iteracao k do laco interno (k = 1..N),
%          buf(idx_leitura) contem exatamente x(n - k + 1), que e multiplicada
%          pelo coeficiente correspondente h(k), realizando a soma de
%          convolucao discreta:
%              y(n) = sum_{k=1}^{N} h(k) * x(n - k + 1).
%
%   Entradas:
%       x - Vetor de amostras do sinal de entrada no tempo discreto [amplitude]
%       h - Vetor de coeficientes da resposta ao impulso do filtro FIR [adimensional]
%
%   Saidas:
%       y - Vetor de amostras do sinal filtrado na saida (mesma dimensao de x) [amplitude]
%
%   Autor/Disciplina:
%       Processamento Digital de Sinais (SENAI CIMATEC) - Pratica 3 (2026)

%% 1. Validacao e Preparacao das Dimensoes
if isempty(h)
    error('FirCircular:CoeficientesVazios', ...
        'O vetor de coeficientes h nao pode ser vazio.');
end

eh_coluna = iscolumn(x);       % Flag para preservar a orientacao original da entrada [logico]
x_lin     = x(:).';            % Sinal de entrada organizado como vetor linha [amplitude]
h_lin     = h(:).';            % Coeficientes do filtro organizados como vetor linha [adimensional]

num_amostras = numel(x_lin);   % Comprimento total do sinal de entrada L [amostras]
N            = numel(h_lin);   % Numero de coeficientes / tamanho do buffer circular [coeficientes]

%% 2. Inicializacao do Buffer Circular e dos Ponteiros
buf = zeros(1, N);             % Buffer circular de N amostras inicializado em repouso [amplitude]
y_lin = zeros(1, num_amostras);% Pre-alocacao do vetor de saida [amplitude]

% Inicializa idx_recente em 1: no primeiro passo (n = 1), o decremento
% anti-horario posiciona idx_recente em N (qualquer posicao inicial em
% buffer zerado produz resultado identico).
idx_recente = 1;               % Ponteiro para a amostra mais recente no buffer (1..N) [indice]

%% 3. Processamento Amostra a Amostra no Tempo Discreto
for n = 1:num_amostras
    % 3.1. Atualizacao do ponteiro de escrita no sentido anti-horario
    %      (sobrescreve a amostra mais antiga do buffer circular)
    idx_recente = idx_recente - 1; % Passo anti-horario [indice]
    if idx_recente < 1
        idx_recente = N;           % Retorno circular ao final do anel (wrap-around) [indice]
    end
    buf(idx_recente) = x_lin(n);   % Armazena a nova amostra x(n) [amplitude]

    % 3.2. Laco de convolucao com leitura no sentido horario a partir de idx_recente
    idx_leitura = idx_recente;     % Indice auxiliar separado para percorrer o buffer [indice]
    acumulador  = 0.0;             % Acumulador da soma de produtos MAC [amplitude]

    for k = 1:N
        acumulador = acumulador + h_lin(k) * buf(idx_leitura); % Acumula h(k) * x(n - k + 1) [amplitude]

        % Avanca o indice auxiliar de leitura no sentido horario com retorno circular
        idx_leitura = idx_leitura + 1; % Passo horario [indice]
        if idx_leitura > N
            idx_leitura = 1;           % Retorno circular ao inicio do anel (wrap-around) [indice]
        end
    end

    % 3.3. Registra a amostra filtrada na saida
    y_lin(n) = acumulador;         % Saida filtrada no instante discreto n [amplitude]
end

%% 4. Formatacao da Saida Consistente com a Entrada
if eh_coluna
    y = y_lin(:);                  % Retorna vetor coluna se a entrada for coluna [amplitude]
else
    y = y_lin;                     % Retorna vetor linha se a entrada for linha [amplitude]
end
end
