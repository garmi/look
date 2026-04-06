# TestFlight Readiness

This repo is now prepared for a first private TestFlight pass.

## Included in the app package
- branded `AppIcon` asset catalog
- versioned build settings in `project.yml`
- camera and photo library usage strings
- supported interface orientations for iPhone and iPad
- document upload fallback mode so testers are not blocked by missing AI keys

## Manual steps before upload
1. Open `LOOKPOC.xcodeproj` in Xcode.
2. Select the `LOOKPOC` target.
3. In `Signing & Capabilities`:
   - choose your Apple Developer Team
   - confirm a unique bundle identifier
4. In `General`:
   - confirm version `0.9.0`
   - increment build number for each TestFlight upload
5. In App Store Connect:
   - create the app record if it does not exist
   - add app name, subtitle, description, and privacy details
   - upload the first archive from Xcode Organizer
6. Add internal testers first.
7. After internal validation, add external testers and complete beta review details.

## Recommended first beta scope
Use this first release as a closed workflow beta.
Ask testers to do only these tasks:
- complete onboarding/profile
- do one morning check-in
- confirm one medication event
- save one question
- upload one blood report or prescription
- review the Insights tab
- send structured feedback

## Important current limitation
Document upload works in `beta mode` when secure AI parsing is not configured.
That means:
- the document flow is testable
- placeholder records can be saved
- real extraction should move to a backend service before wider rollout

## Suggested TestFlight release notes
LOOK beta is focused on daily transplant support workflows:
- morning check-ins
- medication tracking
- doctor questions
- daily logs
- trend insights
- document upload flow

Please use the app normally and note anything confusing, missing, or unsafe.
