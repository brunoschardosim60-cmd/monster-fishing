# Testes da Fase 1

Execução confirmada em 21/10/2026 com Godot 4.7.2 estável para Windows, usando o motor real em modo headless. Os testes não exigem bibliotecas externas.

## Integração da cena principal

Na raiz do projeto, execute no PowerShell:

```powershell
& '.\tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --fixed-fps 60 --script res://tests/integration_test.gd
```

Resultado confirmado: **43 verificações aprovadas, zero falhas, código de saída 0**, sem erros ou avisos de encerramento na execução final.

O teste instancia `scenes/main/main.tscn`, inicia o jogo e verifica:

- Movimento do personagem por WASD e sustentação pelas colisões reais do cais.
- Embarque e desembarque usando eventos de teclado E, com a distância de interação normal.
- Aceleração, deslocamento, frenagem e direção do barco usando W/S/A/D.
- Bloqueio do lançamento quando o barco está rápido e permissão quando está parado.
- Lançamento, espera, mordida, fisgada, recolhimento com alívio da tensão e crédito de uma captura no inventário.
- Retorno seguro ao porto, preservando a captura, e novo embarque após o retorno.
- Percurso cais → ilha → mercado pelas entradas de movimento, sem injetar posições ou velocidades.
- Venda por E com recompensa exata, avanço do objetivo e prevenção de recompensa duplicada.
- Alternância F entre primeira e terceira pessoa.
- Pausa e retomada por Escape; nenhuma movimentação enquanto pausado.
- Recuperação após caminhar pela ponta do cais e cair na água, preservando as moedas.
- Preservação de uma captura não vendida pelo retorno seguro.

Na sequência de pesca, somente o processamento automático do sistema de pesca é temporariamente desativado. A mesma máquina de estados da produção avança em passos fixos de 0,02 s, com sementes conhecidas. Os sinais da cena principal e o inventário continuam reais. Isso evita esperar pela mordida em tempo real e impede tick duplo. O percurso de ida é pilotado; a volta usa a opção de retorno seguro do jogo, portanto este teste não comprova uma manobra manual completa de atracação.

`--fixed-fps 60` mantém um passo de simulação fixo e permite execução acelerada. O encerramento do teste para os sons e aguarda 100 ms para a thread de áudio liberar os recursos; sem essa espera, a execução acelerada pode terminar antes do próximo callback de áudio e emitir um aviso de recursos ainda ativos.

## Outros testes disponíveis

```powershell
& '.\tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/fishing_test.gd
& '.\tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --fixed-fps 60 --script res://tests/world_smoke.gd
```

O teste de pesca cobre também perda por mordida ignorada, excesso de tensão, linha frouxa, cancelamento, dados inválidos e captura das três espécies. O teste do mundo verifica pisos, normais das colisões, espaço de atracação e percurso até o mercado. Consulte os respectivos resultados de execução antes de afirmar aprovação após alterações nesses sistemas.

## Verificação gráfica complementar

Resultados finais: pesca **24**, mundo **15**, integração **43** e regressões de atracação **18** verificações aprovadas: **100 verificações técnicas**, sem erros nos logs finais. O teste gráfico `visual_smoke.gd` adiciona **24 verificações**, incluindo limites da HUD dentro da tela, leitura/salvamento de seis imagens da viewport, pesca/captura real e representação do peixe 3D.

O teste `docking_regression.gd` cobre aproximação pilotada e frenagem, desembarque no limite de distância, amarração automática, novo embarque, bloqueio de pesca em terra, quatro ilhas, câmera acima da água e teclas lógicas F/Esc. Execute com `--headless --fixed-fps 60 --script res://tests/docking_regression.gd`.

Inspeção gráfica realizada na Radeon RX 580 2048SP com OpenGL/Compatibility: tela inicial, cais, HUD, pesca, captura, barco e vista da vila. Foram corrigidos elementos da HUD fora da tela, placas espelhadas e uma órbita de câmera submersa. O lançamento pela tecla Espaço foi confirmado também via automação nativa do Windows. O ciclo completo usa os testes no motor; não foi uma sessão humana longa de controle por mouse/teclado.

O cenário estático é agrupado por material e célula espacial, preservando as colisões e os objetos animados. Na execução gráfica visível após essa otimização, foram observados **59–60 FPS** nas amostras de navegação e vila (janela física aproximadamente 1198×749; layout 1440×900). São amostras curtas, com outros aplicativos ativos, e não garantia de FPS nem benchmark sustentado. A janela de teste oculta teve resultados inferiores, portanto não deve ser usada para estimar o desempenho visível.

Para repetir a inspeção gráfica: `--rendering-method gl_compatibility --audio-driver Dummy --max-fps 60 --script res://tests/visual_smoke.gd -- --visible-visual`. Imagens e métricas são gravadas em `tests/output/visual/`. O teste com Dummy não verifica a qualidade auditiva; os sons foram sintetizados e carregados, mas o volume e o conforto auditivo devem ser avaliados pelo jogador.

Ainda recomendado: uma viagem longa com teclado/mouse físicos, ajuste subjetivo de sensibilidade, apreciação visual e auditiva e medição sustentada de desempenho. Isso é avaliação complementar de polimento, não substitui nem invalida os testes técnicos executados.

O progresso desta Fase 1 é mantido apenas durante a sessão. Os testes de recuperação e retorno seguro preservam o estado em memória; não afirmam salvamento em disco.
