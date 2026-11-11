# First person: the eyes, the mouse, the look (2026-11-10)

**Status:** BUILT (0.46.0). Numbers in `configs/View.luau`; code in `Client/Controllers/ViewController`.

## What the developer asked for

The whole game "full screen", as the Roblox game DOORS is: you play through the character's eyes, in the lobby and in
the castle; the mouse is always held and turns the head; **L** lets the mouse go and takes it back; when a friend looks
right and left you see their head do it; and an opening that puts the player in the mood. The mouse lock switch of
0.45.0 is gone (there is nothing to switch).

## How it works

| Thing | How | Where |
|---|---|---|
| The camera | `Player.CameraMode = LockFirstPerson`, zoom held at the eyes. Roblox's own camera looks and turns the body (the engine turns it: nothing sets the body's place by script, which is what stuttered in 0.45.0). | `ViewController`, `CameraController`, `AvatarService` (server side too) |
| The eyes' place | 0.2 up and 0.34 forward of the head's middle: looking down shows chest and legs, never the inside of the neck. It must stay INSIDE the head, or the camera would see through walls. | `View.Eye` |
| Your own body | Roblox hides all of it in first person; every part but the head and what is worn on it is shown again each frame. Hidden for the length of a dash. | `ViewController` (`showBody`) |
| The step | the eyes move with each footfall (from the walk's own step, so feet and picture agree), dip on a landing, lean a little into a sidestep. HEAD BOB in Settings turns the stepping off. | `View.Bob` |
| A dash | the eyes go down 0.85 and come up, the view is 8 degrees wider for a moment, the picture leans away from a dash to the side. | `View.Dash`, `ViewController.dash` |
| Field of view | 80 to start; 60 to 100 in Settings. Running adds 4. | `View.Fov` |
| The dot | 4 pixels, cream with a dark edge, in the true middle. Hidden while the mouse is free, in a scene, and when dead. | `View.Dot` |

**The mouse.** Held in the middle. **L** frees it and takes it back. It is also freed, by itself, whenever a screen of
order 15 or above is showing a BUTTON (the Settings, the Muster Roll, the forge, the chapel, the train's board, the
arrival scene's SKIP), and when the pack is open; taken back when they close. Other controllers ask
`ViewController.isFree()` before treating a click as a blow. (It is done with a 2-pixel unseen `Modal` button in the
corner of the screen: that is how Roblox lets the mouse go in first person. It must be ON the screen: at -10,-10 it did
nothing.)

**The lines.** While L has the mouse free, small lines stand above the weapon bar, each a thing to do with it:
"Hang the lantern on your belt", "Carry the quiver on your back". A controller adds one with
`ViewController.chip(id, text, click)`; `text` returning nil hides it. Under them: "Press L to lock your mouse". For
twelve seconds after you get a body: "Press L to unlock your mouse".

**The look.** Each client sends where its player looks, up and down, 12 times a second and only when it changes
(`LookSync`, an event that may lose one). The server passes it to the others (`MovementService`, 15 a second at most).
Every client then leans that player's chest (a third of the angle) and head (half of it), and turns the head a little
ahead of a turning body (0.14 s of the turn, 38 degrees at most): a friend looking round is seen to look round. A weapon
in the hands follows the eyes too (a drawn bow wholly: the arrow goes where the eyes are).

**Opening the eyes.** Black; a slit; shut; half; a small last blink; open, over 4.2 seconds, while a blur clears and the
view settles from narrow (52) to the player's own. In the castle after the arrival scene (`IntroController` tells the
view when a scene begins and ends), in the lobby after the title. The player can already walk.

**Scenes.** Anything that sets the camera to Scriptable (the arrival, a death, the train) is left alone: the view code
only works while the camera is Roblox's own.

## Learned while building (2026-11-11)

- Measuring from the Studio tool: a tool call that begins while the camera is Scriptable and ends after it became
  Custom is "put back" to Scriptable by the tool, and the view then stands back for good. Skip the arrival scene in one
  short call, look in another.
- With the screen locked, Studio draws nothing: RenderStepped never fires, the loading screen never finishes, and a
  capture times out. The simulation still runs.

## Still to do

- Two players: see a friend's head follow their look, and a friend's roll, with eyes.
- A phone: the lines of the free mouse need a touch way in (there is no L).
- A lantern held in the hand is low in the picture (it hangs 1.2 studs under the fist): judge it in the dark places.
