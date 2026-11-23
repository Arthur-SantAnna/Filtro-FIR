function specs = config_specs()
% CONFIG_SPECS Define as especificacoes imutaveis do filtro FIR e caminhos do projeto.
%
%   Proposito:
%       Centralizar todos os parametros fisicos e de especificacao da mascara
%       do filtro FIR passa-baixa da Pratica 3, alem de resolver de forma
%       portavel os diretorios de dados, figuras e resultados.
%
%   Saidas:
%       specs - Estrutura (struct) contendo:
%           .Fs            - Frequencia de amostragem [Hz]
%           .Fpass         - Limite superior da banda passante [Hz]
%           .Fstop         - Limite inferior da banda de rejeicao [Hz]
%           .fc            - Frequencia de corte ideal inicial [Hz]
%           .tol_pass_dB   - Desvio maximo permitido na banda passante [dB]
%           .aten_stop_dB  - Atenuacao minima exigida na banda de rejeicao [dB]
%           .Nfft          - Numero de pontos da grade densa de frequencia [pontos]
%           .caminhos      - Subestrutura com diretorios absolutos portaveis

%% 1. Especificacoes Imutaveis do Filtro Passa-Baixa
specs.Fs           = 8000;  % Frequencia de amostragem [Hz]
specs.Fpass        = 1000;  % Frequencia limite da banda passante [Hz]
specs.Fstop        = 2200;  % Frequencia inicial da banda de rejeicao [Hz]
specs.fc           = 1600;  % Frequencia de corte ideal inicial (centro da transicao) [Hz]
specs.tol_pass_dB  = 0.1;   % Desvio maximo permitido na banda passante em torno de 0 dB [dB]
specs.aten_stop_dB = 45.0;  % Atenuacao minima exigida na banda de rejeicao [dB]

%% 2. Parametros de Avaliacao Espectral
specs.Nfft         = 32768; % Numero de pontos da grade densa de frequencia (>= 16384) [pontos]

%% 3. Resolucao Portavel de Caminhos
dir_atual = fileparts(mfilename('fullpath')); % Diretorio onde config_specs.m reside
dir_utils = fullfile(dir_atual, 'utils');
if isfolder(dir_utils)
    addpath(dir_utils);
end

% Verifica se estamos na estrutura padrao (src/ dentro da raiz) ou pacote unico (entrega/)
[~, nome_pasta] = fileparts(dir_atual);
if strcmpi(nome_pasta, 'src')
    dir_raiz = fileparts(dir_atual);
    specs.caminhos.raiz    = dir_raiz;
    specs.caminhos.src     = dir_atual;
    specs.caminhos.utils   = dir_utils;
    specs.caminhos.data    = fullfile(dir_raiz, 'data');
    specs.caminhos.figures = fullfile(dir_raiz, 'figures');
    specs.caminhos.results = fullfile(dir_raiz, 'results');
    specs.caminhos.report  = fullfile(dir_raiz, 'report');
    specs.caminhos.entrega = fullfile(dir_raiz, 'entrega');
else
    % Modo autocontido (ex.: todos os .m e .mat executados dentro de entrega/)
    specs.caminhos.raiz    = dir_atual;
    specs.caminhos.src     = dir_atual;
    specs.caminhos.utils   = dir_utils;
    if isfolder(fullfile(dir_atual, 'data'))
        specs.caminhos.data = fullfile(dir_atual, 'data');
    else
        specs.caminhos.data = dir_atual;
    end
    specs.caminhos.figures = fullfile(dir_atual, 'figures');
    specs.caminhos.results = fullfile(dir_atual, 'results');
    specs.caminhos.report  = fullfile(dir_atual, 'report');
    specs.caminhos.entrega = dir_atual;
end

% Garante a existencia dos diretorios de saida
pastas_saida = {specs.caminhos.data, specs.caminhos.figures, specs.caminhos.results};
for i = 1:numel(pastas_saida)
    if ~isfolder(pastas_saida{i})
        mkdir(pastas_saida{i});
    end
end
end
