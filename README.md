# Monster Fishing — Arquipélago da Aurora

Jogo de pesca e exploração em Godot 4.7.2. Esta versão amplia a costa inicial para uma ilha de aproximadamente 500 × 570 metros, com vila, interiores acessíveis, trilhas, praia, mirante, gruta e ruínas. O mar navegável ocupa 4,4 × 4,4 km e conecta as bordas opostas.

## Jogar

Abra **Jogar.cmd** e clique em **Começar a explorar**. O barco fica à direita da ponta do cais. **Jogar leve.cmd** usa OpenGL/Compatibility, com iluminação e reflexos simplificados. **Abrir editor.cmd** abre o projeto no Godot portátil em tools/godot/.

| Controle | Ação |
|---|---|
| WASD / Mouse | Caminhar, nadar ou pilotar / olhar |
| Shift | Correr / nadar mais rápido |
| E | Interagir, embarcar ou desembarcar, inclusive em mar aberto |
| R | Alternar leme e caminhada no convés |
| Espaço / botão esquerdo | Lançar, fisgar e recolher; solte para aliviar tensão |
| Botão direito | Cancelar a pesca |
| G / X | Guardar o peixe que está na mão / devolvê-lo ao mar |
| F | Primeira / terceira pessoa |
| M / Z | Abrir mapa / mudar sua escala |
| J / Tab | Enciclopédia e descobertas / capturas |
| Esc | Pausa, retorno seguro, clima e horário |

Pesque olhando para água livre a partir de praias, cais, rochas ou do barco parado. Quando capturar, escolha **G** ou **X**; a captura só entra no inventário ao guardar. Na água, aproxime-se do barco e pressione **E** para subir. O barco continua desacelerando quando você passa ao convés.

Na vila, entre pelas portas abertas e use **E** perto do centro do estabelecimento. A loja vende iscas, vara, linha e anzol; a oficina vende melhoria de motor e repara o casco. O mercado compra capturas, o armazém guarda/retira peixes e a cabana permite descansar. As compras usam as moedas e modificam os sistemas reais de pesca e navegação.

## Mundo e modelos

- 14 prédios acessíveis, seis serviços, moradores caminhando, iluminação noturna, fumaça e aves.
- Trilhas até o farol, mirante, ruínas, gruta e praia; descobertas dão moedas e materiais uma única vez por sessão.
- Ondas geométricas e normais finas, profundidade, espuma, refração, reflexos, abrigo no porto, esteira persistente e flutuação compartilhada entre CPU/GPU.
- Ciclo de dia/noite, sol, lua, estrelas, nuvens, chuva, relâmpagos, trovão e ondulação residual.
- Modelos reais fornecidos pelo usuário: barco pesqueiro pilotável, rebocador atracado, personagem, cabra, dragão e arquitetura derivada do porto. As versões otimizadas ficam em assets/; os originais em Downloads não foram alterados.

Veja [a entrega, testes e capturas atuais](docs/ARCHIPELAGO.md) e [o contrato de integração de assets](assets/README.md).

## Testar

**Testar.cmd** executa pesca, integração, terreno, água, atracação, caminhada pelos interiores/trilhas e uma volta completa de barco ao redor da ilha. **Testar arquipelago visual.cmd** gera imagens no Godot e mede seis cenários em 1440×900. **Testar oceano visual.cmd** percorre os cenários marítimos. Saídas temporárias: tests/output/; evidências versionadas: docs/archipelago-audit/.

O projeto funciona localmente, sem serviço Tripo em execução. O Blender é necessário apenas para refazer a preparação dos modelos, usando os scripts em scripts/pipeline/. O Godot portátil não é versionado; em outra máquina use uma instalação Standard compatível.

## Limites desta etapa

O progresso ainda é mantido **somente durante a sessão**. O mundo usa conexão entre bordas de um mapa plano; não é um planeta esférico. A ilha inicial concentra o conteúdo: as três ilhas distantes ainda são bases para futuras regiões, sem vilas completas. Dragão e cabra chegaram sem rig; o dragão é uma descoberta não capturável, com movimento respiratório simples, e a cabra é estática. O personagem recebeu rig e sete animações básicas locais, que ainda comportam refinamento artístico.

O GLB do porto não tinha interiores caminháveis. Seus telhados foram separados e reaproveitados sobre salas com portas e colisões próprias; a cena completa também está disponível e aparece como maquete na oficina. A vila combina esses módulos com construção procedural. O resultado é uma etapa jogável ampliada; não equivale ao acabamento final das imagens conceituais.

Documentos de fases anteriores em docs/ são históricos. Para o estado atual, use docs/ARCHIPELAGO.md.
