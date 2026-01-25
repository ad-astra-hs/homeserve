# Homeserve 🏠

A selfhosted webcomic server built with Gleam. Designed to be simple for the tech oriented, and not too complex for the layman.

## What it does

Homeserve lets you:
- Serve webcomics from simple markdown files
- Add images, videos, and audio to your comics
- Keep track of contributors with a Hall of Fame
- Customize any panels with CSS and JavaScript

## How it works

Write your story in markdown with a bit of YAML at the top:

```yaml
---
title: "My Awesome Comic"
media:
  kind: "image"
  url: "..etc../panel1.jpg"
  alt: "First panel!"
...
---
Your name is...
```

Homeserve turns these files into a nice web experience with:
- Smooth navigation between panels
- Media players for your audio/video
- A clean, responsive design
- Contributor credits

## Getting started

1. Install Gleam
2. Clone this repo
3. Run `gleam run`
4. Visit `http://localhost:8000`

That's it! Your comics are now serving.

Built with Gleam → Erlang/BEAM for concurrency and reliability. Uses smart caching so it stays fast even with lots of panels.

More robust documentation and contributing guidelines coming soon.
