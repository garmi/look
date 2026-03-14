# LOOK iOS POC

This repository is now the main workspace for the LOOK iOS proof of concept.

The app is an offline-first `SwiftUI` + `SwiftData` prototype for daily personal trials. It lets you capture transplant-related questions, test a local triage flow, browse starter knowledge and directory data, and log daily friction so we can improve the product from real usage.

## What Supabase Sync Would Do

Option `2` from earlier means adding `Supabase` as the backend so the app stops being local-only.

With Supabase in place, the app could:
- back up your profile, questions, and daily trial logs across Mac and iPhone
- let us keep a shared content library and doctor directory without shipping a new app build each time
- support sign-in, cloud storage, and simple admin workflows
- become the foundation for later AI features, WhatsApp intake, and analytics

For this POC, Supabase is not required yet. Right now everything is stored on-device, which keeps iteration fast and low-risk. We should add Supabase when you want sync, backup, or remotely editable content.

## Current App Flow

```mermaid
flowchart TD
    A["Open app"] --> B["Update profile context"]
    B --> C["Ask a question"]
    C --> D["Local triage engine"]
    D --> E["Save guidance locally"]
    D --> F["Use directory and seed knowledge"]
    E --> G["Log daily trial"]
    F --> G
    G --> H["Review patterns and improve"]
```

## Current Architecture

```mermaid
flowchart LR
    UI["SwiftUI Screens"] --> VM["View State"]
    VM --> TE["TriageEngine"]
    VM --> KR["KnowledgeRepository"]
    VM --> SD["SwiftData"]
    SD --> UI
```

## Run It

For iPhone setup and general Xcode launch:

```bash
cd "/Users/gauravm/Documents/New project"
./run-ios.sh
```

That script:
- regenerates `LOOKPOC.xcodeproj` from `project.yml`
- opens the Xcode project

For a Mac-focused daily flow:

```bash
cd "/Users/gauravm/Documents/New project"
./run-mac.sh
```

That script:
- regenerates `LOOKPOC.xcodeproj` from `project.yml`
- opens the Xcode project
- reminds you to choose the Mac runtime

From Xcode:
1. Choose `My Mac (Designed for iPad/iPhone)` to run on Mac.
2. Choose your connected iPhone to run on device.
3. Press `Cmd+R`.

## Daily Trial Loop

1. Capture at least one real question in `Ask`.
2. Check if the triage output feels useful.
3. Record the biggest friction in `Trials`.
4. Write one concrete improvement for tomorrow.
5. Repeat daily and review weekly.
