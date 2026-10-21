# Direção visual — Fase 1

Uma enseada atlântica fictícia, em uma tarde dourada. Verde de pinheiro, azul-petróleo, madeira gasta e laranja queimado. Formas simples compostas em objetos reconhecíveis: casas com telhados, chaminés e janelas, barracas de pescado, árvores ramificadas, rochas irregulares, cais de tábuas e farol no horizonte.

Os modelos são originais, gerados localmente por GDScript. Nenhum modelo, textura, som ou imagem de outro jogo foi utilizado. `geometry.gd` concentra os auxiliares substituíveis por modelos glTF em etapas futuras. Materiais de cores sólidas e geometria facetada são uma escolha estilística provisória, não arte final de produção.

O oceano usa ondas e normais analíticas, espuma costeira e reflexo ambiental do céu. Funciona no renderizador Compatibility e não depende de texturas de tela ou profundidade. Não há reflexão planar, refração, simulação hidrodinâmica nem ondas que atingem a embarcação fisicamente nesta fase.

As ilhotas e o farol criam escala e orientação no horizonte. A ilha principal tem colisão e uma área plana para circulação; as ilhotas ainda não contêm atividades. Casas são fachadas nesta fase. Gaivotas e boias possuem animação procedural econômica. Horário e iluminação permanecem fixos: o ciclo de dia e noite pertence à Fase 3.
