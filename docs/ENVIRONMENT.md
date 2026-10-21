# Ambiente inspecionado — 21/10/2026

- Windows x64, Ryzen 5 3600 (6 núcleos / 12 threads), 15,9 GB RAM.
- Radeon RX 580 2048SP, aproximadamente 4 GB VRAM reportados pelo Windows.
- Espaço livre inicial: C: 45,2 GB, D: 111,1 GB.
- Git e Node presentes; nenhum Godot anterior encontrado em PATH ou diretórios usuais de programas/usuário inspecionados.
- Nenhum projeto Monster Fishing anterior encontrado nas pastas inspecionadas. Outros projetos foram preservados.
- Godot 4.7.2 estável, Standard portátil x86_64, baixado do link de Windows no site oficial. Extraído localmente em tools/godot, sem instalador, autenticação ou privilégios administrativos.
- Página de origem: https://godotengine.org/download/windows/
- URL: https://downloads.godotengine.org/?flavor=stable&platform=windows.64&slug=win64.exe.zip&version=4.7.2
- Execução confirmou versão `4.7.2.stable.official.ed1daf0bf`.
- Compatibility/OpenGL, MSAA 2x, resolução base 1440×900 / janela 1280×800. Escolha conservadora para este hardware; medir o desempenho real antes de migrar para efeitos mais pesados.

O executável standalone exportado e os export templates não foram necessários. Jogar.cmd usa o motor portátil para executar o projeto diretamente.
