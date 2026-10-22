# Peixes

Pasta preparada para GLBs reais de peixes. Atualmente sardinha, cavala e robalo usam as malhas procedurais funcionais de `scripts/fishing/catch_display.gd`, com os dados em `data/fish/`. Não há arquivos externos fictícios.

Ao importar um peixe, siga `assets/README.md`, crie uma cena visual e associe-a ao campo `FishSpecies.visual_scene`. Inspecione se há rig antes de usar animação esquelética. `scripts/creatures/marine_actor.gd` oferece deslocamento básico e sinais de observação/captura; a enciclopédia é mantida pelo inventário.
