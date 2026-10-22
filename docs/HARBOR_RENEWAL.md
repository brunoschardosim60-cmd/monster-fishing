# Porto, navegação e interface — 22/10/2026

Atualização implementada sobre o projeto existente, preservando pesca, captura na mão, barco, salto, natação, inventário e progressão da sessão.

## Interface

A exploração mostra somente horário/clima, rumo, saldo/capturas e uma ação curta quando existe algo para interagir. Foram retirados o título grande, o objetivo permanente e a faixa com todos os controles. Os comandos continuam disponíveis em ESC; mapa, enciclopédia e capturas continuam sob demanda. A pesca usa um painel menor, com barras apenas durante a disputa. Avisos repetidos de lançamento e espera foram removidos.

## Vila e pontes

- Iluminação ambiente azul suave à noite, luz da lua, janelas quentes e mais postes com lanternas. As luzes locais não usam sombras individuais e são desligadas fora do alcance da câmera.
- Ponte oeste arqueada de 31 m até o porto antigo; ponte leste de 41 m, retorno de 11 m e ligação de 12 m à praia. Uma rampa de 4 m preserva a entrada do armazém.
- Tabuado, pilares, contraventamentos, guarda-corpos e vãos para as bancas. Os pisos têm colisão contínua; as aberturas dos corrimãos foram verificadas caminhando com o controlador real.
- Três bancas acessíveis: peixaria/mercado, pesca e acessórios navais. As lonas têm malha curva e movimento ligado ao vento do oceano, com as bordas fixas.
- Dois moradores percorrem as novas pontes, além dos moradores existentes. A altura dos pés acompanha a curvatura do piso.

## Pessoas e peixes

Moradores aceleram e desaceleram progressivamente e param apenas nas paradas da rota. O ciclo de caminhada acompanha a velocidade. O rig original foi reexportado pelo Blender com ajustes de apoio dos pés, flexão de joelhos, movimento de braços, rotação de tronco e transições mais longas. O personagem usa corrida leve acima de 3 m/s; movimentação, salto e controles continuam preservados. O boné acompanha a posição real da cabeça.

Os cardumes passaram de posições instantâneas em círculos para movimento com velocidade, aceleração, separação entre peixes, inclinação e velocidade angular limitada. A cauda recebe fase individual e frequência ligada à velocidade; as normais acompanham a deformação. Atração pela isca e fuga do motor continuam funcionando.

Dois pescadores utilizam instâncias do mesmo sistema de pesca do jogador: lançam, aguardam a mordida, fisgam, controlam a tensão, recolhem e depositam a captura no balde. O estoque do mercado recebe o peixe real, com espécie, peso e valor. O estoque está limitado a 24 unidades. Comprar um peixe retira a unidade do estoque e transfere a captura para o inventário; não concede uma descoberta de espécie por pesca.

## Comércio

As bancas de pesca e oficina usam as melhorias já existentes. Nos mercados também é possível:

- Comprar e revender kit de reparo, caixa de anzóis e lona naval.
- Consumir um kit para recuperar 35% do casco, sem ultrapassar 100%.
- Preparar seis iscas usando uma caixa de anzóis.
- Montar um kit com uma lona e dois materiais coletados.
- Vender uma isca, um material, uma captura individual ou todas as capturas.
- Comprar as entregas dos pescadores locais, pagando 125% do valor de revenda.

Saldo e quantidades são alterados na economia existente. Itens consumidos ou vendidos não podem ser reutilizados. O sistema continua usando a persistência de sessão existente; esta atualização não acrescenta salvamento de campanha.

## Faróis e embarcação

O farol da trilha foi remodelado com alvenaria, balcão, guarda-corpos, armação da lanterna e anéis da lente. Um segundo farol, perto da trilha da praia em (174, 96), orienta a aproximação pelo mar e aparece na carta náutica. À noite, o foco gira a cada 12 segundos; o brilho observado varia conforme sua direção. Um SpotLight ilumina superfícies até 650 m, acompanhado por uma representação leve do feixe. É um efeito visual de espalhamento, não uma simulação óptica/volumétrica completa.

O barco fornecido pelo usuário continua sendo a base navegável. Foram acrescentados tabuado e juntas do convés, defensas, cordas, cunhos, guarda-corpos, porta-varas, banco de popa e caixa de equipamento. Esses elementos acompanham o casco nas ondas, junto das luzes existentes.

## Referências e imagens

As referências de organização do porto vieram das passagens e frentes comerciais do [cais histórico de Bergen](https://en.visitbergen.com/ideas-and-inspiration/explore-bergen/bergen-world-heritage-city). A construção visual da lanterna considerou a [explicação da Library of Congress sobre lentes de faróis](https://www.loc.gov/everyday-mysteries/categories/technology/item/how-is-lighthouse-light-magnified/). A arquitetura do jogo é original.

Foram geradas duas imagens de conceito pelo image_gen integrado: [pontes e mercado](art-direction/harbor-bridges-concept.png) e [acabamento da embarcação](art-direction/boat-outfitting-concept.png). Elas orientam o trabalho e **não são capturas do jogo**. Os prompts completos e o modo de geração estão em [harbor-renewal-prompts.json](harbor-renewal-prompts.json).

As capturas reais e os registros da execução estão em `docs/harbor-renewal-audit/`. Os testes reproduzíveis são `tests/harbor_renewal_contract.gd`, `tests/harbor_renewal_visual.gd` e `tests/harbor_benchmark.gd`. O contrato funcional também foi incluído em `Testar.cmd`.

## Validação

O contrato novo passou nas 18 verificações: travessia das pontes, acesso ao mercado, dinheiro/estoques, consumo de itens, reparo, fabricação, venda individual, fornecimento dos NPCs, movimento dos cardumes e farol. Regressões: pesca (29), integração (45), atracação (18), água (8), oceano (18), arquipélago (26), rotas expandidas (3), mundo vivo/animações (20) e vida marinha/tráfego (17). O teste do arquipélago percorreu os 14 interiores; um corrimão que bloqueava o armazém foi removido do acesso e substituído por ligação com rampa.

Execução gráfica em Forward+ e Compatibility, com capturas reais de dia, noite, ponte, barco, pescador, cardume, mercado e interface. Não foi usado o conceito gerado como comprovação do resultado em jogo.

Medição local em 1440×900, VSync ligado, 300 quadros por vista após aquecimento, na GPU identificada pelo Godot como AMD Radeon RX 580 2048SP:

| Qualidade | Vila à noite | Pontes à noite |
|---|---:|---:|
| Equilibrada | 59,8 FPS | 59,8 FPS |
| Alta | 43,6 FPS | 52,0 FPS |

São duas vistas medidas, não uma garantia de FPS para o mundo inteiro. Os ajustes de qualidade permanecem disponíveis em ESC. O arquivo `harbor-benchmark.json` contém os tempos de quadro e as chamadas de desenho.
