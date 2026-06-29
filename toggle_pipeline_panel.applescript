(*
  Code Visualizer — Pipeline Panel Toggle

  1. Enable: System Settings → Privacy & Security → Accessibility → [Terminal]
  2. Run: osascript toggle_pipeline_panel.applescript

  Targets the first visible stage card in Pipeline Visualization
  and clicks it to toggle selection (collapse/expand the side panel).
  Falls back to the Inspector toolbar button.
*)

tell application "Code Visualizer"
    activate
end tell
delay 0.5

tell application "System Events"
    tell process "CodeVisualizer"
        set frontmost to true
        delay 0.3

        try
            -- Strategy A: find the stage description text and click its container
            set stageCards to every group of window 1 whose description contains "Loading data from file or API"
            if (count of stageCards) > 0 then
                click (item 1 of stageCards)
            else
                -- Strategy B: click text directly (SwiftUI forwards to gesture)
                set stageLabels to every static text of window 1 whose value contains "Loading data from file or API"
                if (count of stageLabels) > 0 then
                    click (item 1 of stageLabels)
                else
                    -- Strategy C: Inspector toolbar button
                    click (first button of window 1 whose description is "Inspector")
                end if
            end if
        on error errMsg
            try
                click (first button of window 1 whose description is "Inspector")
            end try
        end try
    end tell
end tell
