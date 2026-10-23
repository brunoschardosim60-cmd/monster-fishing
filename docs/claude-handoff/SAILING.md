# Navegação a vela — documento recuperado do Claude

Fonte: https://claude.ai/chat/02a08ba3-8a95-403d-9d89-6baf46402f55

Recuperado em 22/10/2026 da operação “Update README, Testar.cmd, add SAILING doc”. Esta documentação descreve a implementação na cópia temporária do Claude; ela NÃO está aplicada ao projeto local ou ao GitHub. Os testes abaixo são resultados relatados por ele, não revalidados aqui.

O pesqueiro deixou de ser uma lancha com acelerador. A velocidade vem do vento, que já existia no jogo (`Waves.direction` e `Waves.wind`, controlados pelo clima) e agora também move o barco.

## Controles (no leme)

| Tecla | Efeito |
|---|---|
| W / S | Abrem / recolhem a vela (0–100%). Com a vela já recolhida, S freia. |
| A / D | Leme. Funciona mesmo parado, para sair de um trecho contra o vento. |
| Shift + W / S | Motor auxiliar: ~7 nós adiante, 4,7 ré, sem depender do vento. A vela não é mexida. |
| R | Vai para o convés. A vela e o rumo ficam como estão: o barco segue navegando. |
| E | Desembarcar. A vela é recolhida automaticamente. |

## Cálculo da velocidade

`FishingBoat._update_sailing()` calcula a cada passo de física:

```
ângulo   = ângulo entre a proa e a direção DE ONDE o vento vem (0 = de proa, π = de popa)
eficácia = sail_efficiency(ângulo)
empuxo   = eficácia × rajada × abrigo × vela × estado do casco
alvo     = max_speed × 0,82 × empuxo × (1 − arrasto de tempestade)
```

`speed` caminha até `alvo` a 1,25 m/s² (acelera) ou 1,0 m/s² (perde velocidade).

| Vento vem de | Ângulo | Eficácia |
|---|---:|---:|
| Proa | 0°–20° | ~0 |
| Bolina | ~40° | ~0,2 |
| Través | ~90° | 1,0 |
| Popa | 180° | 0,7 |

- Rajada = `0,3 + vento × 1,5`, limitada a 0,3–1,15. Mar calmo (0,09): cerca de 7,6 nós de través; brisa (0,32): cerca de 13,8 nós.
- Abrigo: perto do porto o vento é bloqueado (`Waves.exposure`), e o empuxo cai até 40%.
- A melhoria da oficina (`engine`, agora “Velame reforçado”) continua multiplicando `max_speed` em +15% por nível.

## Visual

- Mastro, retranca e vela montados por `_build_sail()` sobre `fishing_boat.glb`, na proa livre.
- Shader `assets/shaders/sail.gdshader`: infla para sotavento, bate contra o vento ou com pouco vento, afina no topo.
- Retranca acompanha o vento até 75°. Com vento vindo por trás cruza o eixo (jibe).
- Casco adorna para sotavento até aproximadamente 10°.
- Catavento vermelho aponta para onde o vento sopra.
- Interface: nós, porcentagem de vela e vento de proa/bolina/través/alheta/popa.

## Limitações e validação relatadas

Uma vela com abertura automática da retranca. Ajuste manual e outras velas ficam para depois. Posições escolhidas pelas caixas das peças do modelo, sem inspeção visual. Embarcações de tráfego continuam em trajetos fixos, sem vento.

`tests/sailing_test.gd`: 28 verificações relatadas como aprovadas, cobrindo eficácia, aceleração, adernamento nos dois bordos, motor, freio, leme parado e recolhimento da vela. Também relatou ajustes em `docking_regression`, `integration_test` e `exploration_journey`.

Na resposta final, Claude informou que a renderização Vulkan foi encerrada com código 137 antes de produzir imagens. O shader e a posição do mastro não foram verificados visualmente. Também informou que tempestades ainda aceleram o barco e falta reduzir a vela nessas condições.

## Situação da transferência

GitHub permaneceu em `fbc21ddd6a05103eb6e6ffb9d261229e29b849e4`. O pedido “gere o patch” foi interrompido pelo limite gratuito do Claude, com retomada indicada pela interface às 23:30. Não havia patch entregue na resposta. Este arquivo recupera a documentação; não substitui os arquivos de implementação.
