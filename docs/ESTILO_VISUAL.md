# Estilo visual do Monster Fishing

Meta: **estilizado e detalhado**, não realismo total. A referência é a faixa de Sea of Thieves e dos
pacotes "stylized" de barcos e vilas costeiras: formas um pouco exageradas e cores vivas, mas cada objeto
mostra **como foi construído**. O que denuncia o modelo "básico" é a caixa lisa. O que dá vida é a junta,
a borda, a tábua e o desgaste.

## Referências usadas

- Barcos de pesca e traineiras estilizados (Sketchfab: "Stylized trawler", "Fishing trawler"): casco com
  costado em tábuas, borda falsa com balaústres, cabos, boias, pneus de defensa e guincho.
- Canoas low-poly/hand-painted: costado com tábuas sobrepostas, cavernas (costelas) aparentes por dentro,
  bancos com joelhos, roda de proa e cadaste subindo acima da borda.
- Cabines de navio (Sea of Thieves, captain's quarters): madeira escura com painéis, lampiões de latão,
  mapas, baús, prateleiras cheias, nada de parede vazia.
- Vilas costeiras estilizadas: casas com moldura de madeira, janelas com esquadria, beirais, vasos,
  redes e cordas penduradas.

## Regras para cada modelo novo

1. **Nada de caixa lisa sozinha.** Toda caixa ganha pelo menos uma destas: borda ou moldura, divisão
   em tábuas, pés, puxador, tampo maior que o corpo.
2. **Madeira em tábuas.** Cascos usam `painted_hull.gdshader` (tábuas, calafeto, veio, tinta gasta,
   sujeira na linha d'água). Tampos de mesa são feitos de 3 a 6 tábuas.
3. **Juntas visíveis.** Pernas torneadas (bloco, fuste, anel, pé), travessas, joelhos sob bancos,
   batentes nas portas, cantoneiras em caixotes.
4. **Metal só onde trabalha:** dobradiças, aros de barril, puxadores, sino, lampião. Latão é quente
   (`b58d3f`), ferro é escuro (`2e2b28`).
5. **Cores:** madeira clara para o que se toca (tampos, corrimãos), madeira escura para a estrutura,
   tinta saturada no casco e uma faixa de contraste sob a borda. Tecido em azul, ocre e vermelho-tijolo.
6. **Vida de uso:** corda enrolada, balde, iscas, caixote, rede pendurada. Todo cômodo tem pelo menos
   um ponto de luz quente (lampião ou lamparina) e uma parede com algo pendurado.
7. **Escala humana:** mesa a 0,76 m, assento a 0,45 m, cama 1 × 2 m, corrimão a 0,75–1 m.
8. **Desempenho:** peças pequenas recebem `_detail()` (somem de longe); materiais são compartilhados
   (`furniture.gd` guarda um material por cor).

## Onde está cada coisa

| O quê | Arquivo |
|---|---|
| Tábuas, calafeto e desgaste dos cascos | `assets/shaders/painted_hull.gdshader` |
| Borda, cavernas, piso de ripas e roda de proa de barcos abertos | `vessel_models.gd › _open_boat_joinery` |
| Balaústres, corrimão e verdugo de barcos com convés | `vessel_models.gd › _deck_rails` |
| Escotilha com grade, barril, cunho, rolo de cabo, lampião | `vessel_models.gd › _hatch / _barrel / _cleat / _coil / _lantern` |
| Móveis (mesa, cadeira, armário, cômoda, cama, lampião, tapete, prateleira, quadro, caixote) | `scripts/visuals/furniture.gd` |
| Lamparina do barco | `fishing_boat.gd › _build_lamparina` |

## Como conferir

Cada mudança visual ganha um cenário em `tests/feature_shots.gd` (ex.: `detalhe`, `casa`, `vitrine`,
`canoa`) e é comparada antes e depois na imagem renderizada. Se de perto ainda parece caixa, falta
detalhe.
