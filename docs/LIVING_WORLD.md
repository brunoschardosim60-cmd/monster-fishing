# Entrega atual — mundo vivo, pesca e navegação

Estado de 22/10/2026. Esta página substitui os números e limitações desatualizados das entregas anteriores. Os sistemas de movimento, pesca, inventário, economia, barco, oceano e interface foram ampliados no projeto existente.

## Jogabilidade implementada

- **Salto:** Espaço em terra e no convés; tolerância de borda de 0,12 s e comando antecipado de 0,16 s; animações Jump/Fall. O convés mantém o jogador acompanhando a flutuação.
- **Pesca livre:** clique esquerdo/Q para carregar alcance de 5–42 m e soltar para lançar, roda para ajustar a mira, trajetória e obstáculos verificados. Caminhada lenta durante a pesca; cancelar ao entrar na água ou exceder o alcance. Molinete comprado acrescenta 12 m.
- **Captura:** peixe segue a mão; G guarda no balde/mochila, X devolve ao mar e registra a descoberta. Inventário e pagamento não duplicam a captura.
- **Cinco espécies:** sardinha, cavala, robalo, atum e peixe-lanterna. Mar aberto e noite mudam os encontros; os peixes difíceis têm arrancadas que exigem aliviar tensão.
- **Cardumes:** três grupos de oito peixes, aproximando-se da isca e fugindo de motores rápidos. Pescar no cardume aumenta a probabilidade de sua espécie. Saltos ocasionais usam o efeito de brecha e respingo existente.
- **Criatura:** Vigia Abissal de 18 m, com movimento de asas/cauda; mergulha perto de motores rápidos e sobe com aproximação lenta. V registra na enciclopédia e concede 40 moedas uma vez. Sem combate ou captura de monstros nesta etapa.
- **Lojas:** molinete de 45 moedas, holofote de 60 e proteção de casco de 80, conectados às compras anteriores. L alterna lâmpadas, emissivos e holofote real do Aurora.
- **Tráfego:** pesqueiro de 12 m, rebocador de 21 m e navio de apoio de 30 m; rota circular em oito trechos. Seguem ondas, reduzem velocidade em tempestades, deixam esteiras e desviam do jogador. Os dois maiores adaptam o GLB de rebocador enviado.

## Ilha, vila e arte

A ilha principal foi ampliada para cerca de 700 × 1.100 m, com trilha norte até 150 m de altitude e novas descobertas. A vila possui 14 módulos acessíveis, interiores, portas abertas, rampas, ruas, moradores e serviços. O porto original completo tem 58 m e está conectado por cais a duas bancas que usam a economia do jogo.

As casas receberam telhas curvas, alvenaria e venezianas modeladas; o arco costeiro tem abertura com colisão real. Vegetação combina árvores com galhos modelados, folhas recortadas, coqueiros de frondes curvas e samambaias. Vento vem do mesmo estado climático do oceano. Rochas e materiais de solo incluem recursos CC0 da Poly Haven.

O personagem conserva o modelo enviado, preparado com 17 ossos e 11 animações locais. Caminhada/corrida incluem braços e tronco; a vara acompanha a mão durante lançamento e recolhimento. Boné e mochila seguem o rig. O dragão e a cabra enviados continuam presentes, com as limitações descritas abaixo.

O céu usa nuvens em camadas, movimento, iluminação solar/lunar, estrelas, chuva, relâmpagos e trovão. O oceano mantém ondas geométricas, profundidade, espuma, abrigo costeiro e flutuação comum à CPU/GPU. O corredor de gelo foi deslocado para permanecer fora da ilha fria ampliada.

## Qualidade gráfica

Esc oferece Baixa, Equilibrada, Alta e Ultra, resolução 3D de 50–150% e VSync. Alterações são imediatas e persistem em user://graphics.cfg. Alta é o padrão; os testes não alteram a preferência salva do usuário.

| Preset | Vegetação detalhada | Distância de sombras | Recursos |
|---|---:|---:|---|
| Baixa | 85 m | sem sombras direcionais | sem efeitos de tela, MSAA desligado |
| Equilibrada | 125 m | 90 m | MSAA 2×, TAA, SSAO/SSR em Forward+; sombra simplificada da copa |
| Alta | 220 m | 180 m | MSAA 2×, SSIL e sombras da folhagem real |
| Ultra | 400 m | 300 m | MSAA 4×, maior alcance de detalhes e SSR |

Compatibility mantém alternativa jogável sem os efeitos exclusivos de Forward+. As malhas usam instâncias compartilhadas e versões simplificadas à distância. O terreno está dividido em componentes de 80 m; ainda é carregado na inicialização, sem streaming de regiões.

### Medição na máquina disponível

GPU identificada pelo Godot: **AMD Radeon RX 580 2048SP**. Render alvo de 1440×900, resolução 3D de 100%, Forward+, VSync com teto próximo de 60 FPS; 600 quadros medidos por cenário após aquecimento. Os números abaixo são médias observadas, sem prometer desempenho em outra GPU.

| Cenário | Equilibrada | Alta |
|---|---:|---:|
| Cais | 59,8 FPS | 59,8 FPS |
| Vila | 59,8 FPS | 38,1 FPS |
| Barco | 59,8 FPS | 59,8 FPS |
| Tempestade | 59,8 FPS | 59,8 FPS |
| Floresta | 42,6 FPS | 18,4 FPS |
| Vila noturna | 59,8 FPS | 29,0 FPS |

Alta e Ultra foram mantidas disponíveis conforme solicitado. Na floresta, sombras completas e vegetação mais distante têm custo significativo; Equilibrada reduz esse custo. Ultra foi verificada funcionalmente, sem benchmark sustentado nesta entrega. Arquivos JSON incluem tempos p50/p95/p99, chamadas de desenho e memória estimada pelo engine.

## Validação

Os scripts usam os controladores reais e eventos de entrada quando necessário; as capturas vêm do framebuffer do Godot.

- Todas as cinco espécies foram encontradas e capturadas, com duração de disputa entre 10,7 e 21,7 s no cenário de teste; isca no cardume aumentou a taxa da espécie correta.
- Integração de movimento, pesca, armazenamento, venda e retorno ao cais: 45 verificações.
- Terreno, 14 interiores, trilhas, desembarque, natação e captura na mão: 26 verificações.
- Salto, pesca em movimento, acessórios, rig e vento: 20 verificações.
- Caminhada contínua no circuito norte e até a banca do porto antigo: 3 verificações.
- Volta ao redor da ilha com acelerador e direção reais: 8 trechos, 3.779 m, tráfego ativo e casco sem dano. Desembarque e caminhada na praia também verificados.
- Três navios passaram pelos oito trechos de navegação. O primeiro teste revelou bloqueio do jogador; foi corrigido com manobra lateral e desvio antecipado.
- CPU/GPU: 1.280 amostras em cinco estados, erro máximo de altura de 0,00026 m; abrigo costeiro comparado com codificação de 16 bits.
- Animações renderizadas: cavala, atum, peixe-lanterna e Vigia Abissal apresentaram deslocamento visual. Vento forte alterou 7.914 pixels amostrados contra 2.846 no vento fraco; nenhuma mudança na base do tronco inspecionada.

Resultados consolidados e benchmarks ficam em living-world-audit/. O registro de teste diferencia aprovação das verificações, erros do engine e observações visuais. Não se infere desempenho a partir de um teste headless.

## Limitações concretas

O progresso de jogo continua apenas na sessão; somente configurações gráficas são persistidas. O mundo liga bordas de um mapa plano. As outras ilhas não têm o mesmo conteúdo da inicial. Os edifícios fechados do GLB do porto não têm interiores; as salas acessíveis são as da vila modular. Navios NPC não são pilotáveis, e criaturas marinhas não têm combate. Cabra permanece estática e dragão tem respiração simples porque chegaram sem rig. As animações locais e parte da modelagem ainda comportam refinamento; o resultado não tem a fidelidade das imagens conceituais.

Veja [as imagens, prompts e malhas](ART_GENERATION.md) e [os controles](../README.md).
