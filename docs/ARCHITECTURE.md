# Arquitetura e evolução

## Composição

Main instancia World, Boat, Player, FishingSystem, FishingVisual, CatchDisplay, OceanAudio e HUD. A máquina de pesca emite sinais, sem conhecer câmera ou interface. O inventário recebe capturas e garante venda única. Espécies são Resources, adicionáveis por dados. A apresentação usa malhas procedurais originais; modelos exportados podem substituir os construtores mantendo a interface pública.

Player é CharacterBody3D, com movimento relativo à câmera e SpringArm. Embarcar desativa sua colisão e o vincula ao assento; desembarcar valida proximidade/velocidade e usa ponto seguro do cais. Boat é outro CharacterBody3D, com colisão estática contra terra/cais e balanço apenas visual. Collision layers: mundo=1, barco=2, jogador=4. Máscaras de jogador/barco/câmera consultam mundo=1.

Pesca segue IDLE → CASTING → WAITING → BITE → REELING → CAUGHT/ESCAPED → IDLE. O tempo de espera e a espécie variam por RNG. Captura exige reação e alternância de pressão/soltura. Movimento fica bloqueado durante a pesca. Pausa congela os sistemas, mas mantém o menu ativo.

## Próximas fases

1. Base jogável atual. Preservar testes de captura, venda, colisão e navegação.
2. Inventário persistente, loja, equipamento, experiência, níveis e enciclopédia; migrar saldo/cesto para serviço de progresso com save versionado e escrita atômica.
3. Interiores, cozinha, fome/energia moderadas, descanso e relógio/clima.
4. Regiões carregáveis por distância, mapa, sonar, barcos e naufrágios. Substituir borda da baía por StreamingRegionManager.
5. Criaturas observáveis, eventos com condições/probabilidade/cooldown e histórico persistente por identificador.
6. Assets finais, animações, áudio profissional, opções, otimização por perfil, salvamento abrangente e testes finais.

Não há singletons obrigatórios nem dependências online. A ilha pequena é carregada integralmente nesta fase; streaming e LOD complexo só devem ser introduzidos quando a escala justificar. Não marcar fases futuras como completas por existir um diretório.

`world/static_batch.gd` agrupa malhas estáticas por material e células de 40 m para reduzir chamadas de desenho. Os corpos de colisão originais são preservados. Água, gaivotas e boias ficam fora dos grupos para continuar animadas. A bússola mostra a direção real da câmera.
