# Imagens, modelos e materiais — outubro de 2026

As imagens foram geradas pelo **image_gen integrado** (modo built-in, generate). Não foi usado o fallback CLI nem um serviço Tripo. As malhas foram construídas/preparadas no Blender 5.2 e importadas no Godot. Uma imagem de referência não foi tratada como se fosse um GLB pronto.

| Imagem salva no projeto | Uso |
|---|---|
| art-direction/coastal-house.png | Referência para telhas curvas, alvenaria, caixilhos e venezianas das casas |
| art-direction/island.png | Referência para a costa e o arco rochoso modelado |
| art-direction/fisherman.png | Referência para boné e mochila, presos ao rig existente |
| art-direction/fish.png | Referência e projeção UV dos corpos de cavala, atum e peixe-lanterna |
| art-direction/sea-guardian.png | Referência do Vigia Abissal de 18 m |
| art-direction/support-ship.png | Direção visual das embarcações; o navio atual usa o GLB de rebocador fornecido |
| ../assets/textures/lime_plaster_color.png | Reboco envelhecido e variação das telhas |
| ../assets/textures/cliff_granite_color.png | Rocha do terreno e arco |
| ../assets/textures/fisher_canvas_color.png | Tecido dos acessórios |
| ../assets/textures/marine_skin_color.png | Pele da criatura marinha |
| ../assets/textures/marine_reference_color.png | Cópia integral da referência dos peixes, usada nos materiais |
| ../assets/textures/palm_frond.png | Folha recortada sobre malhas curvas dos coqueiros |
| ../assets/textures/coastal_leaves.png | Ramos foliares recortados sobre árvores com galhos modelados |

Prompts exatos: [casas, ilha, personagem e materiais](art-prompts.json), [peixes e criatura](marine-art-prompts.json), [pele marinha](marine-skin-prompt.txt), [navio](ship-art-prompt.txt), [folhagem](foliage-art-prompts.json). Os arquivos originais de geração permanecem na pasta local do Codex; as cópias usadas pelo projeto estão todas dentro deste repositório.

## Malhas efetivamente integradas

| GLB | Triângulos | Integração |
|---|---:|---|
| coastal_house_details | 16.828 | 14 construções com interiores e portas existentes |
| aurora_sea_arch | 4.844 | Costa leste, passagem física aberta |
| fisher_cap | 1.376 | Acompanha osso da cabeça |
| fisher_backpack | 1.864 | Acompanha peito/tronco |
| mackerel | 4.940 | Cardume, captura e exibição na mão |
| tuna | 4.946 | Cardume, pesca em mar aberto e exibição na mão |
| lanternfish | 10.572 | Pesca noturna profunda e exibição na mão |
| abyssal_guardian | 13.738 | Natação, mergulho, aproximação e observação |

Reprodução: scripts/pipeline/build_art_assets.py, build_marine_assets.py, prepare_nature.py e rig_survivalist.py. As auditorias numéricas estão em asset-audit/. Árvores/rochas CC0 têm fontes e licenças próprias; **Powered by Poly Haven**.

As referências são metas artísticas. Não são capturas do jogo, nem prova de equivalência visual. As imagens em living-world-audit/ foram renderizadas pelo Godot a partir dos assets efetivamente integrados.
