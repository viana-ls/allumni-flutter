# Allumni Flutter

Aplicativo Flutter que substitui o frontend web do Allumni. Ele usa a API Node/Express/SQLite existente no repositório `alumni-backend`.

## Funções incluídas

- Login e cadastro.
- Sessão persistida no aparelho.
- Perfil editável.
- Vagas e candidatura.
- Eventos e palestras.
- Grupos e entrada em comunidades.
- Configuração da URL da API no login.

## Gerar APK

1. Instale Flutter 3.22+ e Android Studio/SDK.
2. Dentro desta pasta, execute `flutter create .` para gerar as pastas nativas Android/iOS.
3. Execute `flutter pub get`.
4. Inicie o backend Allumni em um computador ou servidor acessível.
5. No aparelho físico, informe no login a URL da API, por exemplo `http://192.168.0.10:3000/api`. Não use `localhost`.
6. Execute `flutter build apk --release`.

O APK será criado em `build/app/outputs/flutter-apk/app-release.apk`.

## Gerar sem computador (GitHub Actions)

O arquivo `.github/workflows/build-apk.yml` gera o APK automaticamente em uma máquina Linux x64 do GitHub. Envie esta pasta para um repositório GitHub, abra a aba **Actions**, escolha **Gerar APK Allumni**, clique em **Run workflow** e baixe o artefato `allumni-release-apk` quando finalizar.

## Observação de segurança

Antes de publicar, a API deve receber autenticação por token (JWT), autorização no servidor e remoção das credenciais padrão de administrador.
