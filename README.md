# Monster Fishing — Fase 1, atualização visual

Um protótipo 3D jogável de pescaria e exploração, construído em Godot 4.7.2 e GDScript. A Costa do Farol é uma pequena ilha com mercado, cabana cenográfica, cais e um barco pilotável, cercada por um oceano animado e ilhotas no horizonte.

## Jogar no Windows

1. Dê dois cliques em **Jogar.cmd** nesta pasta.
2. Clique em **Começar a explorar**.
3. Caminhe até a ponta do cais. O barco Aurora está à direita. Pressione **E** para embarcar.
4. Acelere com **W**, vire com **A/D** e freie com **S**. Pare para pescar.
5. Pressione **Espaço** para lançar. Aguarde **MORDIDA** e pressione novamente para fisgar.
6. Segure **Espaço** ou o botão esquerdo para recolher. Solte para aliviar a tensão, antes de chegar a 100%. Repita até completar a captura.
7. Volte devagar ao lado direito da ponta do cais e pressione **E**. O barco é amarrado ao berço. Caminhe pela passarela em direção à ilha; o mercado fica à direita.
8. Perto do balcão, pressione **E** para vender o cesto e receber moedas.

Também é possível pescar diretamente do cais. Se perder a direção, **Esc → Voltar em segurança ao cais** recupera jogador e barco sem perder as capturas da sessão.

**Jogar.cmd** usa agora Forward+ (Vulkan), com reflexos de tela, oclusão ambiente e a nova água. **Jogar leve.cmd** usa Compatibility/OpenGL, preservando as ondas, texturas e jogabilidade com iluminação simplificada. Veja as capturas reais e os resultados em [docs/VISUAL_UPGRADE.md](docs/VISUAL_UPGRADE.md).

## Controles

| Tecla | Ação |
|---|---|
| WASD | Caminhar / pilotar |
| Mouse | Olhar ao redor |
| Shift | Correr |
| E | Embarcar, desembarcar no cais ou vender no mercado |
| Espaço / botão esquerdo | Lançar, fisgar e segurar para recolher |
| Botão direito | Cancelar pesca |
| F | Alternar primeira / terceira pessoa |
| Tab | Abrir caderno de capturas |
| Esc | Pausar / continuar |
| Setas esquerda / direita | Girar câmera pelo teclado |

## Abrir e desenvolver

**Abrir editor.cmd** abre o projeto na versão portátil do Godot disponível em `tools/godot/`. Também é possível importar `project.godot` pelo gerenciador do Godot 4.7.2. O projeto não depende de rede, login, plugins pagos ou pacotes externos durante o jogo.

A pasta `tools/` contém o motor oficial, que não é versionado pelo Git. O gerador original de texturas `tools/generate_materials.py` é a exceção versionada. Em outro computador, baixe a edição Standard portátil Windows x86_64 em https://godotengine.org/download/windows/ e coloque os executáveis nessa pasta ou abra o projeto por uma instalação compatível.

## Entrega desta fase

- Personagem composto e articulado, câmera com SpringArm, caminhada e corrida.
- Barco com casco original, aceleração, freio/ré, direção, balanço e esteira.
- Ilha com colisão, cais, vegetação, pedras, estruturas, farol e aves animadas.
- Oceano com ondas, variação de cor e reflexos de iluminação; céu e atmosfera de fim de tarde.
- Pesca com espera, janela de reação, disputa de tensão, perda de peixe e captura.
- Sardinha, cavala e robalo em Resources configuráveis.
- Cesto, peso/valor/data da captura e venda com recompensa em moedas.
- Interface contextual, pausa, câmera alternativa e recuperação segura.
- Áudio de ondas e sinais sintetizados originalmente.

## Limites explícitos

Esta entrega encerra a Fase 1. Não é o mundo aberto completo. **O cesto e as moedas são mantidos apenas durante a sessão; sair fecha esse progresso.** Não há ainda salvamento entre sessões, loja, melhorias, fome, cozinha funcional, entrada na cabana, clima dinâmico, ciclo temporal, sonar, criaturas lendárias ou outras regiões jogáveis. A luz de fim de tarde é fixa. As ilhotas distantes são cenográficas. O desembarque ocorre no cais inicial; não há natação. Existe um limite de navegação da baía.

Os modelos e as animações continuam originais e procedurais, agora com superfícies suaves, articulações, detalhes construtivos e materiais texturizados. O mar tem ondas geométricas, espuma, normais animadas, refração por profundidade e reflexos de céu/luz; Forward+ acrescenta SSR. Não há simulação de fluidos nem reflexão completa de objetos fora da tela. O balanço acompanha as ondas visualmente, enquanto a navegação mantém o controle e as colisões existentes.

## Estrutura

`scripts/main.gd` conecta os sistemas. `scripts/player/`, `boats/`, `fishing/`, `inventory/`, `world/`, `ui/` e `audio/` separam responsabilidades. `data/fish/` contém o conteúdo configurável. `scenes/main/main.tscn` é a entrada. `tests/` contém regressões executáveis. `docs/` registra arquitetura, arte, ambiente e testes.

Execute **Testar.cmd** para os testes técnicos. A inspeção gráfica e seus limites são registrados em `docs/TESTS.md`.
