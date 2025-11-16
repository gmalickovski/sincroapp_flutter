# Compatibilidade de Versões - SincroApp Flutter

## Contexto

Este documento descreve as alterações feitas nas versões dos pacotes para garantir compatibilidade com **Flutter SDK 3.27.1** e **Dart SDK 3.5.4** usados no servidor VPS.

## Problema

O ambiente de desenvolvimento local usa versões mais recentes (Flutter 3.35.7, Dart 3.9.2), mas o VPS usa Flutter 3.27.1 com Dart 3.5.4. Vários pacotes no `pubspec.yaml` requerem Dart SDK >= 3.7.0, causando falhas durante `flutter pub get` no servidor.

## Solução

Os scripts de deploy (`install.sh` e `update.sh`) agora aplicam patches automáticos no `pubspec.yaml` após clonar/atualizar o repositório, garantindo compatibilidade com o ambiente do servidor.

Total de pacotes corrigidos: **15**

## Versões Ajustadas

### Pacotes Core

| Pacote | Versão Original | Versão Compatível | Motivo |
|--------|----------------|-------------------|--------|
| `collection` | ^1.19.1 | ^1.18.0 | flutter_test SDK requer 1.18.0 |
| `google_sign_in` | ^7.2.0 | ^6.2.1 | Requer Dart >= 3.7.0 |
| `google_fonts` | ^6.3.2 | ^6.1.0 | Requer Dart >= 3.7.0 |
| `table_calendar` | ^3.2.0 | ^3.1.3 | Requer intl ^0.20.0 mas flutter_localizations SDK usa 0.19.0 |

### Pacotes Firebase

| Pacote | Versão Original | Versão Compatível | Motivo |
|--------|----------------|-------------------|--------|
| `firebase_core` | ^4.2.0 | ^3.6.0 | Compatibilidade com Dart 3.5.4 |
| `firebase_auth` | ^6.1.1 | ^5.3.1 | Compatibilidade com Dart 3.5.4 |
| `cloud_firestore` | ^6.0.3 | ^5.4.4 | Compatibilidade com Dart 3.5.4 |
| `firebase_ai` | ^3.4.0 | ^2.3.0 | Compatibilidade com Dart 3.5.4 |
| `firebase_app_check` | ^0.4.1+1 | ^0.3.1+2 | Compatibilidade com Dart 3.5.4 |
| `cloud_functions` | ^6.0.3 | ^5.1.3 | Compatibilidade com Dart 3.5.4 |
| `firebase_messaging` | ^16.0.3 | ^15.1.3 | Compatibilidade com Dart 3.5.4 |

### Notificações

| Pacote | Versão Original | Versão Compatível | Motivo |
|--------|----------------|-------------------|--------|
| `flutter_local_notifications` | ^18.0.1 | ^17.2.3 | Compatibilidade com Dart 3.5.4 |
| `timezone` | ^0.10.0 | ^0.9.4 | Compatibilidade com Dart 3.5.4 |

### Dev Dependencies

| Pacote | Versão Original | Versão Compatível | Motivo |
|--------|----------------|-------------------|--------|
| `flutter_lints` | ^4.0.0 | ^3.0.2 | Compatibilidade com Dart 3.5.4 |

## Implementação

### Scripts Automatizados

Os patches são aplicados automaticamente via `sed` nos arquivos:

1. **deploy/install.sh** (Step 9) - 15 patches
2. **deploy/update.sh** (Step 6) - 15 patches

Exemplo de patch:
```bash
sed -i 's/firebase_core: \^4\.2\.0/firebase_core: ^3.6.0/' "$INSTALL_DIR/pubspec.yaml"
```

### Verificação Local

Para testar localmente com as versões compatíveis:

```bash
flutter pub get
flutter pub outdated
```

## Notas Importantes

1. **Ambiente de Desenvolvimento**: No Windows, o projeto usa as versões mais recentes dos pacotes (definidas no `pubspec.yaml` do repositório)

2. **Ambiente de Produção (VPS)**: Os scripts de deploy aplicam os patches automaticamente antes de executar `flutter pub get`

3. **Sem Conflito**: As alterações não precisam ser commitadas no Git, pois são aplicadas dinamicamente durante o deploy

4. **Atualizações Futuras**: Ao atualizar o Flutter no VPS para uma versão com Dart >= 3.7.0, os patches podem ser removidos dos scripts

## Validação

Após aplicar os patches, o comando `flutter pub get` deve executar sem erros:

```
Resolving dependencies...
Got dependencies!
```

## Manutenção

Se novos pacotes forem adicionados e causarem conflitos de versão:

1. Identificar a versão compatível com Dart 3.5.4
2. Adicionar novo comando `sed` nos scripts `install.sh` e `update.sh`
3. Testar no VPS antes de commitar

## Referências

- Flutter SDK 3.27.1: https://docs.flutter.dev/release/archive
- Dart SDK 3.5.4: https://dart.dev/get-dart/archive
- Pub.dev versioning: https://pub.dev/help
