# Modelos externos e cenas reutilizáveis

Os seis arquivos enviados foram lidos e exportados para cópias próprias do jogo. Nenhum original em Downloads foi substituído. Auditorias com SHA-256, estrutura, materiais, triângulos e resultado estão em `docs/asset-audit/`.

| Origem | Arquivo do jogo | Uso |
|---|---|---|
| fishing boat 3d model.glb | boats/fishing_boat.glb | Aurora, navegação e convés |
| tugboat 3d model.glb | boats/tugboat.glb | Embarcação atracada, colisão e flutuação |
| coastal village harbor 3d model.glb | environment/harbor.glb + harbor_roof_0..3.glb | Arquitetura reaproveitada + cena completa |
| survivalist character 3d model.zip | characters/survivalist.glb + survivalist_rigged.glb | Original convertido e personagem preparado |
| dragon creature 3d model.glb | monsters/dragon.glb | Guardião da Vigia, observado pela enciclopédia |
| goat 3d model (1).glb | props/goat.glb | Animal estático na vila |

`scenes/models/` contém wrappers reutilizáveis. Uma unidade do Godot corresponde a um metro; Y é altura, mar é Y=0, proa/frente é −Z. `external_model.gd` calcula limites reais, centraliza o chão e normaliza tamanho e rumo. `waterline_m` ajusta o calado. Materiais originais texturizados são preservados para cabra/personagem; barcos, dragão e porto vieram sem texturas e recebem materiais locais.

## Acrescentar um GLB

1. Guarde a cópia de jogo em characters/, fish/, monsters/, boats/, environment/ ou props/ conforme o uso. Mantenha a fonte original separada.
2. Inspecione malhas, materiais, escala, partes desconectadas, Skeleton3D e AnimationPlayer. Geometria não implica rig ou animações.
3. Crie uma cena em `scenes/models/` e defina escala/origem. Use colisões simples separadas das malhas de renderização. Evite colisão trimesh para corpos móveis.
4. Para barco, acrescente os marcadores Helm, DeckCenter e BoardPort e um Resource `BoatHydrodynamics`; adapte o volume de colisão e os limites do convés ao novo casco. O controlador mantém navegação, ondas, integridade e esteira.
5. Para peixe/criatura, use um `FishSpecies` real em `data/fish/`. Os campos `visual_scene`, `swim_speed`, `capture_allowed` e `preferred_depth` conectam a apresentação a `marine_actor.gd`. O modo swim oferece deslocamento básico; os sinais observed/capture_requested permitem expandir IA e encontros. Isso não é um sistema de combate pronto.
6. Só inclua espécies capturáveis na lista de pesca após definir raridade, peso, valor e regras de região. O guardião usa observação e não entra na seleção aleatória de peixes.
7. Execute primeiro `first_asset_in_game.gd` ou um cenário equivalente para UM asset: aparência, dimensões, colisão, ponto do jogador, controle e desempenho. Expanda depois.

As alternativas procedurais de barco/personagem/peixes permanecem no código. Peixes não possuem GLBs externos nesta entrega; usam a malha funcional existente. Não crie caminhos para arquivos que ainda não existem.

## Pipeline local

Execute no Blender em modo background os scripts em `scripts/pipeline/`. `prepare_external_assets.py -- <chave>` converte/decima uma cópia; `rig_survivalist.py` prepara o personagem; `extract_harbor_roofs.py` separa arquitetura; `foliage_texture.py` usa Pillow para a textura original da folhagem. Texturas dos modelos são limitadas a 2048 pixels. O runtime não executa Python/Blender.

O personagem de origem tinha três figuras fundidas em uma malha, sem esqueleto. A figura central foi recortada, normalizada para 1,82 m e recebeu 17 ossos, pesos locais e sete clips. Não há retarget automático ou animações Tripo presumidas.
