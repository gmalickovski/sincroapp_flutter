# Como Configurar Firebase App Check para Android (Debug Build)

## Problema Identificado
A IA funciona na web mas não no Android porque o **Firebase App Check** está bloqueando as requisições. Isso acontece porque estamos usando **debug signing keys** mas o App Check precisa de um **debug token registrado**.

## Solução: Registrar Debug Token no Firebase Console

### Passo 1: Executar o App e Obter o Debug Token

1. Instale o APK atualizado no seu Samsung S24+
2. Abra o app
3. Tente usar qualquer função de IA
4. Execute no PC:
```bash
adb logcat | findstr "DebugAppCheckProvider"
```

5. Você verá algo como:
```
D DebugAppCheckProvider: Enter this debug token into the Firebase console: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
```

6. **Copie esse token** (formato: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX)

### Passo 2: Registrar o Token no Firebase Console

1. Acesse: https://console.firebase.google.com/project/sincroapp-529cc/appcheck
2. Clique em **"App Check"** no menu lateral
3. Clique em **"Apps"** ou **"Gerenciar"**
4. Encontre **"sincro_app_flutter (android)"**
5. Clique em **"Gerenciar tokens de depuração"** ou **"Debug tokens"**
6. Clique em **"Adicionar token de depuração"**
7. Cole o token que você copiou
8. Dê um nome (ex: "Samsung S24+ Debug")
9. Clique em **"Salvar"**

### Passo 3: Testar

1. Force-close o app no smartphone
2. Abra o app novamente
3. Teste as funções de IA
4. Deve funcionar! ✅

## Configuração Atual (Verificada)

✅ SHA-1 registrado no Firebase: `72:c2:f9:b7:2b:29:57:db:c9:cb:da:53:9a:90:ee:4e:e8:66:cc:14`
✅ Package name correto: `com.example.sincro_app_flutter`
✅ `google-services.json` correto
✅ Firebase BoM configurado
✅ `main.dart` atualizado para usar `AndroidProvider.debug`

## Quando Publicar na Play Store

Quando você publicar o app na Play Store com certificado de produção:

1. Mude em `lib/main.dart` linha 109:
```dart
androidProvider: AndroidProvider.playIntegrity, // Mudar de .debug para .playIntegrity
```

2. Registre o SHA-1 do certificado de **produção** no Firebase Console

3. O App Check usará Play Integrity API automaticamente
