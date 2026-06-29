# GitHub Release Checklist

Use this checklist before publishing a public build.

## Recommended Monetization Setup

Best zero-website setup:

1. Keep the source code in a private repository.
2. Create a separate public repository named `code-visualizer-downloads` or `code-visualizer`.
3. Put only the README, screenshots, release notes, and downloadable app builds in the public repository.
4. Use GitHub Releases for versioned app files.
5. Use Gumroad, Lemon Squeezy, Stripe Payment Links, or Ko-fi for payments.
6. Deliver license keys or paid builds through the payment provider.

## Before Release

- [ ] Choose whether the public repo contains source code or only release/download material.
- [ ] Add product screenshots under `docs/assets/`.
- [ ] Build the app in release mode.
- [ ] Create a `.zip` or `.dmg` for distribution.
- [ ] Sign the app with an Apple Developer ID.
- [ ] Notarize the app with Apple.
- [ ] Test the downloaded build on a different Mac user account.
- [ ] Confirm the app opens notebooks from outside the project folder.
- [ ] Confirm the bundled sample notebook loads on first launch.
- [ ] Confirm Python backend files are included in the app bundle.
- [ ] Confirm payment page and license/delivery flow works.

## Suggested Release Assets

- `Code-Visualizer-v0.1.0-macOS.zip`
- `Code-Visualizer-v0.1.0-macOS.dmg`
- `flowchart.png`
- `pipeline.png`
- `inspector.png`
- `learn.png`

## GitHub Release Description

Copy from `docs/marketing-kit.md`, then add:

- macOS version requirement
- install instructions
- known limitations
- payment/unlock instructions if this is a paid release

