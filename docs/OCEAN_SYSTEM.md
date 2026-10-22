# Monster Fishing — oceano integrado

Implementado em 21/10/2026 no projeto Godot existente. A lancha, personagem, controles, pesca, mercado, inventário, dinheiro, retorno ao cais e progresso da sessão continuam usando os sistemas anteriores.

## Jogar

Abra `Jogar.cmd`. No menu inicial ou em **ESC → Condições do mar**, escolha clima dinâmico, mar calmo, brisa, agitado, tempestade ou após a tempestade. As escolhas alteram o destino da transição, sem trocar a superfície instantaneamente. A mudança fica perceptível ao longo de dezenas de segundos; as ondas demoram mais a perder força.

O ciclo automático começa com brisa. As fases duram aproximadamente 100–150 segundos, com uma frente de tempestade mais curta. O horário visual continua sendo fim de tarde, como no projeto anterior. Pausar congela o clima, a água, o barco e os efeitos.

`Jogar leve.cmd` usa Compatibility/OpenGL. As ondas, chuva, espuma, boias, esteiras e amostragem permanecem funcionais; SSR, SSAO e TAA dependem do renderizador Forward+.

## Arquitetura e comportamento

| Parte | Implementação |
|---|---|
| Estado ambiental | `scripts/ocean/sea_weather.gd`: vento, chuva, nuvens, neblina e energia acumulada. Vento responde em cerca de 18 s; o swell cresce em cerca de 30 s e perde energia em cerca de 115 s. São constantes de suavização, não prazos rígidos. |
| Superfície compartilhada | `scripts/world/wave_field.gd` e `assets/shaders/ocean_common.gdshaderinc`: oito componentes de 2–64 m, fases independentes, direções variadas, cristas assimétricas, modulação espacial e deriva gradual pelo vento. O relógio é controlado pela física do jogo. |
| Praia e abrigo | Distância e normal das quatro ilhas determinam profundidade aproximada, amortecimento costeiro e proteção a sotavento. A enseada do cais tem abrigo adicional. O shader combina rebentação móvel, espuma por contato e escurecimento da areia molhada. |
| Rochas | Afloramentos nas ilhas distantes, colisões preservando a aproximação sul já utilizada, pontos de impacto na face externa e respingos acionados pela passagem das cristas. |
| Passagem entre gelo e costa | Corredor localizado perto de **(84, −136)** no plano X/Z, com redução das ondas curtas transversais e ondulação alinhada ao canal. É uma zona autorada para essa geografia, não uma simulação de correntes de fluido. |
| Região fria | Gelo flutuante com colisão, amostragem da água, costa com cobertura clara, água mais escura e neblina local na ilha a nordeste. O gelo também bloqueia lançamentos da linha sobre sua superfície. |
| Barco | Quatro amostras na linha d’água e uma no centro alimentam uma mola amortecida de sustentação. Arfagem e balanço vêm da diferença entre proa/popa e bombordo/boreste. Curvas e velocidade acrescentam inclinação; vento forte reduz moderadamente a velocidade máxima em áreas expostas. |
| Tipos de embarcação | Recursos em `data/boats/`: lancha de 1.200 kg e perfil de pesqueiro de 6.500 kg, com comprimento, boca, massa, amortecimento, calado e limites próprios. O pesqueiro é um perfil para integração de outros modelos; a embarcação jogável continua sendo a lancha existente. |
| Esteira | Histórico em coordenadas do mundo, máximo de 102 amostras, expansão e dissipação em 12 s. Segue curvas e permanece após soltar o acelerador. Voltar ao cais limpa a esteira antiga. |
| Efeitos locais | Pool de 12 conjuntos de ondulação/respingo, 40 partículas por conjunto, descarte por distância. Espuma e anéis acompanham o mesmo shader da superfície. |
| Pesca | Boia na altura amostrada, linha conectada à vara, anéis deformados pela água, impactos no lançamento/mordida/captura e breve salto do peixe fisgado. A apresentação não altera chances, tensão, recompensas ou progressão. |
| Chuva e tempestade | Chuva próxima da câmera, impactos pequenos na superfície, reflexos mais fragmentados, nuvens densas, neblina, vento com rajadas, clarão ocasional e trovão com atraso. A melhora do tempo deixa ondulação residual. |
| Submersão | Fundo costeiro, absorção por espessura, tratamento da face inferior da água e neblina/áudio abafados quando uma câmera está submersa. O controle do jogador conserva a recuperação ao cair na água; não foi adicionado um sistema de mergulho. |
| Áudio | Camadas sintetizadas originais de mar, vento e chuva; fontes espaciais de costa, casco, respingo e trovão. Ganhos, timbre e posição acompanham clima e localização. |

O movimento horizontal e as colisões da lancha continuam no `CharacterBody3D` existente. A sustentação vertical e angular movimenta o casco e o assento real do jogador. Essa solução híbrida mantém a resposta visual ligada à superfície sem comprometer atracação e circulação no cais.

## Desempenho

A área navegável usa uma grade de aproximadamente 0,75 m. Quatro faixas de baixa densidade prolongam o horizonte. O deslocamento geométrico se reduz além da área de jogo, enquanto as normais continuam dando detalhe ao mar distante. A câmera e as faixas foram ampliadas para remover o corte artificial do horizonte.

A água escreve profundidade mesmo na passagem de refração. A inspeção isolando SSR, sombras e fundo revelou que a ausência dessa escrita deixava faces distantes sobrepostas às cristas próximas, formando triângulos escuros. A correção preserva a refração e a visão submersa. `tests/ocean_render_probe.gd` permite repetir o diagnóstico.

A atualização de radiância do céu usa filtragem em tempo real para evitar os picos que apareceram durante a primeira avaliação de tempestade. Essa escolha segue os modos de atualização documentados para [Sky no Godot](https://docs.godotengine.org/en/stable/classes/class_sky.html). Chuva e respingos usam os mesmos emissores CPU limitados nos dois renderizadores, conforme a API de [CPUParticles3D](https://docs.godotengine.org/en/stable/classes/class_cpuparticles3d.html).

Os relatórios JSON ao lado das capturas registram a GPU, renderizador, tamanho real do framebuffer, tempos de quadro, chamadas de desenho e memória de renderização. São observações locais com limite de 60 FPS e outros aplicativos possivelmente abertos, não uma garantia para qualquer máquina.

Medição sustentada na **Radeon RX 580 2048SP**, Forward+, MSAA 2× e TAA, framebuffer 1440 × 900, 600 quadros por vista após aquecimento:

| Vista | FPS médio | Quadro p95 | Memória de renderização |
|---|---:|---:|---:|
| Cais | 59,77 | 17,58 ms | 490 MB |
| Vila | 59,79 | 17,56 ms | 490 MB |
| Navegação | 59,79 | 17,52 ms | 490 MB |
| Tempestade | 59,79 | 17,47 ms | 490 MB |

Dados completos: [benchmark](ocean-audit/benchmark.json). As passagens curtas do roteiro de capturas tiveram alguns picos maiores, especialmente durante mudanças de estado e capturas. Não foram omitidos: estão no [relatório dos cenários](ocean-audit/scenarios.json). A coluna de memória é a informada pelo renderizador, não o consumo total do processo ou da placa.

## Validação reproduzível

- `Testar.cmd`: regressões de pesca, mundo, movimentação, atracação, câmera e contratos do oceano.
- `Testar oceano visual.cmd`: executa as capturas dos cenários e a comparação numérica CPU/GPU.
- `tests/ocean_contract.gd`: transições graduais, memória de ondas, abrigo, profundidade, canal, comparação de 1.280 pontos CPU/GPU em cinco estados, resposta do casco e persistência/dissipação da esteira.
- `tests/ocean_scenarios.gd`: framebuffer real de **1440 × 900**, dez cenários solicitados e vistas adicionais de salto do peixe, gelo, canal, fundo submerso e menu.
- `tests/render_benchmark.gd`: 600 quadros medidos após aquecimento em cada vista: cais, vila, barco e tempestade.

O teste gráfico acelera apenas os intervalos de espera entre as etapas de uma frente climática. As imagens são produzidas pelo jogo real, sem pintura, montagem de concept art ou pós-processamento externo. Os outros cenários usam estados estabilizados para permitir comparação.

Resultado: **108 verificações anteriores + 19 do contrato do oceano**, sem falhas; o contrato novo passou tanto em Forward+ quanto em Compatibility. A diferença máxima entre a altura calculada na CPU e a lida do shader foi de aproximadamente **0,26 mm**, incluindo pontos da passagem entre gelo e costa. O teste gráfico de jogabilidade acrescenta 32 verificações de interface, pesca/captura e leitura das imagens.

Os testes de áudio usam o driver Dummy: verificam carregamento e execução, não conforto auditivo. O jogador pode ouvir a mixagem sintetizada na execução normal do jogo.

## Capturas do jogo

| Cenário | Captura |
|---|---|
| 1. Lancha parada, mar calmo | [Imagem](ocean-audit/01_calm_boat.png) |
| 2. Navegação em mar aberto | [Imagem](ocean-audit/02_open_water.png) |
| 3. Travessia de ondas grandes | [Imagem](ocean-audit/03_large_waves.png) |
| 4. Rebentação na praia | [Imagem](ocean-audit/04_beach_breakers.png) |
| 5. Ondas na costa rochosa | [Imagem](ocean-audit/05_rock_coast.png) |
| 6. Enseada protegida | [Imagem](ocean-audit/06_sheltered_harbor.png) |
| 7. Chuva forte → tempestade | [Chuva](ocean-audit/07a_heavy_rain.png) · [Tempestade](ocean-audit/07b_storm.png) · [Relâmpago](ocean-audit/07c_lightning.png) |
| 8. Melhora com ondas residuais | [Imagem](ocean-audit/08_after_storm.png) |
| 9. Boia e linha na superfície | [Boia](ocean-audit/09_fishing_float.png) · [Peixe fisgado](ocean-audit/09b_hooked_fish_breach.png) |
| 10. Esteira após acelerar e virar | [Imagem](ocean-audit/10_persistent_turning_wake.png) |
| Região fria e passagem | [Gelo](ocean-audit/11_cold_floes.png) · [Canal](ocean-audit/14_ice_channel.png) |
| Observação abaixo da água | [Imagem](ocean-audit/12_underwater.png) |
| Escolha do clima | [Imagem](ocean-audit/13_weather_menu.png) |

## Limites da solução

É um oceano híbrido adequado ao mapa atual. A batimetria e o abrigo são aproximações baseadas nas ilhas, complementadas por efeitos de contato e zonas autoradas. Não há solver volumétrico, quebra de ondas com malha enrolando, correntes fluidodinâmicas, inundação interna do barco ou gelo destrutível. A região fria é uma área demonstrativa integrada à ilha existente. A qualidade dos modelos e texturas do restante do mundo continua distinta das referências cinematográficas enviadas pelo usuário.
