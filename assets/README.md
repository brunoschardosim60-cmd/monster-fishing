# Modelos externos e cenas reutilizáveis

Os seis arquivos enviados foram lidos e exportados para cópias próprias do jogo. Nenhum original em Downloads foi substituído. Auditorias com SHA-256, estrutura, materiais, triângulos e resultado estão em `docs/asset-audit/`.

| Origem | Arquivo do jogo | Uso |
|---|---|---|
| fishing boat 3d model.glb | boats/fishing_boat.glb | Aurora, navegação e convés |
| tugboat 3d model.glb | boats/tugboat.glb | Rebocador atracado e duas embarcações de tráfego |
| coastal village harbor 3d model.glb | environment/harbor_dressed.glb | Porto antigo completo, 58 m, ligado à vila |
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

As alternativas procedurais de barco/personagem/peixes permanecem no código. Cavala, atum e peixe-lanterna agora têm GLBs reais em fish/, com cenas em scenes/models/. O Vigia Abissal usa monsters/abyssal_guardian.glb. Foram modelados no Blender com referências e texturas geradas; não houve conversão automática pela Tripo. Sardinha e robalo mantêm a alternativa procedural. Não crie caminhos para arquivos que ainda não existem.

marine_ecosystem.gd conecta cardumes à isca e ao motor, define habitats por profundidade/horário e mantém a observação da criatura. marine_visual.gd compartilha cenas/materiais e anima caudas e nadadeiras no shader. Os Resources registram espécie, raridade, valor, região, cena e permissão de captura. maritime_traffic.gd e traffic_vessel.gd controlam as embarcações independentes; o Aurora preserva seu próprio controlador.

Natureza CC0 preparada em environment/nature/ usa malhas compartilhadas, vento e representações simplificadas à distância. **Powered by Poly Haven**. Consulte docs/asset-audit/polyhaven-sources.json e ground-sources.json para origem e licença. Arquitetura, geologia e acessórios locais estão em environment/architecture/, environment/geology/ e characters/accessories/.

## Pipeline local

Execute no Blender em modo background os scripts em `scripts/pipeline/`. `prepare_external_assets.py -- <chave>` converte/decima uma cópia; `rig_survivalist.py` prepara o personagem; `extract_harbor_roofs.py` separa arquitetura; `foliage_texture.py` usa Pillow para a textura original da folhagem. Texturas dos modelos são limitadas a 2048 pixels. O runtime não executa Python/Blender.

O personagem de origem tinha três figuras fundidas em uma malha, sem esqueleto. A figura central foi recortada, normalizada para 1,82 m e recebeu 17 ossos e 11 clips: Idle, Walk, Run, Fish, Hold, Steer, Swim, Cast, Reel, Jump e Fall. Não há retarget automático ou animações Tripo presumidas. Boné, mochila, vara e captura acompanham pontos do corpo animado.
