# github-desktop-remote-hosts

**Русский** | [English](README.en.md)

Патч для установленного GitHub Desktop (Windows), который включает пункты меню для репозиториев не на GitHub — GitLab (в т.ч. self-hosted), Bitbucket, Gitea/Codeberg/Forgejo:

| Пункт меню | GitLab | Bitbucket | Gitea |
|---|---|---|---|
| Repository → View on … | `<repo>` | `<repo>` | `<repo>` |
| Repository → Create issue on … | `/-/issues/new` | `/issues/new` | `/issues/new` |
| Branch → View branch on … | `/-/tree/<branch>` | `/src/<branch>` | `/src/branch/<branch>` |
| Branch → Compare on … | `/-/compare/<default>...<branch>` | `/branches/compare/<branch>%0D<default>` | `/compare/<default>...<branch>` |
| History → коммит → View on … | `/-/commit/<sha>` | `/commits/<sha>` | `/commit/<sha>` |
| History → файл коммита → View on … | `/-/commit/<sha>#<SHA-1 пути файла>` | `/commits/<sha>` | `/commit/<sha>` |
| Список репозиториев → View on … (только у выбранного репозитория) | `<repo>` | `<repo>` | `<repo>` |

Адрес страницы берётся из URL remote'а (`https://…`, `git@host:…`, `ssh://…:port/…`), название в меню — по хосту (GitLab, Bitbucket, …). Про остальные хосты GitHub Desktop один раз в фоне спрашивает сервер `/api/v1/version`: если отвечает Gitea/Forgejo (в т.ч. «Only signed in user is allowed…» на закрытом сервере) — это Gitea, иначе GitLab. Ответ запоминается; пока сервер не ответил, хост считается GitLab (подпись в меню обновится при следующем обновлении состояния репозитория). На экране «No local changes» появляется карточка «Open the repository page on … in your browser». Для GitHub-репозиториев поведение не меняется.

Пункты Branch → … включаются только для опубликованной ветки; если ветка по умолчанию неизвестна, в Compare подставляется `main`.

«Create pull request» не трогается — он работает через GitHub API.

## Установка

Распаковать архив, закрыть GitHub Desktop и запустить `patch.bat`. Ничего ставить не нужно — скрипт на PowerShell, который есть в Windows 10/11.

Патчится самая новая папка `%LOCALAPPDATA%\GitHubDesktop\app-x.y.z`; можно указать путь явно:

```
patch.bat C:\Users\<user>\AppData\Local\GitHubDesktop\app-3.6.11
```

**После каждого обновления GitHub Desktop патч надо применить заново** — обновление ставит новую папку `app-x.y.z`. Запускать повторно (и ставить новую версию патча поверх старой) безопасно: патчится всегда оригинал из `.orig`.

## Откат

```
patch.bat -Restore
```

Оригиналы лежат рядом с пропатченными файлами как `main.js.orig` / `renderer.js.orig`.

## Как это устроено

Всё в одном файле `patch.ps1` (`patch.bat` только запускает его):

1. `$helpers` — обычный JavaScript: разбор URL remote'а и ссылки под GitLab/Bitbucket/Gitea. Дописывается в начало `resources/app/renderer.js` как `window.remoteHosts`.
2. `$mainChanges` / `$rendererChanges` — пары «было → стало» для минифицированных `main.js` (подписи пунктов меню) и `renderer.js` (включение пунктов, построение ссылок).

Минифицированные имена (`Mo`, `Vo`, `Lo`, …) в каждой версии GitHub Desktop свои, поэтому в «было» они записаны как `%Repository%`, `%CloningRepository%` и т.п. — скрипт сам находит, как они называются в установленной версии, и подставляет их в «стало».

Каждое «было» должно найтись ровно один раз — иначе скрипт ничего не меняет и пишет, что не нашлось. Тогда в этой версии GitHub Desktop поменялся сам код, и пару нужно поправить.

Проверено на GitHub Desktop 3.6.6, 3.6.7, 3.6.10 и 3.6.11.
