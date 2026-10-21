# Logbook

This is yours. It is what makes the course *your* course.

**What to write down:** what you did not understand the first time · the error message you could not read · what you believed about containers that turned out to be different · what surprised you · the numbers you measured (sizes, times).

**Why it matters:** in two weeks you will not remember what was hard for you. And what was hard for you is exactly what you need to review.

---

## Lesson 0 — What a container is and what it is NOT

_date:_

- What I thought a container was:
- In my own words, the difference between an image and a container:
- What surprised me:

## Lesson 1 — Installing Docker on your Linux Mint

_date:_

- Versions I got (`docker version`, `docker compose version`):
- The permission error I triggered on purpose and how I read it:
- Did I have conflicting packages? Which ones:

## Lesson 2 — Containers in day-to-day work

_date:_

- A container I left running without realizing it:
- What changes between `-p 8080:8080` and `-p 127.0.0.1:8080:8080` (I checked it with `ss -ltn`):

## Lesson 3 — Your first Dockerfile

_date:_

- Size of `revisor:1.0.0`: ____ MB
- What `docker build --check` warned me about:
- How long `docker stop` takes with the *shell* form and with the *exec* form: ____ s and ____ s

## Lesson 4 — Layers, cache and context

_date:_

- Rebuild before reordering: ____ s → after: ____ s
- Context size with and without `.dockerignore`:
- The heaviest layer of my image (`docker history`):

## Lesson 5 — Multi-stage: from gigabytes to megabytes

_date:_

- Size before: ____ → after: ____
- The "no such file or directory" error I saw with the non-static binary and why:
- What I pinned on the base: version, *digest* or both:

## Lesson 6 — Configuration and secrets

_date:_

- A secret I put in `ENV` and where I found it afterward:
- How I passed it to the `revisor` the right way:

## Lesson 7 — Health checks and lifecycle

_date:_

- States I saw in the healthcheck (`starting`, `healthy`, `unhealthy`) and what caused them:
- What broke when I made the filesystem read-only and how I solved it:
- Capabilities that the `revisor` did not need:

## Lesson 8 — Volumes and networks

_date:_

- What disappeared when I mounted a volume over a directory with content:
- The permission error that kept me from writing to the volume and how I fixed it without going back to `root`:
- Name by which the `revisor` found the other container:

## Lesson 9 — Compose: the complete system

_date:_

- What happened when I removed the `service_healthy` condition:
- What differences I found between my `compose.yaml` and the one `docker init` generated:

## Lesson 10 — Delivering the image

_date:_

- Vulnerabilities the scan found and which ones really matter to me:
- The tag and *digest* of my final image:
- What I still need to take it to Kubernetes:

---

## What I want to build next

_The list of things that occur to you as you go along. It is the best sign that the course worked._

-
