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

## Painel de administrador

Contas admin gerenciam **notícias, vagas, eventos e grupos** direto pelo app (Firestore, projeto `alumni-d1a49`).

1. No console do Firebase, abra `Firestore Database > usuarios > {documento do usuário}`.
2. Adicione o campo `admin` (tipo **boolean**) com valor `true`.
3. Entre no app com essa conta: aparece o ícone de escudo na barra superior. Ele abre o painel com uma aba por coleção (adicionar, editar e excluir).

Coleções usadas: `noticias` (`titulo`, `resumo`, `conteudo`, `imagem`, `imagens`, `autor`, `criado_em`), `vagas`, `eventos`, `grupos`.

Imagens de notícia: o projeto não tem Firebase Storage, então a foto escolhida da galeria é redimensionada e salva no próprio documento (data URI, máx. 600 KB). Também é possível usar o link de uma imagem. Admins veem o botão **Editar notícia** em cada notícia da tela Início.

> **Segurança:** o app usa login próprio na coleção `usuarios` (sem Firebase Auth) e o `firestore.rules` atual libera leitura/escrita para todos. Portanto o flag `admin` só esconde o painel na interface; não impede escrita direta no Firestore. Para proteger de verdade, migre o login para Firebase Auth e restrinja as regras por `request.auth`.
