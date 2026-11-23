function caminhos_arquivos = salvar_figura(fig_handle, nome_base, specs)
% SALVAR_FIGURA Padroniza a estetica da figura e exporta em PDF vetorial e PNG 300 dpi.
%
%   Proposito:
%       Garantir consistencia tipografica, tema claro (fundo branco e textos
%       pretos, independente do tema dark/light do MATLAB R2025+/R2026+),
%       grade visivel e exportacao dupla (.pdf para LaTeX e .png 300 dpi
%       para visualizacao) de todas as figuras geradas no projeto.
%
%   Entradas:
%       fig_handle - Handle da figura MATLAB a ser exportada
%       nome_base  - Nome base do arquivo sem extensao (ex.: 'fig_A1_impulso_janela')
%       specs      - (Opcional) Estrutura retornada por config_specs()
%
%   Saidas:
%       caminhos_arquivos - Estrutura com os caminhos .pdf e .png gerados

if nargin < 3 || isempty(specs)
    specs = config_specs();
end

% Forca tema claro no MATLAB R2025a/R2026b+ para evitar fundo escuro e fonte clara
try
    theme(fig_handle, 'light');
catch
    % Compatibilidade com versoes anteriores do MATLAB sem a funcao theme()
end

set(fig_handle, 'Color', 'w');

% Padroniza todos os eixos contidos na figura
eixos = findall(fig_handle, 'Type', 'axes');
for k = 1:numel(eixos)
    ax = eixos(k);
    set(ax, ...
        'Color', 'w', ...
        'XColor', [0.1, 0.1, 0.1], ...
        'YColor', [0.1, 0.1, 0.1], ...
        'GridColor', [0.4, 0.4, 0.4], ...
        'MinorGridColor', [0.6, 0.6, 0.6], ...
        'FontName', 'Helvetica', ...
        'FontSize', 10, ...
        'LineWidth', 0.9, ...
        'Box', 'on', ...
        'XGrid', 'on', ...
        'YGrid', 'on', ...
        'GridAlpha', 0.30, ...
        'MinorGridAlpha', 0.15);
    if ~isempty(ax.Title)
        set(ax.Title, 'Color', [0, 0, 0], 'FontWeight', 'bold', 'FontSize', 11);
    end
    if ~isempty(ax.XLabel)
        set(ax.XLabel, 'Color', [0, 0, 0], 'FontSize', 10);
    end
    if ~isempty(ax.YLabel)
        set(ax.YLabel, 'Color', [0, 0, 0], 'FontSize', 10);
    end
end

% Padroniza legendas com fundo branco e texto preto
legendas = findall(fig_handle, 'Type', 'legend');
for k = 1:numel(legendas)
    set(legendas(k), ...
        'FontSize', 9, ...
        'Box', 'on', ...
        'Color', [1, 1, 1], ...
        'TextColor', [0, 0, 0], ...
        'EdgeColor', [0.3, 0.3, 0.3]);
end

dir_figures = specs.caminhos.figures;
if ~isfolder(dir_figures)
    mkdir(dir_figures);
end

caminho_pdf = fullfile(dir_figures, [nome_base, '.pdf']);
caminho_png = fullfile(dir_figures, [nome_base, '.png']);

% Exporta PDF vetorial para o relatorio LaTeX e PNG 300 dpi para inspecao
exportgraphics(fig_handle, caminho_pdf, 'ContentType', 'vector', 'BackgroundColor', 'white');
exportgraphics(fig_handle, caminho_png, 'Resolution', 300, 'BackgroundColor', 'white');

caminhos_arquivos.pdf = caminho_pdf;
caminhos_arquivos.png = caminho_png;
end
