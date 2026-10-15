# ADR 0003 — Projeto Xcode com pastas sincronizadas

**Status:** Accepted · 2026-10-14

## Contexto
Agentes de código criam e movem arquivos o tempo todo. No formato clássico do `.pbxproj`, cada
arquivo novo exige editar o projeto à mão (IDs, grupos, build phases), o que gera erros e conflitos de merge.

## Decisão
- Xcode 16+, `objectVersion = 77`, com `PBXFileSystemSynchronizedRootGroup` para `SamsungRemote/` e `SamsungRemoteTests/`.
  Qualquer arquivo criado nessas pastas entra no target automaticamente.
- `Info.plist` parcial e entitlements ficam em `Config/`, fora das pastas sincronizadas, para não virarem resource.
- Scheme compartilhado em `xcshareddata/` para `xcodebuild -scheme SamsungRemote` funcionar no CLI.
- Sem XcodeGen/Tuist: o `pbxproj` é pequeno e estável.

## Consequências
- Exige Xcode 16 ou mais novo.
- Arquivos que não devem ir para o bundle (docs, scripts) ficam fora de `SamsungRemote/`.
