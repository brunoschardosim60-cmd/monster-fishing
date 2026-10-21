# Pescaria — contrato e balanceamento da Fase 1

`scripts/fishing/fishing_system.gd` é uma máquina de estados sem leitura de teclado, mouse, câmera, colisão ou inventário. A cena principal decide se o jogador está em local adequado, chama a API e apresenta os sinais. `scripts/inventory/catch_inventory.gd` recebe a captura e controla a venda.

## Fluxo jogável

1. `start_cast("coast")` inicia um lançamento de 0,85 s.
2. A espera leva de 3 a 5,8 s. Tentar fisgar antes da mordida apenas mostra uma orientação.
3. A mordida deixa uma janela de 3,2 s para `strike()`.
4. `set_reeling(true)` recolhe a linha, aumentando progresso e tensão. `false` alivia rapidamente a tensão, com pequena perda de progresso.
5. Tensão máxima rompe a linha. Mais de 5,5 s sem recolher deixa o peixe escapar. Progresso completo emite uma única captura.
6. O resultado fica visível por 2,8 s antes de liberar novo lançamento. `cancel()` encerra uma tentativa ativa com segurança.

Segurar continuamente não captura peixes: é necessário alternar esforço e descanso. Para apresentação, sugerem-se tensão âmbar acima de 65% e vermelha acima de 85%. Não há custo de isca ou linha nesta fase; é sempre possível tentar novamente. A região desconhecida é rejeitada, sem consumir recurso nem iniciar um estado inválido.

## API

O script exporta `MonsterFishingSystem`, mas pode ser instanciado por `preload(...).new()`. `State` contém `IDLE`, `CASTING`, `WAITING`, `BITE`, `REELING`, `CAUGHT`, `ESCAPED` nessa ordem.

Campos de leitura para apresentação: `state`, `species_current`, `tension`, `progress`, `bite_time_remaining`, `state_time`, `last_message`, `last_catch`, `region_current`. `active()` retorna verdadeiro apenas do lançamento até a luta. `rng.seed` permite reprodução determinística de seleções, esperas e pesos. Não é necessário configurar um autoload.

Sinais:

- `status_changed(message: String)` — texto em português.
- `state_changed(state: int)` — mudança de etapa; `state_time` reinicia em zero.
- `caught(catch_data: Dictionary)` — cópia independente dos dados de captura.

`advance(delta)` contém o avanço temporal e é chamado por `_process`. Em testes, desative `_process` antes de chamar `advance` diretamente para evitar contagem dupla. O processamento normal respeita a pausa da árvore.

## Espécies e dados

| Resource | Frequência relativa na costa | Peso | Preço/kg | Dificuldade |
|---|---:|---:|---:|---:|
| `sardine.tres` | 60% | 0,18–0,65 kg | 38 | 0,15 |
| `mackerel.tres` | 30% | 0,70–2,10 kg | 26 | 0,40 |
| `seabass.tres` | 10% | 1,20–4,50 kg | 32 | 0,68 |

Os nomes e descrições são originais. Novas espécies utilizam `MonsterFishSpecies` em outro `.tres`, registrado em `SPECIES`; regiões aceitas ficam no próprio Resource. Peso, valor, dificuldade e frequência não exigem nova lógica por espécie. Horário, clima, equipamento, tamanho em centímetros e ecologia avançada ficam para fases posteriores.

Cada captura contém `id`/`species_id`, `name`/`species_name`, `weight` em kg, `value` inteiro, `rarity`, `region`, `caught_at` em UTC, `timestamp` Unix e `color` HTML. Os pares de nomes são aliases explícitos para facilitar a integração inicial. Não há referência a Node ou Resource no registro, permitindo serialização futura.

## Inventário e venda

`MonsterCatchInventory` é `RefCounted`, com `catches: Array[Dictionary]`, `money: int`, sinal `changed`, `add_catch(Dictionary) -> bool`, `count() -> int`, `total_value() -> int` e `sell_all() -> int`. Recebe cópias dos registros e rejeita capturas incompletas ou com peso/valor inválido. `sell_all` adiciona o valor à carteira e esvazia a cesta, impedindo venda repetida das mesmas capturas. Dinheiro começa em zero.

Este módulo não salva em disco; salvamento de sessão, se oferecido pela integração, deve ser implementado separadamente. Capacidade da cesta, armazenamento no barco, equipamentos, economia completa e enciclopédia pertencem à Fase 2 ou posteriores.

## Testes executáveis

Na raiz do projeto:

```powershell
& '.\tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/fishing_test.gd
```

O teste percorre lançamento, espera, mordida, luta, captura e venda; verifica falhas por demora, tensão excessiva e linha frouxa; cancelamento; região não cadastrada; proteção contra venda dupla; validade dos Resources; e captura das três espécies por uma estratégia de recolher/aliviar. Ele não substitui a verificação gráfica da boia, linha, interface e integração dos controles.
