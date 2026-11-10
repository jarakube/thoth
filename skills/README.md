# Skills

This directory contains [OpenCode](https://opencode.ai) skills that are copied
into the container image at build time.

```
skills/<skill-name>/SKILL.md   ->  /home/appuser/.config/opencode/skills/<skill-name>/SKILL.md
```

The `Dockerfile` bundles everything under `skills/` into
`/home/appuser/.config/opencode/skills/`, which is OpenCode's global skill
location for the in-container `appuser`.

## What ships in the image

| Skill | Purpose |
|-------|---------|
| `ceph` | Production-oriented Ceph expert persona: RADOS, RGW, dynamic bucket sharding, Rook on Kubernetes, OpenStack integration |

The `ceph` skill is intentionally generic: it demonstrates the expected
`SKILL.md` format (YAML frontmatter with `name` and `description`, followed by
markdown instructions) without referencing any private infrastructure.

## Adding your own skills

1. Create `skills/<your-skill>/SKILL.md`:

   ```markdown
   ---
   name: my-skill
   description: One-line description of when to use this skill.
   ---

   # My Skill

   Instructions for the agent ...
   ```

2. Rebuild the image:

   ```bash
   docker build -t thoth .
   ```

3. Verify inside the container:

   ```bash
   docker run --rm -it agent bash -c 'ls ~/.config/opencode/skills/'
   ```

## Mapping skills into the container without rebuilding

Build-time bundling is convenient but not the only option. Any of the
following work at runtime, with no image rebuild:

| Method | How | Best for |
|--------|-----|----------|
| **Bind mount** (recommended) | `docker run -v "$(pwd)/my-skills:/home/appuser/.config/opencode/skills:ro" ...` | Development: edit skills on the host, reload instantly |
| **Volume** | `docker volume create agent-skills` then mount it at `/home/appuser/.config/opencode/skills` | Long-lived skill collections shared across containers |
| **Kubernetes ConfigMap** | Mount a ConfigMap at `/home/appuser/.config/opencode/skills` (or use ` projected volumes` to combine ConfigMap + image content) | Cluster deployments; version skills via GitOps |
| **Kubernetes PVC** | Persistent volume mounted at the same path | Large skill packs or skills generated at runtime |
| **`docker cp`** | `docker cp my-skill running-container:/home/appuser/.config/opencode/skills/` | Quick experimentation in a running container |
| **Custom `FROM` image** | `FROM thoth:latest` + `COPY my-skills/ /home/appuser/.config/opencode/skills/` | Derived, opinionated images that bake in your skills |
| **Git clone at startup** | Mount a script/entrypoint hook that clones your skills repo into the skills dir | Keeping skills in their own repository with independent versioning |

### Notes on Kubernetes mounts

When you mount a ConfigMap or volume over `/home/appuser/.config/opencode/skills`,
it **shadows** the image-bundled skills. To combine both, use a `projected`
volume:

```yaml
volumes:
  - name: skills
    projected:
      sources:
        - configMap:
            name: my-extra-skills
      # image-bundled skills are not directly projectable; for combined
      # setups, copy the bundled skills into the ConfigMap or use an init
      # container that merges them into an emptyDir.
```

A common pattern for merging image skills with dynamic skills:

```yaml
containers:
  - name: agent
    volumeMounts:
      - name: merged-skills
        mountPath: /home/appuser/.config/opencode/skills
initContainers:
  - name: copy-bundled-skills
    image: agent:latest
    command: ["cp", "-r", "/home/appuser/.config/opencode/skills/.", "/skills/"]
    volumeMounts:
      - name: merged-skills
        mountPath: /skills
```

(Add a second init container or projected source that also writes your
dynamic skills into `merged-skills`.)

## Keeping private skills out of the open-source image

If you maintain organization-specific skills (internal tooling, private
repositories, customer systems), keep them in a separate private repository and
map them into the container at runtime using one of the methods above. Never
add them to this repository's `skills/` directory - the build copies everything
it finds there into the public image.

A typical split:

- **Public repo (this one)**: generic skills (`ceph`), image, scripts, docs.
- **Private repo (yours)**: `skills/<org-skill>/SKILL.md` + supporting files,
  mounted at runtime or baked into a private `FROM`-derived image.
