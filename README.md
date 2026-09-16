# cornell.nvim

A lightweight Cornell Notes workflow for Markdown files in Neovim.

## Features

- `## Cues` / `## Questions`
- `## Notes`
- `## Summary`
- QID format such as `[Q1]`, `[Q2]`, ...
- Automatically creates a Note block when a new Cue is added.
- Automatically synchronizes Note titles with Cue text.
- Cursor synchronization between Cues and Notes.
- Cue alignment using virtual lines.
- Review mode.
- Summary pane.
- Document consistency check.
- Writes the edited Cornell document back to the original Markdown buffer.
- Does not restore the source buffer when the user has already switched to an external buffer.

## Installation with lazy.nvim

```lua
{
  "ocsiker/cornell.nvim",
  ft = "markdown",
  opts = {
    cues_width = 32,
    summary_height = 8,
    content_padding = 4,
    qid_prefix = "Q",

    highlights = {
      cue = "Identifier",
      note = "Title",
      summary = "String",
      qid = "Special",
      heading = "Title",
      separator = "WinSeparator",
      review = "WarningMsg",
    },
  },
}
```

## Local development

```lua
{
  "cornell.nvim",
  dir = vim.fn.stdpath("config") .. "/local-plugins/cornell.nvim",
  ft = "markdown",
  opts = {},
}
```

## Commands

```text
:Cornell
:CornellOpen
:CornellClose
:CornellReview
:CornellCheck
:CornellSummary
```

## Default mappings

```text
<leader>cv  Toggle Cornell
<leader>cq  Add question
<leader>ca  Open answer
<leader>cr  Review
<leader>cs  Toggle Summary
<leader>cc  Focus Cues
<leader>cn  Focus Notes
<CR>        Jump between Cue and Note
<C-s>       Save
q           Close Cornell
```

## Markdown format

```markdown
# Photosynthesis

Some introduction here.

## Cues

- [Q1] What is photosynthesis?
- [Q2] Where does photosynthesis occur?

## Notes

### [Q1] What is photosynthesis?

Photosynthesis is the process by which plants convert light energy...

### [Q2] Where does photosynthesis occur?

It mainly occurs in chloroplasts.

## Summary

Photosynthesis converts light energy into chemical energy.
```

`## Questions` is accepted as an input alias for `## Cues`; when saving, the document is normalized to `## Cues`.

## Public API

```lua
local cornell = require("cornell")

cornell.setup({})
cornell.open()
cornell.close()
cornell.toggle()
cornell.save()
cornell.review()
cornell.check()
cornell.summary()
```
