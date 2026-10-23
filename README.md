# Monster Fishing — Arquipélago da Aurora

Jogo local de pesca e exploração em **Godot 4.7.2**. A ilha inicial tem aproximadamente **700 × 1.100 m**, vila, porto antigo, interiores, trilhas de montanha, fauna marinha e embarcações em movimento. O oceano navegável ocupa 4,4 × 4,4 km e conecta as bordas opostas.

## Jogar

### Abrir a cópia do GitHub

Clone este repositório ou use **Code → Download ZIP** e extraia a pasta. No **Godot 4.7.2 Standard**, escolha **Importar**, selecione `project.godot` e aguarde a importação dos modelos e texturas. Pressione **F6** somente para uma cena específica ou **F5** para iniciar o jogo completo.

O repositório inclui código, cenas, dados, modelos, texturas e documentação. O executável do Godot, o cache `.godot/` e os resultados temporários dos testes ficam fora do Git. Os atalhos `.cmd` desta pasta usam a instalação portátil local em `tools/godot/`; sem essa instalação, abra e execute pelo editor Godot.

### Instalação local com Godot portátil

Abra **Jogar.cmd**. **Esc** permite mudar clima, horário, qualidade Baixa/Equilibrada/Alta/Ultra, resolução 3D e VSync. As preferências gráficas são salvas. **Jogar leve.cmd** usa OpenGL/Compatibility. **Abrir editor.cmd** abre o projeto no Godot portátil.

| Controle | Ação |
|---|---|
| WASD / Mouse | Caminhar, nadar ou pilotar / olhar |
| Shift / Espaço | Correr / pular, inclusive no convés |
| E / R | Interagir, embarcar e sair / alternar leme e convés |
| Clique esquerdo ou Q | Segurar para mirar, soltar para lançar; fisgar e recolher na disputa |
| Roda do mouse / botão direito | Ajustar alcance enquanto mira / cancelar pesca |
| G / X | Guardar a captura na mão / devolver ao mar |
| L / V | Luzes do barco / observar criatura próxima com o barco lento |
| F | Primeira / terceira pessoa |
| M / Z | Mapa / mudar escala |
| J / Tab | Enciclopédia / capturas |
| T | Ativar/desativar voo livre para explorar o mapa |
| Espaço / Ctrl / Shift (voando) | Subir / descer / acelerar |
| Esc | Pausa, retorno ao cais e configurações |

Pesque de praias, cais, rochas ou do barco em baixa velocidade. O lançamento verifica água, alcance e obstáculos; é possível caminhar com a linha lançada. Solte para aliviar a tensão nas arrancadas. A captura entra no inventário ao guardar com **G**. Na água, aproxime-se do Aurora e use **E** para subir.

A costa tem sardinha, cavala e robalo; águas profundas acrescentam atum. À noite, o mar profundo também oferece peixe-lanterna. Cardumes aproximam-se da isca e fogem de motores próximos; lançar junto deles favorece sua espécie. O Vigia Abissal é uma descoberta por observação, sem captura ou combate.

## Porto e interface atualizados

Vila iluminada à noite, dois faróis com feixe giratório, pontes caminháveis com três bancas, pescadores abastecendo o mercado e compra/venda de itens. Moradores e cardumes usam movimento suavizado. A tela mostra menos texto; os controles completos ficam em ESC. Veja [implementação, referências e testes](docs/HARBOR_RENEWAL.md).

## Mundo e arte

- 14 prédios com interiores e portas, mercado, loja, oficina, armazém, cabana e moradores caminhando.
- Porto antigo com o **GLB completo enviado**, em escala de 58 m, conectado à vila por cais e duas bancas funcionais.
- Compras reais de iscas, vara, linha, anzol, motor, reparo, molinete de maior alcance, proteção do casco e holofote de 65 m.
- Trilha norte até o cume de 150 m, mirantes, gruta, ruínas, farol e arco rochoso com passagem navegável.
- Pesqueiro, rebocador e navio de apoio percorrem oito trechos ao redor da ilha, com flutuação, esteiras, luzes e desvio do jogador.
- Todos os seis modelos enviados integrados: personagem, pesqueiro, rebocador, porto, cabra e dragão.
- Personagem com rig local e 11 animações, incluindo braços/tronco, lançamento, recolhimento, salto e queda.
- Novos modelos no Blender: detalhes das casas, arco, boné, mochila, três peixes e criatura marinha. Folhas e materiais gerados também são utilizados no jogo.
- Árvores, samambaias, rochedos e materiais CC0: **Powered by Poly Haven**. Fontes em docs/asset-audit/.

Veja [a entrega e validação atuais](docs/LIVING_WORLD.md), [imagens e prompts](docs/ART_GENERATION.md) e [o contrato de assets](assets/README.md). As imagens conceituais são referências; docs/living-world-audit/ contém capturas do jogo real.

## Testar

**Testar.cmd** executa pesca, economia, navegação, salto, terreno, interiores, caminhada, circunavegação e comportamento marinho. **Testar arquipelago visual.cmd** renderiza imagens, verifica animação/vento e mede seis cenários em 1440×900. **Testar oceano visual.cmd** verifica os cenários marítimos. Saídas temporárias: tests/output/.

Blender só é necessário para refazer scripts em scripts/pipeline/. O runtime não depende de Python nem de um serviço Tripo. O Godot portátil não é versionado; em outra máquina use uma instalação Standard compatível.

## Estado da entrega

O progresso permanece **por sessão**. O mundo conecta bordas de um mapa plano, sem planeta esférico. A ilha inicial concentra o conteúdo; outras regiões são bases para expansão. Os interiores acessíveis são os módulos da vila; construções fechadas do porto importado não ganharam interiores fictícios.

Cabra e dragão chegaram sem rig: a cabra é estática e o dragão tem respiração simples e descoberta. O navio de apoio adapta o rebocador fornecido para 30 m. Navios de tráfego não podem ser pilotados.

O acabamento ainda não equivale às referências realistas. Documentos anteriores, incluindo docs/ARCHIPELAGO.md, são históricos; o estado atual está em docs/LIVING_WORLD.md.
