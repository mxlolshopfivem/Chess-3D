# Commands

### Add Chess Boards

| Command | Description |
|---------|-------------|
| `/addboard 1` | Adds a chess board to the ground (runtime). |
| `/addboard 2` | Adds a table, chairs, and the chess board (runtime). |

### Get Board Information

| Command | Description |
|---------|-------------|
| `/addboardInfo 1` | Prints the board information to the F8 console so you can create a static prop in the config. |
| `/addboardInfo 2` | Prints the table, chairs, and board information to the F8 console so you can create the static props in the config. |

---

# Installation

## 1. Download the Chess Props

Download **bzzz_chess** from the Cfx.re forum:

https://forum.cfx.re/t/props-chess-for-scripters/5409605

## 2. Start the Resources

Add the following to your `server.cfg`:

```cfg
ensure bzzz_chess
ensure chess3d
```

Rename `chess3d` to the name of the folder where you placed the resource.
