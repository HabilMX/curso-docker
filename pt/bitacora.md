# Diário de bordo

Isto é pessoal. É o que faz do curso o *próprio* curso.

**O que anotar:** o que não se entendeu de primeira · a mensagem de erro que não se soube ler · o que se achava dos contêineres e acabou sendo diferente · o que surpreendeu · os números medidos (tamanhos, tempos).

**Por que importa:** em duas semanas a gente não vai lembrar o que foi difícil. E o que foi difícil é exatamente o que precisa ser revisado.

---

## Lição 0 — O que é um contêiner e o que NÃO é

_data:_

- O que eu achava que era um contêiner:
- Com as minhas palavras, a diferença entre imagem e contêiner:
- O que me surpreendeu:

## Lição 1 — Instalar o Docker no Linux Mint

_data:_

- Versões que obtive (`docker version`, `docker compose version`):
- O erro de permissões que provoquei de propósito e como o interpretei:
- Eu tinha pacotes em conflito? Quais:

## Lição 2 — Contêineres no dia a dia

_data:_

- Um contêiner que deixei rodando sem perceber:
- O que muda entre `-p 8080:8080` e `-p 127.0.0.1:8080:8080` (comprovei com `ss -ltn`):

## Lição 3 — O primeiro Dockerfile

_data:_

- Tamanho de `revisor:1.0.0`: ____ MB
- O que `docker build --check` me avisou:
- Quanto demora `docker stop` com a forma *shell* e com a forma *exec*: ____ s e ____ s

## Lição 4 — Camadas, cache e contexto

_data:_

- Reconstrução antes de reordenar: ____ s → depois: ____ s
- Tamanho do contexto com e sem `.dockerignore`:
- A camada mais pesada da minha imagem (`docker history`):

## Lição 5 — Multi-stage: de gigabytes a megabytes

_data:_

- Tamanho antes: ____ → depois: ____
- O erro de “no such file or directory” que vi com o binário não estático e por quê:
- O que fixei da base: versão, *digest* ou os dois:

## Lição 6 — Configuração e segredos

_data:_

- Um segredo que coloquei em `ENV` e onde o encontrei depois:
- Como o passei ao `revisor` da forma correta:

## Lição 7 — Verificação de saúde e ciclo de vida

_data:_

- Estados que vi no healthcheck (`starting`, `healthy`, `unhealthy`) e o que os provocou:
- O que quebrou quando coloquei o sistema de arquivos em somente leitura e como resolvi:
- Capacidades de que o `revisor` não precisava:

## Lição 8 — Volumes e redes

_data:_

- O que desapareceu quando montei um volume sobre um diretório com conteúdo:
- O erro de permissão ao escrever no volume e como a corrigi sem voltar a `root`:
- Nome com o qual o `revisor` encontrou o outro contêiner:

## Lição 9 — Compose: o sistema completo

_data:_

- O que aconteceu quando removi a condição `service_healthy`:
- Que diferenças encontrei entre o meu `compose.yaml` e o que `docker init` gerou:

## Lição 10 — Entregar a imagem

_data:_

- Vulnerabilidades que a varredura encontrou e quais me importam de verdade:
- A tag e o *digest* da minha imagem final:
- O que me falta para levá-la ao Kubernetes:

---

## O que quero construir depois

_A lista de ideias que surgirem enquanto a gente avança. É o melhor sinal de que o curso funcionou._

- 
