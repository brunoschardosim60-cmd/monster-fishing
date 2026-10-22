# PROJETO: MONSTER FISHING
## Documento mestre de desenvolvimento do jogo

Assuma o papel de desenvolvedor sênior de jogos, especialista em Godot 4, GDScript, jogos 3D de mundo aberto, gameplay, inteligência artificial, sistemas de sobrevivência, otimização e design de jogos.

Você tem acesso ao meu computador e deve trabalhar diretamente no ambiente de desenvolvimento, quando as ferramentas disponíveis permitirem.

Sua missão é TRANSFORMAR A IDEIA ABAIXO EM UM JOGO REAL, JOGÁVEL, EXPANSÍVEL E VISUALMENTE BONITO.

Não quero apenas um planejamento, um dashboard, uma demonstração estática ou uma cena que não funciona. Quero um jogo de verdade, com personagem controlável, mundo 3D, movimentação, navegação, pesca, progressão, interface e sistemas funcionais.

Não tente construir todos os sistemas complexos simultaneamente. Primeiro estabeleça uma base funcional, teste-a e depois implemente as funcionalidades em etapas, sem perder as mecânicas já concluídas.

# 1. VISÃO DO JOGO

Nome provisório: Monster Fishing.

Gênero:
- Simulação de pescaria.
- Exploração em mundo aberto.
- Sobrevivência leve.
- Progressão e gerenciamento de recursos.
- Aventura com criaturas misteriosas.
- Elementos ocasionais de suspense e terror.

Plataforma inicial: PC Windows.

Motor: Godot 4, utilizando a versão estável compatível mais recente disponível.

Linguagem: GDScript, preferencialmente tipado.

Estilo visual: 3D estilizado semi-realista, com iluminação cinematográfica, ambientes naturais bonitos, água visualmente convincente, criaturas detalhadas e uma atmosfera que pode variar de tranquila para misteriosa.

Câmera principal: terceira pessoa, com possibilidade de alternar para primeira pessoa.

O jogo deve combinar três sensações:
1. Relaxamento e liberdade.
2. Progressão, coleção e descoberta.
3. Mistério, perigo e encontros imprevisíveis.

A experiência principal deve ser agradável mesmo quando nenhum evento extraordinário acontece.

# 2. PRINCÍPIOS FUNDAMENTAIS

O oceano precisa parecer um mundo vivo, não apenas um cenário decorativo.

O jogador deve ter liberdade para escolher como passar seu tempo. Pode pescar perto de casa, vender os peixes, cozinhar, melhorar sua cabana, explorar ilhas ou arriscar uma expedição distante.

Não obrigue o jogador a seguir uma sequência rígida de missões para aproveitar o jogo.

Criaturas raras não devem aparecer sempre nos mesmos lugares ou em momentos previsíveis. Use condições ambientais, regiões, horários, probabilidades controladas e sistemas de acontecimentos.

Eventos raros devem ser especiais, mas não devem prejudicar injustamente o jogador nem destruir seu progresso sem possibilidade de recuperação.

Não transforme tudo em terror. A maior parte da experiência deve continuar sendo uma aventura de pescaria e exploração.

O mundo deve permitir histórias emergentes: uma tempestade inesperada, um peixe raro, um barco avariado longe da costa ou uma criatura que volta a aparecer dias depois.

# 3. PREPARAÇÃO DO AMBIENTE

Antes de começar:

1. Inspecione o computador e verifique as ferramentas já instaladas.
2. Verifique se existe algum projeto Monster Fishing ou projeto relacionado que deva ser preservado.
3. Verifique a versão do Godot, o espaço disponível, as ferramentas de desenvolvimento e os recursos do computador.
4. Se necessário, instale ou baixe o Godot 4 estável para Windows e os componentes estritamente necessários, utilizando fontes oficiais.
5. Se alguma ferramenta exigir permissões administrativas, uma compra, autenticação ou confirmação de segurança, solicite minha autorização antes de prosseguir.
6. Não apague arquivos pessoais, projetos existentes nem dados sem minha autorização.
7. Crie uma pasta própria para o projeto, chamada MonsterFishing, preferencialmente em Documentos ou em outra pasta adequada.
8. Inicialize um repositório Git se possível, com commits por etapas concluídas.
9. Crie uma estrutura de diretórios organizada e documente como abrir e executar o projeto.

Se o Codex não tiver acesso a alguma ferramenta ou permissão, informe exatamente o que está faltando e ofereça uma alternativa.

Não afirme que algo foi instalado, executado ou testado se isso não ocorreu.

# 4. IDENTIDADE VISUAL

Desenvolva uma direção artística consistente.

Referências conceituais:
- A sensação de descoberta e estranheza de DREDGE.
- A exploração submarina e o sentimento de escala de Subnautica.
- A tranquilidade de jogos de vida e simulação.
- Um mundo 3D estilizado com acabamento profissional.

Essas referências servem somente como inspiração. Não copie personagens, mapas, modelos, interface, músicas ou outros elementos protegidos desses jogos.

Características visuais desejadas:
- Água com reflexos e ondas.
- Iluminação natural e ciclo de dia e noite.
- Pôr do sol, neblina, chuva e tempestades.
- Ilhas com vegetação, pedras, praias e estruturas exploráveis.
- Barcos com modelos visualmente interessantes.
- Peixes de diferentes tamanhos, cores e comportamentos.
- Criaturas gigantes que transmitam escala e imponência.
- Efeitos de chuva, espuma, respingos e partículas quando viáveis.
- Interface limpa, legível e integrada ao universo do jogo.

Não use uma interface genérica de administração como tela principal.

Não use cubos, cápsulas e objetos sem acabamento como aparência final. Primitivos são permitidos durante os testes iniciais, mas devem ser substituídos ou aprimorados nas etapas visuais.

Priorize qualidade consistente e desempenho, em vez de efeitos pesados que não funcionem no meu computador.

# 5. MUNDO ABERTO

Crie um oceano navegável com regiões distintas.

O jogador deve poder controlar livremente seu personagem, caminhar, interagir com objetos, entrar e sair de barcos, navegar, pescar e explorar ilhas.

O mundo pode utilizar regiões e limites naturais, mas não deve parecer uma sequência de fases separadas por menus.

A progressão deve permitir descobrir áreas novas naturalmente, por meio de exploração, equipamentos, pistas e preparação.

Regiões planejadas:

A. Costa inicial:
- Vila de pescadores.
- Pequeno porto.
- Cabana do jogador.
- Loja de equipamentos.
- Vendedores e moradores.
- Peixes comuns.
- Águas relativamente tranquilas.

B. Mar aberto:
- Águas mais profundas.
- Cardumes maiores.
- Tubarões e atuns.
- Naufrágios.
- Tempestades mais perigosas.
- Ilhas distantes.

C. Região tropical:
- Águas claras.
- Peixes coloridos.
- Recifes.
- Ilhas escondidas.
- Espécies exóticas.

D. Águas congeladas:
- Icebergs.
- Neve e frio.
- Pinguins.
- Focas, orcas e baleias.
- Equipamentos de proteção térmica.

E. Profundezas:
- Peixes abissais.
- Criaturas bioluminescentes.
- Águas escuras.
- Sinais de sonar desconhecidos.
- Regiões com fenômenos inexplicáveis.

F. Oceano proibido:
- Águas extremamente perigosas.
- Criaturas lendárias.
- Eventos raros.
- Kraken e outros encontros de grande escala.
- Descobertas que expliquem parte dos mistérios do mundo.

Não é necessário construir todas as regiões agora. Prepare uma arquitetura que permita adicioná-las posteriormente sem reescrever todo o projeto.

# 6. PERSONAGEM E CÂMERAS

Implemente um personagem controlável em terceira pessoa.

Controles iniciais sugeridos:
- WASD: movimentação.
- Mouse: controlar a câmera.
- Shift: correr.
- E: interagir.
- F: alternar câmera quando permitido.
- ESC: pausar.

Adapte os controles se necessário e permita remapeamento futuramente.

O personagem deve conseguir:
- Caminhar e correr.
- Olhar ao redor.
- Interagir com objetos.
- Usar uma vara de pesca.
- Recolher peixes.
- Entrar e sair de barcos.
- Caminhar por áreas seguras das ilhas.
- Entrar na cabana e acessar seus objetos.

Crie animações coerentes para caminhada, corrida, pesca, interação e entrada no barco. Caso não existam animações finais, utilize soluções provisórias claramente identificadas e substituíveis.

A câmera principal deve acompanhar o personagem e permitir observar o ambiente sem ficar presa em objetos.

Implemente uma câmera em primeira pessoa como alternativa, especialmente útil durante a pesca e a observação do oceano.

# 7. SISTEMA DE BARCOS

O barco é uma das mecânicas centrais do jogo.

Implemente:
- Entrada e saída do barco.
- Controle de aceleração.
- Direção.
- Desaceleração e frenagem.
- Limites de velocidade coerentes.
- Câmera apropriada durante a navegação.
- Interação com o cais.
- Sistema de combustível quando aplicável.
- Danos e reparos em etapas posteriores.
- Melhorias e personalização.

Tipos planejados:
1. Barquinho básico.
2. Barco de pesca intermediário.
3. Lancha de exploração.
4. Embarcação resistente para tempestades.
5. Barco de águas frias.
6. Embarcações especializadas para regiões avançadas.

Cada embarcação deve apresentar vantagens e desvantagens, como velocidade, capacidade de armazenamento, consumo, resistência e estabilidade.

Não disponibilize todas as embarcações no começo. O jogador deve conquistá-las com dinheiro, exploração e progressão.

# 8. SISTEMA DE PESCARIA

A pesca deve ser uma mecânica real, interativa e satisfatória.

Fluxo básico:
1. Equipar uma vara.
2. Escolher uma isca.
3. Lançar a linha.
4. Aguardar a aproximação de um peixe.
5. Detectar uma mordida.
6. Reagir no momento adequado.
7. Recolher a linha por meio de uma mecânica de esforço e tensão.
8. Capturar ou perder o peixe.
9. Registrar a descoberta e adicionar a captura ao inventário.

Não transforme toda captura em uma animação automática sem participação do jogador.

Implemente diferentes dificuldades de captura, com base no tamanho, na espécie, na raridade, no equipamento e nas condições ambientais.

Inclua:
- Varas de diferentes categorias.
- Anzóis.
- Iscas naturais e artificiais.
- Linhas com resistências distintas.
- Equipamentos de pesca avançados.
- Peixes pequenos, médios, grandes e gigantes.
- Possibilidade de perder peixes.
- Registros de peso, tamanho, local e data da captura.
- Capturas raras e recordes pessoais.

A pescaria deve ser acessível no começo e progressivamente mais desafiadora.

# 9. ESPÉCIES E CRIATURAS

Crie uma arquitetura de dados para adicionar novas espécies sem precisar programar cada uma individualmente.

Cada espécie pode ter:
- Identificador único.
- Nome.
- Modelo 3D.
- Categoria.
- Tamanho e peso.
- Raridade.
- Regiões de ocorrência.
- Profundidade preferida.
- Horários de atividade.
- Preferências de isca.
- Valor de venda.
- Comportamento.
- Periculosidade.
- Informações para a enciclopédia.

Categorias:
- Comuns.
- Incomuns.
- Raras.
- Épicas.
- Lendárias.
- Misteriosas.

Espécies e criaturas planejadas:
- Sardinhas.
- Tilápias.
- Atuns.
- Salmões.
- Polvos.
- Lulas.
- Caranguejos.
- Tubarões.
- Golfinhos.
- Baleias.
- Orcas.
- Pinguins.
- Peixes abissais.
- Criaturas bioluminescentes.
- Serpentes marinhas.
- Kraken.

A presença de animais deve fazer sentido no contexto das regiões, salvo eventos extraordinários intencionais.

Pinguins devem aparecer em regiões adequadas, não aleatoriamente em qualquer oceano.

Baleias, golfinhos e outros animais devem apresentar comportamentos próprios e não funcionar apenas como objetos que o jogador captura.

Animais protegidos ou criaturas especiais podem ser apenas observáveis, fotografáveis ou estudáveis, em vez de capturáveis.

O Kraken deve ser uma criatura lendária de escala gigantesca, com tentáculos, efeitos ambientais e comportamentos próprios. Seu encontro não deve ser uma aparição rotineira.

Não tente produzir centenas de modelos finais de imediato. Construa primeiro um pequeno conjunto de espécies funcionais e uma estrutura que permita expandi-lo.

# 10. SONAR E ENCONTROS MISTERIOSOS

O sonar deve se tornar uma ferramenta importante na exploração.

Inicialmente, ele pode indicar:
- Cardumes.
- Profundidade.
- Obstáculos.
- Naufrágios.
- Objetos submersos.

Em regiões avançadas, podem surgir sinais estranhos.

Exemplo de evento raro:

O jogador está pescando durante a noite, longe da costa. O sonar detecta uma massa abaixo do barco.

Primeira mensagem:
"O sonar detectou um movimento abaixo de você."

A leitura de profundidade começa a mudar de forma inexplicável.

Depois, a mensagem:
"TAMANHO NÃO IDENTIFICADO."

O sinal desaparece.

O sistema de som reduz a música ambiente, deixando o som das ondas e do equipamento.

O jogador não recebe confirmação imediata do que aconteceu.

Esse é um exemplo de evento narrativo, não uma sequência obrigatória.

Crie um sistema de eventos configuráveis com:
- Probabilidades ajustáveis.
- Condições de região.
- Horário.
- Clima.
- Equipamentos necessários.
- Histórico do jogador.
- Tempo mínimo entre ocorrências.
- Consequências possíveis.

Eventos extraordinários devem ser raros, mas não tão improváveis que a maior parte dos jogadores nunca veja conteúdo importante.

Não use apenas sorte aleatória. Combine probabilidades com condições e mecanismos que permitam que os eventos sejam encontrados eventualmente.

# 11. CRIATURAS QUE LEMBRAM DO JOGADOR

Uma das mecânicas mais importantes é a persistência dos encontros.

Se o jogador encontrar uma criatura especial e escapar, o mundo pode registrar o encontro.

Dias depois, o jogador pode retornar à região e encontrar pistas de que a criatura continua por perto.

Exemplo:
"Você já encontrou esta criatura antes."

Não implemente memória artificial complexa desnecessária. Crie inicialmente um sistema simples e confiável de histórico de encontros, identificação de criaturas e eventos relacionados.

No futuro, determinadas criaturas poderão:
- Reconhecer regiões anteriormente visitadas.
- Reagir à presença do barco.
- Aparecer após determinados acontecimentos.
- Fugir de equipamentos poderosos.
- Seguir o jogador por algum tempo.
- Retornar em encontros posteriores.

As criaturas precisam ter regras de comportamento consistentes, mesmo quando seus encontros são imprevisíveis.

# 12. SOBREVIVÊNCIA

A sobrevivência deve complementar a pescaria, sem transformar o jogo em uma tarefa excessivamente punitiva.

Sistemas planejados:
- Fome.
- Energia.
- Temperatura corporal.
- Cansaço.
- Condições climáticas.
- Combustível.
- Integridade do barco.
- Armazenamento de alimentos.
- Preparação para viagens.

O jogador deve conseguir cozinhar, fritar e consumir peixes.

Implemente uma cozinha na cabana e, posteriormente, opções de preparo em embarcações adequadas.

Comer deve recuperar recursos do personagem.

Comidas diferentes podem oferecer benefícios distintos, como recuperar mais energia ou proteger temporariamente contra o frio.

O frio deve ser mais relevante em regiões congeladas e durante condições climáticas severas.

A fome não deve aumentar de forma exageradamente rápida. O jogador precisa ter tempo para explorar e pescar sem precisar interromper tudo a cada poucos minutos.

Permita dormir, descansar e avançar o tempo.

# 13. CICLO DE DIA E NOITE

Implemente um relógio de jogo e uma transição visual entre:
- Amanhecer.
- Manhã.
- Tarde.
- Pôr do sol.
- Noite.
- Madrugada.

A iluminação deve acompanhar o horário.

Os peixes podem apresentar diferentes padrões de atividade durante o dia e a noite.

Algumas criaturas e eventos só devem ocorrer em condições específicas.

A noite não deve ser sempre perigosa. Em determinadas regiões, ela pode ser ideal para pescar espécies raras.

A cabana deve ser um local acolhedor e seguro para descansar.

# 14. CLIMA DINÂMICO

Implemente condições meteorológicas configuráveis:
- Céu limpo.
- Nublado.
- Chuva leve.
- Chuva forte.
- Vento.
- Neblina.
- Tempestades.
- Condições frias e neve em regiões adequadas.

O clima deve influenciar a experiência de maneira funcional.

Exemplos:
- Ventos afetam a navegação.
- Ondas aumentam durante tempestades.
- A visibilidade diminui com neblina.
- A chuva modifica o som ambiente e a aparência da água.
- Algumas espécies aparecem com maior frequência em condições específicas.
- O jogador pode buscar abrigo quando as condições ficam perigosas.

Não implemente todas as simulações físicas avançadas logo no início. Comece com um sistema de clima consistente e visualmente convincente, evoluindo conforme a capacidade do projeto.

# 15. ECONOMIA E PROGRESSÃO

O jogador começa com poucos recursos.

Seu objetivo inicial é pescar, vender capturas e investir em equipamentos melhores.

Sistemas:
- Dinheiro.
- Inventário.
- Armazenamento no barco.
- Venda de peixes.
- Compra de equipamentos.
- Melhorias de embarcações.
- Desbloqueio de regiões.
- Experiência e níveis.
- Descobertas.
- Conquistas.
- Missões opcionais.

O dinheiro não deve ser apenas um número. Ele precisa abrir novas possibilidades de jogo.

O nível pode ser aumentado por:
- Capturas.
- Descobertas de novas espécies.
- Exploração.
- Registro de criaturas.
- Eventos.
- Desafios.
- Missões opcionais.

A progressão deve desbloquear equipamentos, regiões, ferramentas e novas possibilidades.

A dificuldade pode aumentar em regiões avançadas, mas não deve aumentar simplesmente retirando todos os peixes do mundo.

Em vez disso, use ecossistemas distintos, espécies mais difíceis, condições ambientais e maior exigência de equipamento.

# 16. ENCICLOPÉDIA DE DESCOBERTAS

Crie uma enciclopédia que registre espécies e criaturas encontradas.

Para cada descoberta, mostre:
- Nome.
- Ilustração ou modelo.
- Descrição.
- Raridade.
- Habitat.
- Profundidade.
- Horário de atividade.
- Maior peso capturado.
- Número de encontros.
- Informações ainda desconhecidas.

Algumas informações devem permanecer ocultas até serem descobertas.

A enciclopédia deve dar vontade de explorar o mundo inteiro.

Inclua recordes pessoais, coleções e objetivos opcionais.

# 17. CABANA E VIDA NA VILA

O jogador deve ter uma base própria.

Funcionalidades planejadas:
- Entrar e sair da cabana.
- Dormir.
- Cozinhar.
- Armazenar itens.
- Consultar o mapa.
- Organizar equipamentos.
- Exibir troféus e descobertas.
- Melhorar instalações em etapas posteriores.

A vila deve funcionar como um lugar para descansar, vender peixes, comprar itens e conversar com moradores.

Posteriormente, adicione personagens com diálogos, histórias, pedidos e missões opcionais.

A cabana e a vila devem transmitir conforto e contraste com os perigos do oceano.

# 18. EXPLORAÇÃO E DESCOBERTAS

Adicione gradualmente:
- Ilhas escondidas.
- Cavernas acessíveis.
- Praias remotas.
- Naufrágios.
- Baús.
- Objetos perdidos.
- Documentos e pistas.
- Pontos de interesse.
- Regiões que precisam ser registradas no mapa.

A descoberta de novos lugares deve ser recompensadora.

Não coloque marcadores gigantes em absolutamente tudo. O jogador deve poder observar o horizonte, seguir pistas e descobrir coisas naturalmente.

# 19. ÁUDIO E ATMOSFERA

Planeje:
- Sons de ondas.
- Vento.
- Chuva.
- Motor do barco.
- Passos.
- Equipamentos.
- Lançamento da linha.
- Mordidas e capturas.
- Sons de animais.
- Sonar.
- Música tranquila na vila.
- Atmosfera sonora de exploração.
- Silêncio e mudanças de áudio em eventos extraordinários.

O áudio é fundamental para transmitir a diferença entre tranquilidade e perigo.

Utilize sons originais, gerados ou devidamente licenciados. Não copie trilhas sonoras de outros jogos.

# 20. INTERFACE

A interface deve ser bonita, minimalista e legível.

Elementos planejados:
- Indicador de interação.
- Inventário.
- Dinheiro.
- Nível e experiência.
- Barra de fome e energia quando relevantes.
- Temperatura em regiões frias.
- Combustível e integridade do barco.
- Estado da pescaria.
- Mapa.
- Sonar.
- Enciclopédia.
- Loja.
- Cozinha.
- Menu de pausa.
- Opções gráficas e de áudio.

Não exiba todos os indicadores o tempo inteiro.

A interface deve apresentar apenas as informações necessárias para a situação atual.

# 21. SALVAMENTO

Implemente salvamento local confiável.

O jogo deve conseguir preservar:
- Posição segura do jogador.
- Região.
- Dinheiro.
- Nível.
- Inventário.
- Equipamentos.
- Barco e melhorias.
- Descobertas.
- Histórico de encontros.
- Progresso da enciclopédia.
- Estado de missões.
- Configurações.

O salvamento deve incluir tratamento de erros e uma estrutura versionada para facilitar futuras atualizações.

Não salve estados que possam colocar o jogador preso no oceano ou dentro de objetos. Defina um ponto seguro de recuperação quando necessário.

# 22. ARQUITETURA DO PROJETO

Organize o código em sistemas separados, evitando um único script gigantesco.

Estrutura sugerida:

res://
  scenes/
    main/
    world/
    player/
    boats/
    fishing/
    creatures/
    village/
    cabin/
    ui/
  scripts/
    player/
    boats/
    fishing/
    inventory/
    economy/
    progression/
    weather/
    time/
    events/
    creatures/
    save/
  data/
    fish/
    creatures/
    equipment/
    boats/
    regions/
    events/
  assets/
    models/
    textures/
    materials/
    audio/
    animations/
  tests/
  docs/

Adapte essa estrutura às necessidades reais do projeto.

Use Resources ou estruturas de dados apropriadas para conteúdo configurável.

Separe lógica de jogo, dados, apresentação visual e interface.

Utilize sinais, estados e componentes de maneira organizada.

Evite dependências circulares e código duplicado.

Crie documentação básica explicando os principais sistemas.

# 23. ASSETS E RECURSOS EXTERNOS

Verifique quais modelos, texturas, sons e animações são necessários.

Priorize:
1. Recursos já disponíveis no projeto.
2. Recursos originais simples.
3. Recursos gratuitos com licença compatível.
4. Ferramentas oficiais e fontes confiáveis.

Se precisar baixar recursos, verifique licença, formato, compatibilidade e origem.

Não baixe executáveis aleatórios nem desative proteções de segurança.

Não use recursos protegidos de outros jogos sem autorização.

Se um recurso final não estiver disponível, crie uma alternativa provisória bem organizada e continue o desenvolvimento.

Não deixe o projeto dependente de serviços online, APIs pagas ou recursos externos que possam desaparecer, a menos que isso seja realmente necessário e autorizado.

# 24. OTIMIZAÇÃO

O projeto deve ser executável em um computador Windows comum, dentro das limitações do hardware disponível.

Inspecione o computador antes de decidir o nível de qualidade gráfica.

Evite:
- Quantidade excessiva de objetos ativos.
- Física desnecessariamente complexa.
- Simulações de água extremamente pesadas.
- Modelos gigantes sem nível de detalhe apropriado.
- Carregamento de todo o mundo ao mesmo tempo.
- Scripts executados sem necessidade a cada quadro.

Prepare uma arquitetura que permita carregar e descarregar áreas, controlar a distância de renderização e limitar os objetos ativos.

Priorize desempenho estável e controles responsivos.

# 25. PLANO OBRIGATÓRIO DE DESENVOLVIMENTO

Não tente implementar o jogo inteiro em uma única etapa.

FASE 1 — PROTÓTIPO JOGÁVEL
- Criar o projeto Godot.
- Configurar a cena principal.
- Criar uma pequena ilha.
- Criar oceano visualmente convincente dentro dos recursos disponíveis.
- Criar personagem em terceira pessoa.
- Implementar câmera e controles.
- Criar um barco.
- Permitir entrar, sair e pilotar o barco.
- Implementar uma primeira mecânica de pesca.
- Adicionar pelo menos uma espécie capturável.
- Permitir vender a captura ou contabilizar seu valor.
- Adicionar uma interface simples e funcional.

FASE 2 — CICLO PRINCIPAL
- Inventário.
- Dinheiro.
- Loja.
- Equipamentos.
- Experiência.
- Níveis.
- Mais espécies.
- Sistema de captura com dificuldades diferentes.
- Primeira enciclopédia.

FASE 3 — VIDA E SOBREVIVÊNCIA
- Cabana.
- Cozinha.
- Fome.
- Energia.
- Ciclo de dia e noite.
- Descanso.
- Clima.
- Armazenamento.

FASE 4 — EXPLORAÇÃO
- Novas ilhas.
- Novos barcos.
- Regiões distintas.
- Mapa.
- Sonar.
- Naufrágios.
- Novos equipamentos.

FASE 5 — CRIATURAS E EVENTOS
- Tubarões.
- Baleias.
- Orcas.
- Pinguins em habitats adequados.
- Criaturas abissais.
- Eventos aleatórios.
- Encontros persistentes.
- Eventos de sonar.
- Primeiros encontros lendários.

FASE 6 — POLIMENTO
- Animações.
- Efeitos visuais.
- Áudio.
- Iluminação.
- Interface.
- Balanceamento.
- Otimização.
- Correção de erros.
- Salvamento.
- Testes finais.

Cada fase deve preservar as funcionalidades anteriores.

# 26. REGRAS DE EXECUÇÃO E TESTES

Trabalhe de maneira autônoma nas tarefas que puder executar com segurança.

Não se limite a descrever o que precisa ser feito. Crie e edite os arquivos, execute ferramentas e teste o projeto sempre que possível.

Depois de cada etapa relevante:
1. Verifique erros de sintaxe.
2. Execute o projeto.
3. Consulte os logs.
4. Corrija os erros encontrados.
5. Teste os controles e as mecânicas afetadas.
6. Confirme que as funcionalidades anteriores continuam funcionando.
7. Atualize a documentação.

Se houver falhas, não as esconda. Corrija-as ou informe claramente o que ainda está pendente.

Não declare uma funcionalidade como concluída só porque seus arquivos foram criados.

Na primeira fase, a definição de concluído é: consigo abrir o jogo, controlar o personagem, entrar no barco, navegar, lançar uma linha, capturar pelo menos um peixe e obter uma recompensa.

Se a execução gráfica automatizada não for possível, faça os testes técnicos disponíveis e me informe exatamente o que preciso verificar manualmente.

# 27. PRIMEIRA AÇÃO

Comece AGORA pela inspeção do ambiente e pela FASE 1.

Antes de instalar qualquer coisa, verifique o que já existe no computador.

Depois:
- Prepare o projeto.
- Crie a cena inicial.
- Implemente as mecânicas mínimas.
- Execute e teste.
- Corrija os problemas encontrados.
- Apresente um resumo do que foi realmente concluído.

Não pare depois de escrever um plano.

Se encontrar limitações de hardware, ferramentas ou permissões, adapte a solução e me informe.

Não tente implementar todas as seis fases de uma só vez. Entregue primeiro uma FASE 1 funcional e preparada para crescer.

O objetivo final é transformar Monster Fishing em um jogo de mundo aberto de pescaria, exploração e sobrevivência, com um oceano vivo, uma rotina acolhedora e criaturas tão misteriosas que o jogador nunca tenha certeza do que pode encontrar na próxima viagem.